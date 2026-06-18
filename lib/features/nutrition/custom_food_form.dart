import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/nutrition_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import 'my_foods_store.dart';

/// Free-form food editor (design `CustomFoodForm`) — name, type selector, serving size, and a
/// four-cell macro grid (kcal / Protein / Carbs / Fat). Shared by the picker's "log a custom food"
/// path and the My-foods add/edit sheet. Calls [onContinue] with a `Food` (isCustom = true) once the
/// minimum facts are present (a name and some calories).
class CustomFoodForm extends StatefulWidget {
  const CustomFoodForm({
    this.initial,
    this.initialName,
    required this.onContinue,
    this.submitLabel = 'Continue',
    this.submitIcon = Icons.chevron_right,
    this.note = "Saved to this log only — it won't change your gym's catalog.",
    super.key,
  });

  final Food? initial;
  final String? initialName;
  final ValueChanged<Food> onContinue;
  final String submitLabel;
  final IconData submitIcon;
  final String note;

  @override
  State<CustomFoodForm> createState() => _CustomFoodFormState();
}

class _CustomFoodFormState extends State<CustomFoodForm> {
  late final TextEditingController _name;
  late final TextEditingController _serving;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late FoodKind _kind;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    String n(num? v) =>
        v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : '$v');
    _name = TextEditingController(text: f?.name ?? widget.initialName ?? '');
    _serving = TextEditingController(text: f?.servingLabel ?? '');
    _kcal = TextEditingController(text: n(f?.energyKcal));
    _protein = TextEditingController(text: n(f?.proteinG));
    _carbs = TextEditingController(text: n(f?.carbsG));
    _fat = TextEditingController(text: n(f?.fatG));
    _kind = f?.kind ?? FoodKind.food;
  }

  @override
  void dispose() {
    for (final c in [_name, _serving, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  num _num(TextEditingController c) {
    // Normalise a comma decimal separator to a dot (comma-locale keyboards offer "," not ".").
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v < 0 ? 0 : v;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _num(_kcal) > 0;

  void _submit() {
    if (!_valid) return;
    final initial = widget.initial;
    final serving = _serving.text.trim();
    widget.onContinue(Food(
      // Editing a saved food keeps its id; otherwise mint a fresh local id.
      id: initial?.mine == true ? initial!.id : MyFoodsController.newId(),
      name: _name.text.trim(),
      kind: _kind,
      brand: initial?.brand,
      servingLabel: serving.isEmpty ? '1 serving' : serving,
      energyKcal: _num(_kcal),
      proteinG: _num(_protein),
      carbsG: _num(_carbs),
      fatG: _num(_fat),
      // A saved edited-variant stays "edited"; everything authored here is custom.
      isCustom: initial?.isEdited == true ? false : true,
      isEdited: initial?.isEdited ?? false,
      mine: initial?.mine ?? false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _label('Name'),
              _textField(_name, "e.g. Mum's lasagna"),
              const SizedBox(height: 14),
              _label('Type'),
              _TypeSelector(
                  value: _kind, onChanged: (k) => setState(() => _kind = k)),
              const SizedBox(height: 14),
              _label('Serving size'),
              _textField(_serving, 'e.g. 1 plate · 350 g'),
              const SizedBox(height: 14),
              _label('Nutrition per serving — your best estimate is fine'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _MacroCell(label: 'kcal', controller: _kcal)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MacroCell(
                          label: 'Protein', unit: 'g', controller: _protein)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MacroCell(
                          label: 'Carbs', unit: 'g', controller: _carbs)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MacroCell(
                          label: 'Fat', unit: 'g', controller: _fat)),
                ],
              ),
              const SizedBox(height: 14),
              Text(widget.note,
                  style:
                      TextStyle(fontSize: 12, height: 1.5, color: gb.grey500)),
            ],
          ),
        ),
        // Rebuild the CTA's enabled state as the name / kcal fields change.
        ListenableBuilder(
          listenable: Listenable.merge([_name, _kcal]),
          builder: (_, __) => GbButton(
            label: widget.submitLabel,
            icon: widget.submitIcon,
            size: GbButtonSize.lg,
            full: true,
            onPressed: _valid ? _submit : null,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.gb.grey500)),
      );

  Widget _textField(TextEditingController c, String hint) {
    final gb = context.gb;
    return TextField(
      controller: c,
      // Keep the focused field clear of the keyboard + pinned CTA so what you type stays visible.
      scrollPadding: const EdgeInsets.only(bottom: 160),
      style: TextStyle(fontSize: 15, color: gb.grey900),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        filled: true,
        fillColor: gb.card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: gb.borderField, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: gb.primary500, width: 1.5),
        ),
      ),
    );
  }
}

/// Three-way type selector (Food / Supplement / Beverage) — active pill is ink-filled.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});
  final FoodKind value;
  final ValueChanged<FoodKind> onChanged;

  static const _icons = {
    FoodKind.food: Icons.restaurant,
    FoodKind.supplement: Icons.medication_outlined,
    FoodKind.beverage: Icons.local_drink_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      children: [
        for (final k in FoodKind.values) ...[
          if (k != FoodKind.food) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(k),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: value == k ? gb.ink : gb.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: value == k ? Colors.transparent : gb.borderCard,
                      width: 1.5),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icons[k],
                          size: 14,
                          color: value == k ? Colors.white : gb.grey600),
                      const SizedBox(width: 6),
                      Text(k.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: value == k ? Colors.white : gb.grey600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One macro grid cell — a bordered box with a centered numeric input, an optional unit, and an
/// uppercase label underneath.
class _MacroCell extends StatefulWidget {
  const _MacroCell({required this.label, required this.controller, this.unit});
  final String label;
  final String? unit;
  final TextEditingController controller;

  @override
  State<_MacroCell> createState() => _MacroCellState();
}

class _MacroCellState extends State<_MacroCell> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Select the whole value on focus (like GbStepper) so the caret never sits
    // on top of the existing number — typing replaces it outright.
    _focus.addListener(() {
      if (_focus.hasFocus) {
        final c = widget.controller;
        c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 7),
      decoration: BoxDecoration(
        color: gb.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: gb.borderField, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Fixed width (design: 38 with a unit, 48 without) — TextField + IntrinsicWidth don't
              // compose, so size it explicitly to keep the cell from overflowing.
              SizedBox(
                width: widget.unit != null ? 38 : 48,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  textAlign: TextAlign.center,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    // Accept "." or "," (comma-locale keyboards); _num normalises before parsing.
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  ],
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: gb.grey900),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: '0',
                  ),
                ),
              ),
              if (widget.unit != null) ...[
                const SizedBox(width: 2),
                Text(widget.unit!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: gb.grey400)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(widget.label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: gb.grey400)),
        ],
      ),
    );
  }
}
