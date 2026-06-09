import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/coach_models.dart';
import '../../data/repositories/tenant_repository.dart';
import '../../shared/widgets/widgets.dart';
import 'coach_providers.dart';

/// Coach home — the client roster + an invite generator. Mirrors membership rules: 8-char,
/// single-use, 7-day invite codes that always join as Client.
class CoachClientsScreen extends ConsumerWidget {
  const CoachClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(coachClientsProvider);

    return Scaffold(
      backgroundColor: context
          .gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
      body: Column(
        children: [
          GbAppHeader(
            title: 'Clients',
            actions: [
              GbButton(
                label: 'Invite',
                icon: Icons.person_add_alt,
                size: GbButtonSize.sm,
                onPressed: () => _openInviteSheet(context),
              ),
            ],
          ),
          Expanded(
            child: AsyncValueView(
              value: clients,
              onRetry: () async => ref.invalidate(coachClientsProvider),
              loading: const GbSkeletonList(count: 5),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.group_outlined,
                    title: 'No clients yet',
                    subtitle: 'Invite a client with a code to start coaching.',
                    action: GbButton(
                      label: 'Invite a client',
                      icon: Icons.person_add_alt,
                      onPressed: () => _openInviteSheet(context),
                    ),
                  );
                }
                final withPlan = list.where((c) => c.hasActivePlan).length;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(coachClientsProvider);
                    await ref.read(coachClientsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                        AppSpacing.gap, AppSpacing.screenH, 90),
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: GbStatTile(
                                  value: '${list.length}', label: 'Clients')),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Expanded(
                              child: GbStatTile(
                                  value: '$withPlan', label: 'On a plan')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      for (final c in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ClientRow(client: c),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openInviteSheet(BuildContext context) {
    showGbSheet<void>(context,
        scrollable: true, builder: (_) => const _InviteSheet());
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client});
  final ClientSummary client;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Status pill derives from real roster data. Per-client adherence (done/goal) isn't carried by
    // the roster provider, so we only distinguish has-plan ("On track") from no-plan ("No plan");
    // "Behind" needs per-client session counts not available here (see deviations).
    final (statusBg, statusFg, statusLabel) = client.hasActivePlan
        ? (gb.success0, gb.success, 'On track')
        : (gb.grey25, gb.grey600, 'No plan');

    return GbTappableRow(
      onTap: () => context.push(
          '/client/${client.userId}?name=${Uri.encodeComponent(client.name)}'),
      leading: Avatar(initial: client.initial, size: 44),
      title: client.name,
      titleTrailing:
          client.visibility != null ? VisBadge(client.visibility!) : null,
      subtitle: client.hasActivePlan
          ? '${client.planName ?? 'Assigned plan'} · ${client.frequency ?? 0}×/wk'
          : 'No active plan',
      trailing: GbStatusBadge(
          label: statusLabel, background: statusBg, foreground: statusFg),
    );
  }
}

/// Generate / list / revoke invite codes.
class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  String? _fresh;
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final code = await ref.read(tenantRepositoryProvider).generateInvite();
      ref.invalidate(coachInvitesProvider);
      if (mounted) setState(() => _fresh = code);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String code) async {
    try {
      await ref.read(tenantRepositoryProvider).revokeInvite(code);
      ref.invalidate(coachInvitesProvider);
      if (_fresh == code && mounted) setState(() => _fresh = null);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final invites = ref.watch(coachInvitesProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
        children: [
          const GbSheetHeader(
            title: 'Invite a client',
            subtitle:
                'Codes are single-use, expire in 7 days, and always join as a Client.',
          ),
          const SizedBox(height: AppSpacing.gap),
          if (_fresh != null)
            _FreshCodeCard(
                code: _fresh!,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: _fresh!));
                  showInfoSnack(context, 'Code copied');
                })
          else
            GbButton(
              label: 'Generate invite code',
              icon: Icons.confirmation_number_outlined,
              full: true,
              busy: _busy,
              onPressed: _busy ? null : _generate,
            ),
          const SizedBox(height: AppSpacing.lg),
          invites.maybeWhen(
            data: (list) => GbSectionTitle('Active invites',
                count: list.where((i) => i.isActive).length),
            orElse: () => const GbSectionTitle('Active invites'),
          ),
          const SizedBox(height: AppSpacing.xs),
          invites.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: GbSkeleton(height: 62, radius: AppRadius.md),
            ),
            error: (e, _) => Text(
                e is Exception ? '$e' : 'Could not load invites',
                style: TextStyle(color: gb.grey500)),
            data: (list) {
              final active = list.where((i) => i.isActive).toList();
              if (active.isEmpty) {
                return Text('No active invites.',
                    style: TextStyle(color: gb.grey500));
              }
              return Column(
                children: [
                  for (final inv in active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: GbTappableRow(
                        leading: GbIconTile(
                          background: gb.grey0,
                          child: Icon(Icons.confirmation_number_outlined,
                              size: AppSizes.iconXl, color: gb.grey500),
                        ),
                        title: inv.code,
                        subtitle: inv.expiresAt != null
                            ? 'Expires ${inv.expiresAt!.toLocal().toString().split(' ').first}'
                            : null,
                        trailing: GbIconButton(
                          icon: Icons.delete_outline,
                          size: 34,
                          semanticLabel: 'Revoke invite',
                          onTap: () => _revoke(inv.code),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The freshly-minted code card (design primary-tinted call-out with a big tracked code).
class _FreshCodeCard extends StatelessWidget {
  const _FreshCodeCard({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      color: gb.primary0,
      border: AppPalette.primary200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEW INVITE CODE',
              style: AppText.eyebrow
                  .copyWith(color: gb.primary700, letterSpacing: 0.9)),
          const SizedBox(height: AppSpacing.xs),
          Text(code,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: gb.grey900)),
          const SizedBox(height: AppSpacing.sm),
          GbButton(
            label: 'Copy',
            icon: Icons.copy,
            size: GbButtonSize.sm,
            variant: GbButtonVariant.outlined,
            severity: GbButtonSeverity.secondary,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
