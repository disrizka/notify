import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sapa_jonusa/api/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class Job {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int currentStep;
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
    required this.currentStep,
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
      description: json['description'],
      status: json['status'] ?? 'pending',
      // Gunakan tryParse agar aman jika current_step datang sebagai String atau null
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
      stepNumber: int.tryParse(json['step_number']?.toString() ?? '0') ?? 0,
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

class TechnicianUser {
  final int id;
  final String name;
  final String email;
  final String division;

  TechnicianUser({
    required this.id,
    required this.name,
    required this.email,
    required this.division,
  });

  factory TechnicianUser.fromJson(Map<String, dynamic> json) {
    return TechnicianUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      division: json['division'] ?? '-',
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class JobService {
  static const String _apiPath = "$baseUrl/api";

  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  static Future<List<Job>> getActiveJobs() async {
    final token = await _token();
    try {
      final res = await http.get(
        Uri.parse('$_apiPath/jobs/active'),
        headers: _headers(token),
      );

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        List<dynamic> data =
            (decoded is Map && decoded.containsKey('data'))
                ? decoded['data']
                : (decoded as List);
        return data.map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint("Error Active Jobs: $e");
    }
    return [];
  }

  static Future<List<Job>> getJobHistory() async {
    final token = await _token();
    try {
      final res = await http.get(
        Uri.parse('$_apiPath/jobs/history'), // Gunakan 10.0.2.2:8000/api
        headers: _headers(token),
      );

      if (res.statusCode == 200) {
        final dynamic body = jsonDecode(res.body);

        // Ambil List dari dalam key 'data' (Wajib karena Laravel mengirim {success:true, data:[]})
        List<dynamic> data;
        if (body is Map && body.containsKey('data')) {
          data = body['data'];
        } else {
          data = body as List;
        }

        return data.map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint("Error Load History: $e");
    }
    return []; // Balikkan list kosong agar loading spinner di UI berhenti
  }

  static Future<void> acceptJob(int jobId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_apiPath/jobs/$jobId/accept'),
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
      Uri.parse('$_apiPath/jobs/$jobId/progress'),
    );
    request.headers.addAll(_headers(token));
    request.fields['description'] = description;

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
      final data = jsonDecode(res.body);
      return {
        'completed': data['completed'] ?? false,
        'message': data['message'] ?? '',
        // Laravel kamu mengembalikan data job dalam key 'job' atau 'data'
        'job': Job.fromJson(data['job'] ?? data['data']),
      };
    }
    throw Exception('Gagal update progress');
  }

  static Future<List<TechnicianUser>> getTechnicians() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_apiPath/jobs/technicians'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((t) => TechnicianUser.fromJson(t)).toList();
    }
    return [];
  }

  static Future<Job> createJob({
    required String title,
    required String description,
    required int technicianId,
  }) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_apiPath/jobs'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'technician_id': technicianId,
      }),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return Job.fromJson(data['job'] ?? data['data']);
    }
    throw Exception('Gagal membuat tugas');
  }

  static Future<JobComment> addComment({
    required int jobId,
    required String comment,
  }) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_apiPath/jobs/$jobId/comments'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'comment': comment}),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return JobComment.fromJson(data['comment']);
    }
    throw Exception('Gagal mengirim komentar');
  }
}
