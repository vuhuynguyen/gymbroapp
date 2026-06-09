import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/widgets.dart';
import 'auth_controller.dart';

/// Request a reset link, then enter the emailed token + a new password. The API always reports
/// success on forgot-password (no account enumeration).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _newPassword = TextEditingController();
  bool _requested = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(_email.text.trim());
      if (mounted) {
        setState(() => _requested = true);
        showInfoSnack(
            context, 'If that email exists, a reset code is on its way.');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            _email.text.trim(),
            _token.text.trim(),
            _newPassword.text,
          );
      if (mounted) {
        showInfoSnack(context, 'Password reset. Please log in.');
        context.go('/login');
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left,
                              size: AppSizes.iconLg, color: gb.grey600),
                          const SizedBox(width: AppSpacing.xs - 2),
                          Text('Back',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: gb.grey600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Center(
                      child: BrandMark(size: 62, radius: 20, glyph: true)),
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    'Reset password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.22,
                        color: gb.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _requested
                        ? 'Enter the code we sent and choose a new password.'
                        : "We'll email you a reset code if an account exists.",
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, height: 1.5, color: gb.grey500),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GbTextField(
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _request(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GbButton(
                    label: 'Send reset code',
                    iconRight: Icons.arrow_forward,
                    size: GbButtonSize.lg,
                    full: true,
                    busy: _busy && !_requested,
                    onPressed: _busy ? null : _request,
                  ),
                  if (_requested) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const _OrDivider(),
                    const SizedBox(height: AppSpacing.lg),
                    GbTextField(
                      controller: _token,
                      label: 'Reset code',
                      hint: 'Paste the code from your email',
                      icon: Icons.vpn_key_outlined,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    GbTextField(
                      controller: _newPassword,
                      label: 'New password',
                      hint: 'At least 8 characters',
                      helperText:
                          'Use upper & lower case, a number, and a symbol.',
                      icon: Icons.lock_outline,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _reset(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GbButton(
                      label: 'Set new password',
                      icon: Icons.check,
                      size: GbButtonSize.lg,
                      full: true,
                      busy: _busy && _requested,
                      onPressed: _busy ? null : _reset,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two hairlines flanking an "or" label (design divider).
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final line = Expanded(
        child: Container(height: AppSizes.hairline, color: gb.borderCard));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('then',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: gb.grey400)),
        ),
        line,
      ],
    );
  }
}
