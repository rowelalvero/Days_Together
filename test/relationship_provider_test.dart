import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/providers/relationship_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RelationshipProvider', () {
    test('initializes default values correctly and disposes without errors', () async {
      final provider = RelationshipProvider();
      
      expect(provider.isPaired, false);
      expect(provider.isPremium, false);
      expect(provider.yourName, isNull);
      expect(provider.partnerName, isNull);
      
      // Wait for local data load futures to complete
      await Future.delayed(Duration.zero);
      
      // Call dispose and check if it runs without exceptions
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
