import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';

/// Visual style for a food kind — the tinted tile background, foreground, and glyph.
/// Matches the design's FOOD_KIND_STYLE: food → blue, supplement → amber, beverage → cyan.
({Color bg, Color fg, IconData icon}) foodKindStyle(
    BuildContext context, FoodKind kind) {
  final gb = context.gb;
  return switch (kind) {
    FoodKind.food => (
        bg: gb.primary0,
        fg: gb.primary600,
        icon: Icons.restaurant
      ),
    FoodKind.supplement => (
        bg: gb.amberSoft,
        fg: gb.amberInk,
        icon: Icons.medication_outlined
      ),
    FoodKind.beverage => (
        bg: gb.secondary0,
        fg: gb.secondary300,
        icon: Icons.local_drink_outlined
      ),
  };
}

/// Rounded, kind-tinted icon tile (design `FoodTile`). [size] 40 in lists, 44 on the confirm card.
class FoodTile extends StatelessWidget {
  const FoodTile({required this.kind, this.size = 40, super.key});
  final FoodKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = foodKindStyle(context, kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(s.icon, size: size * 0.48, color: s.fg),
    );
  }
}

/// Tiny kind chip (design `FoodKindChip`) — "Food" / "Supplement" / "Beverage".
class FoodKindChip extends StatelessWidget {
  const FoodKindChip({required this.kind, super.key});
  final FoodKind kind;

  @override
  Widget build(BuildContext context) {
    final s = foodKindStyle(context, kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration:
          BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(4)),
      child: Text(kind.label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: s.fg)),
    );
  }
}

/// Neutral "My food" / "Custom" / "Edited" tag (design `MineTag`).
class FoodMineTag extends StatelessWidget {
  const FoodMineTag({this.label = 'My food', super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: gb.grey25, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: gb.grey600)),
    );
  }
}
