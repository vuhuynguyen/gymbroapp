/// Domain enums mirroring the GymBro API.
///
/// Wire-format facts (see memory `gymbro-api-enum-wire-format`):
///  * Responses serialize enums as **camelCase strings** (`inProgress`, `working`, `full`…)
///    EXCEPT `SessionSnapshotSetDto.setType`, which the server builds with `.ToString()` →
///    PascalCase (`Working`). The tenant `role` is a plain string (`Owner`/`Client`).
///  * Request bodies accept camelCase, PascalCase, or integer values (System.Text.Json read
///    is case-insensitive + `allowIntegerValues`).
///
// Therefore: parsing is tolerant (string-any-case OR int); serialization emits canonical camelCase
// via WireEnum.wire. Integer values are load-bearing (they are the persisted DB values) and must
// not be renumbered.
abstract interface class WireEnum {
  String get wire;
  int get value;
}

/// Tolerant parse: accepts the camelCase wire form, the PascalCase member name, or the int.
/// Returns null when nothing matches (callers supply their own fallback).
T? parseWire<T extends WireEnum>(List<T> values, Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    final i = raw.toInt();
    for (final v in values) {
      if (v.value == i) return v;
    }
    return null;
  }
  final s = raw.toString().toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
  for (final v in values) {
    if (v.wire.toLowerCase() == s) return v;
    if ((v as Enum).name.toLowerCase() == s) return v;
    if (v.value.toString() == s) return v;
  }
  return null;
}

enum SessionStatus implements WireEnum {
  inProgress('inProgress', 1),
  completed('completed', 2),
  abandoned('abandoned', 3);

  const SessionStatus(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static SessionStatus parse(Object? raw, {SessionStatus fallback = SessionStatus.completed}) =>
      parseWire(values, raw) ?? fallback;

  bool get isInProgress => this == SessionStatus.inProgress;
  bool get isTerminal => this != SessionStatus.inProgress;
}

enum SessionSource implements WireEnum {
  fromAssignment('fromAssignment', 1),
  adhoc('adhoc', 2);

  const SessionSource(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static SessionSource parse(Object? raw, {SessionSource fallback = SessionSource.adhoc}) =>
      parseWire(values, raw) ?? fallback;
}

enum PerformedSetType implements WireEnum {
  warmup('warmup', 1),
  working('working', 2),
  drop('drop', 3),
  amrap('amrap', 4),
  failure('failure', 5);

  const PerformedSetType(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static PerformedSetType parse(Object? raw,
          {PerformedSetType fallback = PerformedSetType.working}) =>
      parseWire(values, raw) ?? fallback;

  String get label => switch (this) {
        PerformedSetType.warmup => 'Warmup',
        PerformedSetType.working => 'Working',
        PerformedSetType.drop => 'Drop',
        PerformedSetType.amrap => 'AMRAP',
        PerformedSetType.failure => 'Failure',
      };
}

enum ExercisePerformStatus implements WireEnum {
  inProgress('inProgress', 1),
  completed('completed', 2),
  skipped('skipped', 3),
  substituted('substituted', 4);

  const ExercisePerformStatus(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static ExercisePerformStatus parse(Object? raw,
          {ExercisePerformStatus fallback = ExercisePerformStatus.inProgress}) =>
      parseWire(values, raw) ?? fallback;
}

/// `PUT /sessions/{id}/exercises/{exerciseId}` action. The API enum is `{ Skip, Substitute }`
/// (Skip=0, Substitute=1); the portal does not call this endpoint yet, but the API supports it
/// and BUSINESS_RULES require skip/substitute, so the mobile client uses it.
enum ExerciseUpdateAction implements WireEnum {
  skip('skip', 0),
  substitute('substitute', 1);

  const ExerciseUpdateAction(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;
}

enum PlanVisibilityMode implements WireEnum {
  full('full', 1),
  guided('guided', 2),
  blind('blind', 3);

  const PlanVisibilityMode(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static PlanVisibilityMode parse(Object? raw,
          {PlanVisibilityMode fallback = PlanVisibilityMode.guided}) =>
      parseWire(values, raw) ?? fallback;

  String get label => switch (this) {
        PlanVisibilityMode.full => 'Full',
        PlanVisibilityMode.guided => 'Guided',
        PlanVisibilityMode.blind => 'Blind',
      };
}

enum PlanSetType implements WireEnum {
  warmup('warmup', 1),
  working('working', 2),
  drop('drop', 3),
  amrap('amrap', 4);

  const PlanSetType(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static PlanSetType parse(Object? raw, {PlanSetType fallback = PlanSetType.working}) =>
      parseWire(values, raw) ?? fallback;
}

enum TenantRole implements WireEnum {
  owner('owner', 1),
  client('client', 2);

  const TenantRole(this.wire, this.value);
  @override
  final String wire;
  @override
  final int value;

  static TenantRole? parse(Object? raw) => parseWire(values, raw);

  String get label => this == TenantRole.owner ? 'Owner' : 'Client';
}
