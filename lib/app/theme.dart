import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tema do app. Todas as cores usadas nas telas devem vir do [ColorScheme]
/// (`Theme.of(context).colorScheme`), nunca de `Color(0xFF...)` solto.
///
/// Mapa de uso:
/// - `primary`            azul escuro da marca (AppBar, rodapé, textos)
/// - `secondary`          azul de destaque (botões, links, seleção)
/// - `surface`            fundo das telas
/// - `primaryContainer`   fundo dos cards de consulta
/// - `inversePrimary`     azul claro para textos sobre fundo `primary`
/// - `tertiary*`          estado "ok/sucesso" (ex.: fila em tempo real)
class AppTheme {
  static const Color blue50 = Color(0xFFF0F7FF);
  static const Color blue100 = Color(0xFFE0EFFE);
  static const Color blue200 = Color(0xFFBADFFD);
  static const Color blue300 = Color(0xFF7EC5FB);
  static const Color blue400 = Color(0xFF39A8F7);
  static const Color blue500 = Color(0xFF0F8DE8);
  static const Color blue600 = Color(0xFF0371CA);
  static const Color blue700 = Color(0xFF0458A0);
  static const Color blue800 = Color(0xFF084B84);
  static const Color blue900 = Color(0xFF0C406E);
  static const Color blue950 = Color(0xFF082849);

  static final ThemeData lightTheme = ThemeData(
    fontFamily: 'Inter',
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue950,
      primary: blue950,
      onPrimary: Colors.white,
      secondary: blue600,
      onSecondary: Colors.white,
      surface: blue50,
      onSurface: blue950,
      primaryContainer: blue100,
      onPrimaryContainer: blue950,
      secondaryContainer: blue100,
      onSecondaryContainer: blue800,
      inversePrimary: blue300,
      tertiary: const Color(0xFF18A86F),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFE3F7EE),
      onTertiaryContainer: const Color(0xFF18A86F),
    ),
  );
}
