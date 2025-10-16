import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';

// Custom markdown syntaxes to ensure <mathblock> and <mathinline> HTML-like
// tags are parsed into elements that Flutter Markdown's `builders` can
// handle. The app's `processMath` emits these tags, so we must ensure the
// markdown parser recognizes them.

class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();

  @override
  RegExp get pattern => RegExp(r'^<mathblock>');

  @override
  bool canParse(md.BlockParser parser) {
    return parser.current.content.trimLeft().startsWith('<mathblock>');
  }

  @override
  md.Node parse(md.BlockParser parser) {
    // Consume until </mathblock>
    final buffer = StringBuffer();
    // Remove the starting token from the first line
    var line = parser.current.content;
    var startIdx = line.indexOf('<mathblock>');
    // If tag is indented or preceded by spaces, account for trimmed start
    if (startIdx < 0) {
      final trimmed = line.trimLeft();
      startIdx = line.indexOf(trimmed);
      startIdx += trimmed.indexOf('<mathblock>');
    }
    line = line.substring(startIdx + '<mathblock>'.length);
    var endIdx = line.indexOf('</mathblock>');
    if (endIdx >= 0) {
      buffer.writeln(line.substring(0, endIdx));
      parser.advance();
      return md.Element.text('mathblock', buffer.toString().trim());
    }
    buffer.writeln(line);
    parser.advance();
    while (!parser.isDone) {
      final cur = parser.current.content;
      final closeIdx = cur.indexOf('</mathblock>');
      if (closeIdx >= 0) {
        buffer.writeln(cur.substring(0, closeIdx));
        parser.advance();
        break;
      }
      buffer.writeln(cur);
      parser.advance();
    }
    // Trim leading/trailing blank lines inside the math block
    String trimBlankLines(String s) {
      final lines = s.split('\n');
      var start = 0;
      var end = lines.length - 1;
      while (start <= end && lines[start].trim().isEmpty) start++;
      while (end >= start && lines[end].trim().isEmpty) end--;
      if (start > end) return '';
      return lines.sublist(start, end + 1).map((l) => l.replaceAll('\r', '')).join('\n');
    }

    return md.Element.text('mathblock', trimBlankLines(buffer.toString()));
  }
}

class MathInlineSyntax extends md.InlineSyntax {
  // Allow optional surrounding whitespace inside the inline math tags.
  MathInlineSyntax() : super(r'<mathinline>\s*(.+?)\s*<\/mathinline>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    var text = match[1] ?? '';
    // Trim outer whitespace for inline math
    text = text.trim();
    parser.addNode(md.Element.text('mathinline', text));
    return true;
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  final bool isInline;
  MathElementBuilder({this.isInline = false});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var content = element.textContent;
    if (content.isEmpty) return const SizedBox.shrink();
    // Normalize: trim leading/trailing blank lines and remove trailing spaces
    final lines = content.split('\n');
    var start = 0;
    var end = lines.length - 1;
    while (start <= end && lines[start].trim().isEmpty) start++;
    while (end >= start && lines[end].trim().isEmpty) end--;
    if (start > end) return const SizedBox.shrink();
    content = lines.sublist(start, end + 1).map((l) => l.trimRight()).join('\n');
    final baseSize = (preferredStyle?.fontSize ?? 16.0);
    final effectiveStyle = (preferredStyle ?? const TextStyle(fontSize: 16)).copyWith(
      fontSize: isInline ? baseSize * 0.92 : baseSize,
    );
    return Padding(
      padding: isInline ? const EdgeInsets.symmetric(horizontal: 2.0) : const EdgeInsets.symmetric(vertical: 8.0),
      child: Math.tex(
        content,
        textStyle: effectiveStyle,
        mathStyle: isInline ? MathStyle.text : MathStyle.display,
        onErrorFallback: (e) => Text('Math error: $e'),
      ),
    );
  }
}
