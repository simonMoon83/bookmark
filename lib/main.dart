import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/foundation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
      _sharedFiles.value = value;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp build method called');
    return MaterialApp(
      title: '북마크 앱',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ValueListenableBuilder<List<SharedMediaFile>>(
        valueListenable: _sharedFiles,
        builder: (context, sharedFiles, child) {
          debugPrint('ValueListenableBuilder rebuilt with: $sharedFiles');
          return HomeScreen(initialSharedFiles: sharedFiles);
        },
      ),
    );
  }
}
