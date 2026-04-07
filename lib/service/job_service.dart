import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ── Model ─────────────────────────────────────────────────────────────────────

class Job {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int? currentStep;
  final int? technicianId; // PINDAHKAN KE SINI (sebagai properti class)
  final String? feedback;
  final Map<String, dynamic>? cs;
  final Map<String, dynamic>? technician;
  final List<JobTracker> trackers;
  final List<JobComment> comments;
  final String? createdAt;

  Job({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.currentStep,
    this.technicianId, // Masukkan ke constructor dengan benar
    this.feedback,
    this.cs,
    this.technician,
    this.trackers = const [],
    this.comments = const [],
    this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isProcess => status == 'process';
  bool get isPending => status == 'pending';

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      technicianId: json['technician_id'], // Ambil ID teknisi dari database
      description: json['description'],
      status: json['status'] ?? 'pending',
      currentStep: int.tryParse(json['current_step']?.toString() ?? '1') ?? 1,
      feedback: json['feedback'],
      cs: json['cs'] != null ? Map<String, dynamic>.from(json['cs']) : null,
      technician:
          json['technician'] != null
              ? Map<String, dynamic>.from(json['technician'])
              : null,
      trackers:
          (json['trackers'] as List? ?? [])
              .map((t) => JobTracker.fromJson(t))
              .toList(),
      comments:
          (json['comments'] as List? ?? [])
              .map((c) => JobComment.fromJson(c))
              .toList(),
      createdAt: json['created_at'],
    );
  }
}

class JobTracker {
  final int id;
  final int stepNumber;
  final String? descriptionValue;
  final String? photoUrl;
  final String? videoUrl;
  final String? createdAt;

  JobTracker({
    required this.id,
    required this.stepNumber,
    this.descriptionValue,
    this.photoUrl,
    this.videoUrl,
    this.createdAt,
  });

  factory JobTracker.fromJson(Map<String, dynamic> json) {
    return JobTracker(
      id: json['id'] ?? 0,
      stepNumber: json['step_number'] ?? 0,
      descriptionValue: json['description_value'],
      photoUrl: json['photo_url'],
      videoUrl: json['video_url'],
      createdAt: json['created_at'],
    );
  }
}

class JobComment {
  final int id;
  final String comment;
  final String userName;
  final int userId;
  final String? createdAt;

  JobComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.userId,
    this.createdAt,
  });

  factory JobComment.fromJson(Map<String, dynamic> json) {
    return JobComment(
      id: json['id'] ?? 0,
      comment: json['comment'] ?? '',
      userName: json['user_name'] ?? '-',
      userId: json['user_id'] ?? 0,
      createdAt: json['created_at'],
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class JobService {
  static const _storage = FlutterSecureStorage();

  // Ini sudah benar, gunakan ini SAJA untuk semua fungsi
  static String get _baseUrl => '${Api.baseUrl}/api';

  static Future<String> _token() async {
    final token = await _storage.read(key: 'auth_token');
    return token ?? '';
  }

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  static List<Job> _parseJobList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded
            .map((j) => Job.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          return data
              .map((j) => Job.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Job>> getActiveJobs() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_baseUrl/jobs/active'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) return _parseJobList(res.body);
    throw Exception('Sesi habis (401). Silakan login ulang.');
  }

  static Future<List<Job>> getJobHistory() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_baseUrl/jobs/history'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) return _parseJobList(res.body);
    throw Exception('Gagal memuat riwayat');
  }

  static Future<void> acceptJob(int jobId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_baseUrl/jobs/$jobId/accept'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) throw Exception('Gagal menerima tugas');
  }

  static Future<Map<String, dynamic>> updateProgress({
    required int jobId,
    required String description,
    File? photoFile,
    File? videoFile,
  }) async {
    final token = await _token();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/jobs/$jobId/progress'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    request.fields['description_value'] =
        description; // Sesuaikan dengan key Laravel

    if (photoFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photoFile.path),
      );
    }
    if (videoFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'message': data['message'] ?? '',
        'completed': data['completed'] ?? false, // tambahkan ini
        'job': Job.fromJson(data['job'] as Map<String, dynamic>),
      };
    }
    throw Exception('Gagal update progress');
  }

  static Future<Map<String, dynamic>> addComment(
    int jobId,
    String comment,
  ) async {
    final token = await _storage.read(key: 'auth_token');

    // FIX: pakai _baseUrl bukan baseUrl
    final url = Uri.parse('$_baseUrl/jobs/$jobId/comments');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'comment': comment}),
    );

    debugPrint("STATUS KOMENTAR: ${response.statusCode}");
    debugPrint("BODY KOMENTAR: ${response.body}");

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal kirim komentar: ${response.statusCode}');
    }
  }

  static Future<Job> getJobDetail(int jobId) async {
    final token = await _storage.read(key: 'auth_token');

    // FIX: pakai _baseUrl bukan baseUrl
    final response = await http.get(
      Uri.parse('$_baseUrl/jobs/$jobId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Job.fromJson(data['job'] ?? data);
    } else {
      throw Exception('Gagal mengambil data terbaru');
    }
  }

  static Future<List<dynamic>> getTechnicians() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      // FIX: pakai _baseUrl bukan baseUrl
      final response = await http.get(
        Uri.parse('$_baseUrl/jobs/technicians'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("STATUS TECHNICIANS: ${response.statusCode}");
      debugPrint("BODY TECHNICIANS: ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("Network Error getTechnicians: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> createJob({
    required String title,
    required String description,
    required int technicianId,
  }) async {
    final token = await _storage.read(key: 'auth_token');

    // FIX: pakai _baseUrl bukan baseUrl
    final response = await http.post(
      Uri.parse('$_baseUrl/jobs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'technician_id': technicianId,
      }),
    );

    debugPrint("STATUS CREATE JOB: ${response.statusCode}");
    debugPrint("BODY CREATE JOB: ${response.body}");

    return jsonDecode(response.body);
  }
}
