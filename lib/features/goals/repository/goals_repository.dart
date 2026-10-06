import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_rule.dart';

/// Syncs the user's app rules to Firestore under users/{uid}/appRules.
/// The native blocking module reads its own on-device cache (kept fresh by
/// [GoalsRepository.watchRules]) rather than hitting Firestore directly, so
/// blocking decisions never depend on network availability.
class GoalsRepository {
  final FirebaseFirestore _firestore;
  final String uid;

  GoalsRepository({required this.uid, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rules =>
      _firestore.collection('users').doc(uid).collection('appRules');

  Stream<List<AppRule>> watchRules() =>
      _rules.snapshots().map((snap) => snap.docs.map((d) => AppRule.fromJson(d.data())).toList());

  Future<void> upsertRule(AppRule rule) => _rules.doc(rule.id).set(rule.toJson());

  Future<void> deleteRule(String ruleId) => _rules.doc(ruleId).delete();
}
