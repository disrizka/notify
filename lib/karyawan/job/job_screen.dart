import 'package:flutter/material.dart';
import 'package:sapa_jonusa/service/job_service.dart';

const _kPrimary = Color(0xFF1565C0);
const _kAccent = Color(0xFF0D47A1);
const _kBg = Color(0xFFF0F4FF);
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kRed = Color(0xFFE53935);

class CsCreateJobScreen extends StatefulWidget {
  const CsCreateJobScreen({super.key});

  @override
  State<CsCreateJobScreen> createState() => _CsCreateJobScreenState();
}

class _CsCreateJobScreenState extends State<CsCreateJobScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<TechnicianUser> _technicians = [];
  TechnicianUser? _selectedTech;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicians() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await JobService.getTechnicians();
      setState(() {
        _technicians = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTech == null) {
      _showSnack('Pilih teknisi terlebih dahulu!', _kRed);
      return;
    }
    setState(() => _submitting = true);
    try {
      await JobService.createJob(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        technicianId: _selectedTech!.id,
      );
      if (!mounted) return;
      _showSnack('Tugas berhasil dikirim ke ${_selectedTech!.name}!', _kGreen);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack('Gagal: $e', _kRed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Buat Tugas Baru',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _error != null
              ? _buildError()
              : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
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
            onPressed: _loadTechnicians,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info Banner ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kPrimary, _kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Isi detail tugas di bawah dan pilih teknisi yang akan mengerjakan.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Judul Tugas ──────────────────────────────────────────────
            _label('Judul Tugas *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration: _inputDecoration(
                hint: 'Contoh: Perbaikan AC Ruang Rapat',
                icon: Icons.work_outline,
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Judul tidak boleh kosong'
                          : null,
            ),

            const SizedBox(height: 16),

            // ── Deskripsi ────────────────────────────────────────────────
            _label('Deskripsi Pekerjaan'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration: _inputDecoration(
                hint: 'Jelaskan detail pekerjaan yang harus dilakukan...',
                icon: Icons.description_outlined,
              ),
            ),

            const SizedBox(height: 16),

            // ── Pilih Teknisi ────────────────────────────────────────────
            _label('Pilih Teknisi *'),
            const SizedBox(height: 6),

            if (_technicians.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.orange),
                    SizedBox(width: 10),
                    Text(
                      'Tidak ada teknisi tersedia saat ini.',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ],
                ),
              )
            else
              ..._technicians.map((tech) => _buildTechnicianTile(tech)),

            const SizedBox(height: 32),

            // ── Tombol Submit ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_submitting || _technicians.isEmpty) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _submitting
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Kirim Tugas',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianTile(TechnicianUser tech) {
    final isSelected = _selectedTech?.id == tech.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTech = tech),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? _kPrimary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  tech.name.isNotEmpty ? tech.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isSelected ? Colors.white : _kSub,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tech.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? _kPrimary : _kText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tech.division,
                    style: const TextStyle(fontSize: 12, color: _kSub),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: _kText,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _kSub, fontSize: 13),
      prefixIcon: Icon(icon, color: _kSub, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
