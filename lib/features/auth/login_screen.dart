import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/widgets.dart';
import '../tenant/tenant_controller.dart';
import 'auth_controller.dart';

/// Auth entry — segmented Log in / Sign up, with an optional invite code on sign-up so a trainee can
/// create an account and join their coach in one step (the API requires an account before joining).
/// On success the router redirect navigates to the shell automatically.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, signup }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Mode _mode = _Mode.login;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _showInvite = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      showInfoSnack(context, 'Enter your email and password.');
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_mode == _Mode.login) {
        await auth.login(email, password);
      } else {
        await auth.register(email, password, _name.text.trim());
        final code = _code.text.trim();
        if (code.isNotEmpty) {
          await ref.read(tenantControllerProvider.notifier).joinByCode(code);
        }
      }
      // Router redirect handles navigation once the token is set.
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final isSignup = _mode == _Mode.signup;
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
                  const _BrandHeader(),
                  const SizedBox(height: AppSpacing.lg),
                  GbSegmented<_Mode>(
                    value: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                    options: const [
                      (_Mode.login, 'Log in'),
                      (_Mode.signup, 'Sign up'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md + 2),
                  if (isSignup) ...[
                    GbTextField(
                      controller: _name,
                      label: 'Full name',
                      hint: 'e.g. Alex Carter',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                  ],
                  GbTextField(
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  GbTextField(
                    controller: _password,
                    label: 'Password',
                    hint: isSignup ? 'At least 8 characters' : 'Your password',
                    helperText: isSignup
                        ? 'Use upper & lower case, a number, and a symbol.'
                        : null,
                    icon: Icons.lock_outline,
                    obscure: true,
                    textInputAction:
                        isSignup ? TextInputAction.next : TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (isSignup) ...[
                    const SizedBox(height: AppSpacing.gap),
                    _InviteAffordance(
                      expanded: _showInvite,
                      controller: _code,
                      onToggle: () =>
                          setState(() => _showInvite = !_showInvite),
                    ),
                  ],
                  if (!isSignup) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.push('/forgot-password'),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: gb.primary600),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md + 2),
                  GbButton(
                    label: isSignup ? 'Create account' : 'Log in',
                    iconRight: Icons.arrow_forward,
                    size: GbButtonSize.lg,
                    full: true,
                    busy: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.md + 2),
                  const _OrDivider(),
                  const SizedBox(height: AppSpacing.md + 2),
                  Text(
                    "By continuing you agree to GymBro's Terms & Privacy Policy.",
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, height: 1.5, color: gb.grey400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered brand block: gradient glyph mark, wordmark, and tagline.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      children: [
        const BrandMark(size: 62, radius: 20, glyph: true),
        const SizedBox(height: AppSpacing.gap),
        Text(
          'GymBro',
          style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.81,
              color: gb.ink),
        ),
        const SizedBox(height: 2),
        Text('Coach. Train. Track.',
            style: TextStyle(fontSize: 14, color: gb.grey500)),
      ],
    );
  }
}

/// Collapsible "Have an invite code?" affordance for sign-up. The app requires an account before
/// joining a coach, so the prototype's standalone invite flow is folded into sign-up here.
class _InviteAffordance extends StatelessWidget {
  const _InviteAffordance(
      {required this.expanded,
      required this.controller,
      required this.onToggle});
  final bool expanded;
  final TextEditingController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(Icons.confirmation_number_outlined,
                  size: AppSizes.iconMd, color: gb.primary600),
              const SizedBox(width: AppSpacing.xs - 2),
              Text(
                'Have an invite code?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: gb.primary600),
              ),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: AppSizes.iconLg,
                color: gb.grey400,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.gap),
          GbTextField(
            controller: controller,
            label: 'Invite code',
            hint: 'e.g. K7P2W9XQ',
            icon: Icons.vpn_key_outlined,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            helperText: 'Join your coach now, or later from Profile.',
          ),
        ],
      ],
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
          child: Text('or',
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
