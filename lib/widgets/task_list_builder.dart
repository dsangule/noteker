import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class LiTaskListBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Only convert if the list item starts with [ ] or [x]
    final raw = element.textContent;
    final match = RegExp(r'^\s*\[( |x|X)\]\s*(.*)$').firstMatch(raw);
    if (match == null) {
      return Text(raw, style: preferredStyle);
    }
    final isChecked = match.group(1)!.toLowerCase() == 'x';
    final text = match.group(2) ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: isChecked, onChanged: null),
        Expanded(child: Text(text, style: preferredStyle)),
      ],
    );
  }
}


