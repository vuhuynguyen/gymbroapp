import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/widgets.dart';
import 'tenant_controller.dart';

/// Redeem an 8-character invite code to join a coach's workspace as a Client.
class JoinWorkspaceScreen extends ConsumerStatefulWidget {
  const JoinWorkspaceScreen({super.key});

  @override
  ConsumerState<JoinWorkspaceScreen> createState() => _JoinWorkspaceScreenState();
}

class _JoinWorkspaceScreenState extends ConsumerState<JoinWorkspaceScreen> {
  static const _codeLength = 8;

  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(tenantControllerProvider.notifier).joinByCode(code);
      if (mounted) {
        showInfoSnack(context, 'Joined your coach\'s workspace.');
        context.go('/log');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Scaffold(
      backgroundColor: gb.card,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand header — BrandMark glyph + wordmark + tagline (design auth header).
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BackButton(onTap: () => context.pop()),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Center(child: BrandMark(size: 62, radius: AppRadius.lg, glyph: true)),
              const SizedBox(height: AppSpacing.gap),
              Text('GymBro',
                  textAlign: TextAlign.center,
                  style: AppText.heroTitle.copyWith(fontSize: 27, letterSpacing: -0.81, color: gb.ink)),
              const SizedBox(height: 2),
              Text('Coach. Train. Track.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: gb.grey500)),
              const SizedBox(height: AppSpacing.lg),

              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Join your coach',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.22, color: gb.grey900)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Enter the 8-character invite code your coach shared. Codes are single-use and expire after 7 days.',
                      style: TextStyle(fontSize: 14, height: 1.5, color: gb.grey500),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Real input: an offstage uppercase TextField, presented as the design code boxes.
                    _CodeEntry(
                      controller: _code,
                      focusNode: _focus,
                      length: _codeLength,
                      onChanged: () => setState(() {}),
                      onSubmitted: _busy ? null : _join,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Info banner — secondary0 surface, explains the client-join behaviour.
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.gap),
                      decoration: BoxDecoration(
                        color: gb.secondary0,
                        borderRadius: AppRadius.brSm,
                        border: Border.all(color: gb.primary25),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(Icons.person_outline, size: AppSizes.iconLg, color: gb.primary600),
                          ),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'You\'ll join your '),
                                TextSpan(
                                    text: 'coach\'s workspace',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: gb.grey900)),
                                const TextSpan(
                                    text: ' as a client. Your own training history stays private.'),
                              ]),
                              style: TextStyle(fontSize: 13, height: 1.5, color: gb.grey700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    GbButton(
                      label: 'Join workspace',
                      icon: Icons.check,
                      size: GbButtonSize.lg,
                      full: true,
                      busy: _busy,
                      onPressed: _code.text.trim().isEmpty ? null : _join,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular grey back button (matches the detail-header leading control).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Material(
      color: gb.grey0,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.chevron_left, size: AppSizes.iconXl, color: gb.grey700),
        ),
      ),
    );
  }
}

/// Invite-code entry: the design's row of character boxes backed by a single real [TextField].
/// The field is offstage (transparent, 0-opacity) so it still owns focus, the keyboard, and the
/// controller text; tapping any box focuses it. Filled cells get the primary-tinted treatment.
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final chars = controller.text.characters.toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _CodeBox(char: i < chars.length ? chars[i] : null)),
              ],
            ],
          ),
          // The actual input — transparent, capturing keystrokes into the controller.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.visiblePassword,
                maxLength: length,
                style: const TextStyle(fontSize: 21, letterSpacing: 24, fontWeight: FontWeight.w800),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(length),
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  _UpperCaseFormatter(),
                ],
                onChanged: (_) => onChanged(),
                onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One code cell — primary-tinted when filled, neutral field surface when empty.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.char});
  final String? char;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final filled = char != null;
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? gb.primary0 : gb.grey0,
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: filled ? AppPalette.primary300 : gb.borderField,
          width: AppSizes.border,
        ),
        boxShadow: filled
            ? [BoxShadow(color: gb.primary500.withValues(alpha: 0.12), blurRadius: 0, spreadRadius: 3)]
            : null,
      ),
      child: Text(
        char ?? '',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: gb.ink).tabular,
      ),
    );
  }
}

/// Uppercases invite-code input as it is typed (codes are stored/compared uppercase).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
