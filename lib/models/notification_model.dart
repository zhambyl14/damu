// lib/models/notification_model.dart
import 'package:flutter/material.dart';

/// Хабарландыру: notifications/{id}
/// type: 'score' | 'content' | 'system'
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'system',
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['createdAt'] ?? map['created_at'];
    DateTime created;
    if (rawDate is String) {
      created = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      created = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is DateTime) {
      created = rawDate;
    } else {
      created = DateTime.now();
    }

    return AppNotification(
      id: id,
      userId: (map['userId'] ?? map['user_id'] ?? '') as String,
      title: (map['title'] ?? 'Хабарландыру') as String,
      body: (map['body'] ?? '') as String,
      type: (map['type'] ?? 'system') as String,
      read: (map['read'] ?? false) as bool,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': read,
        'created_at': createdAt.toIso8601String(),
      };

  IconData get icon {
    switch (type) {
      case 'score':
        return Icons.assignment_turned_in_rounded;
      case 'content':
        return Icons.menu_book_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'score':
        return const Color(0xFF27AE60);
      case 'content':
        return const Color(0xFF2980B9);
      default:
        return const Color(0xFFC5A059);
    }
  }
}
