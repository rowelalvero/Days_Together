import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/mock_supabase_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> secureStorageMock = {};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      final args = methodCall.arguments as Map?;
      final key = args?['key'] as String?;
      
      switch (methodCall.method) {
        case 'write':
          if (key != null) {
            secureStorageMock[key] = args?['value'] as String;
          }
          return null;
        case 'read':
          return secureStorageMock[key];
        case 'delete':
          secureStorageMock.remove(key);
          return null;
        case 'deleteAll':
          secureStorageMock.clear();
          return null;
        case 'containsKey':
          return secureStorageMock.containsKey(key);
        case 'readAll':
          return secureStorageMock;
      }
      return null;
    });

    // Initialize SharedPreferences mock values
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase mock client
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock_anon_key',
      httpClient: MockSupabaseHttpClient(),
    );
  });

  setUp(() {
    secureStorageMock.clear();
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultProvider', () {
    test('initial state does not have PIN and is locked', () async {
      final provider = VaultProvider();
      await Future.delayed(Duration.zero); // allow loadState futures to complete
      expect(provider.hasPin, isFalse);
      expect(provider.isUnlocked, isFalse);
      expect(provider.items, isEmpty);
      expect(provider.allItems, isEmpty);
      expect(provider.isDecoyMode, isFalse);
    });

    test('sets PIN and updates status correctly', () async {
      final provider = VaultProvider();
      await Future.delayed(Duration.zero);
      
      await provider.setPin('4321');
      expect(provider.hasPin, isTrue);
      // When a PIN is first set, it unlocks the vault
      expect(provider.isUnlocked, isTrue);
      expect(secureStorageMock['vault_pin'], '4321');
    });

    test('verifies correct PIN and rejects incorrect PIN, increments wrong attempts', () async {
      final provider = VaultProvider();
      await Future.delayed(Duration.zero);

      await provider.setPin('5555');
      provider.lock();
      expect(provider.isUnlocked, isFalse);

      // Verify correct PIN
      final resultCorrect = await provider.verifyPin('5555');
      expect(resultCorrect, isTrue);
      expect(provider.isUnlocked, isTrue);

      // Lock again
      provider.lock();
      expect(provider.isUnlocked, isFalse);

      // Verify incorrect PIN
      final resultIncorrect = await provider.verifyPin('1111');
      expect(resultIncorrect, isFalse);
      expect(provider.isUnlocked, isFalse);
    });

    test('activates decoy mode after 3 wrong attempts and allows reset', () async {
      final provider = VaultProvider();
      await Future.delayed(Duration.zero);

      await provider.setPin('9999');
      provider.lock();

      // Attempt 1
      await provider.verifyPin('0001');
      expect(provider.isDecoyMode, isFalse);

      // Attempt 2
      await provider.verifyPin('0002');
      expect(provider.isDecoyMode, isFalse);

      // Attempt 3 -> activates decoy mode
      await provider.verifyPin('0003');
      expect(provider.isDecoyMode, isTrue);

      // Reset decoy attempts
      provider.resetDecoy();
      expect(provider.isDecoyMode, isFalse);
    });
  });
}
