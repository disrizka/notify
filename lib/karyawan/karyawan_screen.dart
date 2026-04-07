import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;
import 'package:sapa_jonusa/auth/login_screen.dart';
import 'package:sapa_jonusa/karyawan/attedance_history_screen.dart';
import 'package:sapa_jonusa/karyawan/chat/chat_screen.dart';
import 'package:sapa_jonusa/karyawan/checkin_screen.dart';
import 'package:sapa_jonusa/karyawan/checkout_screen.dart';
import 'package:sapa_jonusa/karyawan/cuti_screen.dart';
import 'package:sapa_jonusa/karyawan/job/job_list_screen.dart';
import 'package:sapa_jonusa/karyawan/job/job_screen.dart';
import 'package:sapa_jonusa/karyawan/profile_screen.dart';
import 'package:sapa_jonusa/karyawan/sakit_screen.dart';
import "notification_screen.dart";
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sapa_jonusa/main.dart';

// ─── Warna utama tema biru ────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryMd = Color(0xFF1976D2);
const _kPrimaryLt = Color(0xFF42A5F5);
const _kAccent = Color(0xFF0D47A1);
const _kCyan = Color(0xFF00BCD4);
const _kBg = Color(0xFFF0F4FF);
const _kCard = Colors.white;
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kAmber = Color(0xFFF57C00);
const _kRed = Color(0xFFE53935);

class KaryawanHomeScreen extends StatefulWidget {
  const KaryawanHomeScreen({super.key});

  @override
  State<KaryawanHomeScreen> createState() => _KaryawanHomeScreenState();
}

class _KaryawanHomeScreenState extends State<KaryawanHomeScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  int _unreadCount = 0; // Tambahkan ini
  Timer? _notifTimer;
  int get unreadCount => _unreadCount;
  int _lastNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Cek notifikasi setiap 10 detik agar tidak berat
    _notifTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      // DEBUG: cek user yang sedang login
      final userRes = await http.get(
        Uri.parse('${Api.baseUrl}/api/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      print('DEBUG USER LOGIN: ${userRes.body}');

      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/notifications/count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('DEBUG NOTIF RESPONSE: ${res.body}');

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        int newCount = data['unread_count'] ?? 0;

        String title = data['latest_title'] ?? "Sapa Jonusa";
        String message = data['latest_message'] ?? "Ada pesan baru untukmu";

        if (newCount > _lastNotifCount) {
          _showNotificationPopup(title, message);
        }

        if (mounted) {
          setState(() {
            _unreadCount = newCount;
            _lastNotifCount = newCount;
          });
        }
      }
    } catch (e) {
      print('Error Fetch: $e');
    }
  }

  Future<void> _showNotificationPopup(String title, String body) async {
    // Pakai ID 'sapa_jonusa_high_v2' agar Android membuat channel baru yang FRESH
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'sapa_jonusa_high_v2',
          'Notifikasi Penting',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          icon: '@mipmap/ic_launcher', // Memastikan ikon muncul
          channelShowBadge: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond, // ID unik biar gak numpuk
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // ── Bottom Nav Screens ───────────────────────────────────────────────────
  late final List<Widget> _screens = [
    _HomeTab(),
    const _PlaceholderTab(
      icon: Icons.access_time_filled_rounded,
      label: 'Timeline',
    ),
    const _PlaceholderTab(icon: Icons.business_rounded, label: 'Perusahaan'),
    ProfileScreen(),
  ];

  // ── Helper navigasi dari absen sheet ────────────────────────────────────
  void _goToAbsenPage(Widget screen) async {
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Refresh HomeTab setelah kembali dari absen screen
    setState(() {});
  }

  // ── Bottom Sheet Absensi ─────────────────────────────────────────────────
  void showAbsenSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kPrimaryMd, _kPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Absensi & Pengajuan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                          ),
                        ),
                        Text(
                          'Pilih jenis presensi atau pengajuan',
                          style: TextStyle(fontSize: 12, color: _kSub),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _AbsenOption(
                  icon: Icons.login_rounded,
                  label: 'Presensi Masuk',
                  description: 'Catat kehadiran awal kerja hari ini',
                  color: _kPrimaryMd,
                  onTap: () => _goToAbsenPage(const CheckinScreen()),
                ),
                const SizedBox(height: 10),
                _AbsenOption(
                  icon: Icons.logout_rounded,
                  label: 'Presensi Pulang',
                  description: 'Catat waktu selesai kerja hari ini',
                  color: _kGreen,
                  onTap: () => _goToAbsenPage(const CheckoutScreen()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade200,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'Pengajuan',
                          style: TextStyle(
                            fontSize: 11,
                            color: _kSub,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade200,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                _AbsenOption(
                  icon: Icons.beach_access_rounded,
                  label: 'Izin & Cuti',
                  description: 'Tahunan, Khusus, atau Tanpa Gaji',
                  color: _kAmber,
                  onTap: () => _goToAbsenPage(const CutiScreen()),
                ),
                const SizedBox(height: 10),
                _AbsenOption(
                  icon: Icons.medical_services_rounded,
                  label: 'Sakit',
                  description: 'Lapor sakit dengan bukti surat dokter',
                  color: _kRed,
                  onTap: () => _goToAbsenPage(const SakitScreen()),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Keluar Akun?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('Sesi kamu akan diakhiri.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: _kSub)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
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
      extendBodyBehindAppBar: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Halaman 0
          _HomeTab(key: ValueKey(_unreadCount)),

          // Halaman 1 (Ganti sesuai nama file timeline kamu, misal TimelineScreen)
          // const AttendanceScreen(),
          const Center(child: Text("Halaman Perusahaan")),
          // Halaman 2 (Ganti sesuai nama file perusahaan kamu)
          const Center(child: Text("Halaman Perusahaan")),

          // Halaman 4
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () => showAbsenSheet(context),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPrimaryLt, _kPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: _kPrimaryLt.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.fingerprint, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.access_time_outlined,
        activeIcon: Icons.access_time_filled,
        label: 'Timeline',
      ),
      _NavItem(icon: null, activeIcon: null, label: ''),
      _NavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business_rounded,
        label: 'Perusahaan',
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              if (i == 2) return const Expanded(child: SizedBox());
              final realIndex = i > 2 ? i - 1 : i;
              final active = _selectedIndex == realIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedIndex = realIndex),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: active ? 14 : 0,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              active
                                  ? _kPrimary.withOpacity(0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          active ? items[i].activeIcon : items[i].icon,
                          color: active ? _kPrimary : _kSub,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          color: active ? _kPrimary : _kSub,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Home Tab ────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Ambil state untuk dapetin jumlah notif dan fungsi fetch
    final mainState =
        context.findAncestorStateOfType<_KaryawanHomeScreenState>();
    final count = mainState?.unreadCount ?? 0;
    debugPrint("UI Refresh: HomeTab menggambar ulang dengan count = $count");
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderSection(
            unreadCount: count,
            onRefresh: () {
              // Menjalankan fungsi fetch di class utama
              mainState?._fetchNotifications();
            },
          ),
          const SizedBox(height: 16),
          const _SwipeableInfoCards(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _PresenceCard(key: ValueKey(DateTime.now().day)),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: _MenuGrid(),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onRefresh; // Ini kunci untuk refresh

  _HeaderSection({
    super.key,
    required this.unreadCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Logika Tanggal
    final now = DateTime.now();
    final days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final dateStr =
        '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 20,
        22,
        32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // SISI KIRI: PROFIL
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat datang',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // SISI KANAN: IKON LONCENG
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
              // Panggil refresh setelah balik dari halaman notif
              onRefresh();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF1744),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Swipeable Info Cards ─────────────────────────────────────────────────────
class _SwipeableInfoCards extends StatefulWidget {
  const _SwipeableInfoCards();

  @override
  State<_SwipeableInfoCards> createState() => _SwipeableInfoCardsState();
}

class _SwipeableInfoCardsState extends State<_SwipeableInfoCards> {
  final _controller = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Column(children: []);
  }
}

// ─── Presence Card (REAL API) ─────────────────────────────────────────────────
class _PresenceCard extends StatefulWidget {
  const _PresenceCard({super.key});

  @override
  State<_PresenceCard> createState() => _PresenceCardState();
}

class _PresenceCardState extends State<_PresenceCard> {
  final _storage = const FlutterSecureStorage();

  String? _checkinTime;
  String? _checkoutTime;
  bool _isLoading = true;

  bool get _hasCheckin => _checkinTime != null;
  bool get _hasCheckout => _checkoutTime != null;

  @override
  void initState() {
    super.initState();
    _fetchTodayStatus();
  }

  // ── Ambil status presensi hari ini dari API ──────────────────────────────
  Future<void> _fetchTodayStatus() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/presence/today'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Format waktu: ambil HH:mm dari "HH:mm:ss"
          final checkIn = data['check_in']?.toString();
          final checkOut = data['check_out']?.toString();
          _checkinTime =
              checkIn != null && checkIn.length >= 5
                  ? checkIn.substring(0, 5)
                  : null;
          _checkoutTime =
              checkOut != null && checkOut.length >= 5
                  ? checkOut.substring(0, 5)
                  : null;
        });
      }
    } catch (e) {
      // Gagal fetch → tampilkan belum absen (safe fallback)
      debugPrint('Error fetch presence: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header card ──────────────────────────────────────────────────
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
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Presensi Hari Ini',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const Spacer(),
                // Tombol refresh manual
                if (!_isLoading)
                  GestureDetector(
                    onTap: _fetchTodayStatus,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                _buildStatusChip(),
              ],
            ),
          ),

          // ── Konten utama ─────────────────────────────────────────────────
          if (_isLoading)
            _buildLoadingState()
          else if (!_hasCheckin && !_hasCheckout)
            _buildNotYetAbsen()
          else
            _buildAbsenContent(),

          // ── Footer info ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color:
                  _hasCheckin
                      ? _kPrimary.withOpacity(0.04)
                      : const Color(0xFFFFF8E1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child:
                _isLoading
                    ? Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kSub,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Memuat data...',
                          style: const TextStyle(fontSize: 12, color: _kSub),
                        ),
                      ],
                    )
                    : Row(
                      children: [
                        Icon(
                          _hasCheckin
                              ? Icons.check_circle_rounded
                              : Icons.info_rounded,
                          size: 14,
                          color: _hasCheckin ? _kPrimary : _kAmber,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _hasCheckin
                              ? 'Presensi masuk pukul $_checkinTime'
                              : 'Anda belum melakukan presensi hari ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hasCheckin ? _kPrimary : _kAmber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kSub.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 48,
          height: 10,
          child: LinearProgressIndicator(
            color: _kSub,
            backgroundColor: Colors.transparent,
          ),
        ),
      );
    }
    if (_hasCheckin && _hasCheckout) {
      return _StatusChip(
        label: 'Lengkap',
        color: _kGreen,
        icon: Icons.check_circle_rounded,
      );
    } else if (_hasCheckin) {
      return _StatusChip(
        label: 'Sudah Masuk',
        color: _kPrimary,
        icon: Icons.login_rounded,
      );
    } else {
      return _StatusChip(
        label: 'Belum Absen',
        color: _kRed,
        icon: Icons.radio_button_unchecked_rounded,
      );
    }
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE4F5), width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
              SizedBox(height: 12),
              Text(
                'Memuat data presensi...',
                style: TextStyle(fontSize: 13, color: _kSub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotYetAbsen() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kBg, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE4F5), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.fingerprint, size: 36, color: _kPrimary),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: _kRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Belum presensi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ketuk tombol fingerprint\nuntuk mulai presensi',
                    style: TextStyle(fontSize: 12, color: _kSub, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenContent() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: _TimeBox(
              icon: Icons.login_rounded,
              label: 'Presensi Masuk',
              time: _checkinTime,
              color: _kPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFEAEEF8),
          ),
          Expanded(
            child: _TimeBox(
              icon: Icons.logout_rounded,
              label: 'Presensi Pulang',
              time: _checkoutTime,
              color: _kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── TimeBox: hanya tampil, tidak lagi bisa di-tap untuk edit ─────────────────
class _TimeBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? time;
  final Color color;
  const _TimeBox({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: _kSub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  time ?? '--:--',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: time == null ? _kSub : _kText,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (time != null)
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: color.withOpacity(0.7),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Menu Grid ───────────────────────────────────────────────────────────────
class _MenuGrid extends StatefulWidget {
  const _MenuGrid();

  @override
  State<_MenuGrid> createState() => _MenuGridState();
}

class _MenuGridState extends State<_MenuGrid> {
  final _storage = const FlutterSecureStorage();
  String _userRole = '';
  String _userDivision = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final userStr = await _storage.read(key: 'user_data');
      if (userStr != null) {
        final data = jsonDecode(userStr) as Map<String, dynamic>;
        final div = data['division'];
        setState(() {
          _userRole = (data['role'] as String? ?? '').toLowerCase();
          _userDivision =
              (div is Map ? div['name'] as String? : div as String?) ?? '';
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('_MenuGrid _loadUser error: $e');
      setState(() => _loaded = true);
    }
  }

  // CS = role karyawan + divisi Customer Service
  // Kepala = role kepala
  bool get _canCreateJob =>
      _userRole == 'kepala' ||
      _userDivision.toLowerCase().contains('customer service');

  List<_MenuDef> get _menus {
    final base = [
      const _MenuDef(
        icon: Icons.fingerprint,
        label: 'Kehadiran',
        bg: Color(0xFFE3F2FD),
        iconColor: Color(0xFF1565C0),
        isAbsen: true,
      ),
      const _MenuDef(
        icon: Icons.flight_takeoff_rounded,
        label: 'Izin & Cuti',
        bg: Color(0xFFFFF8E1),
        iconColor: Color(0xFFF57C00),
      ),
      const _MenuDef(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Gaji',
        bg: Color(0xFFE8F5E9),
        iconColor: Color(0xFF2E7D32),
      ),
      const _MenuDef(
        icon: Icons.calendar_month_rounded,
        label: 'Kalender',
        bg: Color(0xFFF3E5F5),
        iconColor: Color(0xFF7B1FA2),
      ),
      const _MenuDef(
        icon: Icons.business_rounded,
        label: 'Perusahaan',
        bg: Color(0xFFE3F2FD),
        iconColor: Color(0xFF0277BD),
      ),
      const _MenuDef(
        icon: Icons.check_circle_outline_rounded,
        label: 'Approval',
        bg: Color(0xFFE8F5E9),
        iconColor: Color(0xFF00695C),
      ),
      const _MenuDef(
        icon: Icons.groups_rounded,
        label: 'Tim',
        bg: Color(0xFFE0F2F1),
        iconColor: Color(0xFF00796B),
      ),
      const _MenuDef(
        icon: Icons.receipt_long_rounded,
        label: 'Kasbon',
        bg: Color(0xFFFFF3E0),
        iconColor: Color(0xFFE65100),
      ),
      _MenuDef(
        icon: Icons.chat,
        label: 'Chat',
        bg: const Color.fromARGB(255, 221, 255, 249),
        iconColor: const Color.fromARGB(255, 0, 100, 100),
        route: ChatScreen(),
      ),
      _MenuDef(
        icon: Icons.task_alt_rounded,
        label: 'Tracker Tugas',
        bg: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF1B5E20),
        route: JobListScreen(),
      ),
      _MenuDef(
        icon: Icons.history_rounded,
        label: 'Riwayat',
        bg: const Color(0xFFE8EAF6),
        iconColor: const Color(0xFF3949AB),
        route: AttendanceHistoryScreen(),
      ),
    ];

    // Tambahkan menu "Buat Tugas" hanya untuk CS & Kepala
    if (_canCreateJob) {
      base.add(
        _MenuDef(
          icon: Icons.add_task_rounded,
          label: 'Buat Tugas',
          bg: const Color(0xFFE8EAF6),
          iconColor: const Color(0xFF1565C0),
          route: const CsCreateJobScreen(),
        ),
      );
    }

    return base;
  }

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'Menu Utama',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
          ),

          // Tampilkan shimmer saat loading user data
          if (!_loaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  color: _kPrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              itemCount: _menus.length,
              itemBuilder: (_, i) => _MenuGridItem(menu: _menus[i]),
            ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 6,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuDef {
  final IconData icon;
  final String label;
  final Color bg;
  final Color iconColor;
  final bool isAbsen;
  final Widget? route;

  const _MenuDef({
    required this.icon,
    required this.label,
    required this.bg,
    required this.iconColor,
    this.isAbsen = false,
    this.route,
  });
}

class _MenuGridItem extends StatelessWidget {
  final _MenuDef menu;
  const _MenuGridItem({required this.menu});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final state =
            context.findAncestorStateOfType<_KaryawanHomeScreenState>();
        if (menu.isAbsen) {
          state?.showAbsenSheet(context);
        } else if (menu.route != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => menu.route!),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: menu.bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: menu.iconColor.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(menu.icon, color: menu.iconColor, size: 26),
          ),
          const SizedBox(height: 7),
          Text(
            menu.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Absen Option ─────────────────────────────────────────────────────────────
class _AbsenOption extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final Color color;
  final VoidCallback onTap;

  const _AbsenOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: _kSub),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav Item ────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData? icon, activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─── Placeholder Tab ─────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kPrimary.withOpacity(0.1),
                  _kPrimaryLt.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: _kPrimary.withOpacity(0.5)),
          ),
          const SizedBox(height: 18),
          Text(
            'Fitur $label',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Segera Hadir',
              style: TextStyle(
                color: _kPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
