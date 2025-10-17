import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class KaTeXView extends StatelessWidget {
  const KaTeXView({
    required this.tex,
    required this.display,
    this.fontSize = 16,
    this.color,
    super.key,
  });

  final String tex;
  final bool display;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, color: color);
    return Math.tex(
      tex,
      textStyle: style,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      onErrorFallback: (e) => Text('Math error: $e', style: style),
    );
  }
}
