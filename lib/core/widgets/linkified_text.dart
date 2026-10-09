import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import 'common_widgets.dart';

/// Plain text whose web links can be tapped.
///
/// Drivers paste links into notes — a workshop's page, a parts listing, a
/// shared map pin — and a link that only reads as text has to be copied out by
/// hand. Everything that is not a link renders exactly as [Text] would.
///
/// **Only links that say they are links.** A match needs `http://`,
/// `https://` or `www.`; a bare `example.com` is left alone, because in free
/// text the same shape is just as often a file name or a bay number, and a
/// false link is worse than a missing one.
///
/// Tapping elsewhere in the text falls through to whatever wraps it, so a note
/// row still opens for editing; only the link itself is taken.
class LinkifiedText extends ConsumerStatefulWidget {
  const LinkifiedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  /// `http(s)://` or `www.`, up to the next whitespace.
  static final RegExp _link = RegExp(
    r'(?:https?://|www\.)\S+',
    caseSensitive: false,
  );

  /// Punctuation that ends a sentence rather than a link: "see
  /// https://x.com/a." links to `/a`, not `/a.`. Arabic marks included,
  /// since the notes are mostly written in Arabic.
  static const String _trailing = '.,;:!?)]}\'"،؛؟';

  @override
  ConsumerState<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends ConsumerState<LinkifiedText> {
  /// Owned here because a [TapGestureRecognizer] must be disposed, and a
  /// `TextSpan` has no lifecycle of its own to do it.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(Uri uri) async {
    final ok = await ref.read(launcherServiceProvider).openUrl(uri);
    if (!ok && mounted) showAppSnack(context, context.l10n.couldNotLaunch);
  }

  List<InlineSpan> _spans(String text, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in LinkifiedText._link.allMatches(text)) {
      var end = match.end;
      while (end > match.start &&
          LinkifiedText._trailing.contains(text[end - 1])) {
        end--;
      }
      final raw = text.substring(match.start, end);
      final uri = Uri.tryParse(
        raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw,
      );
      // Too short to be anything once the punctuation is off, or not a URL
      // after all: leave it as text.
      if (uri == null || uri.host.isEmpty) continue;

      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: raw, style: linkStyle, recognizer: recognizer));
      cursor = end;
    }

    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final linkStyle = TextStyle(
      color: AppColors.cyan,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.cyan,
    );

    return Text.rich(
      TextSpan(style: style, children: _spans(widget.text, linkStyle)),
    );
  }
}
