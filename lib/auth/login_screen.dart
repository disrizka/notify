import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notify/admin/admin_screen.dart';
import 'package:notify/api/api.dart';
import 'package:notify/karyawan/karyawan_screen.dart';


// ─── Warna tema biru (konsisten dengan home screen) ──────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryMd = Color(0xFF1976D2);
const _kPrimaryLt = Color(0xFF42A5F5);
const _kAccent = Color(0xFF0D47A1);
const _kBg = Color(0xFFF0F4FF);
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Email dan password tidak boleh kosong.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login'),
            body: {
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      // Cari bagian ini di fungsi _login() kamu
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 1. SIMPAN TOKEN
        await _storage.write(key: 'auth_token', value: data['access_token']);

        // 2. SIMPAN USER ID (WAJIB untuk fitur chat kanan-kiri)
        // Pastikan backend kamu mengirim data['user']['id']
        await _storage.write(
          key: 'user_id',
          value: data['user']['id'].toString(),
        );

        final role = data['user']['role'].toString().trim().toLowerCase();

        if (role == 'admin' || role == 'kepala') {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const TesAdminPage()),
          );
        } else if (role == 'karyawan' || role == 'staff') {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const KaryawanHomeScreen()),
          );
        } else {
          _showError('Role "$role" tidak dikenali sistem.');
        }
      } else {
        _showError(
          data['message'] ?? 'Login gagal. Periksa kembali data Anda.',
        );
      }
    } catch (_) {
      _showError('Gagal terhubung ke server. Pastikan koneksi internet aktif.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Background dekoratif ──────────────────────────────────
          _BackgroundDecor(size: size),

          // ── Konten utama ─────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: math.max(
                  size.height - MediaQuery.of(context).padding.top,
                  600,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),

                          // ── Logo / Icon ─────────────────────────
                          _LogoSection(),
                          const SizedBox(height: 36),

                          // ── Judul ───────────────────────────────
                          const Text(
                            'Selamat Datang',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: _kText,
                              height: 1.25,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Masuk untuk melanjutkan aktivitas kerja Anda.',
                            style: TextStyle(
                              fontSize: 14,
                              color: _kSub,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Form Card ───────────────────────────
                          _FormCard(
                            emailCtrl: _emailController,
                            passwordCtrl: _passwordController,
                            obscurePassword: _obscurePassword,
                            onToggleObscure:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                            isLoading: _isLoading,
                            onLogin: _login,
                          ),

                          const Spacer(),

                          // ── Footer ──────────────────────────────
                          Center(
                            child: Text(
                              'Hubungi admin jika lupa password',
                              style: TextStyle(
                                fontSize: 12,
                                color: _kSub.withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background dekoratif lingkaran ──────────────────────────────────────────
class _BackgroundDecor extends StatelessWidget {
  final Size size;
  const _BackgroundDecor({required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Lingkaran besar kanan atas
        Positioned(
          top: -size.width * 0.3,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.75,
            height: size.width * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kPrimaryMd.withOpacity(0.18), Colors.transparent],
              ),
            ),
          ),
        ),
        // Lingkaran kecil kiri bawah
        Positioned(
          bottom: size.height * 0.05,
          left: -size.width * 0.15,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kPrimaryLt.withOpacity(0.12), Colors.transparent],
              ),
            ),
          ),
        ),
        // Titik-titik dekoratif
        Positioned(
          top: size.height * 0.15,
          right: 28,
          child: _DotGrid(color: _kPrimary.withOpacity(0.12)),
        ),
      ],
    );
  }
}

class _DotGrid extends StatelessWidget {
  final Color color;
  const _DotGrid({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          16,
          (_) => Container(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ─── Logo section ─────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimaryLt, _kPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.business_center_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jonusa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _kText,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Group Management System',
              style: TextStyle(
                fontSize: 11,
                color: _kSub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Form Card ────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final TextEditingController emailCtrl, passwordCtrl;
  final bool obscurePassword, isLoading;
  final VoidCallback onToggleObscure, onLogin;

  const _FormCard({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Email field ──────────────────────────────────────────
          _FieldLabel(icon: Icons.email_outlined, label: 'Email'),
          const SizedBox(height: 8),
          _InputField(
            controller: emailCtrl,
            hint: 'masukkan@email.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_rounded,
          ),
          const SizedBox(height: 20),

          // ── Password field ───────────────────────────────────────
          _FieldLabel(icon: Icons.lock_outline_rounded, label: 'Password'),
          const SizedBox(height: 8),
          _InputField(
            controller: passwordCtrl,
            hint: '••••••••',
            obscureText: obscurePassword,
            prefixIcon: Icons.lock_rounded,
            suffixWidget: GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: _kSub,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Lupa password ─────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            // child: Text(
            //   'Hubungi Admin',
            //   style: TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w600),
            // ),
          ),
          const SizedBox(height: 24),

          // ── Tombol Login ─────────────────────────────────────────
          _LoginButton(isLoading: isLoading, onPressed: onLogin),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _kSub),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData prefixIcon;
  final Widget? suffixWidget;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14,
        color: _kText,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _kSub.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(prefixIcon, size: 18, color: _kPrimary.withOpacity(0.7)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon:
            suffixWidget != null
                ? Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: suffixWidget,
                )
                : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFDDE4F5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimaryMd, width: 2),
        ),
      ),
    );
  }
}

// ─── Tombol Login ─────────────────────────────────────────────────────────────
class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient:
              isLoading
                  ? LinearGradient(
                    colors: [
                      _kPrimary.withOpacity(0.6),
                      _kPrimaryMd.withOpacity(0.6),
                    ],
                  )
                  : const LinearGradient(
                    colors: [_kAccent, _kPrimary, _kPrimaryMd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isLoading
                  ? []
                  : [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: _kPrimaryLt.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Center(
          child:
              isLoading
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                  : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'MASUK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
