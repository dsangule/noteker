import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:noteker/utils/markdown_helpers.dart';
import 'package:noteker/widgets/math_element_builder.dart';
import 'package:noteker/widgets/code_block_builder.dart';
import 'package:noteker/widgets/task_list_builder.dart';

class NoteMarkdownView extends StatelessWidget {
  final String content;
  final bool mathEnabled;
  const NoteMarkdownView({required this.content, required this.mathEnabled, super.key});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: mathEnabled ? processMarkdownForPreview(content) : preserveLineBreaks(content),
      inlineSyntaxes: mathEnabled ? [MathInlineSyntax()] : null,
      blockSyntaxes: mathEnabled ? [MathBlockSyntax()] : null,
      builders: {
        if (mathEnabled) ...{
          'mathblock': MathElementBuilder(isInline: false),
          'mathinline': MathElementBuilder(isInline: true),
        },
        'li': LiTaskListBuilder(),
        'code': CodeBlockBuilder(),
        'pre': CodeBlockBuilder(),
      },
    );
  }
}


