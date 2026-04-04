import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/admin/chat/admin_chat_screen.dart';

class TesAdminPage extends StatefulWidget {
  const TesAdminPage({super.key});

  @override
  State<TesAdminPage> createState() => _TesAdminPageState();
}

class _TesAdminPageState extends State<TesAdminPage> {
  // Warna tema Admin
  final Color primaryColor = const Color(0xFF0D47A1);
  final Color accentColor = const Color(0xFF1976D2);

  // Fungsi Logout
  Future<void> _logout() async {
    const storage = FlutterSecureStorage();

    // Tampilkan loading sebentar (opsional)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Hapus token dan data user dari storage
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'user_id');
      await storage.delete(key: 'role');

      if (!mounted) return;

      // Pindah ke halaman login dan hapus semua history navigasi
      // Pastikan nama class LoginScreen sesuai dengan project kamu
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      Navigator.pop(context); // Tutup loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal logout, coba lagi.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          // --- TOMBOL LOGOUT ---
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              // Tampilkan dialog konfirmasi sebelum logout
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Apakah Anda yakin ingin keluar?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Batal"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Tutup dialog
                            _logout(); // Jalankan fungsi logout
                          },
                          child: const Text(
                            "Ya, Keluar",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER SECTION ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Halo, Admin Rizka!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Pantau aktivitas karyawan Jonusa hari ini.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- STATS CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatCard("Hadir", "12", Icons.people, Colors.green),
                  const SizedBox(width: 15),
                  _buildStatCard(
                    "Izin/Sakit",
                    "3",
                    Icons.assignment_late,
                    Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- QUICK ACTION (CHAT) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text(
                "Menu Utama",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 15),

            _buildMenuTile(
              context,
              title: "Chat Internal",
              subtitle: "Hubungi semua karyawan Jonusa",
              icon: Icons.chat_bubble_rounded,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminChatScreen()),
                );
              },
            ),

            _buildMenuTile(
              context,
              title: "Kelola Karyawan",
              subtitle: "Lihat dan tambah data karyawan baru",
              icon: Icons.person_add_rounded,
              color: Colors.blue,
              onTap: () {
                // Navigasi ke fitur karyawan jika sudah ada route-nya
              },
            ),

            _buildMenuTile(
              context,
              title: "Approval Kehadiran",
              subtitle: "Cek laporan masuk/pulang",
              icon: Icons.fact_check_rounded,
              color: Colors.teal,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET CARD STATISTIK
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 15),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET MENU LIST TILE
  Widget _buildMenuTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
