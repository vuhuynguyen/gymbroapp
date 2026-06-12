import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/auth_models.dart';
import '../../data/models/tenant_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_controller.dart';
import '../tenant/tenant_controller.dart';

/// Profile + account actions: workspace switch, join a coach, change password, sign out, logout-all.
/// Mirrors the design's Profile screen — identity card, a single grouped menu card, and the danger
/// account actions — over the real auth/tenant state.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final me = ref.watch(authControllerProvider);
    final tenant = ref.watch(tenantControllerProvider).valueOrNull;
    final active = tenant?.active;

    return Scaffold(
      backgroundColor: gb.canvas,
      body: Column(
        children: [
          GbAppHeader(
            title: 'Profile',
            actions: [
              GbBellButton(
                  onTap: () => showInfoSnack(context, 'No notifications yet'))
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 100),
              children: [
                _ProfileCard(me: me, roleLabel: _roleLabel(active)),
                const SizedBox(height: AppSpacing.md),
                _MenuCard(items: [
                  // Personal saved foods (device-local) — reachable by anyone who logs nutrition.
                  (
                    Icons.restaurant_menu,
                    'My foods',
                    'Your saved custom foods',
                    () => context.push('/my-foods')
                  ),
                  // A coach (Owner) owns their workspace — no joining a coach, no tenant switching.
                  // A client can join a coach, and switch only when they belong to more than one gym.
                  if (active?.role != TenantRole.owner)
                    (
                      Icons.confirmation_number_outlined,
                      'Join a coach',
                      'Enter an invite code',
                      () => context.push('/join')
                    ),
                  if (active?.role != TenantRole.owner &&
                      (tenant?.tenants.length ?? 0) > 1)
                    (
                      Icons.workspaces_outline,
                      'Switch workspace',
                      active?.name,
                      () => context.push('/workspaces')
                    ),
                  (
                    Icons.key_outlined,
                    'Change password',
                    null,
                    () => _changePassword(context, ref)
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                GbButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  variant: GbButtonVariant.text,
                  severity: GbButtonSeverity.danger,
                  full: true,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'GymBro Mobile · v0.1.0',
                    style: TextStyle(fontSize: 11, color: gb.grey400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Owner · Hale Strength" for a coach; "Client · Coach Morgan" for a trainee (design Profile).
  static String? _roleLabel(TenantSummary? active) {
    if (active == null) return null;
    if (active.role == TenantRole.owner) return 'Owner · ${active.name}';
    return active.ownerName != null ? 'Client · ${active.ownerName}' : 'Client';
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Current password',
                    hintText: 'Enter your current password')),
            const SizedBox(height: AppSpacing.xs),
            TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password',
                    hintText: 'At least 8 characters')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update')),
        ],
      ),
    );
    // Capture then dispose the controllers on every path (the dialog is gone now).
    final currentPw = current.text;
    final newPw = next.text;
    current.dispose();
    next.dispose();
    if (ok != true) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(currentPw, newPw);
      if (context.mounted) {
        showInfoSnack(
            context, 'Password updated. Other sessions were signed out.');
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }
}

/// Identity card — gradient avatar, name + email, and a soft-tint role badge.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me, required this.roleLabel});
  final AsyncValue<Me?> me;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final profile = me.valueOrNull;
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : (me.isLoading ? null : 'GymBro athlete');
    final initial = (name != null && name.trim().isNotEmpty)
        ? name.trim()[0].toUpperCase()
        : 'A';

    return GbCard(
      radius: AppRadius.lg,
      child: Row(
        children: [
          Avatar(initial: initial, size: 56),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                name == null
                    ? const GbSkeleton(width: 130, height: 17)
                    : Text(
                        name,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.17,
                            color: gb.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                const SizedBox(height: 2),
                me.hasError
                    ? Text('Could not load profile',
                        style: TextStyle(fontSize: 13, color: gb.danger))
                    : Text(profile?.email ?? '',
                        style: TextStyle(fontSize: 13, color: gb.grey500),
                        overflow: TextOverflow.ellipsis),
                if (roleLabel != null) ...[
                  const SizedBox(height: 7),
                  GbStatusBadge(
                    label: roleLabel!,
                    background: gb.primary0,
                    foreground: gb.primary700,
                    stadium: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped account menu — role-adaptive rows stacked inside one card, divided by hairlines.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});

  /// (icon, label, optional subtitle, onTap) per row.
  final List<(IconData, String, String?, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.lg,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: gb.borderCard),
            _MenuTile(
                icon: items[i].$1,
                label: items[i].$2,
                sub: items[i].$3,
                onTap: items[i].$4),
          ],
        ],
      ),
    );
  }
}

/// One menu row — leading icon, label + optional sub, trailing chevron (design Profile list item).
class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon, required this.label, this.sub, required this.onTap});
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.gap),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconXl, color: gb.grey500),
            const SizedBox(width: AppSpacing.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: gb.grey900)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        style: TextStyle(fontSize: 12, color: gb.grey400),
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right, size: AppSizes.iconMd, color: gb.grey400),
          ],
        ),
      ),
    );
  }
}
