import 'package:flutter/material.dart';

import '../../../theme/mercury_theme.dart';

/// Renders the small markdown subset Mercury supports in the composer hints:
/// `**bold**`, `*italic*`, `` `code` `` and `> quote` lines.
///
/// Deliberately tiny: no links or HTML, so untrusted message content can't
/// smuggle in clickable targets before we have a vetted link-preview policy.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  static final _inline = RegExp(r'(\*\*[^*]+\*\*|\*[^*\s][^*]*\*|`[^`]+`)');

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        const TextStyle(
          color: MercuryColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        );

    final lines = source.split('\n');
    final children = <Widget>[];
    for (final line in lines) {
      if (line.startsWith('> ')) {
        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: MercuryColors.textMuted, width: 3),
              ),
            ),
            child: Text.rich(
              TextSpan(children: _spans(line.substring(2), base)),
              style: base.copyWith(color: MercuryColors.textSecondary),
            ),
          ),
        );
      } else {
        children.add(
          Text.rich(TextSpan(children: _spans(line, base)), style: base),
        );
      }
    }

    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static List<InlineSpan> _spans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: MercuryColors.codeBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: MercuryColors.border),
              ),
              child: Text(
                token.substring(1, token.length - 1),
                style: base.copyWith(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Consolas', 'Menlo', 'Courier New'],
                  fontSize: (base.fontSize ?? 15) - 1.5,
                  color: const Color(0xFFE6C07B),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }
}
