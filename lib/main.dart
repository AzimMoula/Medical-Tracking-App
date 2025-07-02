import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medical_tracking_app/firebase_options.dart';
import 'package:medical_tracking_app/screens/add_schedule.dart';
import 'package:medical_tracking_app/screens/auth/login.dart';
import 'package:medical_tracking_app/screens/auth/register.dart';
import 'package:medical_tracking_app/screens/home_page.dart';
import 'package:medical_tracking_app/screens/settings_page.dart';
import 'package:medical_tracking_app/screens/medication_history_page.dart';
import 'package:medical_tracking_app/screens/alarm_screen.dart';
import 'package:medical_tracking_app/services/alarm_service.dart';
import 'package:medical_tracking_app/services/medication_alarm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Alarm services with enhanced setup
  debugPrint('🔄 Initializing alarm services...');
  await Alarm.init();
  await AlarmNotificationService.initialize();

  // Request critical permissions upfront for system-like behavior
  await AlarmNotificationService.requestAllPermissions();

  debugPrint('✅ Alarm services initialized with permissions');

  // Schedule alarms if user is logged in
  if (FirebaseAuth.instance.currentUser != null) {
    debugPrint('🔔 User logged in, scheduling all medication alarms...');
    MedicationAlarmService.scheduleAllUserAlarms();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late StreamSubscription<User?> _authSubscription;
  static StreamSubscription<AlarmSet>? _alarmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);

    // Set up global alarm listener for full-screen alarms
    _setupGlobalAlarmListener();
  }

  void _setupGlobalAlarmListener() {
    debugPrint('🔔 Setting up global alarm listener...');
    _alarmSubscription?.cancel();
    _alarmSubscription = Alarm.ringing.listen(_onAlarmRinging);
  }

  void _onAlarmRinging(AlarmSet alarmSet) {
    debugPrint('🚨 ALARM RINGING DETECTED - Global listener triggered');
    debugPrint('📊 Number of ringing alarms: ${alarmSet.alarms.length}');

    if (alarmSet.alarms.isNotEmpty) {
      final firstAlarm = alarmSet.alarms.first;
      debugPrint('🔔 First alarm details:');
      debugPrint('   ID: ${firstAlarm.id}');
      debugPrint('   Title: ${firstAlarm.notificationSettings.title}');
      debugPrint('   Body: ${firstAlarm.notificationSettings.body}');
      debugPrint('   Full-screen: ${firstAlarm.androidFullScreenIntent}');

      final context = navigatorKey.currentContext;
      if (context != null) {
        debugPrint('✅ Context available - navigating to full-screen alarm');
        // Navigate to full-screen alarm
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => AlarmScreen(alarmSettings: firstAlarm),
            settings: const RouteSettings(name: '/alarm'),
          ),
        );
      } else {
        debugPrint('❌ No context available for alarm navigation');
        debugPrint(
            '🔍 navigatorKey.currentState: ${navigatorKey.currentState}');
        debugPrint(
            '🔍 navigatorKey.currentContext: ${navigatorKey.currentContext}');
      }
    } else {
      debugPrint('⚠️ No alarms in the ringing set');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    _alarmSubscription?.cancel();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    if (user != null) {
      MedicationAlarmService.scheduleAllUserAlarms();
    } else {
      MedicationAlarmService.cancelAllUserAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Tracking App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        '/add-schedule': (context) => const AddSchedule(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/history': (context) => const MedicationHistoryPage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false);
                    },
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          );
        }

        return snapshot.hasData ? const HomePage() : const LoginPage();
      },
    );
  }
}
