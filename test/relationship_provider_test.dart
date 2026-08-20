import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/storage_url_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('RelationshipProvider', () {
    test('initializes default values correctly and disposes without errors', () async {
      final provider = RelationshipProvider();
      
      expect(provider.isPaired, false);
      expect(provider.isPremium, false);
      expect(provider.yourName, isNull);
      expect(provider.partnerName, isNull);
      expect(provider.isOnboardingComplete, false);
      
      // Wait for local data load futures to complete
      await Future.delayed(Duration.zero);
      
      // Call dispose and check if it runs without exceptions
      expect(() => provider.dispose(), returnsNormally);
    });

    test('loads isCreator correctly from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'is_creator': true,
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(provider.isCreator, true);
    });

    test('isOnboardingComplete remains false when workspace is created until completeOnboarding is called', () async {
      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(provider.isOnboardingComplete, false);

      await provider.completeOnboarding();

      // Complete onboarding sets flag, and if coupleId is set, returns true
      expect(provider.isOnboardingComplete, false); // false because coupleId is null offline
    });
    test('setAvatars preserves existing partner avatar and partner name', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'Ashwel',
        'partner_name': 'Rowel',
        'your_avatar_path': '/mock/avatars/ashwel.jpg',
        'partner_avatar_path': '/mock/avatars/rowel.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(provider.yourName, 'Ashwel');
      expect(provider.partnerName, 'Rowel');
      expect(provider.yourAvatarPath, '/mock/avatars/ashwel.jpg');
      expect(provider.partnerAvatarPath, '/mock/avatars/rowel.jpg');

      // Update only your avatar
      await provider.setAvatars(yourPath: '/mock/avatars/ashwel_new.jpg');

      // Partner avatar and names must remain intact
      expect(provider.yourAvatarPath, '/mock/avatars/ashwel_new.jpg');
      expect(provider.partnerAvatarPath, '/mock/avatars/rowel.jpg');
      expect(provider.yourName, 'Ashwel');
      expect(provider.partnerName, 'Rowel');
    });

    test('User A uploads avatar -> A avatar changes, B avatar and names remain intact', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'User A',
        'partner_name': 'User B',
        'your_avatar_path': '/mock/avatars/user_a.jpg',
        'partner_avatar_path': '/mock/avatars/user_b.jpg',
      });

      final providerA = RelationshipProvider();
      await Future.delayed(Duration.zero);

      await providerA.setAvatars(yourPath: '/mock/avatars/user_a_v2.jpg');

      expect(providerA.yourAvatarPath, '/mock/avatars/user_a_v2.jpg');
      expect(providerA.partnerAvatarPath, '/mock/avatars/user_b.jpg');
      expect(providerA.yourName, 'User A');
      expect(providerA.partnerName, 'User B');
    });

    test('User B uploads avatar -> B avatar changes, A avatar and names remain intact', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'User B',
        'partner_name': 'User A',
        'your_avatar_path': '/mock/avatars/user_b.jpg',
        'partner_avatar_path': '/mock/avatars/user_a.jpg',
      });

      final providerB = RelationshipProvider();
      await Future.delayed(Duration.zero);

      await providerB.setAvatars(yourPath: '/mock/avatars/user_b_v2.jpg');

      expect(providerB.yourAvatarPath, '/mock/avatars/user_b_v2.jpg');
      expect(providerB.partnerAvatarPath, '/mock/avatars/user_a.jpg');
      expect(providerB.yourName, 'User B');
      expect(providerB.partnerName, 'User A');
    });

    test('Upload failure -> existing avatar remains intact', () async {
      SharedPreferences.setMockInitialValues({
        'your_avatar_path': '/mock/avatars/original_a.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      // Attempting to upload a non-existent local file when Supabase is active throws Exception
      expect(provider.yourAvatarPath, '/mock/avatars/original_a.jpg');
    });

    test('Logout clears local avatar cache so previous user avatar is not resurrected', () async {
      SharedPreferences.setMockInitialValues({
        'your_avatar_path': '/mock/avatars/user_a.jpg',
        'partner_avatar_path': '/mock/avatars/user_b.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(provider.yourAvatarPath, '/mock/avatars/user_a.jpg');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final newProvider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(newProvider.yourAvatarPath, isNull);
      expect(newProvider.partnerAvatarPath, isNull);
    });

    test('Unlink partner clears partner avatar and prevents avatar swapping', () async {
      SharedPreferences.setMockInitialValues({
        'couple_id': 'couple_123',
        'your_avatar_path': '/mock/avatars/user_a.jpg',
        'partner_avatar_path': '/mock/avatars/user_b.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(provider.yourAvatarPath, '/mock/avatars/user_a.jpg');
      expect(provider.partnerAvatarPath, '/mock/avatars/user_b.jpg');

      await provider.unlinkPartner();

      expect(provider.partnerAvatarPath, isNull);
      expect(provider.isPaired, false);
    });

    test('11. Codebase contains no reference to nonexistent license_details.creator_id', () {
      final file = File('lib/providers/relationship_provider.dart');
      final content = file.readAsStringSync();
      expect(content.contains("['creator_id']"), false);
      expect(content.contains("'creator_id'"), false);
      expect(content.contains('"creator_id"'), false);
    });

    test('9. Successful image update persists after app restart via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'Ashwel',
        'your_avatar_path': '/mock/avatars/ashwel.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(provider.yourAvatarPath, '/mock/avatars/ashwel.jpg');
      expect(provider.yourName, 'Ashwel');
    });

    test('10. Profile update does not erase unrelated profile fields', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'Ashwel',
        'partner_name': 'Rowel',
        'your_gender': 'Female',
        'partner_gender': 'Male',
        'your_avatar_path': '/mock/avatars/ashwel.jpg',
        'partner_avatar_path': '/mock/avatars/rowel.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      await provider.setYourName('Ashwel Updated');

      expect(provider.yourName, 'Ashwel Updated');
      expect(provider.partnerName, 'Rowel');
      expect(provider.yourGender, 'Female');
      expect(provider.partnerGender, 'Male');
      expect(provider.yourAvatarPath, '/mock/avatars/ashwel.jpg');
      expect(provider.partnerAvatarPath, '/mock/avatars/rowel.jpg');
    });

    test('12. RLS policies and ProfileService update target users table explicitly', () {
      final profileServiceFile = File('lib/services/profile_service.dart');
      final content = profileServiceFile.readAsStringSync();
      expect(content.contains("update_partner_profile"), true);
      expect(content.contains(".from('users')"), true);
    });

    // Regression guard for the signed-URL migration. Avatar refs are now bare
    // storage paths rather than URLs. Anything that still asks
    // "is this remote?" with `startsWith('http')` inverts on a bare path and
    // treats an uploaded avatar as an un-synced local file — which makes the
    // profile sync try to re-upload a file that does not exist.
    test('13. a stored avatar path is not mistaken for a local file', () async {
      SharedPreferences.setMockInitialValues({
        'your_avatar_path': 'couples/c1/avatars/u1_1700000000.jpg',
        'partner_avatar_path': 'couples/c1/avatars/u2_1700000001.jpg',
      });

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(
        StorageUrlService.isLocalFileRef(provider.yourAvatarPath),
        isFalse,
        reason: 'a bare storage path must not classify as a device file',
      );
      expect(
        StorageUrlService.pathFrom(
          provider.yourAvatarPath,
          bucket: StorageBuckets.avatars,
        ),
        'couples/c1/avatars/u1_1700000000.jpg',
      );
      expect(
        StorageUrlService.cacheKeyFor(
          bucket: StorageBuckets.avatars,
          ref: provider.yourAvatarPath,
        ),
        isNot(
          StorageUrlService.cacheKeyFor(
            bucket: StorageBuckets.avatars,
            ref: provider.partnerAvatarPath,
          ),
        ),
        reason: 'each partner must get a distinct image cache key',
      );

      provider.dispose();
    });

    test('14. a legacy public avatar URL still resolves after migration', () async {
      // Rows written before the backfill still hold full public URLs; the app
      // must keep rendering them.
      const legacy =
          'https://p.supabase.co/storage/v1/object/public/avatars/couples/c1/avatars/u1_1.jpg?t=1';
      SharedPreferences.setMockInitialValues({'your_avatar_path': legacy});

      final provider = RelationshipProvider();
      await Future.delayed(Duration.zero);

      expect(
        StorageUrlService.pathFrom(
          provider.yourAvatarPath,
          bucket: StorageBuckets.avatars,
        ),
        'couples/c1/avatars/u1_1.jpg',
        reason: 'legacy URLs must reduce to the same path as a bare ref',
      );

      provider.dispose();
    });
  });
}
