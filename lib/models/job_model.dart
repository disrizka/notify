import 'package:sapa_jonusa/service/job_service.dart';

// --- 1. MODEL KOMENTAR (BARU) ---
class JobComment {
  final int id;
  final String comment;
  final String userName;
  final int userId;
  final String createdAt;

  JobComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.userId,
    required this.createdAt,
  });

  factory JobComment.fromJson(Map<String, dynamic> json) => JobComment(
    id: json['id'],
    comment: json['comment'],
    userName: json['user_name'] ?? '-',
    userId: json['user_id'] ?? 0,
    createdAt: json['created_at'] ?? '',
  );
}

// --- 2. MODEL TRACKER (RIWAYAT TAHAP) ---
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
    id: json['id'],
    stepNumber: json['step_number'] ?? 0,
    descriptionValue: json['description_value'],
    photoUrl: json['photo_url'],
    videoUrl: json['video_url'],
    createdAt: json['created_at'],
  );
}

// --- 3. MODEL JOB (DATA UTAMA) ---
class Job {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int? currentStep;
  final String? feedback;
  final String? createdAt;
  final Map<String, dynamic>? cs;
  final Map<String, dynamic>? technician;
  final List<JobTracker> trackers;
  final List<JobComment> comments; // TAMBAHKAN INI

  Job({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.currentStep,
    this.feedback,
    this.createdAt,
    this.cs,
    this.technician,
    required this.trackers,
    required this.comments, // TAMBAHKAN INI
  });

  // GETTER: Ambil ID Teknisi secara aman
  int get technicianId {
    if (technician != null && technician!['id'] != null) {
      return technician!['id'] is int
          ? technician!['id']
          : int.parse(technician!['id'].toString());
    }
    return 0;
  }

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    status: json['status'],
    currentStep: json['current_step'],
    feedback: json['feedback'],
    createdAt: json['created_at'],
    cs: json['cs'] != null ? Map<String, dynamic>.from(json['cs']) : null,
    technician:
        json['technician'] != null
            ? Map<String, dynamic>.from(json['technician'])
            : null,
    // Parsing List Tracker
    trackers:
        (json['trackers'] as List<dynamic>? ?? [])
            .map((t) => JobTracker.fromJson(t))
            .toList(),
    // Parsing List Komentar (PENTING!)
    comments:
        (json['comments'] as List<dynamic>? ?? [])
            .map((c) => JobComment.fromJson(c))
            .toList(),
  );

  bool get isPending => status == 'pending';
  bool get isProcess => status == 'process';
  bool get isCompleted => status == 'completed';
}
