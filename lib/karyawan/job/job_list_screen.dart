import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'job_progress_screen.dart';

// Palette Warna Modern
const _kPrimary = Color(0xFF1E3A8A); // Indigo Blue
const _kAccent = Color(0xFF3B82F6); // Bright Blue
const _kBg = Color(0xFFF8FAFC); // Slate Light
const _kText = Color(0xFF1E293B); // Slate Dark
const _kSub = Color(0xFF64748B); // Slate Gray
const _kGreen = Color(0xFF10B981); // Emerald
const _kAmber = Color(0xFFF59E0B); // Amber
const _kRed = Color(0xFFEF4444); // Rose

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _storage = const FlutterSecureStorage();

  List<Job> _active = [];
  List<Job> _history = [];
  bool _loading = true;
  String? _error;
  int? _currentUserId; // Untuk simpan ID user yang login

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserData();
    await _load();
  }

  // Ambil data user yang sedang login dari storage
  Future<void> _loadUserData() async {
    try {
      // 1. Cek dulu apakah ada key 'user_data' (biasanya dari login_screen kamu)
      final userStr = await _storage.read(key: 'user_data');

      if (userStr != null) {
        final userData = jsonDecode(userStr);
        setState(() {
          // Pastikan ambil field 'id'
          _currentUserId = userData['id'];
        });
        print("DEBUG: Berhasil load ID User -> $_currentUserId");
      } else {
        // 2. Jika 'user_data' kosong, coba cek key 'user_id' langsung
        final userIdStr = await _storage.read(key: 'user_id');
        if (userIdStr != null) {
          setState(() {
            _currentUserId = int.tryParse(userIdStr);
          });
        }
      }
    } catch (e) {
      print("DEBUG: Gagal load user data -> $e");
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await JobService.getActiveJobs();
      final history = await JobService.getJobHistory();
      if (mounted) {
        setState(() {
          _active = active;
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _accept(Job job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Terima Tugas',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _kText,
                letterSpacing: -0.5,
              ),
            ),
            content: Text('Anda yakin ingin mengambil tugas "${job.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: _kSub)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ambil'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await JobService.acceptJob(job.id);
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas berhasil diambil!'),
          backgroundColor: _kGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _openProgress(Job job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobProgressScreen(job: job)),
    );
    _load();
  }

  // ── Fungsi Aksi Dinamis ──────────────────────────────────────────────────
  Widget _buildActionButton(Job job, bool isHistory, bool isMyJob) {
    if (isHistory) {
      return _actionButton(
        label: "Lihat Detail Riwayat",
        icon: Icons.history,
        color: _kSub,
        onPressed: () => _openProgress(job),
        isOutlined: true,
      );
    }

    if (job.isPending) {
      return _actionButton(
        label: isMyJob ? "AMBIL TUGAS SEKARANG" : "TUGAS DIVISI LAIN",
        icon: Icons.play_arrow_rounded,
        color: isMyJob ? _kAmber : _kSub.withOpacity(0.3),
        onPressed: isMyJob ? () => _accept(job) : null,
      );
    }

    if (job.isProcess) {
      return _actionButton(
        label:
            isMyJob
                ? "INPUT PROGRESS TAHAP ${job.currentStep}"
                : "SEDANG DIKERJAKAN",
        icon: isMyJob ? Icons.add_task_rounded : Icons.hourglass_bottom_rounded,
        color: isMyJob ? _kAccent : _kSub.withOpacity(0.2),
        onPressed: isMyJob ? () => _openProgress(job) : null,
      );
    }

    return const SizedBox();
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.white : color,
          foregroundColor: isOutlined ? color : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          side:
              isOutlined
                  ? BorderSide(color: color.withOpacity(0.5))
                  : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Job job, {bool isHistory = false}) {
    final statusColor =
        job.status == 'pending'
            ? _kAmber
            : (job.status == 'process' ? _kAccent : _kGreen);

    final String jobTechId =
        (job.technicianId ?? job.technician?['id'] ?? 0).toString();
    final String loginUserId = _currentUserId.toString();
    final bool isMyJob = jobTechId == loginUserId && loginUserId != "null";

    // HITUNG PROGRESS: Tahap yang selesai adalah (currentStep - 1)
    // Jika currentStep = 2, berarti tahap 1 sudah selesai (1/4)
    final double progressValue = ((job.currentStep ?? 1) - 1) / 4;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openProgress(job),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: _kText,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Dibuat: ${job.createdAt?.substring(0, 10) ?? '-'}",
                              style: const TextStyle(
                                color: _kSub,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(job.status.toUpperCase(), statusColor),
                    ],
                  ),

                  // --- TAMBAHKAN PROGRESS BAR DI SINI ---
                  if (job.status == 'process') ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Progress Kerja",
                          style: TextStyle(
                            fontSize: 11,
                            color: _kSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "${((job.currentStep ?? 1) - 1)} / 4 Selesai",
                          style: TextStyle(
                            fontSize: 11,
                            color: _kAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 6,
                        backgroundColor: _kAccent.withOpacity(0.1),
                        color: _kAccent,
                      ),
                    ),
                  ],

                  // --------------------------------------
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: _kAccent.withOpacity(0.1),
                        child: const Icon(
                          Icons.person,
                          size: 14,
                          color: _kAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Teknisi: ",
                        style: TextStyle(
                          color: _kSub,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        job.technician?['name'] ?? '-',
                        style: const TextStyle(
                          color: _kText,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildActionButton(job, isHistory, isMyJob),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Tracker Tugas',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _kPrimary,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [Tab(text: 'Aktif'), Tab(text: 'Riwayat')],
            ),
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : TabBarView(
                controller: _tab,
                children: [
                  _buildList(_active, false),
                  _buildList(_history, true),
                ],
              ),
    );
  }

  Widget _buildList(List<Job> list, bool isHistory) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: _kSub.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Belum ada tugas",
              style: TextStyle(color: _kSub, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 80),
        itemCount: list.length,
        itemBuilder:
            (context, index) => _buildCard(list[index], isHistory: isHistory),
      ),
    );
  }
}
