import 'package:days_together/services/couple_service.dart';

/// A controllable substitute for [CoupleService], injected into
/// [CoupleSession]'s constructor (ADR-010's exception: "singletons convert
/// to providers only when a specific test needs a fake"). Implements the
/// interface directly rather than extending [CoupleService], since that
/// class's constructor is private (`CoupleService._()`) and cannot be
/// invoked from outside its own library.
///
/// Each method either returns [response] (or the value configured via the
/// per-method fields below when set) or throws [errorToThrow] when set, so a
/// test can script both the success and failure branch of whatever call it
/// is exercising without touching Supabase.
class FakeCoupleService implements CoupleService {
  Map<String, dynamic>? createWorkspaceResponse;
  Object? createWorkspaceError;
  int createWorkspaceCallCount = 0;

  Map<String, dynamic>? joinWithCodeResponse;
  Object? joinWithCodeError;
  int joinWithCodeCallCount = 0;
  String? lastJoinCode;

  Map<String, dynamic>? getOrRotatePairingCodeResponse;
  Map<String, dynamic>? recoverWithCodeResponse;
  Map<String, dynamic>? regenerateRecoveryCodeResponse;

  String? lastCreateWorkspacePublicKey;
  String? lastJoinPublicKey;
  String? lastRecoverPublicKey;

  @override
  Future<Map<String, dynamic>> createRelationshipWorkspace({String? publicKey}) async {
    createWorkspaceCallCount++;
    lastCreateWorkspacePublicKey = publicKey;
    if (createWorkspaceError != null) throw createWorkspaceError!;
    return createWorkspaceResponse ??
        {
          'couple_id': 'fake-couple-id',
          'pairing_code': 'FAKE01',
          'recovery_code': 'FAKE-RECOVERY',
        };
  }

  @override
  Future<Map<String, dynamic>> getOrRotatePairingCode({bool forceRotate = false}) async {
    return getOrRotatePairingCodeResponse ?? {'success': true, 'pairing_code': 'FAKE01'};
  }

  @override
  Future<Map<String, dynamic>> joinWithCode(String code, {String? publicKey}) async {
    joinWithCodeCallCount++;
    lastJoinCode = code;
    lastJoinPublicKey = publicKey;
    if (joinWithCodeError != null) throw joinWithCodeError!;
    return joinWithCodeResponse ?? {'success': false, 'error': 'not configured'};
  }

  @override
  Future<Map<String, dynamic>> recoverWithCode(String code, {String? publicKey}) async {
    lastRecoverPublicKey = publicKey;
    return recoverWithCodeResponse ?? {'success': false, 'error': 'not configured'};
  }

  @override
  Future<Map<String, dynamic>> regenerateRecoveryCode() async {
    return regenerateRecoveryCodeResponse ?? {'success': false, 'error': 'not configured'};
  }

  @override
  Future<void> disconnectRelationshipWorkspace() async {}
}
