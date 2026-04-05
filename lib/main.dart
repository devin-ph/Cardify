import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firestore_sync_status.dart';
import 'services/class_schedule_notification_service.dart';
import 'services/xp_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: 'assets/.env');
    } catch (_) {
      // Continue without a bundled .env file.
    }
  }

  String? supabaseUrl;
  String? supabaseAnonKey;
  if (dotenv.isInitialized) {
    supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
    supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
  }

  if (supabaseUrl?.trim().isNotEmpty == true &&
      supabaseAnonKey?.trim().isNotEmpty == true) {
    await Supabase.initialize(
      url: supabaseUrl!.trim(),
      anonKey: supabaseAnonKey!.trim(),
    );
  }
  try {
    await ClassScheduleNotificationService.instance.initialize();
  } catch (_) {
    // Keep app startup working if notification setup is unavailable.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI English Learning - Object Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 247, 236, 247), // màu nền
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Color.fromARGB(
          255,
          245,
          240,
          248,
        ), // màu nền tổng thể
        useMaterial3: true,
      ),
      home: const _AppBootstrap(),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<void> _initializeFuture;
  SharedPreferences? _preferences;
  bool _shouldShowOnboarding = false;

  static const String _onboardingSeenKey = 'onboarding_seen_v1';
  static const String _appStartedAtKey = 'app_started_at_v1';

  DocumentReference<Map<String, dynamic>>? _profileDoc() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Future<void> _syncBootstrapStateFromFirebase() async {
    final docRef = _profileDoc();
    if (docRef == null) {
      return;
    }

    try {
      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${docRef.id}',
        reason: 'đồng bộ onboarding/app_started_at khi mở app',
      );
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null) {
        await _pushBootstrapStateToFirebase();
        return;
      }

      final remoteOnboarding = data['onboarding_seen'];
      final remoteStartedAt = data['app_started_at'];

      final preferences = _preferences ?? await SharedPreferences.getInstance();
      _preferences = preferences;

      if (remoteOnboarding is bool) {
        await preferences.setBool(_onboardingSeenKey, remoteOnboarding);
        _shouldShowOnboarding = !remoteOnboarding;
      }
      if (remoteStartedAt is String && remoteStartedAt.trim().isNotEmpty) {
        await preferences.setString(_appStartedAtKey, remoteStartedAt);
      }
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.id}',
        message: 'Đã đọc trạng thái bootstrap từ Firestore',
      );
    } catch (error) {
      // Keep local bootstrap flow working when cloud read fails.
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${docRef.id}',
        operation: 'read bootstrap state',
        error: error,
      );
    }
  }

  Future<void> _pushBootstrapStateToFirebase() async {
    final docRef = _profileDoc();
    if (docRef == null) {
      return;
    }

    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    final onboardingSeen = preferences.getBool(_onboardingSeenKey) ?? false;
    final appStartedAt = preferences.getString(_appStartedAtKey);

    try {
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${docRef.id}',
        reason: 'ghi onboarding/app_started_at',
      );
      await docRef.set({
        'onboarding_seen': onboardingSeen,
        if (appStartedAt != null && appStartedAt.isNotEmpty)
          'app_started_at': appStartedAt,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.id}',
        message: 'Đã ghi bootstrap state lên Firestore',
      );
    } catch (error) {
      // Keep local bootstrap flow working when cloud write fails.
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${docRef.id}',
        operation: 'write bootstrap state',
        error: error,
      );
    }
  }

  Future<void> _initializeFirebase() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<void> _initializeAppState() async {
    await _initializeFirebase();
    await XPService.instance.init();
    _preferences = await SharedPreferences.getInstance();
    _shouldShowOnboarding =
        !(_preferences?.getBool(_onboardingSeenKey) ?? false);
    await _syncBootstrapStateFromFirebase();
  }

  Future<void> _markAppStarted() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    if (preferences.containsKey(_appStartedAtKey)) {
      await _pushBootstrapStateToFirebase();
      return;
    }

    await preferences.setString(
      _appStartedAtKey,
      DateTime.now().toIso8601String(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _preferences = preferences;
    });

    await _pushBootstrapStateToFirebase();
  }

  Future<void> _markOnboardingComplete() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingSeenKey, true);

    if (!mounted) {
      return;
    }

    setState(() {
      _shouldShowOnboarding = false;
      _preferences = preferences;
    });

    await _pushBootstrapStateToFirebase();
  }

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initializeAppState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error.toString();
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 44,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Khoi dong Firebase that bai',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _initializeFuture = _initializeFirebase();
                        });
                      },
                      child: const Text('Thu lai'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_shouldShowOnboarding) {
          return OnboardingScreen(
            onFinished: _markOnboardingComplete,
            onStarted: _markAppStarted,
          );
        }

        return const AuthGate();
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainScreen();
        }

        return const CardifyLoginScreen();
      },
    );
  }
}
