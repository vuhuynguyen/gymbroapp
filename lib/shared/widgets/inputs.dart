import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Labeled text field (design `Field`) — a label above a themed [TextField] with a leading icon.
/// Thin wrapper over [TextFormField] so it keeps full controller/validation behavior.
class GbTextField extends StatelessWidget {
  const GbTextField({
    required this.controller,
    this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.helperText,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gb.grey700)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autocorrect: autocorrect,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixIcon: icon == null ? null : Icon(icon, size: AppSizes.iconLg, color: gb.grey400),
          ),
        ),
      ],
    );
  }
}

/// Read-only search field affordance (design add-exercise search bar). Pairs with a controller for
/// live filtering.
class GbSearchField extends StatelessWidget {
  const GbSearchField({required this.controller, this.hint = 'Search…', this.onChanged, super.key});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: gb.grey0,
        prefixIcon: Icon(Icons.search, size: AppSizes.iconLg, color: gb.grey400),
      ),
    );
  }
}

/// Segmented control (design `Segmented`) — an inset pill track with a raised selected segment.
class GbSegmented<T> extends StatelessWidget {
  const GbSegmented({required this.options, required this.value, required this.onChanged, super.key});

  /// (value, label) pairs.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: gb.grey25, borderRadius: AppRadius.brSm),
      child: Row(
        children: [
          for (final (val, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: val == value ? gb.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: val == value ? AppShadows.sm : null,
                  ),
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.14,
                        color: val == value ? gb.ink : gb.grey500,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
