// ignore_for_file: undefined_prefixed_name, avoid_web_libraries_in_flutter, deprecated_import
import 'dart:js_interop';
import 'dart:math';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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

  String _cssColor(Color? c) {
    if (c == null) {
      return 'inherit';
    }
    final r = (c.r * 255.0).round() & 0xff;
    final g = (c.g * 255.0).round() & 0xff;
    final b = (c.b * 255.0).round() & 0xff;
    final a = c.a; // 0..1 for CSS rgba
    return 'rgba($r, $g, $b, $a)';
  }

  @override
  Widget build(BuildContext context) {
    // Unique view type per instance to avoid reuse issues
    final viewType = 'katex-view-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

    // Register a factory that returns a DIV which loads KaTeX and renders the TeX string
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.display = 'block'
        ..style.overflow = 'visible';

      final style = web.HTMLStyleElement()
        ..innerHTML = '''
          .katex-host { 
            font-size: ${fontSize}px; 
            color: ${_cssColor(color)}; 
          }
        '''.jsify()!;

      final katexCss = web.HTMLLinkElement()
        ..rel = 'stylesheet'
        ..href = 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css';

      final katexScript = web.HTMLScriptElement()
        ..type = 'application/javascript'
        ..src = 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js';

      final encoded = Uri.encodeComponent(tex);
      final host = web.HTMLDivElement()
        ..classList.add('katex-host')
        ..style.display = display ? 'block' : 'inline'
        ..style.overflow = 'visible'
        ..setAttribute('data-tex', encoded)
        ..id = 'host-$viewType';

      // After KaTeX loads, render the formula.
      final loadCallback = () {
        final renderScript = web.HTMLScriptElement()
          ..type = 'application/javascript'
          ..innerHTML = '''
            try {
              var host = document.getElementById('host-$viewType');
              var raw = host ? host.getAttribute('data-tex') : null;
              if (!raw) return; // no data -> nothing to render
              var tex = decodeURIComponent(raw);
              if (!tex || tex.trim().length === 0) return; // empty -> skip
              katex.render(tex, host, {displayMode: ${display ? 'true' : 'false'}, throwOnError: false});
            } catch (e) {
              console.warn('KaTeX render error', e);
            }
          '''.jsify()!;
        container.append(renderScript);
      }.toJS;
      katexScript.addEventListener('load', loadCallback);

      container
        ..append(style)
        ..append(katexCss)
        ..append(host)
        ..append(katexScript);

      return container;
    });

    return HtmlElementView(viewType: viewType);
  }
}
