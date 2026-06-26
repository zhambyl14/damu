// lib/services/user_admin_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Управление аккаунтами (curator/admin) через Supabase.
///
/// Примечание: создание новых Auth-пользователей выполняется через
/// Edge Function `admin_create_user` (runs with service_role). Клиент
/// вызывает функцию; сама функция создаёт пользователя и profile в users.
class UserAdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Создаёт пользователя (Auth + profile) через Edge Function.
  Future<String> createStudent({
    required String name,
    required String email,
    required String password,
    required String curatorId,
    required String electivePairKey,
    String studentType = 'online',
    String? className,
    String? classId,
    int? grade,
  }) async {
    final payload = {
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      'role': 'student',
      'curatorId': curatorId,
      'className': className,
      'classId': classId,
      'grade': grade,
      'electivePairKey': electivePairKey,
      'studentType': studentType,
    };

    final res = await _supabase.functions.invoke('super-action', body: payload);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) throw Exception(data['error'].toString());
      return data['id'] as String;
    }
    throw Exception('Unexpected response from admin_create_user');
  }

  Future<void> updateStudent({
    required String uid,
    String? name,
    String? className,
    String? classId,
    int? grade,
    String? electivePairKey,
    String? studentType,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name.trim();
    if (className != null) data['className'] = className;
    if (classId != null) data['classId'] = classId;
    if (grade != null) data['grade'] = grade;
    if (electivePairKey != null) data['electivePair'] = electivePairKey;
    if (studentType != null) data['studentType'] = studentType;
    if (data.isEmpty) return;

    await _supabase.from('users').update(data).eq('id', uid);
  }

  Future<void> removeStudentProfile(String uid) async {
    await _supabase.from('users').delete().eq('id', uid);
  }

  Future<void> updateCurator({
    required String uid,
    String? name,
    String? className,
    int? grade,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name.trim();
    if (className != null) data['className'] = className;
    if (grade != null) data['grade'] = grade;
    if (data.isEmpty) return;

    await _supabase.from('users').update(data).eq('id', uid);
  }

  /// Жалпы staff (curator/director) аккаунтын жасау (Auth + profile).
  Future<String> createStaff({
    required String name,
    required String email,
    required String password,
    required String role, // 'curator' | 'director'
    String? className,
    String? classId,
    int? grade,
  }) async {
    final payload = {
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      'role': role,
      'className': className,
      'classId': classId,
      'grade': grade,
    };
    final res = await _supabase.functions.invoke('super-action', body: payload);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) throw Exception(data['error'].toString());
      return data['id'] as String;
    }
    throw Exception('Unexpected response from admin_create_user');
  }

  Future<String> createCurator({
    required String name,
    required String email,
    required String password,
    String? className,
    String? classId,
    int? grade,
  }) =>
      createStaff(
        name: name,
        email: email,
        password: password,
        role: 'curator',
        className: className,
        classId: classId,
        grade: grade,
      );

  /// Кураторды өшіру алдында оның оқушыларын басқа кураторға көшіру.
  Future<void> reassignStudents(
      String fromCuratorId, String toCuratorId) async {
    await _supabase
        .from('users')
        .update({'curator_id': toCuratorId}).eq('curator_id', fromCuratorId);
  }

  /// Staff (curator/director) профилін өшіру. RLS: admin/director рұқсат береді.
  /// Ескерту: auth.users жазбасы қалады (қолданбадан жоғалады) — толық auth-өшіру
  /// үшін edge function қажет.
  Future<void> deleteStaffProfile(String uid) async {
    await _supabase.from('users').delete().eq('id', uid);
  }

  String friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Бұл email тіркелген. Басқасын қолданыңыз.';
      case 'invalid-email':
        return 'Email мекенжайы жарамсыз.';
      case 'weak-password':
        return 'Құпия сөз тым әлсіз (кемінде 6 таңба).';
      default:
        return 'Оқушыны жасау сәтсіз болды. Қайталап көріңіз.';
    }
  }
}
