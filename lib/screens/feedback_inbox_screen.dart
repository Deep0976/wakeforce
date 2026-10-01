import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/feedback_prompt.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';

/// Everything students have written, newest first, for the accounts allowed
/// to read it.
///
/// Reachable only from Settings and only when signed in as
/// [FeedbackPrompt.ownerEmails]. Hiding the row is convenience; the Firestore
/// rule is what actually stops anyone else, so a student who found this
/// screen would still get an empty list and a refusal.
class FeedbackInboxScreen extends StatelessWidget {
  const FeedbackInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Feedback'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FeedbackPrompt.inbox(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _Message(
              title: 'Could not load feedback',
              body: 'Signed in as the wrong account, or offline. Only '
                  '${FeedbackPrompt.ownerEmails.join(' and ')} can read this.',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const _Message(
              title: 'Nothing yet',
              body: 'Answers land here as students send them. The first ask '
                  'comes once a student has solved their first alarm.',
            );
          }

          final stars = docs
              .map((d) => (d.data()['stars'] as num?)?.toDouble() ?? 0)
              .toList();
          final average =
              stars.fold<double>(0, (a, b) => a + b) / stars.length;

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screen),
            itemCount: docs.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.gapTight),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.gapTight),
                  child: Text(
                    '${docs.length} ${docs.length == 1 ? 'answer' : 'answers'} '
                    '· ${average.toStringAsFixed(1)} average',
                    style: TextStyle(
                      fontFamily: kMono,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: c.textMuted,
                    ),
                  ),
                );
              }
              return _AnswerCard(data: docs[i - 1].data());
            },
          );
        },
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AnswerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final stars = (data['stars'] as num?)?.toInt() ?? 0;
    final comment = (data['comment'] as String? ?? '').trim();
    final reasons = (data['reasons'] as List?)?.cast<String>() ?? const [];
    final who = (data['name'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    final topic = data['topic'] as String? ?? '';
    final round = (data['round'] as num?)?.toInt();
    final when = (data['submittedAt'] as Timestamp?)?.toDate();

    return WakeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: i <= stars ? c.accent : c.textFaint,
                ),
              const Spacer(),
              Text(
                _ago(when),
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 11,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            who == null || who.isEmpty ? (email ?? 'Unknown student') : who,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          if (email != null && email.isNotEmpty && who != null && who.isNotEmpty)
            Text(
              email,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11,
                color: c.textMuted,
              ),
            ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in reasons)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.accentInk,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _trail(topic, round, data['solvedAlarms'], data['context']),
            style: TextStyle(
              fontFamily: kMono,
              fontSize: 10,
              color: c.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  /// The one line that says which ask this was and what they were doing --
  /// a two-star answer means something different on day one than on day fifty.
  static String _trail(
    String topic,
    int? round,
    Object? solved,
    Object? context,
  ) {
    final parts = <String>[
      if (topic.isNotEmpty) topic,
      if (round != null) 'round $round',
      if (solved is num) '${solved.toInt()} solved',
    ];
    if (context is Map) {
      final mission = context['mission'];
      final difficulty = context['difficulty'];
      final time = context['time'];
      if (time != null) parts.add('$time');
      if (mission != null) {
        parts.add(difficulty == null ? '$mission' : '$mission/$difficulty');
      }
    }
    return parts.join(' · ');
  }

  static String _ago(DateTime? when) {
    if (when == null) return 'just now';
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    final w = when.toLocal();
    final dd = w.day.toString().padLeft(2, '0');
    final mm = w.month.toString().padLeft(2, '0');
    return '$dd-$mm-${w.year}';
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String body;

  const _Message({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: 1.5,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
