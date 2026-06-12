import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import '../tenant/tenant_controller.dart';
import 'clients_screen.dart';
import 'coach_plans_screen.dart';

/// The Coach tab — one hub folding the client roster and plan library together (the brief's
/// "whole coaching workspace in one tab"). A shared [GbAppHeader] ("Coach" + the workspace name),
/// a two-segment control (Clients | Plans), and an Invite action shown only on the Clients segment.
///
/// The two segments render the EXISTING [CoachClientsScreen] / [CoachPlansScreen] bodies in their
/// `embedded` form (header/Scaffold dropped) — no duplicated list logic. Plans stays VIEW + ASSIGN
/// only; authoring is portal-first.
class CoachHubScreen extends ConsumerStatefulWidget {
  const CoachHubScreen({super.key});

  @override
  ConsumerState<CoachHubScreen> createState() => _CoachHubScreenState();
}

enum _CoachSegment { clients, plans }

class _CoachHubScreenState extends ConsumerState<CoachHubScreen> {
  _CoachSegment _segment = _CoachSegment.clients;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(
        tenantControllerProvider.select((s) => s.valueOrNull?.active?.name));
    final onClients = _segment == _CoachSegment.clients;

    return Scaffold(
      backgroundColor: context.gb.grey0,
      body: Column(
        children: [
          GbAppHeader(
            title: 'Coach',
            subtitle: workspace,
            actions: [
              // Invite belongs to the roster — hide it on the Plans segment.
              if (onClients)
                GbButton(
                  label: 'Invite',
                  icon: Icons.person_add_alt,
                  size: GbButtonSize.sm,
                  onPressed: () => showCoachInviteSheet(context),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                AppSpacing.sm, AppSpacing.screenH, AppSpacing.xs),
            child: GbSegmented<_CoachSegment>(
              value: _segment,
              options: const [
                (_CoachSegment.clients, 'Clients'),
                (_CoachSegment.plans, 'Plans'),
              ],
              onChanged: (s) => setState(() => _segment = s),
            ),
          ),
          Expanded(
            child: onClients
                ? const CoachClientsScreen(embedded: true)
                : const CoachPlansScreen(embedded: true),
          ),
        ],
      ),
    );
  }
}
