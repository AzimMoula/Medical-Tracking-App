import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medical_tracking_app/services/alarm_service.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:alarm/alarm.dart';

class MedicationAlarmService {
  // Schedule alarms for all user's medications
  static Future<void> scheduleAllUserAlarms() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        debugPrint('⚠️ No user logged in for alarm scheduling');
        return;
      }

      debugPrint('🧹 Cleaning up orphaned alarms before scheduling...');
      await cleanupOrphanedAlarms();

      // Get all active medications for user
      final medicationsSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(currentUser.uid)
          .collection('medicines')
          .where('is_active', isEqualTo: true)
          .get();

      debugPrint(
          '📋 Found ${medicationsSnapshot.docs.length} active medications');

      for (var medicationDoc in medicationsSnapshot.docs) {
        await _scheduleMedicationAlarms(medicationDoc);
      }

      debugPrint('✅ All medication alarms scheduled successfully');
    } catch (e) {
      debugPrint('❌ Error scheduling medication alarms: $e');
    }
  }

  // Schedule alarms for a specific medication
  static Future<void> _scheduleMedicationAlarms(
      DocumentSnapshot medicationDoc) async {
    try {
      final medicationData = medicationDoc.data() as Map<String, dynamic>;
      final medicationName =
          medicationData['pill_name'] ?? 'Unknown Medication';

      // Get schedules for this medication
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(AuthService.getCurrentUser()?.uid)
          .collection('medicines')
          .doc(medicationDoc.id)
          .collection('schedules')
          .where('is_active', isEqualTo: true)
          .get();

      debugPrint(
          '⏰ Found ${schedulesSnapshot.docs.length} schedules for $medicationName');

      for (var scheduleDoc in schedulesSnapshot.docs) {
        await _scheduleAlarmForSchedule(
          medicationDoc.id,
          medicationName,
          scheduleDoc,
        );
      }
    } catch (e) {
      debugPrint(' Error scheduling alarms for medication: $e');
    }
  }

  // Schedule alarm for a specific schedule
  static Future<void> _scheduleAlarmForSchedule(
    String medicationId,
    String medicationName,
    DocumentSnapshot scheduleDoc,
  ) async {
    try {
      final scheduleData = scheduleDoc.data() as Map<String, dynamic>;
      final timeString = scheduleData['time'] ?? '';
      final dosage = scheduleData['dosage'] ?? 'Take as prescribed';

      // Parse the time string from database
      final timeOfDay = _parseTimeString(timeString);
      if (timeOfDay == null) {
        debugPrint(' Could not parse time: $timeString');
        return;
      }

      // Create unique alarm ID using medication and schedule IDs
      final alarmId = _generateAlarmId(medicationId, scheduleDoc.id);

      // Schedule the alarm (daily for now - you can modify for duration-based later)
      await AlarmNotificationService.scheduleMedicationAlarm(
        id: alarmId,
        medicationName: medicationName,
        dosage: dosage,
        time: timeOfDay,
        weekdays: [1, 2, 3, 4, 5, 6, 7], // Daily (Mon-Sun)
      );

      debugPrint(
          'Scheduled alarm for $medicationName at ${timeOfDay.format} (ID: $alarmId)');
    } catch (e) {
      debugPrint('Error scheduling alarm for schedule: $e');
    }
  }

  // Parse time string from database (handles various formats)
  static TimeOfDay? _parseTimeString(String timeString) {
    try {
      final cleanTime = timeString.trim().toUpperCase();

      if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
        // 12-hour format: "09:00 AM", "2:30 PM"
        final isPM = cleanTime.contains('PM');
        final timeOnly = cleanTime.replaceAll(RegExp(r'[AP]M'), '').trim();
        final parts = timeOnly.split(':');

        if (parts.length == 2) {
          int hour = int.parse(parts[0].trim());
          final minute = int.parse(parts[1].trim());

          // Convert 12-hour to 24-hour
          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;

          return TimeOfDay(hour: hour, minute: minute);
        }
      } else {
        // 24-hour format: "14:30", "09:00"
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0].trim());
          final minute = int.parse(parts[1].trim());

          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
    } catch (e) {
      debugPrint(' Error parsing time string "$timeString": $e');
    }
    return null;
  }

  // Generate unique alarm ID from medication and schedule IDs
  static int _generateAlarmId(String medicationId, String scheduleId) {
    //  Create a safer ID generation method
    final combined = '${medicationId}_$scheduleId';

    // Use a simple hash that fits in 32-bit range
    int hash = combined.hashCode;

    //  Ensure it's positive and within 32-bit range
    hash = hash.abs();
    if (hash > 2147483647) {
      hash = hash % 2147483647;
    }

    //  Ensure it's not too large for alarm manager
    if (hash > 1000000) {
      hash = hash % 1000000;
    }

    debugPrint(' Generated alarm ID: $hash for $combined');
    return hash;
  }

  // Schedule alarms for a specific medication ID (useful when adding new medication)
  static Future<void> scheduleMedicationAlarms(String medicationId) async {
    try {
      final medicationDoc = await FirebaseFirestore.instance
          .collection('medications')
          .doc(AuthService.getCurrentUser()?.uid)
          .collection('medicines')
          .doc(medicationId)
          .get();

      if (medicationDoc.exists) {
        await _scheduleMedicationAlarms(medicationDoc);
        debugPrint(' Scheduled alarms for medication: $medicationId');
      }
    } catch (e) {
      debugPrint(' Error scheduling alarms for medication $medicationId: $e');
    }
  }

  // Cancel alarms for a specific medication
  static Future<void> cancelMedicationAlarms(String medicationId) async {
    try {
      // Get all schedules for this medication
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(AuthService.getCurrentUser()?.uid)
          .collection('medicines')
          .doc(medicationId)
          .collection('schedules')
          .get();

      // Cancel alarm for each schedule
      for (var scheduleDoc in schedulesSnapshot.docs) {
        final alarmId = _generateAlarmId(medicationId, scheduleDoc.id);
        await AlarmNotificationService.cancelMedicationAlarms(alarmId);
      }

      debugPrint(' Cancelled alarms for medication: $medicationId');
    } catch (e) {
      debugPrint(' Error cancelling alarms for medication $medicationId: $e');
    }
  }

  // Cancel all user alarms
  static Future<void> cancelAllUserAlarms() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) return;

      final medicationsSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(AuthService.getCurrentUser()?.uid)
          .collection('medicines')
          .get();

      for (var medicationDoc in medicationsSnapshot.docs) {
        await cancelMedicationAlarms(medicationDoc.id);
      }

      debugPrint(' Cancelled all user alarms');
    } catch (e) {
      debugPrint(' Error cancelling all user alarms: $e');
    }
  }

  // Reschedule all alarms (useful for app updates or user login)
  static Future<void> rescheduleAllAlarms() async {
    debugPrint('🔄 Rescheduling all medication alarms...');
    await cleanupAllAlarms(); // Clean up all alarms first
    await scheduleAllUserAlarms();
    debugPrint('✅ All alarms rescheduled');
  }

  // Clean up ALL alarms (including orphaned ones) and start fresh
  static Future<void> cleanupAllAlarms() async {
    try {
      debugPrint('🧹 Cleaning up all alarms...');
      
      // Get all currently scheduled alarms
      final allAlarms = await Alarm.getAlarms();
      debugPrint('📋 Found ${allAlarms.length} total alarms to clean up');
      
      // Cancel all alarms one by one
      for (final alarm in allAlarms) {
        await Alarm.stop(alarm.id);
        debugPrint('🗑️ Cancelled alarm ID: ${alarm.id}');
      }
      
      debugPrint('✅ All ${allAlarms.length} alarms cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning up alarms: $e');
    }
  }

  // Clean up orphaned alarms (alarms for medications/schedules that no longer exist)
  static Future<void> cleanupOrphanedAlarms() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) return;

      debugPrint('🔍 Checking for orphaned alarms...');
      
      // Get all currently scheduled alarms
      final allAlarms = await Alarm.getAlarms();
      debugPrint('📋 Found ${allAlarms.length} total scheduled alarms');
      
      // Get all active medications and their schedules
      final medicationsSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(currentUser.uid)
          .collection('medicines')
          .where('is_active', isEqualTo: true)
          .get();

      Set<String> validMedicationIds = {};
      Set<int> validAlarmIds = {};
      
      for (var medicationDoc in medicationsSnapshot.docs) {
        validMedicationIds.add(medicationDoc.id);
        
        final schedulesSnapshot = await FirebaseFirestore.instance
            .collection('medications')
            .doc(currentUser.uid)
            .collection('medicines')
            .doc(medicationDoc.id)
            .collection('schedules')
            .where('is_active', isEqualTo: true)
            .get();
            
        for (var scheduleDoc in schedulesSnapshot.docs) {
          // Generate valid alarm ID for this schedule
          final int alarmId = _generateAlarmId(medicationDoc.id, scheduleDoc.id);
          validAlarmIds.add(alarmId);
        }
      }
      
      debugPrint('📋 Found ${validMedicationIds.length} valid medications with ${validAlarmIds.length} valid schedules');
      
      // Remove orphaned alarms
      int orphanedCount = 0;
      for (final alarm in allAlarms) {
        bool isOrphaned = false;
        
        // Check if alarm ID is not in our valid set
        if (!validAlarmIds.contains(alarm.id)) {
          isOrphaned = true;
        }
        
        // Also check if alarm body contains a medication ID that no longer exists
        if (!isOrphaned && alarm.notificationSettings.body.isNotEmpty) {
          final body = alarm.notificationSettings.body;
          bool foundValidMedication = false;
          for (String validMedId in validMedicationIds) {
            if (body.contains(validMedId)) {
              foundValidMedication = true;
              break;
            }
          }
          if (!foundValidMedication) {
            isOrphaned = true;
          }
        }
        
        if (isOrphaned) {
          await Alarm.stop(alarm.id);
          debugPrint('🗑️ Removed orphaned alarm ID: ${alarm.id} - ${alarm.notificationSettings.title}');
          orphanedCount++;
        }
      }
      
      debugPrint('✅ Cleaned up $orphanedCount orphaned alarms');
    } catch (e) {
      debugPrint('❌ Error cleaning up orphaned alarms: $e');
    }
  }
}
