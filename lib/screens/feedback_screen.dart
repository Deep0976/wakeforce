import 'package:flutter/material.dart';

import '../services/feedback_prompt.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_ui.dart';

/// The form behind the prompt, for students who have more to say than a star
/// rating. Everything below the rating is optional -- a student who taps
/// Send with nothing but stars has still told us something.
class FeedbackScreen extends StatefulWidget {
  final FeedbackTopic topic;
  final int initialStars;
  final int solvedAlarms;

  /// What the student had just done when asked -- the alarm they set, say.
  /// Sent only if they leave the switch on. Null when there is nothing to
  /// attach, and then the switch is not shown at all.
  final Map<String, dynamic>? answerContext;

  /// Opens straight on the confirmation. The prompt card can file a rating
  /// on its own now, and a student who did that still deserves to be told it
  /// went somewhere.
  final bool startSent;

  const FeedbackScreen({
    super.key,
    required this.topic,
    required this.initialStars,
    required this.solvedAlarms,
    this.answerContext,
  }) : startSent = false;

  const FeedbackScreen.sent({super.key})
      : topic = FeedbackTopic.usage,
        initialStars = 0,
        solvedAlarms = 0,
        answerContext = null,
        startSent = true;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late int _stars = widget.initialStars;
  final _reasons = <String>{};
  final _comment = TextEditingController();
  bool _sendContext = true;
  bool _sending = false;
  late bool _sent = widget.startSent;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    await FeedbackPrompt.submit(
      stars: _stars,
      reasons: _reasons.toList(),
      comment: _comment.text,
      solvedAlarms: widget.solvedAlarms,
      context: _sendContext ? widget.answerContext : null,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
  }

  Future<void> _skip() async {
    await FeedbackPrompt.defer(widget.solvedAlarms);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(child: _sent ? _sentBody(c) : _formBody(c)),
    );
  }

  // ---------------------------------------------------------------- form

  Widget _formBody(WakeColors c) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            children: [
              Row(
                children: [
                  InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    radius: 22,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Feedback',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _ratingCard(c),
              const SizedBox(height: 13),
              _sectionLabel(c, widget.topic.question),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in widget.topic.reasons)
                    _reasonChip(c, reason),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _sectionLabel(c, 'ANYTHING ELSE?'),
                  const Spacer(),
                  Text(
                    'optional',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 10.5,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _commentBox(c),
              if (widget.answerContext != null) ...[
                const SizedBox(height: 13),
                _contextSwitch(c),
              ],
            ],
          ),
        ),
        _bottomBar(c),
      ],
    );
  }

  Widget _ratingCard(WakeColors c) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: 0.14),
            c.accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.topic.label,
              style: TextStyle(
                fontFamily: kMono,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: c.accentInk,
              ),
            ),
          ),
          const SizedBox(height: 13),
          FeedbackStars(
            value: _stars,
            onChanged: (v) => setState(() => _stars = v),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(WakeColors c, String text) => Text(
        text,
        style: TextStyle(
          fontFamily: kMono,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: c.textMuted,
        ),
      );

  Widget _reasonChip(WakeColors c, String reason) {
    final on = _reasons.contains(reason);
    return Material(
      color: on ? c.accent.withValues(alpha: 0.12) : c.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(
          () => on ? _reasons.remove(reason) : _reasons.add(reason),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: on
                ? Border.all(color: c.accent.withValues(alpha: 0.45))
                : (c.cardBorder == null
                    ? null
                    : Border.all(color: c.cardBorder!)),
          ),
          child: Text(
            reason,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 12,
              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              color: on ? c.accentInk : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _commentBox(WakeColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: c.cardBorder == null ? null : Border.all(color: c.cardBorder!),
        boxShadow: c.cardShadow,
      ),
      child: TextField(
        controller: _comment,
        enabled: !_sending,
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 12.5,
          height: 1.45,
          color: c.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          border: InputBorder.none,
          hintText: 'What would you change?',
          hintStyle: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            color: c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _contextSwitch(WakeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: c.cardBorder == null ? null : Border.all(color: c.cardBorder!),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        children: [
          Switch(
            value: _sendContext,
            onChanged: (v) => setState(() => _sendContext = v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Send the settings I picked',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(WakeColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FeedbackFilledButton(
              label: _sending ? 'Sending...' : 'Send feedback',
              onPressed: _stars == 0 || _sending ? null : _send,
              radius: 16,
              fontSize: 15,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 9),
          TextButton(
            onPressed: _sending ? null : _skip,
            child: Text(
              'Skip for now',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- sent

  Widget _sentBody(WakeColors c) {
    return Container(
      // The design lights the top of this screen green rather than leaving
      // it flat -- the tick is the whole point of the screen.
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.76),
          radius: 1.05,
          colors: [c.done.withValues(alpha: 0.12), c.bg],
          stops: const [0, 0.66],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: c.done.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 46, color: c.done),
          ),
          const SizedBox(height: 20),
          Text(
            'Thanks — noted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Their own words back at them. A student who took the trouble to
          // type something should see that it is the thing that was sent,
          // not a stock line that would look identical if it had been lost.
          if (_comment.text.trim().isNotEmpty) ...[
            Text(
              '“${_comment.text.trim()}”',
              textAlign: TextAlign.center,
              // The box takes 500 characters and the buttons below must stay
              // on screen, so a long note is trimmed here rather than pushing
              // them off. All of it was still sent.
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                height: 1.65,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'We read every note that comes in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 13,
              height: 1.65,
              color: _comment.text.trim().isEmpty
                  ? c.textSecondary
                  : c.textMuted,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FeedbackFilledButton(
              label: 'Back to alarms',
              onPressed: () => Navigator.of(context).pop(),
              radius: 999,
              fontSize: 15,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              await FeedbackPrompt.disable();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text(
              'Turn off feedback requests',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
