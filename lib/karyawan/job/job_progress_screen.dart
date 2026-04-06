import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

// Palette Warna
const _kPrimary = Color(0xFF1565C0);
const _kAccent = Color(0xFF0D47A1);
const _kBg = Color(0xFFF8FAFC);
const _kText = Color(0xFF1E293B);
const _kSub = Color(0xFF64748B);
const _kGreen = Color(0xFF10B981);

class JobProgressScreen extends StatefulWidget {
  final Job job;
  const JobProgressScreen({super.key, required this.job});

  @override
  State<JobProgressScreen> createState() => _JobProgressScreenState();
}

class _JobProgressScreenState extends State<JobProgressScreen> {
  late Job _job;
  final _descCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  File? _photo;
  File? _video;
  final _picker = ImagePicker();
  bool _sendingComment = false;

  bool _uploading = false;
  bool _isLoadingUser = true;

  String _currentUserId = ""; // Simpan sebagai String agar mudah dibanding
  String _currentUserName = "";

  @override
  void initState() {
    super.initState();
    _job = widget.job; // Gunakan data dari widget sebagai awal
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // --- LOGIKA LOAD USER TERPERCAYA ---
  Future<void> _loadCurrentUser() async {
    try {
      final allData = await _storage.readAll();
      debugPrint("DEBUG AUTH: Mencari ID di storage...");

      for (final entry in allData.entries) {
        try {
          final data = jsonDecode(entry.value);
          if (data is Map && data['id'] != null) {
            setState(() {
              _currentUserId = data['id'].toString();
              _currentUserName = data['name']?.toString() ?? "";
              _isLoadingUser = false;
            });
            debugPrint(
              "DEBUG AUTH: Ketemu ID $_currentUserId atas nama $_currentUserName",
            );
            return;
          }
        } catch (_) {}
      }

      // Fallback jika tidak ketemu di JSON
      final idStr = await _storage.read(key: 'user_id');
      if (idStr != null) {
        setState(() {
          _currentUserId = idStr;
          _isLoadingUser = false;
        });
      } else {
        setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
    }
  }

  // --- GETTER KEAMANAN (VERSI FIX) ---
  bool get _isMyJob {
    if (_isLoadingUser) return false;

    // Ambil ID Teknisi dari berbagai sumber di objek Job
    final String jobTechId =
        (_job.technicianId ?? _job.technician?['id'] ?? "").toString();

    debugPrint(
      "CHECK ACCESS: User Login=$_currentUserId | Teknisi Tugas=$jobTechId",
    );

    // Jika ID sama, atau Nama sama (sebagai cadangan)
    if (_currentUserId.isNotEmpty && jobTechId.isNotEmpty) {
      if (_currentUserId == jobTechId) return true;
    }

    final String techName =
        (_job.technician?['name'] ?? '').toString().trim().toLowerCase();
    final String myName = _currentUserName.trim().toLowerCase();

    if (techName.isNotEmpty && myName.isNotEmpty && techName == myName)
      return true;

    return false;
  }

  // 1. Tambahkan fungsi Kirim Komentar

  // 2. Update Widget _buildCommentSection
  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LIST KOMENTAR
        if (_job.comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "Belum ada diskusi",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        else
          ..._job.comments.map((c) => _buildCommentBubble(c)),

        const SizedBox(height: 16),

        // INPUT KOMENTAR
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              _sendingComment
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _submitComment,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;

    setState(() => _sendingComment = true);
    try {
      final res = await JobService.addComment(
        _job.id,
        _commentCtrl.text.trim(),
      );

      if (res['success'] == true) {
        // Panggil refresh agar komentar dari admin di web juga langsung muncul
        await _refreshJob();

        if (mounted) {
          setState(() {
            _commentCtrl.clear();
            _sendingComment = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _sendingComment = false);
      debugPrint("Komentar Gagal: $e");
    }
  }

  Future<void> _refreshJob() async {
    try {
      final updatedJob = await JobService.getJobDetail(_job.id);
      if (mounted) {
        setState(() => _job = updatedJob);
      }
    } catch (e) {
      debugPrint("Refresh Gagal: $e");
    }
  }

  // Fungsi untuk ambil data terbaru (supaya komentar admin juga masuk)

  Widget _buildCommentBubble(JobComment c) {
    // FIX: Pastikan perbandingan tipe datanya sama (sama-sama int)
    final int myId = int.tryParse(_currentUserId) ?? 0;
    bool isMe = c.userId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            c.userName,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue[100] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(c.comment, style: const TextStyle(fontSize: 13)),
          ),
          // FIX: Tambahkan ?? '' agar tidak error Null Safety
          Text(
            c.createdAt ?? '',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isCompleted = _job.status == 'completed';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_kPrimary, _kAccent]),
          ),
        ),
        title: const Text(
          'Detail & Progress Tugas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(isCompleted),
            const SizedBox(height: 24),
            const Text(
              'Riwayat Pengerjaan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            if (_job.trackers.isEmpty)
              const Text(
                "Belum ada progress.",
                style: TextStyle(color: _kSub, fontSize: 13),
              )
            else
              ..._job.trackers.map((t) => _buildTrackerTile(t)),

            const SizedBox(height: 24),

            // --- PROTEKSI TOTAL FORM INPUT ---
            if (!isCompleted)
              if (_isMyJob) ...[
                const Text(
                  'Input Progress Tahap Berikutnya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildProgressForm(),
              ] else ...[
                _buildVisitorNotice(),
              ],

            const SizedBox(height: 24),
            const Text(
              'Diskusi & Komentar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            _buildCommentSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET KOMPONEN ---

  Widget _buildHeaderCard(bool isCompleted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _job.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _job.description ?? '-',
            style: const TextStyle(fontSize: 13, color: _kSub),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(
                Icons.engineering_outlined,
                size: 16,
                color: _kPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                "Teknisi: ${_job.technician?['name'] ?? '-'}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isCompleted)
            LinearProgressIndicator(
              value: ((_job.currentStep ?? 1) - 1) / 4,
              backgroundColor: _kPrimary.withOpacity(0.1),
              color: _kPrimary,
              minHeight: 6,
            )
          else
            _buildSuccessBadge(),
        ],
      ),
    );
  }

  Widget _buildVisitorNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _kPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Tugas ini sedang dikerjakan oleh ${_job.technician?['name'] ?? 'Teknisi'}. Anda hanya dapat memantau progress.",
              style: const TextStyle(
                color: _kPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: _kGreen, size: 18),
          SizedBox(width: 8),
          Text(
            'TUGAS SELESAI',
            style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTile(JobTracker t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: _kGreen.withOpacity(0.1),
            child: Text(
              '${t.stepNumber}',
              style: const TextStyle(
                color: _kGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          // Nama Tahap diambil dari descriptionValue yang diisi Admin saat update
          title: Text(
            'Tahap ${t.stepNumber}: ${t.descriptionValue ?? "Selesai"}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _kText,
            ),
          ),
          trailing: const Icon(Icons.check_circle, color: _kGreen, size: 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 20),
                  if (t.photoUrl != null) ...[
                    const Text(
                      'Bukti Foto:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _kSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        t.photoUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (t.videoUrl != null) ...[
                    const Text(
                      'Bukti Video:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _kSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(t.videoUrl!);
                        if (await canLaunchUrl(uri))
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.play_circle_fill, color: _kPrimary),
                            SizedBox(width: 12),
                            Text(
                              'Putar Video Bukti',
                              style: TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Text(
                    'Selesai pada: ${t.createdAt ?? "-"}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressForm() {
    final int currentStep = _job.currentStep ?? 1;
    final int nextStep = currentStep + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INPUT PROGRESS TAHAP $currentStep',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _kPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Deskripsi Tahap $currentStep',
              hintText: 'Apa hasil pekerjaan di tahap ini?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _kBg,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_photo == null ? 'Foto' : '✓ Foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: Text(_video == null ? 'Video' : '✓ Video'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _uploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child:
                  _uploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                        currentStep >= 4
                            ? 'Selesaikan Tugas ✓'
                            : 'Simpan & Lanjut Tahap $nextStep →',
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI AKSI ---
  Future<void> _submit() async {
    if (_uploading) return;

    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi deskripsi dulu ya Rizka!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // UPDATE: Validasi sesuai ketentuan Admin (Web sudah mewajibkan Foto)
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon tambahkan bukti foto!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      // UPDATE: Pastikan fungsi updateProgress di service kamu sudah menerima parameter photoFile dan videoFile
      final result = await JobService.updateProgress(
        jobId: _job.id,
        description: desc,
        photoFile: _photo, // Kirim Foto
        videoFile: _video, // Kirim Video
      );

      setState(() {
        _job = result['job'];
        _uploading = false;
        _descCtrl.clear();
        // Reset file setelah berhasil simpan
        _photo = null;
        _video = null;
      });

      if (_job.isCompleted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // --- FUNGSI PICKER ---

  Future<void> _pickPhoto() async {
    // Menampilkan dialog pilihan Kamera atau Galeri
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: _kPrimary),
                  title: const Text('Ambil dari Kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: _kPrimary),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );

    if (src == null) return; // User membatalkan

    final picked = await _picker.pickImage(
      source: src,
      imageQuality: 70, // Kompres sedikit agar tidak terlalu berat
    );

    if (picked != null) {
      setState(() {
        _photo = File(picked.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.videocam, color: _kPrimary),
                  title: const Text('Rekam Video Baru'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library, color: _kPrimary),
                  title: const Text('Pilih Video dari Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );

    if (src == null) return;

    final picked = await _picker.pickVideo(source: src);

    if (picked != null) {
      setState(() {
        _video = File(picked.path);
      });
    }
  }
}
