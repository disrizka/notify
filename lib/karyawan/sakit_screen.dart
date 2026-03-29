import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notify/api/api.dart' as Api;


class SakitScreen extends StatefulWidget {
  const SakitScreen({super.key});

  @override
  State<SakitScreen> createState() => _SakitScreenState();
}

class _SakitScreenState extends State<SakitScreen> {
  final _storage = const FlutterSecureStorage();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _imageFile;
  bool _loading = false;

  // Fungsi buka Kamera langsung
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  // Bagian fungsi _submitSakit yang sudah diperbaiki total
  Future<void> _submitSakit() async {
    if (_startDate == null ||
        _reasonController.text.isEmpty ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi form & Foto Surat Dokter!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String? token = await _storage.read(key: 'auth_token');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/presence/permissions'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // SINKRONISASI FIELD DENGAN LARAVEL & BLADE WEB
      // Di dalam fungsi _submitSakit()
      request.fields['category'] = 'sakit'; // PASTIKAN HURUF KECIL SEMUA
      request.fields['start_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(_startDate!);
      request.fields['reason'] = _reasonController.text;

      // Field pendukung durasi
      request.fields['start_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(_startDate!);
      request.fields['end_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(_endDate ?? _startDate!);

      // Key lampiran harus 'attachment' agar link "Lihat Dokumen" di Web aktif
      request.files.add(
        await http.MultipartFile.fromPath('attachment', _imageFile!.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (streamedResponse.statusCode == 201 ||
          streamedResponse.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laporan sakit berhasil dikirim"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Gagal mengirim laporan. Periksa koneksi/absen harian.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Laporan Sakit",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Informasi Sakit",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          _dateTile(
            "Mulai Sakit",
            _startDate,
            (d) => setState(() => _startDate = d),
          ),
          _dateTile(
            "Selesai/Masuk Kembali",
            _endDate,
            (d) => setState(() => _endDate = d),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: "Keterangan/Alasan Sakit",
              border: OutlineInputBorder(),
              hintText: "Contoh: Demam tinggi dan pusing",
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 25),
          const Text(
            "Bukti Surat Dokter (Wajib)",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child:
                  _imageFile == null
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Ambil Foto Surat Dokter",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
            ),
          ),
          const SizedBox(height: 35),
          ElevatedButton(
            onPressed: _loading ? null : _submitSakit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
                _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                      "KIRIM LAPORAN SAKIT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, Function(DateTime) onPick) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          date == null ? label : DateFormat('dd MMMM yyyy').format(date),
        ),
        trailing: const Icon(Icons.calendar_month, color: Colors.redAccent),
        onTap: () async {
          var picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now().subtract(
              const Duration(days: 7),
            ), // Maksimal telat lapor 7 hari
            lastDate: DateTime(2030),
          );
          if (picked != null) onPick(picked);
        },
      ),
    );
  }
}
