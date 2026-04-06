import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
        color: Color(0xFFFFF9C4).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFBC02D).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFF57F17), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Hanya teknisi (${_job.technician?['name'] ?? 'Tester'}) yang dapat mengisi progress. Anda hanya dapat memantau.",
              style: TextStyle(
                color: Color(0xFFF57F17),
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _kGreen,
                child: Text(
                  '${t.stepNumber}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Tahap ${t.stepNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: _kGreen, size: 16),
            ],
          ),
          if (t.descriptionValue != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                t.descriptionValue!,
                style: const TextStyle(fontSize: 13, color: _kText),
              ),
            ),
        ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Form (seperti di Web)
          Text(
            'TAHAP $currentStep: INPUT BUKTI PEKERJAAN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _kPrimary,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // 1. INPUT DESKRIPSI
          const Text(
            'Deskripsi Pekerjaan (Wajib)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Jelaskan apa yang kamu lakukan di tahap ini...',
              hintStyle: TextStyle(color: _kSub.withOpacity(0.5), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _kBg,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // 2. INPUT FOTO (Area putus-putus senada Web)
          const Text(
            'Bukti Foto',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: double.infinity,
              height:
                  _photo == null ? 80 : 150, // Lebih tinggi jika ada preview
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
                // Efek border putus-putus senada web
                border: Border.all(
                  color: _kPrimary.withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child:
                  _photo == null
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: _kPrimary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tambah Foto Bukti',
                            style: TextStyle(color: _kPrimary, fontSize: 12),
                          ),
                        ],
                      )
                      : Stack(
                        // Preview Foto
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _photo!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _photo = null),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. INPUT VIDEO (Area putus-putus senada Web)
          const Text(
            'Bukti Video',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPrimary.withOpacity(0.2)),
              ),
              child:
                  _video == null
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_outlined,
                            color: _kPrimary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tambah Video Bukti',
                            style: TextStyle(color: _kPrimary, fontSize: 12),
                          ),
                        ],
                      )
                      : Row(
                        // Indikator Video terpilih
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: _kGreen),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Video terpilih ✓',
                              style: TextStyle(color: _kGreen, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _video = null),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 24),

          // TOMBOL SUBMIT
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _uploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child:
                  _uploading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        currentStep >= 4
                            ? 'Selesaikan Tugas ✓'
                            : 'Simpan & Lanjut Tahap $nextStep →',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      children: [
        TextField(
          controller: _commentCtrl,
          decoration: InputDecoration(
            hintText: 'Tulis komentar...',
            suffixIcon: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.send, color: _kPrimary),
            ),
            border: UnderlineInputBorder(),
          ),
        ),
      ],
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
