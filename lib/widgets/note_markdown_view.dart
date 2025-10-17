import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../utils/markdown_helpers.dart';
import 'code_block_builder.dart';
import 'math_element_builder.dart';
import 'task_list_builder.dart';

class NoteMarkdownView extends StatefulWidget {
  const NoteMarkdownView({required this.content, required this.mathEnabled, super.key});

  final String content;
  final bool mathEnabled;

  @override
  State<NoteMarkdownView> createState() => _NoteMarkdownViewState();
}

class _NoteMarkdownViewState extends State<NoteMarkdownView> {
  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return const SizedBox.shrink();
    }

    return MarkdownBody(
      data: preserveLineBreaks(widget.content),
      inlineSyntaxes: widget.mathEnabled ? [MathInlineSyntax()] : null,
      blockSyntaxes: widget.mathEnabled ? [const MathBlockSyntax()] : null,
      builders: {
        if (widget.mathEnabled) ...{
          'tex-block': MathElementBuilder(),
          'tex-inline': MathElementBuilder(isInline: true),
        },
        'li': LiTaskListBuilder(),
        'code': CodeBlockBuilder(),
        'pre': CodeBlockBuilder(),
      },
    );
  }
}


