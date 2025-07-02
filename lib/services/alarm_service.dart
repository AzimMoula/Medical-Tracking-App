import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmNotificationService {
  static bool _initialized = false;

  // Initialize the alarm service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🔄 Initializing alarm service...');

      // Initialize the alarm package
      await Alarm.init();

      _initialized = true;
      debugPrint('✅ Alarm service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing alarm service: $e');
      _initialized = false;
    }
  }

  // Request necessary permissions
  static Future<bool> requestAllPermissions() async {
    try {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();

      // Request exact alarm permission (Android 12+)
      final alarmStatus = await Permission.scheduleExactAlarm.request();

      // Request ignore battery optimization
      final batteryStatus =
          await Permission.ignoreBatteryOptimizations.request();

      final allGranted = notificationStatus.isGranted && alarmStatus.isGranted;

      debugPrint(
          '🔐 Permissions - Notification: ${notificationStatus.isGranted}, Alarm: ${alarmStatus.isGranted}, Battery: ${batteryStatus.isGranted}');

      return allGranted;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  // Schedule a medication alarm (daily recurring) - MAIN METHOD
  static Future<void> scheduleMedicationAlarm({
    required int id,
    required String medicationName,
    required String dosage,
    required TimeOfDay time,
    String? medicationId, // Add medication ID for duration checking
    List<int>? weekdays, // Optional: if null, defaults to daily
  }) async {
    try {
      debugPrint('🔔 AlarmNotificationService: Starting to schedule alarm');
      debugPrint('🆔 Base ID: $id');
      debugPrint('💊 Medication: $medicationName');
      debugPrint(
          '⏰ Time: ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
      debugPrint('🔗 Medication ID: $medicationId');

      // Cancel existing alarm first
      await cancelMedicationAlarms(id);

      // For medication alarms, we schedule a daily recurring alarm
      final scheduledDate = _getNextDailyAlarm(time);

      debugPrint('📅 Next alarm scheduled for: $scheduledDate');

      // Include medication ID in notification body for rescheduling
      final notificationBody = medicationId != null
          ? '$medicationName - $dosage|$medicationId' // Include medication ID
          : '$medicationName - $dosage';

      // Create alarm settings with MAXIMUM system-like behavior
      final alarmSettings = AlarmSettings(
        id: id, // Use the base ID directly for daily alarms
        dateTime: scheduledDate,
        assetAudioPath: 'assets/audio/marimba.mp3',
        loopAudio: true,
        vibrate: true,
        // MAXIMUM volume settings for system-like experience
        volumeSettings: VolumeSettings.fixed(volume: 1.0),
        notificationSettings: NotificationSettings(
          title: '🚨 MEDICATION REMINDER',
          body: notificationBody,
          stopButton: 'Take Medicine',
          icon: 'notification_icon',
        ),
        // CRITICAL settings for FORCED full-screen alarm behavior
        androidFullScreenIntent: true,
        androidStopAlarmOnTermination: false,
      );

      // Schedule the alarm
      await Alarm.set(alarmSettings: alarmSettings);

      debugPrint(
          '✅ Alarm SET for $medicationName at ${time.hour}:${time.minute.toString().padLeft(2, '0')} (ID: $id) for $scheduledDate');

      // Verify alarms were set
      final allAlarms = await Alarm.getAlarms();
      debugPrint('📋 Total alarms currently set: ${allAlarms.length}');
      for (final alarm in allAlarms) {
        if (alarm.id == id) {
          debugPrint(
              '🔍 Found our alarm: ID ${alarm.id}, scheduled for ${alarm.dateTime}');
          debugPrint(
              '📱 Full-screen enabled: ${alarm.androidFullScreenIntent}');
          debugPrint('🔊 Volume: ${alarm.volumeSettings.volume}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
      rethrow;
    }
  }

  // Cancel medication alarms
  static Future<void> cancelMedicationAlarms(int baseId) async {
    try {
      // For the new single-alarm approach, just cancel the base ID
      await Alarm.stop(baseId);
      debugPrint('✅ Cancelled alarm for base ID: $baseId');
    } catch (e) {
      debugPrint('❌ Error cancelling alarms: $e');
    }
  }

  // Cancel all alarms
  static Future<void> cancelAllAlarms() async {
    try {
      await Alarm.stopAll();
      debugPrint('✅ All alarms cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all alarms: $e');
    }
  }

  // Show test alarm in 10 seconds with MAXIMUM system-like behavior
  static Future<void> showTestAlarm() async {
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 10));
      final testId = DateTime.now().millisecondsSinceEpoch % 10000;

      debugPrint('🚨 Scheduling FULL-SCREEN test alarm for: $testTime');
      debugPrint('🔢 Test alarm ID: $testId');

      final alarmSettings = AlarmSettings(
          id: testId,
          dateTime: testTime,
          assetAudioPath: 'assets/audio/marimba.mp3',
          loopAudio: true,
          vibrate: true,
          // MAXIMUM volume settings for test alarm
          volumeSettings: VolumeSettings.fixed(volume: 1.0),
          notificationSettings: const NotificationSettings(
            title: '🚨 TEST MEDICATION ALARM',
            body:
                'This is a FULL-SCREEN test alarm - exactly like your medication reminders!',
            stopButton: 'Stop Test',
            icon: 'notification_icon',
          ),
          // CRITICAL for FORCED full-screen behavior
          androidFullScreenIntent: true,
          androidStopAlarmOnTermination: false);

      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint(
          '✅ FULL-SCREEN Test alarm scheduled for ${testTime.toString()}');
      debugPrint(
          '🔔 This alarm will behave exactly like your medication alarms with FULL-SCREEN');

      // Verify the alarm was set
      final allAlarms = await Alarm.getAlarms();
      final ourAlarm = allAlarms.where((a) => a.id == testId).firstOrNull;
      if (ourAlarm != null) {
        debugPrint('✅ Verification: Test alarm found in scheduled alarms');
        debugPrint('📊 Total alarms now: ${allAlarms.length}');
        debugPrint(
            '📱 Full-screen enabled: ${ourAlarm.androidFullScreenIntent}');
      } else {
        debugPrint(
            '❌ Verification failed: Test alarm not found in scheduled alarms');
      }
    } catch (e) {
      debugPrint('❌ Error scheduling test alarm: $e');
    }
  }

  // Get the next scheduled time for daily recurring alarm
  static DateTime _getNextDailyAlarm(TimeOfDay time) {
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);

    // If the time has already passed today, schedule for tomorrow
    if (today.isBefore(now) || today.isAtSameMomentAs(now)) {
      return today.add(const Duration(days: 1));
    }

    return today;
  }

  // Reschedule a recurring alarm (called after an alarm rings)
  static Future<void> rescheduleRecurringAlarm({
    required int id,
    required String medicationName,
    required String dosage,
    required TimeOfDay time,
    String? medicationId,
  }) async {
    try {
      debugPrint('🔄 Rescheduling recurring alarm for $medicationName');

      final nextAlarmTime = _getNextDailyAlarm(time);

      // Include medication ID in notification body for future rescheduling
      final notificationBody = medicationId != null
          ? '$medicationName - $dosage|$medicationId'
          : '$medicationName - $dosage';

      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: nextAlarmTime,
        assetAudioPath: 'assets/audio/marimba.mp3',
        loopAudio: true,
        vibrate: true,
        // MAXIMUM volume settings for system-like experience
        volumeSettings: VolumeSettings.fixed(volume: 1.0),
        notificationSettings: NotificationSettings(
          title: '🚨 MEDICATION REMINDER',
          body: notificationBody,
          stopButton: 'Take Medicine',
          icon: 'notification_icon',
        ),
        // CRITICAL settings for FORCED full-screen alarm behavior
        androidFullScreenIntent: true,
        androidStopAlarmOnTermination: false,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint(
          '✅ Rescheduled FULL-SCREEN alarm for $medicationName at $nextAlarmTime');
    } catch (e) {
      debugPrint('❌ Error rescheduling recurring alarm: $e');
    }
  }

  // Check if alarm is ringing
  static Future<bool> isAlarmRinging(int id) async {
    final alarms = await getActiveAlarms();

    for (final alarm in alarms) {
      if (alarm.id == id) return true;
    }

    return false;
  }

  // Get all active alarms
  static Future<List<AlarmSettings>> getActiveAlarms() => Alarm.getAlarms();
}
