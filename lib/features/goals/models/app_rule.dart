import 'free_window.dart';
import 'goal_type.dart';

/// The gating rule for a single installed app: which goal has to be met
/// to unlock it, and the recurring windows in which the gate is simply
/// switched off (weekends, after 4pm, etc).
class AppRule {
  final String id;
  final String appId; // Android package name / iOS bundle id
  final String appDisplayName;
  final bool enabled;
  final GoalType goalType;
  final int targetValue;
  final List<FreeWindow> freeWindows;
  final int weeklyBypassAllowance;

  const AppRule({
    required this.id,
    required this.appId,
    required this.appDisplayName,
    required this.goalType,
    required this.targetValue,
    this.enabled = true,
    this.freeWindows = const [],
    this.weeklyBypassAllowance = 0,
  });

  /// True if, purely based on the schedule (ignoring goal progress), this
  /// app should be left unlocked right now.
  bool isInFreeWindow(DateTime now) =>
      freeWindows.any((w) => w.coversNow(now));

  AppRule copyWith({
    bool? enabled,
    int? targetValue,
    List<FreeWindow>? freeWindows,
    int? weeklyBypassAllowance,
  }) =>
      AppRule(
        id: id,
        appId: appId,
        appDisplayName: appDisplayName,
        goalType: goalType,
        targetValue: targetValue ?? this.targetValue,
        enabled: enabled ?? this.enabled,
        freeWindows: freeWindows ?? this.freeWindows,
        weeklyBypassAllowance: weeklyBypassAllowance ?? this.weeklyBypassAllowance,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'appId': appId,
        'appDisplayName': appDisplayName,
        'enabled': enabled,
        'goalType': goalType.name,
        'targetValue': targetValue,
        'freeWindows': freeWindows.map((w) => w.toJson()).toList(),
        'weeklyBypassAllowance': weeklyBypassAllowance,
      };

  factory AppRule.fromJson(Map<String, dynamic> json) => AppRule(
        id: json['id'] as String,
        appId: json['appId'] as String,
        appDisplayName: json['appDisplayName'] as String,
        enabled: json['enabled'] as bool? ?? true,
        goalType: GoalType.values.byName(json['goalType'] as String),
        targetValue: json['targetValue'] as int,
        freeWindows: (json['freeWindows'] as List? ?? [])
            .map((w) => FreeWindow.fromJson(w as Map<String, dynamic>))
            .toList(),
        weeklyBypassAllowance: json['weeklyBypassAllowance'] as int? ?? 0,
      );
}
