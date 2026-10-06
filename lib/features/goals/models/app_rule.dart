import 'free_window.dart';

/// The gating rule for a single installed app. It combines up to two
/// conditions, and the app is open only while every condition that's set
/// holds:
///  - [stepGoal]: locked until today's steps reach it;
///  - [dailyLimitMinutes]: locked for the rest of the day once the app has
///    been used this long today.
/// [freeWindows] are recurring times (weekends, after 4pm, ...) when the rule
/// is switched off entirely.
class AppRule {
  final String id;
  final String appId; // Android package name / iOS bundle id
  final String appDisplayName;
  final bool enabled;
  final int? stepGoal;
  final int? dailyLimitMinutes;
  final List<FreeWindow> freeWindows;
  final int weeklyBypassAllowance;

  const AppRule({
    required this.id,
    required this.appId,
    required this.appDisplayName,
    this.stepGoal,
    this.dailyLimitMinutes,
    this.enabled = true,
    this.freeWindows = const [],
    this.weeklyBypassAllowance = 0,
  }) : assert(
         stepGoal != null || dailyLimitMinutes != null,
         'A rule needs a step goal, a daily limit, or both',
       );

  /// True if, purely based on the schedule (ignoring goal progress), this
  /// app should be left unlocked right now.
  bool isInFreeWindow(DateTime now) => freeWindows.any((w) => w.coversNow(now));

  Map<String, dynamic> toJson() => {
    'id': id,
    'appId': appId,
    'appDisplayName': appDisplayName,
    'enabled': enabled,
    'stepGoal': stepGoal,
    'dailyLimitMinutes': dailyLimitMinutes,
    'freeWindows': freeWindows.map((w) => w.toJson()).toList(),
    'weeklyBypassAllowance': weeklyBypassAllowance,
  };

  factory AppRule.fromJson(Map<String, dynamic> json) {
    var stepGoal = json['stepGoal'] as int?;
    final dailyLimitMinutes = json['dailyLimitMinutes'] as int?;
    // Rules saved before time limits existed: {goalType: 'steps', targetValue: N}.
    if (stepGoal == null && dailyLimitMinutes == null) {
      stepGoal = json['targetValue'] as int? ?? 10000;
    }
    return AppRule(
      id: json['id'] as String,
      appId: json['appId'] as String,
      appDisplayName: json['appDisplayName'] as String,
      enabled: json['enabled'] as bool? ?? true,
      stepGoal: stepGoal,
      dailyLimitMinutes: dailyLimitMinutes,
      freeWindows: (json['freeWindows'] as List? ?? [])
          .map((w) => FreeWindow.fromJson(w as Map<String, dynamic>))
          .toList(),
      weeklyBypassAllowance: json['weeklyBypassAllowance'] as int? ?? 0,
    );
  }
}
