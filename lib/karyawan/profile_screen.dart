import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sapa_jonusa/api/api.dart' as Api;
import 'package:sapa_jonusa/auth/login_screen.dart';

// ─── Color Palette (sama dengan checkin/checkout) ───────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryMd = Color(0xFF1976D2);
const _kPrimaryLt = Color(0xFF42A5F5);
const _kAccent = Color(0xFF0D47A1);
const _kDeepBlue = Color(0xFF0D47A1);
const _kAccentBlue = Color(0xFF1E88E5);
const _kLightBlue = Color(0xFFE3F2FD);
const _kBg = Color(0xFFF0F4FF);
const _kCard = Colors.white;
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kRed = Color(0xFFE53935);
const _kAmber = Color(0xFFF57C00);
// ────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  // Controller ganti password
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPass = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Fetch user dari API ────────────────────────────────────────────────────
  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http
          .get(
            Uri.parse('${Api.baseUrl}/api/user'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() => _userData = decoded['data'] ?? decoded);
      }
    } catch (e) {
      debugPrint('Error load user: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: _kRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Keluar Akun?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _kText,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Sesi kamu akan diakhiri dan kamu harus login ulang.',
              style: TextStyle(fontSize: 13, color: _kSub, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: _kSub)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
    );

    if (confirm != true) return;
    setState(() => _isLoggingOut = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      await http.post(
        Uri.parse('${Api.baseUrl}/api/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
    } catch (_) {
    } finally {
      await _storage.delete(key: 'auth_token');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // ── Ganti Password ─────────────────────────────────────────────────────────
  Future<void> _handleChangePassword(StateSetter setDialogState) async {
    if (_oldPassCtrl.text.isEmpty ||
        _newPassCtrl.text.isEmpty ||
        _confirmPassCtrl.text.isEmpty) {
      _showSnackBar('Semua field harus diisi', isError: true);
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _showSnackBar('Password baru tidak cocok', isError: true);
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      _showSnackBar('Password minimal 6 karakter', isError: true);
      return;
    }

    setDialogState(() => _isChangingPass = true);
    try {
      final token = await _storage.read(key: 'auth_token');

      // ✅ Gunakan PUT + JSON body, bukan POST + _method spoofing
      final response = await http.put(
        Uri.parse('${Api.baseUrl}/api/user/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json', // ✅ Wajib untuk JSON
        },
        body: jsonEncode({
          'current_password': _oldPassCtrl.text,
          'new_password': _newPassCtrl.text,
          'new_password_confirmation': _confirmPassCtrl.text,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        Navigator.pop(context);
        _showSnackBar(body['message'] ?? 'Password berhasil diubah');
      } else {
        _showSnackBar(
          body['message'] ?? 'Gagal mengubah password',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Koneksi gagal: $e', isError: true);
    } finally {
      setDialogState(() => _isChangingPass = false);
    }
  }

  void _showChangePasswordDialog() {
    _oldPassCtrl.clear();
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();
    _obscureOld = true;
    _obscureNew = true;
    _obscureConfirm = true;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kAccent, _kPrimaryMd],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Ganti Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _kText,
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPassField(
                          controller: _oldPassCtrl,
                          label: 'Password Lama',
                          isObscure: _obscureOld,
                          onToggle:
                              () => setDialogState(
                                () => _obscureOld = !_obscureOld,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _buildPassField(
                          controller: _newPassCtrl,
                          label: 'Password Baru',
                          isObscure: _obscureNew,
                          onToggle:
                              () => setDialogState(
                                () => _obscureNew = !_obscureNew,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _buildPassField(
                          controller: _confirmPassCtrl,
                          label: 'Konfirmasi Password Baru',
                          isObscure: _obscureConfirm,
                          onToggle:
                              () => setDialogState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Batal',
                        style: TextStyle(color: _kSub),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed:
                          _isChangingPass
                              ? null
                              : () => _handleChangePassword(setDialogState),
                      child:
                          _isChangingPass
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Simpan'),
                    ),
                  ],
                ),
          ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? _kRed : _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty)
      return parts[0][0].toUpperCase();
    return 'U';
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: _kBg,
      body:
          _isLoading
              ? _buildLoadingState()
              : _userData == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  // ─── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kDeepBlue, _kAccentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  // ─── Error ──────────────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: _kRed, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat data',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Periksa koneksi internet kamu',
            style: TextStyle(fontSize: 13, color: _kSub),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _loadUser,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // ─── Main Content ───────────────────────────────────────────────────────────
  Widget _buildContent() {
    final name = _userData!['name'] ?? _userData!['nama'] ?? 'User';
    final email = _userData!['email'] ?? '-';
    final role = _userData!['role'] ?? '-';
    final division =
        _userData!['division']?['name'] ?? _userData!['division_name'] ?? '-';

    return RefreshIndicator(
      onRefresh: _loadUser,
      color: _kPrimary,
      child: CustomScrollView(
        slivers: [
          // ── App Bar dengan Avatar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: _kPrimary,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.light,
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfileHeader(name, role, division),
            ),
            title: const Text(
              'Profil Saya',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info pribadi
                  _buildSectionCard(
                    title: 'Informasi Akun',
                    icon: Icons.person_rounded,
                    children: [
                      _buildInfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Nama Lengkap',
                        value: name,
                        iconColor: _kPrimary,
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                        iconColor: _kAccentBlue,
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        icon: Icons.business_center_outlined,
                        label: 'Divisi',
                        value: division,
                        iconColor: _kAmber,
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: role.toString().toUpperCase(),
                        iconColor: _kGreen,
                        isChip: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Menu aksi
                  _buildSectionCard(
                    title: 'Pengaturan',
                    icon: Icons.settings_rounded,
                    children: [
                      _buildMenuTile(
                        icon: Icons.lock_reset_rounded,
                        label: 'Ganti Password',
                        subtitle: 'Perbarui password akun kamu',
                        iconColor: _kPrimary,
                        iconBg: _kLightBlue,
                        onTap: _showChangePasswordDialog,
                      ),
                      _buildDivider(),
                      _buildMenuTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privasi & Keamanan',
                        subtitle: 'Informasi kebijakan privasi',
                        iconColor: Color(0xFF7B1FA2),
                        iconBg: Color(0xFFF3E5F5),
                        onTap:
                            () => _showInfoDialog(
                              title: 'Privasi & Keamanan',
                              icon: Icons.privacy_tip_outlined,
                              color: Color(0xFF7B1FA2),
                              content:
                                  'Kami berkomitmen menjaga kerahasiaan data kamu.\n\n'
                                  '• Data absensi hanya dapat diakses oleh kamu dan admin\n'
                                  '• Foto presensi disimpan dengan aman di server\n'
                                  '• Token login otomatis dihapus saat logout\n'
                                  '• Data tidak dibagikan ke pihak ketiga',
                            ),
                      ),
                      _buildDivider(),
                      _buildMenuTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Bantuan',
                        subtitle: 'FAQ dan panduan penggunaan',
                        iconColor: _kGreen,
                        iconBg: Color(0xFFE8F5E9),
                        onTap:
                            () => _showInfoDialog(
                              title: 'Bantuan',
                              icon: Icons.help_outline_rounded,
                              color: _kGreen,
                              content:
                                  '• Login menggunakan email & password yang diberikan admin\n\n'
                                  '• Absensi masuk: Ketuk fingerprint → Presensi Masuk\n\n'
                                  '• Absensi pulang: Ketuk fingerprint → Presensi Pulang\n\n'
                                  '• Pastikan GPS aktif saat melakukan presensi\n\n'
                                  '• Pengajuan izin/cuti: Ketuk fingerprint → Izin & Cuti atau Sakit',
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Info versi
                  _buildSectionCard(
                    title: 'Informasi Aplikasi',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _buildInfoRow(
                        icon: Icons.phone_android_rounded,
                        label: 'Versi Aplikasi',
                        value: '1.0.0',
                        iconColor: _kSub,
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        icon: Icons.developer_mode_rounded,
                        label: 'Build',
                        value: 'Notify Mobile',
                        iconColor: _kSub,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Tombol Logout
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profile Header ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader(String name, String role, String division) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kAccent, _kPrimary, _kPrimaryMd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getInitials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (division != '-') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      division,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    role.toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Section Card ───────────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFEAEEF8), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 15, color: _kPrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // ─── Info Row ───────────────────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isChip = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                isChip
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kGreen.withOpacity(0.3)),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Menu Tile ──────────────────────────────────────────────────────────────
  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _kSub),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _kSub.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tombol Logout ──────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), _kRed],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kRed.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoggingOut ? null : _handleLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon:
              _isLoggingOut
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                  : const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          label: Text(
            _isLoggingOut ? 'Keluar...' : 'Keluar dari Akun',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Divider ────────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade100, height: 1, thickness: 1);
  }

  // ─── Password Field ─────────────────────────────────────────────────────────
  Widget _buildPassField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(fontSize: 14, color: _kText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _kSub),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: _kSub,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isObscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _kSub,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: _kBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE4F5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ─── Info Dialog (Privasi / Bantuan) ────────────────────────────────────────
  void _showInfoDialog({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _kText,
                  ),
                ),
              ],
            ),
            content: Text(
              content,
              style: const TextStyle(fontSize: 13, color: _kSub, height: 1.7),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          ),
    );
  }
}
