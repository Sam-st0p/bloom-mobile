class ModuleModel {
  final String id;
  final String title;
  final String category;
  final int progress;
  final String status;
  final int colorValue;
  final int pages;        // kept for library_screen compatibility
  final bool hasBadge;    // kept for library_screen compatibility

  const ModuleModel({
    required this.id,
    required this.title,
    required this.category,
    required this.progress,
    required this.status,
    required this.colorValue,
    this.pages = 0,
    this.hasBadge = false,
  });

  factory ModuleModel.fromMap(Map<String, dynamic> map, {int progress = 0}) {
    return ModuleModel(
      id:         map['id']?.toString() ?? '',
      title:      map['title'] ?? 'Untitled Module',
      category:   map['categories']?['name'] ?? map['category'] ?? 'General',
      progress:   progress,
      status:     map['status'] ?? 'published',
      colorValue: 0xFF40916C,
      pages:      map['pages'] ?? 0,
      hasBadge:   progress == 100,
    );
  }
}

class SeminarModel {
  final String id;
  final String title;
  final String date;
  final String time;
  final String speaker;
  final String type;
  final int participants;
  final int colorValue;

  const SeminarModel({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.speaker,
    required this.type,
    required this.participants,
    required this.colorValue,
  });

  factory SeminarModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['scheduled_at'] ?? map['date'] ?? '';
    final dateStr = rawDate.toString().isNotEmpty
        ? rawDate.toString().substring(0, 10)
        : 'TBA';
    return SeminarModel(
      id:           map['id']?.toString() ?? '',
      title:        map['title'] ?? 'Untitled Seminar',
      date:         dateStr,
      time:         map['time'] ?? '',
      speaker:      map['speaker'] ?? '',
      type:         map['status'] == 'active' ? 'Live' : 'Upcoming',
      participants: map['participants_count'] ?? 0,
      colorValue:   0xFF2D6A4F,
    );
  }
}

class EventModel {
  final String id;
  final String title;
  final String date;
  final String category;
  final int colorValue;

  const EventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.colorValue,
  });

  factory EventModel.fromMap(Map<String, dynamic> map) {
    final raw = map['start_date'] ?? map['start_time'] ?? map['date'] ?? '';
    final dateStr = raw.toString().length >= 10 ? raw.toString().substring(5, 10) : '';
    return EventModel(
      id:         map['id']?.toString() ?? '',
      title:      map['title'] ?? 'Untitled Event',
      date:       dateStr,
      category:   map['category'] ?? 'Event',
      colorValue: 0xFFF4A261,
    );
  }
}

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool earned;
  final int colorValue;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earned,
    required this.colorValue,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map, {bool earned = false}) {
    return BadgeModel(
      id:          map['id']?.toString() ?? '',
      name:        map['name'] ?? 'Badge',
      description: map['description'] ?? '',
      icon:        map['icon'] ?? '🏅',
      earned:      earned,
      colorValue:  0xFF40916C,
    );
  }
}

class CertificateModel {
  final String id;
  final String title;
  final String date;
  final String issuer;
  final int colorValue;

  const CertificateModel({
    required this.id,
    required this.title,
    required this.date,
    required this.issuer,
    required this.colorValue,
  });

  factory CertificateModel.fromMap(Map<String, dynamic> map) {
    final raw = map['issued_at'] ?? map['date'] ?? '';
    final dateStr = raw.toString().length >= 10 ? raw.toString().substring(0, 10) : '';
    return CertificateModel(
      id:         map['id']?.toString() ?? '',
      title:      map['title'] ?? 'Certificate',
      date:       dateStr,
      issuer:     map['issuer'] ?? 'GADRC CvSU',
      colorValue: 0xFF2D6A4F,
    );
  }
}

// ForumPost uses String id throughout to match updated models
class ForumPost {
  final String id;
  final String user;
  final String avatar;
  final String title;
  final String body;
  int votes;
  final int comments;
  final String time;
  bool liked;
  final String flair;

  ForumPost({
    required this.id,
    required this.user,
    required this.avatar,
    required this.title,
    required this.body,
    required this.votes,
    required this.comments,
    required this.time,
    required this.liked,
    required this.flair,
  });
}

class StudentProfile {
  final String id;
  final String fullName;
  final String studentId;
  final String courseYear;
  final String email;
  final String? avatarUrl;

  const StudentProfile({
    required this.id,
    required this.fullName,
    required this.studentId,
    required this.courseYear,
    required this.email,
    this.avatarUrl,
  });

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    return StudentProfile(
      id:         map['id']?.toString() ?? '',
      fullName:   map['full_name'] ?? 'Student',
      studentId:  map['student_id'] ?? '',
      courseYear: map['course_year'] ?? '',
      email:      map['email'] ?? '',
      avatarUrl:  map['avatar_url'],
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

// ── SAMPLE DATA (fallback during development) ────────────────────────────────
final List<ModuleModel> sampleModules = [
  const ModuleModel(id: '1', title: 'Introduction to GAD', category: 'Fundamentals', progress: 100, status: 'published', colorValue: 0xFF40916C, pages: 24, hasBadge: true),
  const ModuleModel(id: '2', title: 'Gender Equality in Education', category: 'Education', progress: 65, status: 'published', colorValue: 0xFF4895EF, pages: 32, hasBadge: false),
  const ModuleModel(id: '3', title: 'Women Empowerment', category: 'Leadership', progress: 30, status: 'published', colorValue: 0xFFF4A261, pages: 28, hasBadge: false),
  const ModuleModel(id: '4', title: 'Reproductive Health Rights', category: 'Health', progress: 0, status: 'published', colorValue: 0xFF7B2D8B, pages: 20, hasBadge: false),
  const ModuleModel(id: '5', title: 'Violence Against Women', category: 'Safety', progress: 0, status: 'published', colorValue: 0xFFE63946, pages: 36, hasBadge: false),
];

final List<SeminarModel> sampleSeminars = [
  const SeminarModel(id: '1', title: 'GAD Summit 2025', date: '2025-03-15', time: '9:00 AM', speaker: 'Dr. Maria Santos', type: 'Live', participants: 142, colorValue: 0xFF2D6A4F),
  const SeminarModel(id: '2', title: 'Gender Mainstreaming Workshop', date: '2025-03-22', time: '1:00 PM', speaker: 'Prof. Juan dela Cruz', type: 'Upcoming', participants: 89, colorValue: 0xFF4895EF),
  const SeminarModel(id: '3', title: 'Women in STEM Forum', date: '2025-04-05', time: '10:00 AM', speaker: 'Eng. Ana Reyes', type: 'Upcoming', participants: 67, colorValue: 0xFF7B2D8B),
];

final List<EventModel> sampleEvents = [
  const EventModel(id: '1', title: "Women's Month Celebration", date: '03-08', category: 'Celebration', colorValue: 0xFFF4A261),
  const EventModel(id: '2', title: 'GAD Art Exhibit', date: '03-18', category: 'Culture', colorValue: 0xFF7B2D8B),
  const EventModel(id: '3', title: 'Gender Sensitivity Training', date: '03-25', category: 'Training', colorValue: 0xFF40916C),
  const EventModel(id: '4', title: 'CvSU GAD Annual Report', date: '04-02', category: 'Academic', colorValue: 0xFF4895EF),
];

final List<BadgeModel> sampleBadges = [
  const BadgeModel(id: '1', name: 'First Steps', description: 'Completed first module', icon: '🌱', earned: true, colorValue: 0xFF40916C),
  const BadgeModel(id: '2', name: 'Gender Champion', description: 'Completed 3 modules', icon: '🏆', earned: false, colorValue: 0xFFF4A261),
  const BadgeModel(id: '3', name: 'Webinar Star', description: 'Attended 2 seminars', icon: '⭐', earned: false, colorValue: 0xFF4895EF),
  const BadgeModel(id: '4', name: 'Forum Leader', description: '10 posts liked', icon: '🎤', earned: false, colorValue: 0xFF7B2D8B),
  const BadgeModel(id: '5', name: 'Scholar', description: '100% on all modules', icon: '📚', earned: false, colorValue: 0xFFE63946),
  const BadgeModel(id: '6', name: 'Advocate', description: 'Completed all modules', icon: '💪', earned: false, colorValue: 0xFFFFBA08),
];

final List<CertificateModel> sampleCertificates = [
  const CertificateModel(id: '1', title: 'GAD Summit 2024', date: '2024-12-12', issuer: 'GADRC CvSU', colorValue: 0xFF2D6A4F),
  const CertificateModel(id: '2', title: 'Introduction to GAD', date: '2025-01-20', issuer: 'GADRC CvSU', colorValue: 0xFF4895EF),
];

List<ForumPost> sampleForumPosts = [
  ForumPost(id: '1', user: 'Ana Reyes', avatar: 'AR', title: 'What does gender equality mean to you as a student?', body: "I've been studying GAD for a while now and I'm curious about everyone's personal take on this...", votes: 47, comments: 12, time: '2h ago', liked: false, flair: 'Discussion'),
  ForumPost(id: '2', user: 'Miguel Santos', avatar: 'MS', title: 'Resources for the Gender Equality module?', body: "Looking for additional reading materials beyond what's in the digital library...", votes: 31, comments: 8, time: '4h ago', liked: true, flair: 'Help'),
  ForumPost(id: '3', user: 'Carla Dela Cruz', avatar: 'CD', title: 'Sharing my experience from the GAD Summit!', body: 'Just attended the online summit yesterday and it was really eye-opening. Here are my key takeaways...', votes: 89, comments: 24, time: '1d ago', liked: false, flair: 'Experience'),
];
