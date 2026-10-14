import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';
import 'services/app_controller.dart';
import 'services/notifier.dart';
import 'services/store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await TaskStore.i.load();
  Notifier.onResponse = AppController.i.onNotification;
  await Notifier.i.init();
  runApp(const VoiceTasksApp());
  unawaited(_afterStart());
}

Future<void> _afterStart() async {
  await Notifier.i.requestPermissions();
  await Notifier.i.scheduleDaily();
  await TaskStore.i.rescheduleAll();

  final launch = await Notifier.i.launchPayload();
  if (launch != null) AppController.i.openFromPayload(launch);

  // Long-press the app icon -> "Record a task" (the quick path from the home screen).
  const qa = QuickActions();
  qa.initialize((type) {
    if (type == 'record') AppController.i.post('record');
  });
  qa.setShortcutItems([
    const ShortcutItem(type: 'record', localizedTitle: 'Record a task'),
  ]);
}

class VoiceTasksApp extends StatefulWidget {
  const VoiceTasksApp({super.key});
  @override
  State<VoiceTasksApp> createState() => _VoiceTasksAppState();
}

class _VoiceTasksAppState extends State<VoiceTasksApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Notification buttons may have changed tasks while the app was closed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) TaskStore.i.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Tasks',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
