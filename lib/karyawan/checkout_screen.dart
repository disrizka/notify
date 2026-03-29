import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:notify/api/api.dart';
import 'package:notify/api/api.dart' as Api;

// ─── Color Palette ─────────────────────────────────────────────────────────
const kPrimaryBlue = Color(0xFF1565C0);
const kAccentBlue = Color(0xFF1E88E5);
const kLightBlue = Color(0xFFE3F2FD);
const kDeepBlue = Color(0xFF0D47A1);
const kSkyBlue = Color(0xFF42A5F5);
const kSuccessGreen = Color(0xFF00897B);
const kErrorRed = Color(0xFFE53935);
const kAmber = Color(0xFFF57C00);
// ───────────────────────────────────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _notesController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Office Config ──────────────────────────────────────────────────────────
  double _officeLat = -6.2000;
  double _officeLng = 106.8166;
  double _officeRadius = 50.0;
  String _checkOutLimit = "17:00"; // dari backend
  int _tolerance = 0; // toleransi menit dari backend

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isInRadius = false;
  bool _isTooEarly = true; // default true agar tombol mati sebelum data siap

  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  double? _distanceFromOffice;
  File? _imageFile;

  // ── Computed ───────────────────────────────────────────────────────────────
  /// Jam minimal boleh checkout = checkOutLimit - tolerance
  DateTime get _minAllowedTime {
    final now = DateTime.now();
    final parts = _checkOutLimit.split(':');
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts[0]) ?? 17,
      int.tryParse(parts[1]) ?? 0,
    );
    return target.subtract(Duration(minutes: _tolerance));
  }

  String get _minAllowedTimeStr => DateFormat('HH:mm').format(_minAllowedTime);

  @override
  void initState() {
    super.initState();
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

  // ── 1. Fetch config (lat, lng, radius, jam pulang, toleransi) ──────────────
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

      debugPrint("Respon Config Checkout: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final data = responseData['data'] ?? responseData;

        setState(() {
          _officeLat = double.parse(data['latitude'].toString());
          _officeLng = double.parse(data['longitude'].toString());
          _officeRadius = double.parse(data['radius'].toString());

          // Ambil jam pulang: "17:00:00" → "17:00"
          final rawTime = data['check_out_time']?.toString() ?? '17:00';
          _checkOutLimit = rawTime.split(':').take(2).join(':');

          // Toleransi dalam menit
          _tolerance =
              int.tryParse(data['late_tolerance']?.toString() ?? '0') ?? 0;

          _isLoading = false;
        });

        // Langsung validasi waktu setelah dapat data
        _validateCheckOutTime();

        // Jika lokasi sudah ada, validasi radius ulang
        if (_currentPosition != null) _validateRadius(_currentPosition!);
      }
    } catch (e) {
      debugPrint('Error Config Checkout: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── 2. Validasi waktu checkout ─────────────────────────────────────────────
  void _validateCheckOutTime() {
    final now = DateTime.now();
    setState(() {
      // Tombol aktif hanya jika now >= minAllowedTime
      _isTooEarly = now.isBefore(_minAllowedTime);
    });
  }

  // ── 3. Ambil lokasi user ───────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final position = await _determinePosition();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = latLng;
        _isLoading = false;
      });
      _validateRadius(latLng);
      _moveCamera(latLng);
      _getAddressFromLatLng(latLng);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(e.toString(), isError: true);
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'GPS tidak aktif. Silakan aktifkan GPS.';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'Izin lokasi ditolak.';
    }
    if (permission == LocationPermission.deniedForever)
      throw 'Izin lokasi ditolak permanen.';

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ── 4. Validasi radius ─────────────────────────────────────────────────────
  void _validateRadius(LatLng position) {
    final distance = _haversine(
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

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }

  // ── 5. Ambil foto ──────────────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  // ── 6. Submit checkout ─────────────────────────────────────────────────────
  Future<void> _submitCheckOut() async {
    if (_imageFile == null || _currentPosition == null) {
      _showSnackBar("Foto dan lokasi wajib ada!", isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    debugPrint("🚀 [DEBUG] Memulai proses Checkout...");

    try {
      final token = await _storage.read(key: 'auth_token');
      final url = "${Api.baseUrl}/api/presence/checkout";
      debugPrint("🔗 URL: $url");

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      request.fields['latitude'] = _currentPosition!.latitude.toString();
      request.fields['longitude'] = _currentPosition!.longitude.toString();
      request.fields['notes'] =
          _notesController.text.isEmpty
              ? 'Absen Pulang Mobile'
              : _notesController.text;
      request.files.add(
        await http.MultipartFile.fromPath('photo', _imageFile!.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📥 Status Server: ${response.statusCode}");
      debugPrint("📄 Respon Server: ${response.body}");

      final Map<String, dynamic> body = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSnackBar(body['message'] ?? 'Berhasil Pulang!');
          Navigator.of(context).pop(true);
        }
      } else {
        _showSnackBar(body['message'] ?? 'Gagal', isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error Catch: $e");
      if (mounted) _showSnackBar('Koneksi Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final p = placemarks.first;
      if (mounted)
        setState(() => _currentAddress = '${p.street}, ${p.locality}');
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Alamat tidak terdeteksi');
    }
  }

  void _moveCamera(LatLng pos) async {
    final c = await _controller.future;
    c.animateCamera(CameraUpdate.newLatLngZoom(pos, 17));
  }

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

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Tombol aktif hanya jika: dalam radius + foto ada + tidak terlalu awal
    final canSubmit =
        _isInRadius && _imageFile != null && !_isSubmitting && !_isTooEarly;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Presensi Pulang",
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

  // ─── Loading Screen ─────────────────────────────────────────────────────────
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

  // ─── Map Body ───────────────────────────────────────────────────────────────
  Widget _buildMapBody(bool canSubmit) {
    return Stack(
      children: [
        GoogleMap(
          myLocationEnabled: true,
          initialCameraPosition: CameraPosition(
            target: _currentPosition!,
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

  // ─── Bottom Panel ───────────────────────────────────────────────────────────
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

            // Status Card (radius + waktu)
            _buildStatusCard(),
            const SizedBox(height: 14),

            // Notes field
            TextField(
              controller: _notesController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF263238)),
              decoration: InputDecoration(
                hintText: "Keterangan (Opsional)",
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

  // ─── Status Card (radius + waktu) ──────────────────────────────────────────
  Widget _buildStatusCard() {
    // Tentukan warna & pesan berdasarkan kombinasi kondisi
    Color mainColor;
    IconData statusIcon;
    String statusText;

    if (!_isInRadius) {
      mainColor = kErrorRed;
      statusIcon = Icons.location_off_rounded;
      statusText = "Di Luar Radius Kantor";
    } else if (_isTooEarly) {
      mainColor = kAmber;
      statusIcon = Icons.access_time_rounded;
      statusText = "Belum Waktunya Pulang";
    } else {
      mainColor = kSuccessGreen;
      statusIcon = Icons.verified_rounded;
      statusText = "Lokasi & Waktu Terverifikasi";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mainColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris atas: ikon + teks status + jarak
          Row(
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
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: mainColor,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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

          // Divider + info jadwal
          Divider(color: mainColor.withOpacity(0.2), height: 20),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: mainColor.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                "Jadwal Pulang: $_checkOutLimit"
                "  •  Minimal Absen: $_minAllowedTimeStr",
                style: TextStyle(
                  fontSize: 11,
                  color: mainColor.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Photo Section ──────────────────────────────────────────────────────────
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient:
              canSubmit
                  ? const LinearGradient(
                    colors: [kDeepBlue, kAccentBlue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                  : const LinearGradient(
                    colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)],
                  ),
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              canSubmit
                  ? [
                    BoxShadow(
                      color: kAccentBlue.withOpacity(0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                  : [],
        ),
        child: ElevatedButton(
          onPressed: canSubmit ? _submitCheckOut : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        "KIRIM ABSENSI",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
