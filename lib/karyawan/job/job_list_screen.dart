// lib/karyawan/job/job_list_screen.dart
//
// Dipanggil dari karyawan_screen.dart lewat menu grid "Tugas"
// Style konsisten dengan attendance_history_screen.dart

import 'package:flutter/material.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'job_progress_screen.dart';

const _kPrimary = Color(0xFF1565C0);
const _kAccent = Color(0xFF0D47A1);
const _kPrimaryMd = Color(0xFF1976D2);
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
  List<Job> _active = [];
  List<Job> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await JobService.getActiveJobs();
      final history = await JobService.getJobHistory();
      if (mounted)
        setState(() {
          _active = active;
          _history = history;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  // ── Terima tugas ────────────────────────────────────────────────────────
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
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil diambil!'),
            backgroundColor: _kGreen,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: _kRed),
        );
    }
  }

  // ── Buka halaman progress ────────────────────────────────────────────────
  Future<void> _openProgress(Job job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobProgressScreen(job: job)),
    );
    _load();
  }

  // ── Warna & label status ─────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return _kAmber;
      case 'process':
        return _kPrimary;
      case 'completed':
        return _kGreen;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Menunggu';
      case 'process':
        return 'Berlangsung';
      case 'completed':
        return 'Selesai';
      default:
        return s;
    }
  }

  // ── Kartu tugas ──────────────────────────────────────────────────────────
  Widget _buildCard(Job job, {bool isHistory = false}) {
    final color = _statusColor(job.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(job.status),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            // Deskripsi
            if (job.description != null && job.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                job.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),

            // Info baris
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  job.cs?['name'] ?? '-',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (job.isProcess) ...[
                  const SizedBox(width: 14),
                  Icon(
                    Icons.stairs_outlined,
                    size: 13,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tahap ${job.currentStep}/4',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                if (job.createdAt != null) ...[
                  const Spacer(),
                  Text(
                    job.createdAt!.substring(0, 10),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),

            // Progress bar saat process
            if (job.isProcess) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((job.currentStep ?? 1) - 1) / 4,
                  minHeight: 5,
                  backgroundColor: _kPrimary.withOpacity(0.1),
                  color: _kPrimary,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Tombol aksi
            if (!isHistory) ...[
              if (job.isPending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _accept(job),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Terima & Mulai Tugas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAmber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (job.isProcess)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openProgress(job),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text('Input Progress Tahap ${job.currentStep}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openProgress(job),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Lihat Detail'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: BorderSide(color: _kPrimary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            // Feedback pimpinan
            if (job.feedback != null && job.feedback!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback Pimpinan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.feedback!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Tracker Tugas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.work_outline, size: 16),
                  const SizedBox(width: 6),
                  const Text('Aktif'),
                  if (_active.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_active.length}',
                        style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 16),
                  SizedBox(width: 6),
                  Text('Riwayat'),
                ],
              ),
            ),
          ],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                      onPressed: _load,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tab,
                children: [
                  // ── Tab Aktif ──
                  RefreshIndicator(
                    onRefresh: _load,
                    child:
                        _active.isEmpty
                            ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.25,
                                ),
                                const Icon(
                                  Icons.inbox_outlined,
                                  size: 56,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tidak ada tugas aktif',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tugas baru dari CS akan muncul di sini',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: _active.length,
                              itemBuilder: (_, i) => _buildCard(_active[i]),
                            ),
                  ),

                  // ── Tab Riwayat ──
                  RefreshIndicator(
                    onRefresh: _load,
                    child:
                        _history.isEmpty
                            ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.25,
                                ),
                                const Icon(
                                  Icons.history_toggle_off,
                                  size: 56,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada riwayat tugas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: _history.length,
                              itemBuilder:
                                  (_, i) =>
                                      _buildCard(_history[i], isHistory: true),
                            ),
                  ),
                ],
              ),
    );
  }
}
