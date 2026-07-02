import 'package:flutter/material.dart';
import 'package:days_together/models/local_activity_model.dart';
import 'package:days_together/services/recent_activity_service.dart';

class RecentActivityProvider with ChangeNotifier {
  bool _isLoading = false;

  List<LocalActivity> get activities => RecentActivityService.instance.activitiesNotifier.value;
  bool get isLoading => _isLoading;

  RecentActivityProvider() {
    // Listen to changes in the database service and propagate them to consumers
    RecentActivityService.instance.activitiesNotifier.addListener(_onServiceActivitiesChanged);
    _initService();
  }

  Future<void> _initService() async {
    _isLoading = true;
    notifyListeners();
    await RecentActivityService.instance.init();
    _isLoading = false;
    notifyListeners();
  }

  void _onServiceActivitiesChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    RecentActivityService.instance.activitiesNotifier.removeListener(_onServiceActivitiesChanged);
    super.dispose();
  }

  Future<void> logLocalActivity({
    required String activityType,
    required String title,
    required String description,
    required String icon,
    String? referenceId,
    String? route,
  }) async {
    await RecentActivityService.instance.logActivity(
      activityType: activityType,
      title: title,
      description: description,
      icon: icon,
      referenceId: referenceId,
      route: route,
      initiatedByCurrentUser: true,
    );
  }

  Future<void> clearAllActivities() async {
    await RecentActivityService.instance.clearAll();
  }
}
