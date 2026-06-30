import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:http/http.dart' as http;
import 'helpers/mock_supabase_http_client.dart';

class FakeRelationshipProvider extends Fake implements RelationshipProvider {
  @override
  String get coupleId => 'test_couple_id';

  @override
  String get userId => 'test_user_id';

  @override
  bool get isFirebaseAvailable => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseHttpClient mockHttpClient;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    mockHttpClient = MockSupabaseHttpClient();
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock_anon_key',
      httpClient: mockHttpClient,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NoteitSyncManager.instance.mockConnectionChecker = null;
    NoteitSyncManager.instance.cancel();
  });

  Future<void> waitForSync() async {
    await Future.delayed(const Duration(milliseconds: 15));
    while (NoteitSyncManager.instance.isSyncing) {
      await Future.delayed(const Duration(milliseconds: 15));
    }
  }

  group('NoteitSyncManager & Offline Sync', () {
    test('enqueues a task and updates sync status to sending', () async {
      final relationship = FakeRelationshipProvider();
      final noteitProvider = NoteitProvider();
      noteitProvider.updateRelationship(relationship);

      // Set mock connection checker to online
      NoteitSyncManager.instance.mockConnectionChecker = () => true;

      // Mock database response for love_notes upsert
      mockHttpClient.handler = (req) {
        if (req.url.path.contains('/rest/v1/love_notes')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 404);
      };

      final task = NoteitSyncTask(
        id: 'task_uuid_1',
        type: NoteitType.text,
        content: 'Sweet offline message',
        createdAt: DateTime.now(),
      );

      await NoteitSyncManager.instance.enqueue(task);
      await waitForSync();

      // Verify the task exists in the manager's pending queue or completed
      // Since it is online, triggerSync should process it and remove it from queue
      expect(NoteitSyncManager.instance.hasPendingItems, isFalse);
    });

    test('retains task in queue when connection is offline', () async {
      final relationship = FakeRelationshipProvider();
      final noteitProvider = NoteitProvider();
      noteitProvider.updateRelationship(relationship);

      // Set mock connection checker to offline
      NoteitSyncManager.instance.mockConnectionChecker = () => false;

      final task = NoteitSyncTask(
        id: 'task_uuid_2',
        type: NoteitType.text,
        content: 'This stays offline',
        createdAt: DateTime.now(),
      );

      await NoteitSyncManager.instance.enqueue(task);
      await waitForSync();

      // Queue should still have it since offline
      expect(NoteitSyncManager.instance.hasPendingItems, isTrue);
      expect(NoteitSyncManager.instance.queue.first.id, 'task_uuid_2');

      // Verify SharedPreferences persistent queue save
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('noteit_sync_queue');
      expect(jsonString, isNotNull);
      final list = jsonDecode(jsonString!) as List;
      expect(list.length, 1);
      expect(list[0]['id'], 'task_uuid_2');
    });

    test('recovers and flushes queue when coming back online', () async {
      final relationship = FakeRelationshipProvider();
      final noteitProvider = NoteitProvider();
      noteitProvider.updateRelationship(relationship);

      // 1. Start offline
      NoteitSyncManager.instance.mockConnectionChecker = () => false;

      final task = NoteitSyncTask(
        id: 'task_uuid_3',
        type: NoteitType.text,
        content: 'Going online later',
        createdAt: DateTime.now(),
      );

      await NoteitSyncManager.instance.enqueue(task);
      await waitForSync();
      expect(NoteitSyncManager.instance.hasPendingItems, isTrue);

      // 2. Go online and mock db upsert
      NoteitSyncManager.instance.mockConnectionChecker = () => true;
      mockHttpClient.handler = (req) {
        if (req.url.path.contains('/rest/v1/love_notes')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 404);
      };

      // Trigger manual sync simulation
      await NoteitSyncManager.instance.triggerSync();
      await waitForSync();

      // Should be empty now
      expect(NoteitSyncManager.instance.hasPendingItems, isFalse);
    });

    test('sets failure state on non-recoverable DB error (400 / 42501)', () async {
      final relationship = FakeRelationshipProvider();
      final noteitProvider = NoteitProvider();
      noteitProvider.updateRelationship(relationship);

      // Go online
      NoteitSyncManager.instance.mockConnectionChecker = () => true;

      // Mock database response with 400 Bad Request error
      mockHttpClient.handler = (req) {
        if (req.url.path.contains('/rest/v1/love_notes')) {
          return http.Response(
            jsonEncode({'message': 'Violates RLS constraint', 'code': '42501'}),
            400,
          );
        }
        return http.Response('{}', 404);
      };

      final task = NoteitSyncTask(
        id: 'task_uuid_4',
        type: NoteitType.text,
        content: 'Fails permanently',
        createdAt: DateTime.now(),
      );

      await NoteitSyncManager.instance.enqueue(task);
      await waitForSync();

      // Non-recoverable error sets retryCount = 5, which immediately marks task status as failed
      // Since it failed permanently, it won't be retried but is flagged as failed in the queue
      expect(NoteitSyncManager.instance.queue.first.status, 'failed');
    });
  });
}
