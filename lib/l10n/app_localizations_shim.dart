// Minimal localization shim used while ARB -> generated code isn't produced.
// Replace with generated code by running `flutter pub get` and
// `flutter gen-l10n` (or a Flutter build) which will create the
// official `AppLocalizations` from the ARB files in `lib/l10n`.

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  static AppLocalizations of(BuildContext context) => AppLocalizations(Localizations.localeOf(context));

  String get demoTitle => locale.languageCode.startsWith('es')
      ? 'Bienvenido a Noteker - Demo de matematicas'
      : 'Welcome to Noteker - Math demo';

  String get demoContent {
    if (locale.languageCode.startsWith('es')) {
      return r'''Bienvenido a Noteker!

Esta demo muestra matematicas en linea: $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}

Y una ecuacion en bloque:
$$
\nabla \cdot \mathbf{E} = \frac{\rho}{\varepsilon_0}
$$

Los saltos de linea simples se conservan - pulsa Enter para crear una nueva linea y se mostrara en la vista previa.

Disfruta!''';
    }
    return r'''Welcome to Noteker!

This demo shows inline math: $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}

And a block equation:
$$
\nabla \cdot \mathbf{E} = \frac{\rho}{\varepsilon_0}
$$

Single newlines are preserved - press Enter to create a new line and it will show up in the preview.

Enjoy!''';
  }

  String get walkthroughTitle => locale.languageCode.startsWith('es') ? 'Guia rapida' : 'Quick walkthrough';
  String get walkthroughNext => locale.languageCode.startsWith('es') ? 'Siguiente' : 'Next';
  String get walkthroughBack => locale.languageCode.startsWith('es') ? 'Atras' : 'Back';
  String get walkthroughClose => locale.languageCode.startsWith('es') ? 'Cerrar' : 'Close';
}
