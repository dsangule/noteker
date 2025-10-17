import 'package:flutter_test/flutter_test.dart';
import 'package:noteker/utils/markdown_helpers.dart';

void main() {
  test('preserveLineBreaks turns single newlines into hard breaks', () {
    const src = 'Line one\nLine two\n\nParagraph two';
    final out = preserveLineBreaks(src);
    expect(out.contains('  \n'), isTrue);
    expect(out.contains('\n\nParagraph two'), isTrue);
  });

  test('processMath converts inline and block math markers', () {
    const src = 'This is inline \$x\$ and block:\n\$\$\nE=mc^2\n\$\$\nEnd';
    final out = processMath(src);
    expect(out.contains('<mathinline>x</mathinline>'), isTrue);
    expect(out.contains('<mathblock>'), isTrue);
    expect(out.contains('E=mc^2'), isTrue);
  });

  test('processMath ignores fenced code blocks', () {
    const src = '```\n\$notmath\$\n```';
    final out = processMath(src);
    expect(out.contains('<mathinline>'), isFalse);
    expect(out.contains(r'$notmath$'), isTrue);
  });
}
