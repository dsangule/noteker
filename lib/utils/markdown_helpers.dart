import 'dart:core';

// Helpers used for preparing markdown preview: math processing and line
// break preservation. These are kept in a separate file to make them easy to
// unit test.

String preserveLineBreaks(String text) {
  if (text.isEmpty) return text;
  final lines = text.split('\n');
  final buf = StringBuffer();
  var inFenced = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFenced = !inFenced;
      buf.writeln(line);
      continue;
    }
    if (inFenced) {
      buf.writeln(line);
      continue;
    }
    if (i < lines.length - 1 && lines[i + 1].isNotEmpty) {
      buf.write('$line  \n');
    } else {
      buf.writeln(line);
    }
  }
  return buf.toString();
}

String processMath(String text) {
  if (text.isEmpty) return text;
  final lines = text.split('\n');
  final out = StringBuffer();
  var inFenced = false;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFenced = !inFenced;
      out.writeln(line);
      continue;
    }
    if (inFenced) {
      out.writeln(line);
      continue;
    }
    if (line.contains(r'$$')) {
      if (line.indexOf(r'$$') != line.lastIndexOf(r'$$')) {
        final first = line.indexOf(r'$$');
        final last = line.lastIndexOf(r'$$');
        final before = line.substring(0, first);
        final math = line.substring(first + 2, last);
        final after = line.substring(last + 2);
        if (before.isNotEmpty) out.write(before);
        out.write('<mathblock>$math</mathblock>');
        if (after.isNotEmpty) out.write(after);
        out.writeln();
        continue;
      }
      final startIdx = line.indexOf(r'$$');
      final before = line.substring(0, startIdx);
      final buffer = StringBuffer();
      var found = false;
      var rest = line.substring(startIdx + 2);
      if (rest.contains(r'$$')) {
        final end = rest.indexOf(r'$$');
        buffer.writeln(rest.substring(0, end));
        final after = rest.substring(end + 2);
        if (before.isNotEmpty) out.write(before);
        out.write('<mathblock>${buffer.toString()}</mathblock>');
        if (after.isNotEmpty) out.write(after);
        out.writeln();
        continue;
      }
      buffer.writeln(rest);
      var j = i + 1;
      while (j < lines.length) {
        final l = lines[j];
        if (l.contains(r'$$')) {
          final idx = l.indexOf(r'$$');
          buffer.writeln(l.substring(0, idx));
          final after = l.substring(idx + 2);
          if (before.isNotEmpty) out.write(before);
          out.write('<mathblock>${buffer.toString()}</mathblock>');
          if (after.isNotEmpty) out.write(after);
          out.writeln();
          i = j; // advance outer loop
          found = true;
          break;
        } else {
          buffer.writeln(l);
          j++;
        }
      }
      if (!found) {
        out.write('<mathblock>${buffer.toString()}</mathblock>');
        out.writeln();
        i = j - 1;
      }
      continue;
    }
    line = line.replaceAllMapped(RegExp(r'\$(.+?)\$'), (m) {
      return '<mathinline>${m.group(1)}</mathinline>';
    });
    out.writeln(line);
  }
  return out.toString();
}

String processMarkdownForPreview(String src) => preserveLineBreaks(processMath(src));

const kPrefKeyMathEnabled = 'pref_math_enabled_v1';
