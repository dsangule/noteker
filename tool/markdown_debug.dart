import 'package:noteker/utils/logger.dart';
import 'package:noteker/utils/markdown_helpers.dart';

void main() {
  const s1 = 'Line one\nLine two\n\nParagraph two';
  Logger.info('preserveLineBreaks:\n${preserveLineBreaks(s1)}');

  const s2 = 'This is inline \$x\$ and block:\n\$\$\nE=mc^2\n\$\$\nEnd';
  Logger.info('processMath:\n${processMath(s2)}');

  const s3 = '```\n\$notmath\$\n```';
  Logger.info('processMath fenced:\n${processMath(s3)}');
}
