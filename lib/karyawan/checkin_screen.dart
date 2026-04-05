import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── Color Palette ─────────────────────────────────────────────────────────
const kPrimaryBlue = Color(0xFF1565C0);
const kAccentBlue = Color(0xFF1E88E5);
const kLightBlue = Color(0xFFE3F2FD);
const kDeepBlue = Color(0xFF0D47A1);
const kSkyBlue = Color(0xFF42A5F5);
const kSuccessGreen = Color(0xFF00897B);
const kErrorRed = Color(0xFFE53935);
// ───────────────────────────────────────────────────────────────────────────

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _notesController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Konfigurasi Kantor & Waktu
  double _officeLat = -6.2000;
  double _officeLng = 106.8166;
  double _officeRadius = 50.0;
  String _checkInLimit = "08:00";
  int _tolerance = 0;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLate = false;
  bool _isHoliday = false; // Status apakah hari ini libur
  String _holidayName = ""; // Nama hari libur

  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  double? _distanceFromOffice;
  bool _isInRadius = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _fetchOfficeConfig();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchOfficeConfig();
    await _fetchLocation();
  }

  Future<void> _fetchOfficeConfig() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/attendance/config'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Ambil objek data dari dalam key 'data'
        final data = responseData['data'];

        setState(() {
          _officeLat = double.parse(data['latitude'].toString());
          _officeLng = double.parse(data['longitude'].toString());
          _officeRadius = double.parse(data['radius'].toString());

          // FIX: Pastikan parsing boolean dan string aman
          _isHoliday = data['is_holiday'] == true;
          _holidayName = data['holiday_name']?.toString() ?? "";

          String rawTime = data['check_in_time']?.toString() ?? "08:00";
          _checkInLimit =
              rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;
          _tolerance = int.parse(data['late_tolerance']?.toString() ?? "0");

          _validateTime();
        });

        // Re-validate radius setelah config masuk
        if (_currentPosition != null) {
          _validateRadius(_currentPosition!);
        }
      }
    } catch (e) {
      debugPrint('Error config: $e');
    }
  }

  void _validateTime() {
    final now = DateTime.now();

    final parts = _checkInLimit.split(':');
    if (parts.length < 2) return;

    final limitTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final finalDeadline = limitTime.add(Duration(minutes: _tolerance));

    setState(() {
      _isLate = now.isAfter(finalDeadline);
    });
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = latLng;
        _isLoading = false;
      });
      _validateRadius(latLng);
      _moveCamera(latLng);
      _getAddressFromLatLng(latLng);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal mengambil lokasi: $e", isError: true);
    }
  }

  void _validateRadius(LatLng position) {
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _officeLat,
      _officeLng,
    );
    setState(() {
      _distanceFromOffice = distance;
      _isInRadius = distance <= _officeRadius;
    });
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submitCheckIn() async {
    if (_isHoliday) {
      _showSnackBar(
        "Tidak dapat absen, hari ini adalah $_holidayName!",
        isError: true,
      );
      return;
    }
    if (_isLate) {
      _showSnackBar("Maaf, waktu masuk sudah ditutup!", isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/presence/check-in'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      request.fields['latitude'] = _currentPosition!.latitude.toString();
      request.fields['longitude'] = _currentPosition!.longitude.toString();
      request.fields['notes'] =
          _notesController.text.isEmpty
              ? 'Absen Masuk Mobile'
              : _notesController.text;
      request.files.add(
        await http.MultipartFile.fromPath('photo', _imageFile!.path),
      );

      var res = await request.send();
      var response = await http.Response.fromStream(res);
      final body = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar(body['message'] ?? "Berhasil!");
        Future.delayed(
          const Duration(milliseconds: 800),
          () => Navigator.pop(context, true),
        );
      } else {
        _showSnackBar(body['message'] ?? "Gagal Absen", isError: true);
      }
    } catch (e) {
      _showSnackBar("Kesalahan koneksi.", isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? kErrorRed : kSuccessGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _moveCamera(LatLng pos) async {
    final c = await _controller.future;
    c.animateCamera(CameraUpdate.newLatLngZoom(pos, 17));
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(
        () => _currentAddress = '${p.first.street}, ${p.first.locality}',
      );
    } catch (_) {}
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _isInRadius &&
        _imageFile != null &&
        !_isLate &&
        !_isSubmitting &&
        !_isHoliday;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Presensi Masuk",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kDeepBlue, kAccentBlue],
            ),
          ),
        ),
      ),
      body: _isLoading ? _buildLoadingScreen() : _buildMapBody(canSubmit),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDeepBlue, kAccentBlue, kSkyBlue],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Icon(
                  Icons.location_searching,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Mendeteksi Lokasi...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Mohon tunggu sebentar",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBody(bool canSubmit) {
    // TAMBAHKAN PENGECEKAN INI:
    if (_currentPosition == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text("Gagal mendapatkan koordinat lokasi."),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          myLocationEnabled: true,
          initialCameraPosition: CameraPosition(
            target:
                _currentPosition!, // Sekarang aman karena sudah dicek di atas
            zoom: 17,
          ),
          onMapCreated: (c) => _controller.complete(c),
          circles: {
            Circle(
              circleId: const CircleId('office'),
              center: LatLng(_officeLat, _officeLng),
              radius: _officeRadius,
              fillColor: kAccentBlue.withOpacity(0.15),
              strokeColor: kAccentBlue,
              strokeWidth: 2,
            ),
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _buildBottomPanel(canSubmit),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(bool canSubmit) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.62,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Location row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: kAccentBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _currentAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF546E7A),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildStatusCard(),
            const SizedBox(height: 14),

            // Notes field
            TextField(
              controller: _notesController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF263238)),
              decoration: InputDecoration(
                hintText: "Catatan (Opsional)",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: kAccentBlue,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFE),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.blue.shade100,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kAccentBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _buildPhotoSection(),
            const SizedBox(height: 18),

            _buildSubmitButton(canSubmit),
          ],
        ),
      ),
    );
  }

  // ─── Photo Section ─────────────────────────────────────────────────────────
  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _takePhoto,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: _imageFile != null ? 190 : 64,
        decoration: BoxDecoration(
          color: _imageFile != null ? Colors.black : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageFile != null ? kAccentBlue : Colors.blue.shade200,
            width: _imageFile != null ? 2.5 : 1.5,
          ),
          boxShadow:
              _imageFile != null
                  ? [
                    BoxShadow(
                      color: kAccentBlue.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                  : [],
        ),
        clipBehavior: Clip.antiAlias,
        child:
            _imageFile != null
                ? _buildPhotoPreview()
                : _buildPhotoPlaceholder(),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_imageFile!, fit: BoxFit.cover),
        // Bottom gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "Ketuk untuk ganti foto",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
        // "Foto diambil" badge top-right
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kSuccessGreen.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  "Foto OK",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kAccentBlue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: kAccentBlue,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "Ambil Foto Selfie",
          style: TextStyle(
            color: kAccentBlue,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ─── Submit Button ──────────────────────────────────────────────────────────
  Widget _buildSubmitButton(bool canSubmit) {
    // Jika libur, warna tombol jadi merah pudar atau abu-abu gelap
    final buttonColor =
        _isHoliday
            ? [
              const Color(0xFFB71C1C),
              const Color(0xFFD32F2F),
            ] // Merah tua jika libur
            : (canSubmit
                ? [kDeepBlue, kAccentBlue]
                : [const Color(0xFFB0BEC5), const Color(0xFFCFD8DC)]);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: buttonColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: canSubmit ? _submitCheckIn : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            _isHoliday ? "HARI LIBUR" : "KIRIM ABSENSI",
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Status Card ───────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    // Masukkan _isHoliday ke syarat error
    final hasError = !_isInRadius || _isLate || _isHoliday;
    final bgColor =
        hasError ? const Color(0xFFFFF3F3) : const Color(0xFFF0FBF8);
    final mainColor = hasError ? kErrorRed : kSuccessGreen;

    String statusText;
    IconData statusIcon;

    if (_isHoliday) {
      statusText = "Hari Libur: $_holidayName";
      statusIcon = Icons.event_busy_rounded;
    } else if (_isLate) {
      statusText = "Waktu Absen Habis!";
      statusIcon = Icons.timer_off_rounded;
    } else if (!_isInRadius) {
      statusText = "Di Luar Radius Kantor";
      statusIcon = Icons.location_off_rounded;
    } else {
      statusText = "Lokasi Terverifikasi";
      statusIcon = Icons.verified_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mainColor.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: mainColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: mainColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Batas: $_checkInLimit  •  Toleransi: $_tolerance menit",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78909C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: mainColor.withOpacity(0.3)),
            ),
            child: Text(
              "${_distanceFromOffice?.toStringAsFixed(0) ?? '-'}m",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: mainColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
