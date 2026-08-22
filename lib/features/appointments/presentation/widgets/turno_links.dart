import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/fechas.dart';

/// Links externos del módulo de turnos: cómo llegar, llamar, agregar al
/// calendario. Todo abre la app externa y avisa con un toast si no se pudo.

Future<void> abrirUrlExterna(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    showLiquidToast(
      context,
      'No pudimos abrir el enlace en este dispositivo.',
      tone: LiquidToastTone.error,
    );
  }
}

/// Google Maps por coordenadas (si hay) o por dirección.
String? mapsUrl({double? latitude, double? longitude, String? address}) {
  if (latitude != null && longitude != null) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
  final addr = address?.trim();
  if (addr != null && addr.isNotEmpty) {
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
  }
  return null;
}

Future<void> abrirComoLlegar(
  BuildContext context, {
  double? latitude,
  double? longitude,
  String? address,
}) async {
  final url = mapsUrl(latitude: latitude, longitude: longitude, address: address);
  if (url == null) return;
  await abrirUrlExterna(context, url);
}

Future<void> llamar(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return;
  await abrirUrlExterna(context, 'tel:$digits');
}

String _compactUtc(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// URL de "Agregar a Google Calendar" (misma forma que el turnero web): el
/// instante se calcula en la zona de la sucursal y viaja en UTC.
String googleCalendarUrl({
  required String dateStr,
  required String startTime,
  required int durationMinutes,
  required String timezone,
  required String branchName,
  String? branchAddress,
  required String servicesLabel,
  required String staffName,
}) {
  final start = Fechas.instantOf(dateStr, startTime, timezone);
  final end = start.add(Duration(minutes: durationMinutes > 0 ? durationMinutes : 30));
  final text = '${servicesLabel.isEmpty ? 'Turno' : servicesLabel} en $branchName';
  final details = 'Turno con $staffName. Gestionalo desde la app de Monaco.';
  final location = (branchAddress != null && branchAddress.trim().isNotEmpty)
      ? branchAddress.trim()
      : branchName;
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': text,
    'dates': '${_compactUtc(start)}/${_compactUtc(end)}',
    'location': location,
    'details': details,
  }).toString();
}
