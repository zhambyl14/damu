// lib/models/user_model.dart

enum UserRole { admin, director, curator, student, unknown }

/// Оқушы типі:
/// online  — барлық мүмкіндіктерге доступ (видеосабақ + тақырыптық тест те)
/// offline — видеосабақ пен видеосабақ тақырыптық тестінен басқасының бәрі
enum StudentType { online, offline }

/// ҰБТ пәндік профильдер — seed.js electivePairs.id-ге сәйкес
enum ElectiveProfile {
  mathPhysics,
  mathInformatics,
  bioChemistry,
  bioGeography,
  mathGeography,
  geographyForeign,
  worldhistoryGeography,
  foreignWorldhistory,
  literatureWorldhistory,
  historyGeography,
  historyEnglish,
  kazakhLitLang,
  russianLitLang,
  unknown,
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? avatarUrl;
  final UserRole role;
  final DateTime? createdAt;
  final String? curatorId;
  final String? classId;
  final String? className;
  final int? grade;

  final ElectiveProfile electiveProfile;
  final StudentType studentType;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.createdAt,
    this.curatorId,
    this.classId,
    this.className,
    this.grade,
    this.electiveProfile = ElectiveProfile.unknown,
    this.studentType = StudentType.online,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // Supabase 'elective_pair' бағаны; ескі камелкейс кілттерге де төзімді
    final electiveRaw = (map['elective_pair'] as String?) ??
        (map['electivePair'] as String?) ??
        (map['electiveProfile'] as String?);

    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? 'Пайдаланушы',
      email: map['email'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      role: _parseRole(map['role'] as String?),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      curatorId: map['curator_id'] as String?,
      classId: map['class_id'] as String?,
      className: map['class_name'] as String?,
      grade: (map['grade'] as num?)?.toInt(),
      electiveProfile: _parseElective(electiveRaw),
      studentType: _parseStudentType(map['student_type'] as String?),
    );
  }

  static StudentType _parseStudentType(String? raw) {
    switch (raw) {
      case 'offline': return StudentType.offline;
      default:        return StudentType.online;
    }
  }

  static UserRole _parseRole(String? raw) {
    switch (raw) {
      case 'admin':    return UserRole.admin;
      case 'director': return UserRole.director;
      case 'curator':  return UserRole.curator;
      case 'student':  return UserRole.student;
      default:         return UserRole.unknown;
    }
  }

  static ElectiveProfile _parseElective(String? raw) {
    switch (raw) {
      case 'math_physics':            return ElectiveProfile.mathPhysics;
      case 'math_informatics':        return ElectiveProfile.mathInformatics;
      case 'bio_chemistry':           return ElectiveProfile.bioChemistry;
      case 'bio_geography':           return ElectiveProfile.bioGeography;
      case 'math_geography':          return ElectiveProfile.mathGeography;
      case 'geography_foreign':       return ElectiveProfile.geographyForeign;
      case 'worldhistory_geography':  return ElectiveProfile.worldhistoryGeography;
      case 'foreign_worldhistory':    return ElectiveProfile.foreignWorldhistory;
      case 'literature_worldhistory': return ElectiveProfile.literatureWorldhistory;
      case 'history_geography':       return ElectiveProfile.historyGeography;
      case 'history_english':         return ElectiveProfile.historyEnglish;
      case 'kazakh_lit':              return ElectiveProfile.kazakhLitLang;
      case 'russian_lit':             return ElectiveProfile.russianLitLang;
      default:                        return ElectiveProfile.unknown;
    }
  }

  String get electiveProfileKey => electiveKey(electiveProfile);
  String get electiveProfileLabel => electiveLabel(electiveProfile);

  /// Куратор оқушы жасағанда қолданатын таңдалатын профильдер тізімі.
  static List<ElectiveProfile> get selectableProfiles => ElectiveProfile.values
      .where((p) => p != ElectiveProfile.unknown)
      .toList();

  static ElectiveProfile electiveFromKey(String? raw) => _parseElective(raw);

  static String electiveKey(ElectiveProfile p) {
    switch (p) {
      case ElectiveProfile.mathPhysics:            return 'math_physics';
      case ElectiveProfile.mathInformatics:        return 'math_informatics';
      case ElectiveProfile.bioChemistry:           return 'bio_chemistry';
      case ElectiveProfile.bioGeography:           return 'bio_geography';
      case ElectiveProfile.mathGeography:          return 'math_geography';
      case ElectiveProfile.geographyForeign:       return 'geography_foreign';
      case ElectiveProfile.worldhistoryGeography:  return 'worldhistory_geography';
      case ElectiveProfile.foreignWorldhistory:    return 'foreign_worldhistory';
      case ElectiveProfile.literatureWorldhistory: return 'literature_worldhistory';
      case ElectiveProfile.historyGeography:       return 'history_geography';
      case ElectiveProfile.historyEnglish:         return 'history_english';
      case ElectiveProfile.kazakhLitLang:          return 'kazakh_lit';
      case ElectiveProfile.russianLitLang:         return 'russian_lit';
      default:                                     return 'unknown';
    }
  }

  static String electiveLabel(ElectiveProfile p) {
    switch (p) {
      case ElectiveProfile.mathPhysics:            return 'Математика + Физика';
      case ElectiveProfile.mathInformatics:        return 'Математика + Информатика';
      case ElectiveProfile.bioChemistry:           return 'Биология + Химия';
      case ElectiveProfile.bioGeography:           return 'Биология + География';
      case ElectiveProfile.mathGeography:          return 'Математика + География';
      case ElectiveProfile.geographyForeign:       return 'География + Шет тілі';
      case ElectiveProfile.worldhistoryGeography:  return 'Дүниежүзі тарихы + География';
      case ElectiveProfile.foreignWorldhistory:    return 'Шет тілі + Дүниежүзі тарихы';
      case ElectiveProfile.literatureWorldhistory: return 'Қазақ әдебиеті + Дүниежүзі тарихы';
      case ElectiveProfile.historyGeography:       return 'Дүниежүзі тарихы + География';
      case ElectiveProfile.historyEnglish:         return 'Дүниежүзі тарихы + Ағылшын';
      case ElectiveProfile.kazakhLitLang:          return 'Қазақ тілі + Қазақ әдебиеті';
      case ElectiveProfile.russianLitLang:         return 'Орыс тілі + Орыс әдебиеті';
      default:                                     return 'Профиль таңдалмаған';
    }
  }

  /// 2 таңдау пәнінің атаулары (UI үшін)
  List<ElectiveSubject> get electiveSubjects {
    switch (electiveProfile) {
      case ElectiveProfile.mathPhysics:
        return [const ElectiveSubject('mathematics', 'Математика'),
                const ElectiveSubject('physics', 'Физика')];
      case ElectiveProfile.mathInformatics:
        return [const ElectiveSubject('mathematics', 'Математика'),
                const ElectiveSubject('informatics', 'Информатика')];
      case ElectiveProfile.bioChemistry:
        return [const ElectiveSubject('biology', 'Биология'),
                const ElectiveSubject('chemistry', 'Химия')];
      case ElectiveProfile.bioGeography:
        return [const ElectiveSubject('biology', 'Биология'),
                const ElectiveSubject('geography', 'География')];
      case ElectiveProfile.mathGeography:
        return [const ElectiveSubject('mathematics', 'Математика'),
                const ElectiveSubject('geography', 'География')];
      case ElectiveProfile.geographyForeign:
        return [const ElectiveSubject('geography', 'География'),
                const ElectiveSubject('foreign', 'Шет тілі')];
      case ElectiveProfile.worldhistoryGeography:
      case ElectiveProfile.historyGeography:
        return [const ElectiveSubject('world_history', 'Дүниежүзі тарихы'),
                const ElectiveSubject('geography', 'География')];
      case ElectiveProfile.foreignWorldhistory:
        return [const ElectiveSubject('foreign', 'Шет тілі'),
                const ElectiveSubject('world_history', 'Дүниежүзі тарихы')];
      case ElectiveProfile.literatureWorldhistory:
        return [const ElectiveSubject('kazakh_literature', 'Қазақ әдебиеті'),
                const ElectiveSubject('world_history', 'Дүниежүзі тарихы')];
      case ElectiveProfile.historyEnglish:
        return [const ElectiveSubject('world_history', 'Дүниежүзі тарихы'),
                const ElectiveSubject('english', 'Ағылшын тілі')];
      case ElectiveProfile.kazakhLitLang:
        return [const ElectiveSubject('kazakh_language', 'Қазақ тілі'),
                const ElectiveSubject('kazakh_literature', 'Қазақ әдебиеті')];
      case ElectiveProfile.russianLitLang:
        return [const ElectiveSubject('russian_language', 'Орыс тілі'),
                const ElectiveSubject('russian_literature', 'Орыс әдебиеті')];
      default:
        return [];
    }
  }

  List<String> get electiveSubjectIds =>
      electiveSubjects.map((e) => e.id).toList();

  bool get isAdmin    => role == UserRole.admin;
  bool get isDirector => role == UserRole.director;
  bool get isCurator  => role == UserRole.curator;
  bool get isStudent  => role == UserRole.student;
  bool get isStaff    => isAdmin || isDirector || isCurator;
  bool get hasCoursesAccess => isStaff || isStudent;

  bool get isOnlineStudent => studentType == StudentType.online;
  bool get isOfflineStudent => studentType == StudentType.offline;

  /// offline оқушыларға видеосабақ пен видеосабақ тақырыптық тесті жабық
  bool get canAccessVideoLessons => isStaff || isOnlineStudent;
  bool get canAccessTopicTests => isStaff || isOnlineStudent;

  String get studentTypeLabel =>
      studentType == StudentType.offline ? 'Оффлайн' : 'Онлайн';

  String get roleLabel {
    switch (role) {
      case UserRole.admin:    return 'Әкімші';
      case UserRole.director: return 'Директор';
      case UserRole.curator:  return 'Куратор';
      case UserRole.student:  return 'Оқушы';
      default:                return 'Пайдаланушы';
    }
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
    'id': uid,
    'name': name,
    'email': email,
    'avatar_url': avatarUrl,
    'role': role.name,
    'created_at': createdAt?.toIso8601String(),
    'curator_id': curatorId,
    'class_id': classId,
    'class_name': className,
    'grade': grade,
    'elective_pair': electiveProfileKey,
    'student_type': studentType.name,
  };

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    UserRole? role,
    int? grade,
    String? curatorId,
    String? classId,
    String? className,
    ElectiveProfile? electiveProfile,
    StudentType? studentType,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        createdAt: createdAt,
        curatorId: curatorId ?? this.curatorId,
        classId: classId ?? this.classId,
        className: className ?? this.className,
        grade: grade ?? this.grade,
        electiveProfile: electiveProfile ?? this.electiveProfile,
        studentType: studentType ?? this.studentType,
      );
}

class ElectiveSubject {
  final String id;
  final String label;
  const ElectiveSubject(this.id, this.label);
}