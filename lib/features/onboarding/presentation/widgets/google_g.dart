import 'package:flutter/material.dart';

/// El logotipo "G" de Google, dibujado con las rutas oficiales.
///
/// Va como código y no como PNG por dos razones: las guías de marca de Google
/// exigen el logo exacto (un "G" aproximado a mano queda peor que no ponerlo),
/// y un vector no se pixela en el botón ni depende de que alguien acuerde de
/// meter tres densidades en `assets/`. No hay `flutter_svg` en el proyecto, así
/// que las cuatro rutas del SVG oficial (viewBox 18×18) se parsean acá con el
/// mini-parser de abajo.
///
/// **No lo recolorees**: los cuatro colores son parte de la marca y un botón de
/// Google monocromo no cumple las guías.
class GoogleG extends StatelessWidget {
  final double size;
  const GoogleG({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

/// Rutas del SVG oficial del botón "Sign in with Google" (viewBox 0 0 18 18).
///
/// Público sólo para que `test/unit/google_g_test.dart` pueda verificar que el
/// parser las lee bien: un parser equivocado no explota, devuelve un `Path`
/// raro y el botón queda con una mancha.
const rutasGoogleG = <(String, int)>[
  (
    'M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 '
        '2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z',
    0xFF4285F4,
  ),
  (
    'M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86'
        '-2.344 0-4.328-1.584-5.036-3.711H.957v2.332C2.438 15.983 5.482 18 9 18z',
    0xFF34A853,
  ),
  (
    'M3.964 10.71c-.18-.54-.282-1.117-.282-1.71s.102-1.17.282-1.71V4.958H.957'
        'C.347 6.173 0 7.548 0 9s.348 2.827.957 4.042l3.007-2.332z',
    0xFFFBBC05,
  ),
  (
    'M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0 '
        '5.482 0 2.438 2.017.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z',
    0xFFEA4335,
  ),
];

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);
    for (final (d, color) in rutasGoogleG) {
      canvas.drawPath(
        parsearRutaSvg(d),
        Paint()
          ..color = Color(color)
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final _tokens = RegExp(r'[MmLlHhVvCcSsZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?');

/// Mini-parser de rutas SVG: soporta `M m L l H h V v C c S s Z z`, que es todo
/// lo que usan las rutas de arriba. No pretende ser general — si alguna vez
/// hace falta otro comando, es preferible agregar el caso acá que meter una
/// dependencia entera de SVG para un logo.
@visibleForTesting
Path parsearRutaSvg(String d) {
  final path = Path();
  final tokens = _tokens.allMatches(d).map((m) => m[0]!).toList();

  var i = 0;
  var x = 0.0, y = 0.0; // punto actual
  var sx = 0.0, sy = 0.0; // inicio del subpath (para `z`)
  var cx = 0.0, cy = 0.0; // último control de la cúbica (para `s`)
  String? cmd;

  double num() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(t)) {
      cmd = t;
      i++;
      // `z` no lleva argumentos.
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        x = sx;
        y = sy;
        continue;
      }
    } else if (cmd == null) {
      break; // ruta malformada: mejor un logo vacío que una excepción
    } else if (cmd == 'M') {
      // Coordenadas repetidas después de un `M` son `L` implícitas.
      cmd = 'L';
    } else if (cmd == 'm') {
      cmd = 'l';
    }

    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final nx = num(), ny = num();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        sx = x;
        sy = y;
        path.moveTo(x, y);
        cx = x;
        cy = y;
      case 'L':
        final nx = num(), ny = num();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'H':
        final nx = num();
        x = rel ? x + nx : nx;
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'V':
        final ny = num();
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'C':
        final x1 = num(), y1 = num(), x2 = num(), y2 = num();
        final ex = num(), ey = num();
        final ax1 = rel ? x + x1 : x1, ay1 = rel ? y + y1 : y1;
        final ax2 = rel ? x + x2 : x2, ay2 = rel ? y + y2 : y2;
        final aex = rel ? x + ex : ex, aey = rel ? y + ey : ey;
        path.cubicTo(ax1, ay1, ax2, ay2, aex, aey);
        cx = ax2;
        cy = ay2;
        x = aex;
        y = aey;
      case 'S':
        final x2 = num(), y2 = num(), ex = num(), ey = num();
        final ax1 = 2 * x - cx, ay1 = 2 * y - cy; // reflejo del control previo
        final ax2 = rel ? x + x2 : x2, ay2 = rel ? y + y2 : y2;
        final aex = rel ? x + ex : ex, aey = rel ? y + ey : ey;
        path.cubicTo(ax1, ay1, ax2, ay2, aex, aey);
        cx = ax2;
        cy = ay2;
        x = aex;
        y = aey;
    }
  }
  return path;
}
