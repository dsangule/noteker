import 'package:noteker/utils/markdown_helpers.dart';

void main() {
  final s1 = 'Line one\nLine two\n\nParagraph two';
  print('preserveLineBreaks:\n${preserveLineBreaks(s1)}');

  final s2 = 'This is inline \$x\$ and block:\n\$\$\nE=mc^2\n\$\$\nEnd';
  print('processMath:\n${processMath(s2)}');

  final s3 = '```\n\$notmath\$\n```';
  print('processMath fenced:\n${processMath(s3)}');
}
