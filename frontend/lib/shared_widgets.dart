import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';

/// Uppercase gray section heading
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: LegoApp.legoMuted,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// Count/label badge — yellow bg, red text by default
class LegoBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const LegoBadge(
    this.label, {
    super.key,
    this.bg = const Color(0xFFFFF8DC),
    this.fg = LegoApp.legoRed,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    ),
  );
}

/// Stat chip for the dark hero header
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  const StatChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: LegoApp.legoYellow,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
