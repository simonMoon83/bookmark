import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeMode = prefs.getString('themeMode');
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(
        initialThemeMode: themeMode == 'dark'
            ? ThemeMode.dark
            : themeMode == 'light'
                ? ThemeMode.light
                : ThemeMode.system,
      ),
      child: const MyApp(),
    ),
  );
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode;
  ThemeNotifier({required ThemeMode initialThemeMode})
      : _themeMode = initialThemeMode;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.name);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentSub;
  final _sharedFiles = ValueNotifier<List<SharedMediaFile>>([]);

  @override
  void initState() {
    super.initState();
    _initShareIntent();
  }

  Future<void> _initShareIntent() async {
    debugPrint('_initShareIntent called');
    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      _sharedFiles.value = List<SharedMediaFile>.from(value);
      debugPrint(
          'getMediaStream: ${_sharedFiles.value.map((f) => f.toMap()).toString()}');
      // Tell the library that we are done processing the intent.
      ReceiveSharingIntent.instance.reset();
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _sharedFiles.value = value;
      debugPrint(
          'getInitialMedia: ${_sharedFiles.value.map((f) => f.toMap()).toString()}');

      // Tell the library that we are done processing the intent.
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp build method called');
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: '북마크 앱',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          themeMode: themeNotifier.themeMode,
          home: ValueListenableBuilder<List<SharedMediaFile>>(
            valueListenable: _sharedFiles,
            builder: (context, sharedFiles, child) {
              debugPrint('ValueListenableBuilder rebuilt with: $sharedFiles');
              return HomeScreen(initialSharedFiles: sharedFiles);
            },
          ),
        );
      },
    );
  }
}
