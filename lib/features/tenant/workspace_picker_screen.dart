import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/tenant_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import 'tenant_controller.dart';

/// Switch the active workspace. A trainee can be a Client in several coaches' workspaces (plus their
/// own). Switching resets all tenant-scoped state (see [activeTenantIdProvider]).
class WorkspacePickerScreen extends ConsumerWidget {
  const WorkspacePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tenantControllerProvider);
    return Scaffold(
      body: Column(
        children: [
          GbScreenHeader(
            title: 'Workspaces',
            subtitle: 'Switch the coach you\'re training with',
            trailing: _CircleButton(icon: Icons.close, onTap: () => context.pop()),
          ),
          Expanded(
            child: AsyncValueView(
              value: state,
              onRetry: () => ref.read(tenantControllerProvider.notifier).refresh(),
              loading: const GbSkeletonList(count: 4, itemHeight: 76),
              data: (data) {
                if (data.tenants.isEmpty) {
                  return EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No workspaces yet',
                    subtitle: 'Join a coach with an invite code to get started.',
                    action: GbButton(
                      label: 'Join a coach',
                      icon: Icons.add,
                      onPressed: () => context.push('/join'),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, AppSpacing.xl),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
                      child: Eyebrow('Your workspaces'),
                    ),
                    for (final t in data.tenants) ...[
                      _WorkspaceRow(
                        tenant: t,
                        selected: t.id == data.activeTenantId,
                        onTap: () async {
                          await ref.read(tenantControllerProvider.notifier).switchTenant(t.id);
                          if (context.mounted) context.pop();
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs + 1),
                    ],
                    const SizedBox(height: AppSpacing.xs - 1),
                    GbTappableRow(
                      dashed: true,
                      leading: GbIconTile(
                        background: context.gb.grey25,
                        child: Icon(Icons.add, size: 21, color: context.gb.grey600),
                      ),
                      title: 'Join another coach',
                      subtitle: 'Redeem an 8-character invite code',
                      onTap: () => context.push('/join'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A workspace membership row — gradient avatar, name, role badge, owner/member meta, and a
/// selected check. Tapping switches the active workspace (which resets all tenant-scoped state).
class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({required this.tenant, required this.selected, required this.onTap});
  final TenantSummary tenant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final initial = tenant.name.trim().isNotEmpty ? tenant.name.trim()[0].toUpperCase() : '?';
    final meta = [
      if (tenant.ownerName != null && !tenant.isOwner) tenant.ownerName!,
      '${tenant.memberCount} member${tenant.memberCount == 1 ? '' : 's'}',
    ].join(' · ');

    return GbCard(
      onTap: onTap,
      border: selected ? gb.primary50 : null,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Avatar(initial: initial, size: 44, ring: selected),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tenant.name, overflow: TextOverflow.ellipsis, style: AppText.rowTitle),
                    ),
                    const SizedBox(width: AppSpacing.xs - 1),
                    _RoleBadge(role: tenant.role),
                  ],
                ),
                const SizedBox(height: 2),
                Text(meta, style: AppText.meta.copyWith(color: gb.grey500)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (selected)
            Icon(Icons.check_circle, size: AppSizes.iconXxl, color: gb.primary600)
          else
            Icon(Icons.circle_outlined, size: AppSizes.iconXxl, color: gb.grey400),
        ],
      ),
    );
  }
}

/// Role pill — Owner (your own workspace) vs Client (a coach's), soft-tinted.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final TenantRole? role;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg, label) = switch (role) {
      TenantRole.owner => (gb.amberSoft, gb.amberInk, 'Owner'),
      TenantRole.client => (gb.primary0, gb.primary700, 'Client'),
      null => (gb.grey25, gb.grey600, 'Member'),
    };
    return GbStatusBadge(label: label, background: bg, foreground: fg);
  }
}

/// Circular grey icon button used in the header.
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
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
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: AppSizes.iconXl, color: gb.grey700)),
      ),
    );
  }
}
