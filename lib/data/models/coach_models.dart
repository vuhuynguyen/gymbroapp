import '../../domain/enums.dart';
import 'plan_models.dart';
import 'session_models.dart';

/// A coach's client row: the member joined with their active assignment (plan name + visibility).
class ClientSummary {
  const ClientSummary({
    required this.userId,
    required this.name,
    this.activeAssignmentId,
    this.planName,
    this.visibility,
    this.frequency,
  });

  final String userId;
  final String name;
  final String? activeAssignmentId;
  final String? planName;
  final PlanVisibilityMode? visibility;
  final int? frequency;

  bool get hasActivePlan => activeAssignmentId != null;
  String get initial => name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
}

/// Everything the Client Monitor screen needs for one trainee.
class ClientMonitorData {
  const ClientMonitorData({required this.assignments, required this.sessions});

  final List<AssignedPlan> assignments;
  final List<SessionSummary> sessions;
}
