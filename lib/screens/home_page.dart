import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medical_tracking_app/screens/alarm_screen.dart';
import 'package:medical_tracking_app/services/alarm_service.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:medical_tracking_app/services/medication_alarm_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MedicationWithSchedules> todayMedications = [];
  bool isLoading = true;
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<AlarmSettings> alarms = [];
  static StreamSubscription<AlarmSet>? ringSubscription;
  static StreamSubscription<AlarmSet>? updateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize alarm listeners
    unawaited(loadAlarms());
    ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);
    updateSubscription ??= Alarm.scheduled.listen((_) {
      unawaited(loadAlarms());
    });

    // Load medications
    await _loadTodayMedications();
    await _scheduleUserAlarms();
    await _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      // Check critical permissions
      final notificationStatus = await Permission.notification.status;
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      final systemAlertStatus = await Permission.systemAlertWindow.status;

      // List of missing permissions
      final missingPermissions = <Permission>[];

      if (notificationStatus != PermissionStatus.granted) {
        missingPermissions.add(Permission.notification);
      }
      if (alarmStatus != PermissionStatus.granted) {
        missingPermissions.add(Permission.scheduleExactAlarm);
      }
      if (systemAlertStatus != PermissionStatus.granted) {
        missingPermissions.add(Permission.systemAlertWindow);
      }

      // Show permission dialog if any are missing
      if (missingPermissions.isNotEmpty && mounted) {
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          await _showPermissionSetupDialog(missingPermissions);
        }
      }
    } catch (e) {
      debugPrint(' Error checking permissions: $e');
    }
  }

  Future<void> _showPermissionSetupDialog(
      List<Permission> missingPermissions) async {
    if (!mounted) return;

    final shouldSetup = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Setup Required')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To ensure your medicine reminders work properly, we need to setup a few permissions:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...missingPermissions.map((permission) {
              final info = _getPermissionInfo(permission);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        info.icon,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            info.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Without these permissions, you may miss important medicine reminders.',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setup Permissions'),
          ),
        ],
      ),
    );

    if (shouldSetup == true) {
      await _handlePermissionSetup(missingPermissions);
    }
  }

  Future<void> _handlePermissionSetup(List<Permission> permissions) async {
    for (final permission in permissions) {
      if (!mounted) break;
      await _handleIndividualPermission(permission);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) {
      await _showPermissionSetupComplete();
    }
  }

  Future<void> _handleIndividualPermission(Permission permission) async {
    if (!mounted) return;

    final permissionInfo = _getPermissionInfo(permission);

    if (permission == Permission.systemAlertWindow) {
      await _showSystemAlertWindowDialog();
      return;
    }

    try {
      final status = await permission.request();

      if (status == PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${permissionInfo.title} granted!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _showPermissionSettingsGuide(permission);
      }
    } catch (e) {
      debugPrint(' Error requesting ${permission.toString()}: $e');
      await _showPermissionSettingsGuide(permission);
    }
  }

  Future<void> _showSystemAlertWindowDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const FittedBox(
          child: Row(
            children: [
              Icon(Icons.phone_android, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Display Over Other Apps'),
            ],
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This permission allows medicine reminders to appear even when your phone is locked or you\'re using other apps.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'How to enable:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Tap "Open Settings" below'),
            Text('2. Find "Medical Tracking App"'),
            Text('3. Look for "Display over other apps"'),
            Text('4. Turn ON the permission'),
            Text('5. Return to this app'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This requires manual setup in Android settings.',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip This'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Permission.systemAlertWindow.request();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '📱 Look for "Display over other apps" in the app settings and enable it.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionSettingsGuide(Permission permission) async {
    if (!mounted) return;

    final permissionInfo = _getPermissionInfo(permission);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enable ${permissionInfo.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Please enable ${permissionInfo.title.toLowerCase()} in settings:'),
            const SizedBox(height: 16),
            const Text('1. Tap "Open Settings"'),
            Text('2. Find "${permissionInfo.title}"'),
            const Text('3. Turn ON the permission'),
            const Text('4. Return to this app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionSetupComplete() async {
    if (!mounted) return;
    final notificationStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    final systemAlertStatus = await Permission.systemAlertWindow.status;

    final grantedCount = [notificationStatus, alarmStatus, systemAlertStatus]
        .where((status) => status == PermissionStatus.granted)
        .length;

    final isComplete = grantedCount == 3;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.warning,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComplete
                      ? 'All permissions granted! Medicine reminders are ready.'
                      : '⚠️ $grantedCount of 3 permissions granted. Some features may not work.',
                ),
              ),
            ],
          ),
          backgroundColor: isComplete ? Colors.green : Colors.orange,
          duration: Duration(seconds: isComplete ? 3 : 5),
          action: !isComplete
              ? SnackBarAction(
                  label: 'Fix',
                  textColor: Colors.white,
                  onPressed: () => _checkAndRequestPermissions(),
                )
              : null,
        ),
      );
    }
  }

  PermissionInfo _getPermissionInfo(Permission permission) {
    switch (permission) {
      case Permission.notification:
        return PermissionInfo(
          icon: Icons.notifications_active,
          title: 'Notifications',
          description: 'Show medicine reminder alerts',
        );
      case Permission.scheduleExactAlarm:
        return PermissionInfo(
          icon: Icons.alarm,
          title: 'Exact Alarms',
          description: 'Schedule precise medicine times',
        );
      case Permission.systemAlertWindow:
        return PermissionInfo(
          icon: Icons.phone_android,
          title: 'Display Over Apps',
          description: 'Show urgent alerts over other apps',
        );
      default:
        return PermissionInfo(
          icon: Icons.security,
          title: permission.toString(),
          description: 'Required for app functionality',
        );
    }
  }

  Future<void> loadAlarms() async {
    final updatedAlarms = await Alarm.getAlarms();
    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    setState(() {
      alarms = updatedAlarms;
    });
  }

  Future<void> ringingAlarmsChanged(AlarmSet alarms) async {
    if (alarms.alarms.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AlarmScreen(alarmSettings: alarms.alarms.first),
      ),
    );
    unawaited(loadAlarms());
  }

  Future<void> navigateToAlarmScreen(AlarmSettings settings) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: AlarmScreen(alarmSettings: settings),
        );
      },
    );

    if (res != null && res == true) unawaited(loadAlarms());
  }

  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayMedications() async {
    debugPrint('📱 Loading today\'s medications from Firebase...');
    setState(() => isLoading = true);

    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) return;

      final medicationsSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(currentUser.uid)
          .collection('medicines')
          .where('is_active', isEqualTo: true)
          .get();

      List<MedicationWithSchedules> medications = [];
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      debugPrint('📅 Loading medications for date: $today');

      for (var medicationDoc in medicationsSnapshot.docs) {
        final medicationData = medicationDoc.data();

        final schedulesSnapshot = await FirebaseFirestore.instance
            .collection('medications')
            .doc(currentUser.uid)
            .collection('medicines')
            .doc(medicationDoc.id)
            .collection('schedules')
            .where('is_active', isEqualTo: true)
            .get();

        List<ScheduleItem> schedules = [];

        for (var scheduleDoc in schedulesSnapshot.docs) {
          final scheduleData = scheduleDoc.data();

          // Check if this schedule was taken today
          final takenDocId = '${medicationDoc.id}_${scheduleDoc.id}_$today';
          final takenDocRef = FirebaseFirestore.instance
              .collection('taken_medications')
              .doc(currentUser.uid)
              .collection('daily_records')
              .doc(takenDocId);

          final takenDoc = await takenDocRef.get();
          final isTaken = takenDoc.exists;

          debugPrint(
              '📋 Loading schedule ${scheduleDoc.id} for ${medicationData['pill_name']}: taken status = $isTaken (doc: $takenDocId)');

          schedules.add(ScheduleItem(
            id: scheduleDoc.id,
            time: scheduleData['time'] ?? '',
            dosage: scheduleData['dosage'] ?? '',
            isTaken: isTaken, // Load the actual taken status from Firebase
          ));
        }

        schedules.sort((a, b) => a.time.compareTo(b.time));

        if (schedules.isNotEmpty) {
          medications.add(MedicationWithSchedules(
            id: medicationDoc.id,
            name: medicationData['pill_name'] ?? '',
            type: medicationData['type'] ?? 'pill',
            category: medicationData['category'] ?? 'general',
            totalPills: medicationData['total_pills'] ?? 0,
            schedules: schedules,
          ));
        }
      }

      debugPrint(
          '✅ Loaded ${medications.length} medications with taken status');
      setState(() {
        todayMedications = medications;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading medications: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _scheduleUserAlarms() async {
    try {
      await MedicationAlarmService.scheduleAllUserAlarms();
      debugPrint('User alarms scheduled from home page');
    } catch (e) {
      debugPrint('Error scheduling user alarms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 10,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withAlpha(150),
                Colors.lightBlueAccent.withAlpha(140),
                Colors.cyan.withAlpha(150),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        title: const Text('Today\'s Medications'),
        leading: null,
        actions: [
          // IconButton(
          //   onPressed: () => Navigator.pushNamed(context, '/add-schedule'),
          //   icon: const Icon(Icons.add),
          // ),
          // IconButton(
          //   onPressed: _loadTodayMedications,
          //   icon: const Icon(Icons.refresh),
          // ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'check_permissions',
                child: Row(
                  children: [
                    Icon(Icons.security, size: 20),
                    SizedBox(width: 8),
                    Text('Check Permissions'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_notification',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, size: 20),
                    SizedBox(width: 8),
                    Text('Test Alarm (10 sec)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reschedule_alarms',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 8),
                    Text('Reschedule All Alarms'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: Row(
                  children: [
                    Icon(Icons.notifications_off, size: 20),
                    SizedBox(width: 8),
                    Text('Cancel All Alarms'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cleanup_alarms',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('Cleanup All Alarms'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'check_alarm_count',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, size: 20),
                    SizedBox(width: 8),
                    Text('Check Alarm Count'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reload_medications',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Debug: Reload Medications'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayMedications,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : todayMedications.isEmpty
                ? _buildEmptyState()
                : _buildMedicationsList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-schedule'),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'check_permissions':
        await _checkAndRequestPermissions();
        break;

      case 'test_notification':
        await AlarmNotificationService.showTestAlarm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test alarm will ring in 10 seconds!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        break;

      case 'reschedule_alarms':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rescheduling all alarms...')),
          );
        }
        await MedicationAlarmService.rescheduleAllAlarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All alarms rescheduled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;

      case 'cancel_all':
        await MedicationAlarmService.cancelAllUserAlarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All alarms cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;

      case 'cleanup_alarms':
        if (mounted) {
          // First show current count
          final currentAlarms = await Alarm.getAlarms();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${currentAlarms.length} alarms. Cleaning up...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await MedicationAlarmService.cleanupAllAlarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All alarms cleaned up! Use "Reschedule All Alarms" to set them up again.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
        break;

      case 'check_alarm_count':
        try {
          final currentAlarms = await Alarm.getAlarms();
          debugPrint('🔍 Current alarms (${currentAlarms.length} total):');
          for (final alarm in currentAlarms) {
            debugPrint('  - ID: ${alarm.id}, Title: ${alarm.notificationSettings.title}, Time: ${alarm.dateTime}');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📱 Found ${currentAlarms.length} scheduled alarms. Check console for details.'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          debugPrint('❌ Error checking alarm count: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error checking alarms: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;

      case 'reload_medications':
        debugPrint('🔄 Debug: Manually reloading medications from Firebase...');
        await _loadTodayMedications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medications reloaded from Firebase'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        break;

      case 'logout':
        final response = await AuthService.signOut();
        if (response['success'] && mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Logout failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No medications scheduled for today',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first medication to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/add-schedule'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDateHeader(),
        const SizedBox(height: 16),
        _buildStatsCards(),
        const SizedBox(height: 20),
        ...todayMedications
            .map((medication) => _buildMedicationCard(medication)),
      ],
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Today\'s Schedule',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    int totalSchedules =
        todayMedications.fold(0, (sums, med) => sums + med.schedules.length);
    int completedSchedules = todayMedications.fold(
        0,
        (sums, med) =>
            sums + med.schedules.where((schedule) => schedule.isTaken).length);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Medications',
              todayMedications.length.toString(),
              Icons.medication,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total Doses',
              totalSchedules.toString(),
              Icons.schedule,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Completed',
              completedSchedules.toString(),
              Icons.check_circle,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(MedicationWithSchedules medication) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medication Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getCategoryColor(medication.category).withAlpha(26),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(medication.category),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getMedicationIcon(medication.type),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${_getCategoryName(medication.category)} • ${medication.type.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (medication.type == 'pill')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${medication.totalPills} left',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Schedules
          ...medication.schedules.asMap().entries.map((entry) {
            final schedule = entry.value;
            final isLast = entry.key == medication.schedules.length - 1;

            return _buildScheduleItem(medication, schedule, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(
      MedicationWithSchedules medication, ScheduleItem schedule, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
      ),
      child: Row(
        children: [
          // Time
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              schedule.time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(width: 16),

          // Dosage
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.dosage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  medication.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Action Button
          GestureDetector(
            onTap: () => _toggleScheduleStatus(medication, schedule),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: !_isBeforeScheduledTime(schedule.time)
                    ? schedule.isTaken
                        ? Colors.green
                        : Colors.grey[200]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                schedule.isTaken ? Icons.check : Icons.circle_outlined,
                color: !_isBeforeScheduledTime(schedule.time)
                    ? schedule.isTaken
                        ? Colors.white
                        : Colors.grey[600]
                    : Colors.grey[300],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleScheduleStatus(
      MedicationWithSchedules medication, ScheduleItem schedule) async {
    if (_isBeforeScheduledTime(schedule.time)) {
      return;
    }

    final wasIsTaken = schedule.isTaken;
    debugPrint(
        '🔄 Toggling taken status for ${medication.name} at ${schedule.time}: $wasIsTaken -> ${!wasIsTaken}');

    setState(() {
      schedule.isTaken = !schedule.isTaken;
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = '${medication.id}_${schedule.id}_$today';
      final docRef = FirebaseFirestore.instance
          .collection('taken_medications')
          .doc(AuthService.getCurrentUser()?.uid)
          .collection('daily_records')
          .doc(docId);

      if (schedule.isTaken) {
        debugPrint('💾 Saving taken status to Firebase: $docId');
        await docRef.set({
          'medication_id': medication.id,
          'schedule_id': schedule.id,
          'taken_at': Timestamp.now(),
          'date': today,
        });
        debugPrint('✅ Successfully saved taken status');
      } else {
        debugPrint('🗑️ Deleting taken status from Firebase: $docId');
        await docRef.delete();
        debugPrint('✅ Successfully deleted taken status');
      }
    } catch (e) {
      debugPrint('❌ Error saving taken status: $e');
      // Revert the UI state if Firebase operation failed
      setState(() {
        schedule.isTaken = !schedule.isTaken;
      });
    }
  }

  bool _isBeforeScheduledTime(String timeString) {
    try {
      final now = DateTime.now();
      final scheduledTime = _parseTimeToToday(timeString);

      if (scheduledTime == null) {
        return false;
      }

      return now.isBefore(scheduledTime);
    } catch (e) {
      debugPrint(' Error checking scheduled time: $e');
      return false;
    }
  }

  DateTime? _parseTimeToToday(String timeString) {
    try {
      final now = DateTime.now();
      final cleanTime = timeString.trim().toUpperCase();
      if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
        final isPM = cleanTime.contains('PM');
        final timeOnly = cleanTime.replaceAll(RegExp(r'[AP]M'), '').trim();
        final parts = timeOnly.split(':');

        if (parts.length >= 2) {
          int hour = int.parse(parts[0].trim());
          final minute = int.parse(parts[1].trim());

          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;

          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
    } catch (e) {
      debugPrint(' Error parsing time string "$timeString": $e');
    }
    return null;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'diabetes':
        return Colors.red;
      case 'bp_control':
        return Colors.purple;
      case 'vitamins':
        return Colors.orange;
      case 'fever':
        return Colors.pink;
      case 'cold':
        return Colors.cyan;
      case 'antibiotics':
        return Colors.indigo;
      case 'pain':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'diabetes':
        return 'Diabetes';
      case 'bp_control':
        return 'Blood Pressure';
      case 'vitamins':
        return 'Vitamins';
      case 'fever':
        return 'Fever';
      case 'cold':
        return 'Cold & Flu';
      case 'antibiotics':
        return 'Antibiotics';
      case 'pain':
        return 'Pain Relief';
      default:
        return 'General';
    }
  }

  IconData _getMedicationIcon(String type) {
    switch (type) {
      case 'syrup':
        return Icons.local_drink;
      case 'pill':
        return Icons.medication;
      default:
        return Icons.healing;
    }
  }
}

// Data Models
class MedicationWithSchedules {
  final String id;
  final String name;
  final String type;
  final String category;
  final int totalPills;
  final List<ScheduleItem> schedules;

  MedicationWithSchedules({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.totalPills,
    required this.schedules,
  });
}

class ScheduleItem {
  final String id;
  final String time;
  final String dosage;
  bool isTaken;

  ScheduleItem({
    required this.id,
    required this.time,
    required this.dosage,
    this.isTaken = false,
  });
}

class PermissionInfo {
  final IconData icon;
  final String title;
  final String description;

  PermissionInfo({
    required this.icon,
    required this.title,
    required this.description,
  });
}
