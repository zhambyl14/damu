// lib/screens/curator/manage_content_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../data/subjects_catalog.dart';
import '../../providers/auth_provider.dart';
import 'subject_content_screen.dart';

/// Куратор пәнді таңдап, тақырып/сұрақ/флешкарта қосады.
class ManageContentScreen extends StatelessWidget {
  const ManageContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final curator = context.watch<AuthProvider>().userModel;
    if (curator == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Оқу контенті'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF002147), Color(0xFF003167)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.library_books_rounded,
                    color: AppColors.gold, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Пәнді таңдап, тақырыптар мен тест сұрақтарын, флешкарталарды қосыңыз. Оқушылар оларды қосымшадан көреді.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.white, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _section(context, 'Міндетті пәндер', AppColors.navyBlue),
          const SizedBox(height: 12),
          ...SubjectCatalog.mandatory
              .map((s) => _subjectTile(context, s, curator.uid)),
          const SizedBox(height: 20),
          _section(context, 'Таңдау пәндері', AppColors.gold),
          const SizedBox(height: 12),
          ...SubjectCatalog.electives
              .map((s) => _subjectTile(context, s, curator.uid)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String text, Color color) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      );

  Widget _subjectTile(
      BuildContext context, CatalogSubject s, String curatorUid) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubjectContentScreen(subject: s, curatorUid: curatorUid),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(s.icon, color: s.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(s.title,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
