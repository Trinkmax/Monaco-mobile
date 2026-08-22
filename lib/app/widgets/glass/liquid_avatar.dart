import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/monaco_colors.dart';

/// Avatar circular con foto (cacheada) o iniciales sobre vidrio.
class LiquidAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final Color? tint;
  final IconData fallbackIcon;
  final bool ring;

  const LiquidAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 44,
    this.tint,
    this.fallbackIcon = Icons.person_rounded,
    this.ring = true,
  });

  static String initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p))
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? Colors.white;
    final initials = initialsOf(name);
    final url = imageUrl?.trim();

    Widget inner;
    if (url != null && url.isNotEmpty) {
      inner = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, __) => _Fallback(
          initials: initials,
          icon: fallbackIcon,
          size: size,
          accent: accent,
        ),
        errorWidget: (_, __, ___) => _Fallback(
          initials: initials,
          icon: fallbackIcon,
          size: size,
          accent: accent,
        ),
      );
    } else {
      inner = _Fallback(
        initials: initials,
        icon: fallbackIcon,
        size: size,
        accent: accent,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring
            ? Border.all(color: accent.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(child: inner),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String initials;
  final IconData icon;
  final double size;
  final Color accent;

  const _Fallback({
    required this.initials,
    required this.icon,
    required this.size,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            accent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              )
            : Icon(icon, size: size * 0.5, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }
}
