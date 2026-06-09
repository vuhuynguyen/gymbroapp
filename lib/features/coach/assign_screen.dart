import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/coach_models.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import '../plan/plan_providers.dart';
import 'coach_providers.dart';

/// Assign a plan to a client — pins the current version, sets frequency + visibility (+ hide flags
/// for Guided). The snapshot is captured per-session at start, so none is sent here.
class AssignScreen extends ConsumerStatefulWidget {
  const AssignScreen({required this.planId, this.presetClientId, super.key});
  final String planId;
  final String? presetClientId;

  @override
  ConsumerState<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends ConsumerState<AssignScreen> {
  String? _clientId;
  int _frequency = 3;
  // Guided is the documented product default (USER_FLOWS §3 / API config).
  PlanVisibilityMode _visibility = PlanVisibilityMode.guided;
  final _flags = {
    'hideSetsReps': false,
    'hideExercises': false,
    'hideFutureWorkouts': false,
    'disableTraineeEditing': false,
  };
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _clientId = widget.presetClientId;
  }

  Future<void> _assign() async {
    if (_clientId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(planRepositoryProvider).createAssignment(
            traineeId: _clientId!,
            planId: widget.planId,
            startDate: DateTime.now(),
            frequencyDaysPerWeek: _frequency,
            visibilityMode: _visibility,
            hideSetsReps: _flags['hideSetsReps']!,
            hideExercises: _flags['hideExercises']!,
            hideFutureWorkouts: _flags['hideFutureWorkouts']!,
            disableTraineeEditing: _flags['disableTraineeEditing']!,
          );
      ref.invalidate(coachClientsProvider);
      ref.invalidate(clientMonitorProvider(_clientId!));
      if (mounted) {
        showInfoSnack(context, 'Plan assigned');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showInfoSnack(
            context, e.isConflict ? 'This client already has this plan assigned.' : e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final plan = ref.watch(planDetailProvider(widget.planId));
    final clients = ref.watch(coachClientsProvider);

    final subtitle = plan.maybeWhen(
      data: (p) => '${p.name} · pins v${p.version}',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: context.gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
      body: Column(
        children: [
          _AssignHeader(subtitle: subtitle, onBack: () => context.pop()),
          Expanded(
            child: clients.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  ErrorRetry(message: '$e', onRetry: () async => ref.invalidate(coachClientsProvider)),
              data: (list) => ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.lg),
                children: [
                  // ── Client picker ──
                  const GbSectionTitle('Client'),
                  const SizedBox(height: AppSpacing.xs),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        'No clients yet — invite a client to your workspace before assigning a plan.',
                        style: AppText.body.copyWith(color: context.gb.grey500),
                      ),
                    )
                  else
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _ClientPick(
                          client: c,
                          selected: _clientId == c.userId,
                          onTap: () => setState(() => _clientId = c.userId),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Schedule ──
                  const GbSectionTitle('Schedule'),
                  const SizedBox(height: AppSpacing.xs),
                  GbCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gap),
                    child: Column(
                      children: [
                        _ScheduleRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Start date',
                          trailing: Text('Today', style: TextStyle(fontSize: 14, color: gb.grey600)),
                        ),
                        Divider(height: 1, color: gb.grey25),
                        _ScheduleRow(
                          icon: Icons.history,
                          label: 'Days per week',
                          trailing: _FrequencyStepper(
                            value: _frequency,
                            onChanged: (v) => setState(() => _frequency = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Visibility ──
                  const GbSectionTitle('Visibility'),
                  const SizedBox(height: AppSpacing.xs),
                  GbSegmented<PlanVisibilityMode>(
                    value: _visibility,
                    onChanged: (v) => setState(() => _visibility = v),
                    options: const [
                      (PlanVisibilityMode.full, 'Full'),
                      (PlanVisibilityMode.guided, 'Guided'),
                      (PlanVisibilityMode.blind, 'Blind'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_visibilityDesc(_visibility),
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: gb.grey500)),

                  // ── Hide flags (Guided only) ──
                  if (_visibility == PlanVisibilityMode.guided) ...[
                    const SizedBox(height: AppSpacing.gap),
                    GbCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _flagTile('hideSetsReps', 'Hide sets & reps',
                              'Trainee logs their own sets, guided live.', divider: true),
                          _flagTile('hideExercises', 'Hide exercises',
                              'Strips names in the plan preview only.', divider: true),
                          _flagTile('hideFutureWorkouts', 'Hide future workouts',
                              'Preview shows only the current week.', divider: true),
                          _flagTile('disableTraineeEditing', 'Lock structure',
                              'Blocks add / skip / substitute in-session.', divider: false),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── Confirm bar ──
          _ConfirmBar(
            child: GbButton(
              label: 'Assign plan',
              icon: Icons.check,
              full: true,
              busy: _busy,
              onPressed: (_clientId == null || _busy) ? null : _assign,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagTile(String key, String title, String subtitle, {required bool divider}) {
    final gb = context.gb;
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: gb.borderCard)))
          : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gap, vertical: AppSpacing.sm + 1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: gb.grey900)),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(fontSize: 12, height: 1.4, color: gb.grey400)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: _flags[key]!,
            onChanged: (v) => setState(() => _flags[key] = v),
          ),
        ],
      ),
    );
  }

  static String _visibilityDesc(PlanVisibilityMode m) => switch (m) {
        PlanVisibilityMode.full => 'Trainee sees the whole plan and prescriptions.',
        PlanVisibilityMode.guided => 'Filtered by the hide flags below — you control what shows.',
        PlanVisibilityMode.blind => 'No snapshot at session start — exercises aren\'t seeded.',
      };
}

/// Detail header with a plan subtitle (design Assign header).
class _AssignHeader extends StatelessWidget {
  const _AssignHeader({required this.subtitle, required this.onBack});
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      decoration: BoxDecoration(
        color: gb.card,
        border: Border(bottom: BorderSide(color: gb.borderCard)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              _CircleBack(onTap: onBack),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Assign plan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: gb.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          style: TextStyle(fontSize: 11.5, color: gb.grey500),
                          overflow: TextOverflow.ellipsis),
                    ],
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

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onTap});
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
            width: 40, height: 40, child: Icon(Icons.chevron_left, size: AppSizes.iconXl, color: gb.grey700)),
      ),
    );
  }
}

/// A radio-style client option card (design Assign client picker).
class _ClientPick extends StatelessWidget {
  const _ClientPick({required this.client, required this.selected, required this.onTap});
  final ClientSummary client;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Material(
      color: selected ? gb.primary0 : gb.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brSm,
        side: BorderSide(color: selected ? gb.primary500 : gb.borderCard, width: AppSizes.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.brSm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm - 1),
          child: Row(
            children: [
              Avatar(initial: client.initial, size: 38),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(client.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: gb.grey900)),
                    const SizedBox(height: 1),
                    Text(client.hasActivePlan ? 'On ${client.planName ?? 'a plan'}' : 'No active plan',
                        style: TextStyle(fontSize: 12, color: gb.grey500)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? gb.primary500 : gb.grey25, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: gb.primary500, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

/// One row inside the schedule card — icon + label + trailing control.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.icon, required this.label, required this.trailing});
  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconLg, color: gb.grey500),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: gb.grey900)),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// Compact +/- frequency stepper (1..7) matching the design mini-step buttons.
class _FrequencyStepper extends StatelessWidget {
  const _FrequencyStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GbIconButton(
            icon: Icons.remove,
            semanticLabel: 'Decrease days per week',
            onTap: () => onChanged(value > 1 ? value - 1 : value)),
        SizedBox(
          width: 32,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: gb.grey900).tabular),
        ),
        GbIconButton(
            icon: Icons.add,
            semanticLabel: 'Increase days per week',
            onTap: () => onChanged(value < 7 ? value + 1 : value)),
      ],
    );
  }
}

/// Bottom action bar (white surface + top hairline) for the primary confirm CTA.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      decoration: BoxDecoration(
        color: gb.card,
        border: Border(top: BorderSide(color: gb.borderCard)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.sm),
          child: child,
        ),
      ),
    );
  }
}
