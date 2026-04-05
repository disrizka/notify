// lib/models/job_model.dart

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
    stepNumber: json['step_number'],
    descriptionValue: json['description_value'],
    photoUrl: json['photo_url'],
    videoUrl: json['video_url'],
    createdAt: json['created_at'],
  );
}

class Job {
  final int id;
  final String title;
  final String? description;
  final String status; // pending | process | completed
  final int? currentStep;
  final String? feedback;
  final String? createdAt;
  final Map<String, dynamic>? cs;
  final Map<String, dynamic>? technician;
  final List<JobTracker> trackers;

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
  });

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
    trackers:
        (json['trackers'] as List<dynamic>? ?? [])
            .map((t) => JobTracker.fromJson(t))
            .toList(),
  );

  bool get isPending => status == 'pending';
  bool get isProcess => status == 'process';
  bool get isCompleted => status == 'completed';
}
