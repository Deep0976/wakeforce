import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/feedback_screen.dart';
import '../services/feedback_prompt.dart';
import '../services/stats_provider.dart';
import '../theme/app_theme.dart';

/// Orange is a fill, never flat: the design's primary button is a 140deg
/// gradient with dark ink on top, in both themes.
const _accentFill = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF7A1A), Color(0xFFE35F00)],
);

class FeedbackFilledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double radius;
  final double fontSize;
  final EdgeInsets padding;

  const FeedbackFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.radius = 13,
    this.fontSize = 13,
    this.padding = const EdgeInsets.all(13),
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: _accentFill,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Padding(
              padding: padding,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: context.wake.onAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Five stars on 44px targets, per the design's minimum hit target.
class FeedbackStars extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const FeedbackStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          InkResponse(
            onTap: () => onChanged(i),
            radius: 24,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i <= value ? c.accent : c.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}

/// What the student did with the prompt card.
enum FeedbackCardAction { submit, comment }

/// The prompt itself: a notification-shaped card floated over whatever the
/// student is looking at, answered without leaving it.
///
/// Stars are picked and sent from here -- Submit files the rating and the
/// card is done. The form is for the minority with more to say, which is what
/// "Add a comment" is for. Rating should cost one tap, not a screen.
class _FeedbackPromptCard extends StatefulWidget {
  final String title;
  final String body;

  const _FeedbackPromptCard({required this.title, required this.body});

  @override
  State<_FeedbackPromptCard> createState() => _FeedbackPromptCardState();
}

class _FeedbackPromptCardState extends State<_FeedbackPromptCard> {
  int _stars = 0;

  void _close(FeedbackCardAction action) =>
      Navigator.of(context).pop((action: action, stars: _stars));

  @override
  Widget build(BuildContext context) {
    final c = context.wake;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 21),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          border: c.cardBorder == null ? null : Border.all(color: c.cardBorder!),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1614).withValues(alpha: 0.26),
              blurRadius: 44,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: _accentFill,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.alarm_rounded,
                    size: 16,
                    color: c.onAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WakeForce',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'now',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.body,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: FeedbackStars(
                value: _stars,
                onChanged: (stars) => setState(() => _stars = stars),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FeedbackFilledButton(
                    label: 'Submit',
                    onPressed: _stars == 0
                        ? null
                        : () => _close(FeedbackCardAction.submit),
                  ),
                ),
                const SizedBox(width: 9),
                Material(
                  color: c.textPrimary.withValues(alpha: 0.043),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(13),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: InkWell(
                onTap: () => _close(FeedbackCardAction.comment),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Add a comment',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.accentInk,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floats the prompt and acts on what the student did with it.
///
/// Submit files the rating there and then and shows the confirmation, so the
/// common case costs two taps and never opens a form. Add a comment opens the
/// form with the rating already carried over.
///
/// [title] and [body] are the notification's own words -- what just happened
/// and what is being asked about it.
Future<void> showFeedbackPrompt(
  BuildContext context, {
  required String title,
  required String body,
  required int solvedAlarms,
  Map<String, dynamic>? answerContext,
}) async {
  final topic = await FeedbackPrompt.topic();
  if (!context.mounted) return;

  final answer =
      await showDialog<({FeedbackCardAction action, int stars})>(
    context: context,
    barrierColor: const Color(0xFF1A1614).withValues(alpha: 0.45),
    builder: (_) => _FeedbackPromptCard(title: title, body: body),
  );

  // Dismissed, or "Not now": it waits its turn rather than reappearing.
  if (answer == null) {
    await FeedbackPrompt.defer(solvedAlarms);
    return;
  }

  if (answer.action == FeedbackCardAction.submit) {
    await FeedbackPrompt.submit(
      stars: answer.stars,
      reasons: const [],
      comment: '',
      solvedAlarms: solvedAlarms,
      context: answerContext,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FeedbackScreen.sent()),
    );
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FeedbackScreen(
        topic: topic,
        initialStars: answer.stars,
        solvedAlarms: solvedAlarms,
        answerContext: answerContext,
      ),
    ),
  );
}

/// Lifetime missions solved -- the unit the loop is counted in.
int solvedAlarmsOf(BuildContext context) {
  final s = context.read<StatsProvider>().stats;
  return s.mathSolved +
      s.chemistrySolved +
      s.physicsSolved +
      s.shakeSolved +
      s.photoSolved;
}

/// Asks when a solved alarm brings the student up to the count they are next
/// due at. The first of those is their first solved alarm: by then they have
/// set it up, slept on it and been woken by it, which is the whole thing they
/// are being asked to rate.
///
/// [answerContext] is the mission just solved, when the caller knows it. It
/// rides along with the answer so a low rating arrives with the question that
/// earned it; the student can switch it off before sending.
Future<void> maybeAskAfterMission(
  BuildContext context, {
  Map<String, dynamic>? answerContext,
}) async {
  final solved = solvedAlarmsOf(context);

  // Anything an earlier attempt could not send goes out too, so an answer
  // given offline or signed out is not stranded on the phone forever.
  await FeedbackPrompt.flushPending();

  if (!await FeedbackPrompt.dueAfterMission(solved)) return;
  final first = await FeedbackPrompt.round == 0;
  if (!context.mounted) return;
  await showFeedbackPrompt(
    context,
    title: first
        ? 'You solved your first alarm'
        : 'That is $solved alarms you have solved',
    body: first
        ? 'Setting it up, waking to it, solving the question — how did that '
            'go?'
        : 'How is WakeForce working out so far?',
    solvedAlarms: solved,
    answerContext: answerContext,
  );
}
