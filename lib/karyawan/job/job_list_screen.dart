import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'job_progress_screen.dart';

const _kPrimary = Color(0xFF1565C0);
const _kBg = Color(0xFFF0F4FF);
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kAmber = Color(0xFFF57C00);
const _kRed = Color(0xFFE53935);

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
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text('Ambil tugas "${job.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: _kSub)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
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
  Widget _buildActionButton(Job job, bool isHistory) {
    if (isHistory) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openProgress(job),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Lihat Detail'),
        ),
      );
    }

    // Ambil ID teknisi dari data Job (mendukung data root atau nested object)
    final String jobTechId =
        (job.technicianId ?? job.technician?['id'] ?? 0).toString();

    // Ambil ID user yang login (pastikan sudah di-load di initState)
    final String loginUserId = _currentUserId.toString();

    // DEBUG: Cek di console VS Code apakah angkanya sama
    print("ID Tugas: $jobTechId | ID Login: $loginUserId");

    final bool isMyJob = jobTechId == loginUserId && loginUserId != "null";

    if (job.isPending) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isMyJob ? () => _accept(job) : null,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            isMyJob ? 'AMBIL TUGAS & MULAI' : 'Tugas untuk Teknisi Lain',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isMyJob ? const Color(0xFF1A237E) : Colors.grey[300],
            foregroundColor: isMyJob ? Colors.white : Colors.grey[600],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (job.isProcess) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isMyJob ? () => _openProgress(job) : null,
          icon: const Icon(Icons.upload_outlined, size: 18),
          label: Text(
            isMyJob
                ? 'Input Progress Tahap ${job.currentStep}'
                : 'Sedang dikerjakan teknisi',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isMyJob ? const Color(0xFF1565C0) : Colors.grey[200],
            foregroundColor: isMyJob ? Colors.white : Colors.grey[500],
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildCard(Job job, {bool isHistory = false}) {
    final statusColor =
        job.status == 'pending'
            ? _kAmber
            : (job.status == 'process' ? _kPrimary : _kGreen);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Gunakan withValues jika menggunakan Flutter terbaru,
          // atau biarkan withOpacity jika versi lama, tapi pastikan logikanya benar.
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // FIX DI SINI: Ganti .between menjadi .spaceBetween
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  job.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.description ?? '',
            style: const TextStyle(color: _kSub, fontSize: 13),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: _kSub),
              const SizedBox(width: 4),
              Text(
                "Teknisi: ${job.technician?['name'] ?? '-'}",
                style: const TextStyle(fontSize: 12, color: _kText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButton(job, isHistory),
        ],
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _kPrimary,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Aktif'), Tab(text: 'Riwayat')],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
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
    if (list.isEmpty) return const Center(child: Text("Tidak ada tugas"));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16),
        itemCount: list.length,
        itemBuilder:
            (context, index) => _buildCard(list[index], isHistory: isHistory),
      ),
    );
  }
}
