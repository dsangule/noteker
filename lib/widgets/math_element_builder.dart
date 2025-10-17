import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'katex_view_mobile.dart' if (dart.library.html) 'katex_view_web.dart';

// Custom markdown syntaxes to ensure <mathblock> and <mathinline> HTML-like
// tags are parsed into elements that Flutter Markdown's `builders` can
// handle. The app's `processMath` emits these tags, so we must ensure the
// markdown parser recognizes them.

/// Parse TeX block math delimited by lines starting with $$ and ending with $$.
class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\$\$');

  @override
  bool canParse(md.BlockParser parser) => pattern.hasMatch(parser.current.content);

  @override
  md.Node parse(md.BlockParser parser) {
    final buffer = StringBuffer();
    // Consume opening line
    var line = parser.current.content;
    // Remove the leading $$ (and anything before it)
    final start = line.indexOf(r'$$');
    line = line.substring(start + 2);
    // If closing $$ is on same line
    final sameLineClose = line.indexOf(r'$$');
    if (sameLineClose >= 0) {
      buffer.writeln(line.substring(0, sameLineClose));
      parser.advance();
      return md.Element.text('tex-block', buffer.toString().trim());
    }
    // Accumulate lines until closing $$
    buffer.writeln(line);
    parser.advance();
    while (!parser.isDone) {
      final cur = parser.current.content;
      final closeIdx = cur.indexOf(r'$$');
      if (closeIdx >= 0) {
        buffer.writeln(cur.substring(0, closeIdx));
        parser.advance();
        break;
      }
      buffer.writeln(cur);
      parser.advance();
    }
    // Trim leading/trailing blank lines
    String trimBlankLines(String s) {
      final lines = s.split('\n');
      var start = 0;
      var end = lines.length - 1;
      while (start <= end && lines[start].trim().isEmpty) {
        start++;
      }
      while (end >= start && lines[end].trim().isEmpty) {
        end--;
      }
      if (start > end) {
        return '';
      }
      return lines.sublist(start, end + 1).map((l) => l.replaceAll('\r', '')).join('\n');
    }
    return md.Element.text('tex-block', trimBlankLines(buffer.toString()));
  }
}

/// Parse inline TeX delimited by single $...$ (best-effort, skips $$ and empty).
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(r'\$(.+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final full = match[0] ?? '';
    var inner = match[1] ?? '';
    // Skip if this looks like a block $$...$$ captured by mistake
    if (full.startsWith(r'$$') || full.endsWith(r'$$')) {
      return false;
    }
    inner = inner.trim();
    if (inner.isEmpty) {
      return false;
    }
    parser.addNode(md.Element.text('tex-inline', inner));
    return true;
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  MathElementBuilder({this.isInline = false});
  final bool isInline;

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var content = element.textContent;
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }
    // Normalize: trim leading/trailing blank lines and remove trailing spaces
    final lines = content.split('\n');
    var start = 0;
    var end = lines.length - 1;
    while (start <= end && lines[start].trim().isEmpty) {
      start++;
    }
    while (end >= start && lines[end].trim().isEmpty) {
      end--;
    }
    if (start > end) {
      return const SizedBox.shrink();
    }
    content = lines.sublist(start, end + 1).map((l) => l.trimRight()).join('\n');
    final baseSize = preferredStyle?.fontSize ?? 16.0;
    final effectiveStyle = (preferredStyle ?? const TextStyle(fontSize: 16)).copyWith(
      fontSize: isInline ? baseSize * 0.92 : baseSize,
    );
    return Padding(
      padding: isInline ? const EdgeInsets.symmetric(horizontal: 2.0) : const EdgeInsets.symmetric(vertical: 8.0),
      child: KaTeXView(
        tex: content,
        display: !isInline,
        fontSize: effectiveStyle.fontSize ?? 16,
        color: effectiveStyle.color,
      ),
    );
  }
}
