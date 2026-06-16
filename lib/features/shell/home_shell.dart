import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import '../log/log_screen.dart' show showStartWorkoutSheet;
import '../progress/progress_providers.dart';
import '../tenant/tenant_controller.dart';

/// Role-adaptive bottom-tab shell (design / strategy-doc navigation):
///  - Trainee (Client): Log · Plan · [Start] · Progress · Profile
///  - Coach (Owner):    Coach · Log · [Start] · Progress · Profile
/// The Coach tab is a single hub folding the client roster and plan library together; an Owner self-
/// trains via Log (they have WorkoutLogCreate) and tracks their own trends via Progress. Same
/// StatefulShellRoute; the visible destinations map to the role's branches. "Start Workout" is the
/// centre nav item — a filled rounded-rectangle button (in-row, not a raised FAB).
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  // Fixed branch order in the router.
  static const _log = 0, _plan = 1, _progress = 2, _coach = 3, _profile = 4;

  static const _traineeDestinations = [
    (_log, Icons.history_outlined, Icons.history, 'Log'),
    (_plan, Icons.calendar_today_outlined, Icons.calendar_today, 'Plan'),
    (_progress, Icons.bar_chart_outlined, Icons.bar_chart, 'Progress'),
    (_profile, Icons.person_outline, Icons.person, 'Profile'),
  ];
  static const _coachDestinations = [
    (_coach, Icons.group_outlined, Icons.group, 'Coach'),
    (_log, Icons.history_outlined, Icons.history, 'Log'),
    (_progress, Icons.bar_chart_outlined, Icons.bar_chart, 'Progress'),
    (_profile, Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(
        tenantControllerProvider.select((s) => s.valueOrNull?.active?.role));
    final destinations =
        role == TenantRole.owner ? _coachDestinations : _traineeDestinations;
    final branchIndices = destinations.map((d) => d.$1).toList();

    var selected = branchIndices.indexOf(shell.currentIndex);
    if (selected < 0) selected = 0;

    return Scaffold(
      body: shell,
      bottomNavigationBar: _BottomNav(
        destinations: destinations,
        selected: selected,
        onSelect: (i) {
          final branch = branchIndices[i];
          // Progress is kept alive by the shell, so its autoDispose providers don't refetch on their
          // own — refresh them each time the tab is entered (or re-tapped). skipLoadingOnRefresh keeps
          // the current content on screen while the new data loads, so there's no skeleton flash.
          if (branch == _progress) {
            ref.invalidate(progressOverviewProvider);
            ref.invalidate(strengthLiftsProvider);
            ref.invalidate(bodyweightSeriesProvider);
            ref.invalidate(sleepSeriesProvider);
            ref.invalidate(nutritionAdherenceProvider);
          }
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        onStart: () => showStartWorkoutSheet(context, ref),
      ),
    );
  }
}

// Shared height for every nav item's "icon" slot, so tab icons and the (square) Start button align
// and all the labels sit on one line.
const double _kIconSlot = 36;

/// Custom bottom navigation — icon + label tabs (active = primary colour, no pill) with a filled
/// rounded-rectangle "Start" button sitting in the middle of the row.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onStart,
  });

  final List<(int, IconData, IconData, String)> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final mid = destinations.length ~/ 2; // where the Start button sits
    return Material(
      color: gb.card,
      child: Container(
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: gb.borderCard))),
        child: SafeArea(
          top: false,
          child: Padding(
            // Breathing room between the top hairline and the icons (they were sitting too close).
            padding: const EdgeInsets.only(top: 5),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i == mid) Expanded(child: _StartButton(onTap: onStart)),
                    Expanded(
                      child: _NavItem(
                        icon: destinations[i].$2,
                        selectedIcon: destinations[i].$3,
                        label: destinations[i].$4,
                        selected: i == selected,
                        onTap: () => onSelect(i),
                      ),
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

/// Centre "Start" action — a filled rounded-rectangle (bright blue gradient), in-row with the tabs.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Semantics(
      button: true,
      label: 'Start Workout',
      // No Material ink at all → no grey press background (the active colour is the feedback, iOS
      // style). HitTestBehavior.opaque keeps the whole slot tappable.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _kIconSlot,
              height: _kIconSlot,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gb.primary500, gb.primary700],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.add, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 3),
            Text('Start',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: gb.primary600)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Active = just the primary colour on the icon + bold label (no pill background).
    final color = selected ? gb.primary600 : gb.grey400;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      // No Material ink at all → no grey press background (the active colour is the feedback, iOS
      // style). HitTestBehavior.opaque keeps the whole slot tappable.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _kIconSlot,
              child: Center(
                  child: Icon(selected ? selectedIcon : icon,
                      size: 24, color: color)),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? gb.primary600 : gb.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
