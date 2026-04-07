import 'package:flutter/material.dart';
import 'package:sapa_jonusa/service/job_service.dart';

class JobCreateScreen extends StatefulWidget {
  const JobCreateScreen({super.key});

  @override
  State<JobCreateScreen> createState() => _JobCreateScreenState();
}

class _JobCreateScreenState extends State<JobCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _selectedTechId;
  List<dynamic> _technicians = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTech();
  }

  // FUNGSI 1: Ambil daftar teknisi dari API
  void _loadTech() async {
    try {
      final data = await JobService.getTechnicians();
      setState(() => _technicians = data);
    } catch (e) {
      debugPrint("Gagal load teknisi: $e");
    }
  }

  // FUNGSI 2: Kirim data tugas ke Laravel
  void _submit() async {
    if (_titleCtrl.text.isEmpty || _selectedTechId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Judul dan Teknisi wajib diisi!")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await JobService.createJob(
        title: _titleCtrl.text,
        description: _descCtrl.text,
        technicianId: _selectedTechId!,
      );

      // FIX: Logika pengecekan harus berada di dalam fungsi async ini
      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true); // Kembali ke list dan refresh
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tugas berhasil dibuat!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(res['message'] ?? "Gagal menyimpan tugas");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Buat Tugas Baru",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E), // Sesuaikan tema JONUSA
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Detail Pekerjaan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: "Judul Tugas",
                hintText: "Contoh: Perbaikan AC Lantai 2",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Deskripsi",
                hintText: "Jelaskan detail kendala...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Pilih Pelaksana",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              hint: const Text("Pilih Teknisi"),
              value: _selectedTechId,
              items:
                  _technicians
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t['id'],
                          child: Text(t['name'] ?? '-'),
                        ),
                      )
                      .toList(),
              onChanged: (v) => setState(() => _selectedTechId = v),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading ? null : _submit,
                child:
                    _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "Kirim Tugas ke Teknisi",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
