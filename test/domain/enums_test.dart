import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/domain/enums.dart';

void main() {
  group('tolerant enum parsing (camelCase out, case/int in)', () {
    test('SessionStatus accepts camelCase, PascalCase and int', () {
      expect(SessionStatus.parse('inProgress'), SessionStatus.inProgress);
      expect(SessionStatus.parse('InProgress'), SessionStatus.inProgress);
      expect(SessionStatus.parse('in_progress'), SessionStatus.inProgress);
      expect(SessionStatus.parse(1), SessionStatus.inProgress);
      expect(SessionStatus.parse('completed'), SessionStatus.completed);
      expect(SessionStatus.parse(3), SessionStatus.abandoned);
    });

    test('SessionStatus falls back when unknown/null', () {
      expect(SessionStatus.parse(null), SessionStatus.completed);
      expect(SessionStatus.parse('???', fallback: SessionStatus.inProgress), SessionStatus.inProgress);
    });

    test('SessionSource wire form is camelCase', () {
      expect(SessionSource.fromAssignment.wire, 'fromAssignment');
      expect(SessionSource.adhoc.wire, 'adhoc');
      expect(SessionSource.parse('FromAssignment'), SessionSource.fromAssignment);
    });

    test('PerformedSetType handles PascalCase snapshot setType', () {
      // The session snapshot serializes setType via .ToString() → PascalCase.
      expect(PerformedSetType.parse('Working'), PerformedSetType.working);
      expect(PerformedSetType.parse('amrap'), PerformedSetType.amrap);
      expect(PerformedSetType.working.wire, 'working');
    });

    test('PlanVisibilityMode maps int and string', () {
      expect(PlanVisibilityMode.parse('full'), PlanVisibilityMode.full);
      expect(PlanVisibilityMode.parse('Full'), PlanVisibilityMode.full);
      expect(PlanVisibilityMode.parse(2), PlanVisibilityMode.guided);
      expect(PlanVisibilityMode.parse(3), PlanVisibilityMode.blind);
      expect(PlanVisibilityMode.parse(null), PlanVisibilityMode.guided);
    });

    test('TenantRole tolerant of "Owner"/"Client" strings', () {
      expect(TenantRole.parse('Owner'), TenantRole.owner);
      expect(TenantRole.parse('client'), TenantRole.client);
      expect(TenantRole.parse(1), TenantRole.owner);
      expect(TenantRole.parse('nope'), isNull);
    });

    test('ExerciseUpdateAction wire is camelCase', () {
      expect(ExerciseUpdateAction.skip.wire, 'skip');
      expect(ExerciseUpdateAction.substitute.wire, 'substitute');
    });
  });
}
