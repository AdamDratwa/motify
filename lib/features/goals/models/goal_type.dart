/// The kind of goal that must be met to unlock a gated app.
/// Steps is the only type wired up for the MVP; the enum exists so new
/// goal types (screen-time budget, custom checklist, ...) can be added
/// later without changing the AppRule shape.
enum GoalType { steps }

extension GoalTypeLabel on GoalType {
  String get label => switch (this) {
        GoalType.steps => 'Steps',
      };

  String unitLabel(int target) => switch (this) {
        GoalType.steps => 'steps',
      };
}
