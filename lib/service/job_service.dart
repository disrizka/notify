import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ── Models ────────────────────────────────────────────────────────────────────

class TechnicianUser {
  final int id;
  final String name;
  final String division;

  TechnicianUser({
    required this.id,
    required this.name,
    required this.division,
  });

  factory TechnicianUser.fromJson(Map<String, dynamic> json) {
    return TechnicianUser(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      division: json['division'] as String? ?? '-',
    );
  }
}

class Job {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int? currentStep;
  final int? technicianId;
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
    this.technicianId,
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
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      currentStep: int.tryParse(json['current_step']?.toString() ?? ''),
      technicianId: json['technician_id'] as int?,
      feedback: json['feedback'] as String?,
      cs:
          json['cs'] != null
              ? Map<String, dynamic>.from(json['cs'] as Map)
              : null,
      technician:
          json['technician'] != null
              ? Map<String, dynamic>.from(json['technician'] as Map)
              : null,
      trackers:
          (json['trackers'] as List? ?? [])
              .map((t) => JobTracker.fromJson(t as Map<String, dynamic>))
              .toList(),
      comments:
          (json['comments'] as List? ?? [])
              .map((c) => JobComment.fromJson(c as Map<String, dynamic>))
              .toList(),
      createdAt: json['created_at'] as String?,
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

  factory JobTracker.fromJson(Map<String, dynamic> json) => JobTracker(
    id: json['id'] as int? ?? 0,
    stepNumber: json['step_number'] as int? ?? 0,
    descriptionValue: json['description_value'] as String?,
    photoUrl: json['photo_url'] as String?,
    videoUrl: json['video_url'] as String?,
    createdAt: json['created_at'] as String?,
  );
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

  factory JobComment.fromJson(Map<String, dynamic> json) => JobComment(
    id: json['id'] as int? ?? 0,
    comment: json['comment'] as String? ?? '',
    userName: json['user_name'] as String? ?? '-',
    userId: json['user_id'] as int? ?? 0,
    createdAt: json['created_at'] as String?,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class JobService {
  static const _storage = FlutterSecureStorage();
  static String get _base => '${Api.baseUrl}/api';

  // ── Debug: print semua isi storage ────────────────────────────────────────
  // Panggil di initState: await JobService.debugStorage();
  static Future<void> debugStorage() async {
    try {
      final all = await _storage.readAll();
      debugPrint('══════════════════════════════════════════');
      debugPrint('📦 SECURE STORAGE — semua key yang tersimpan:');
      if (all.isEmpty) {
        debugPrint('  ⚠️  Storage KOSONG — token belum tersimpan!');
      } else {
        all.forEach((k, v) {
          final display = v.length > 100 ? '${v.substring(0, 100)}...' : v;
          debugPrint('  🔑 "$k" = "$display"');
        });
      }
      debugPrint('══════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ debugStorage error: $e');
    }
  }

  // ── Ambil token — key 'auth_token' sesuai login_screen.dart ──────────────
  static Future<String> _getToken() async {
    final token = await _storage.read(key: 'auth_token');
    debugPrint(
      '🔐 _getToken: "${token == null
          ? "NULL - tidak ada!"
          : token.length > 20
          ? "${token.substring(0, 20)}..."
          : token}"',
    );
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }
    return token;
  }

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  static void _checkResponse(http.Response res, String ctx) {
    debugPrint('[$ctx] status=${res.statusCode}');
    if (res.statusCode == 401)
      throw Exception('Sesi habis. Silakan login ulang.');
    if (res.statusCode == 403)
      throw Exception('Anda tidak memiliki izin untuk aksi ini.');
    if (res.statusCode >= 400) {
      String msg = 'Error ${res.statusCode}';
      try {
        msg = (jsonDecode(res.body)['message'] as String?) ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // ── GET active jobs ───────────────────────────────────────────────────────
  static Future<List<Job>> getActiveJobs() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/active'),
      headers: _headers(token),
    );
    _checkResponse(res, 'getActiveJobs');
    final list = (jsonDecode(res.body)['data'] as List? ?? []);
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── GET job history ───────────────────────────────────────────────────────
  static Future<List<Job>> getJobHistory() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/history'),
      headers: _headers(token),
    );
    _checkResponse(res, 'getJobHistory');
    final list = (jsonDecode(res.body)['data'] as List? ?? []);
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── GET technicians ───────────────────────────────────────────────────────
  static Future<List<TechnicianUser>> getTechnicians() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/technicians'),
      headers: _headers(token),
    );
    debugPrint('[getTechnicians] body=${res.body}');
    _checkResponse(res, 'getTechnicians');

    final body = jsonDecode(res.body);
    final List<dynamic> list =
        body is Map && body['data'] != null
            ? body['data'] as List
            : body is List
            ? body
            : [];

    return list
        .map((e) => TechnicianUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST create job ───────────────────────────────────────────────────────
  static Future<Job> createJob({
    required String title,
    required String description,
    required int technicianId,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_base/jobs'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'technician_id': technicianId,
      }),
    );
    debugPrint('[createJob] body=${res.body}');
    _checkResponse(res, 'createJob');
    return Job.fromJson(jsonDecode(res.body)['job'] as Map<String, dynamic>);
  }

  // ── POST accept job ───────────────────────────────────────────────────────
  static Future<void> acceptJob(int jobId) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_base/jobs/$jobId/accept'),
      headers: _headers(token),
    );
    _checkResponse(res, 'acceptJob');
  }

  // ── POST update progress ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProgress({
    required int jobId,
    required String description,
    File? photoFile,
    File? videoFile,
  }) async {
    final token = await _getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/jobs/$jobId/progress'),
    );
    req.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    req.fields['description_value'] = description;

    if (photoFile != null) {
      req.files.add(await http.MultipartFile.fromPath('photo', photoFile.path));
    }
    if (videoFile != null) {
      req.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    debugPrint('[updateProgress] status=${res.statusCode} body=${res.body}');
    _checkResponse(res, 'updateProgress');

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final job = Job.fromJson(data['job'] as Map<String, dynamic>);
    return {
      'job': job,
      'completed': job.isCompleted,
      'message': data['message'] as String? ?? 'Progress diperbarui',
    };
  }

  // ── POST add comment ──────────────────────────────────────────────────────
  static Future<JobComment> addComment({
    required int jobId,
    required String comment,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_base/jobs/$jobId/comments'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'comment': comment}),
    );
    debugPrint('[addComment] status=${res.statusCode} body=${res.body}');
    _checkResponse(res, 'addComment');
    return JobComment.fromJson(
      jsonDecode(res.body)['comment'] as Map<String, dynamic>,
    );
  }

  // ── GET job detail ────────────────────────────────────────────────────────
  static Future<Job> getJobDetail(int jobId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/$jobId'),
      headers: _headers(token),
    );
    _checkResponse(res, 'getJobDetail');
    final body = jsonDecode(res.body);
    return Job.fromJson(body['job'] as Map<String, dynamic>);
  }
}
