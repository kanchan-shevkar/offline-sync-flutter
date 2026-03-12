import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models.dart';
import 'sync_repository.dart';
import 'ui/notes_list.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for web vs mobile/desktop.
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDgdEM0k6v2bCp3BnYVQX4ULkW_lUd0FdU',
        appId: '1:669732755353:android:9f0f6da049222ea534e508',
        messagingSenderId: '669732755353',
        projectId: 'flutter-project-8b5ef',
        storageBucket: 'flutter-project-8b5ef.appspot.com',
        databaseURL: 'https://flutter-project-8b5ef-default-rtdb.firebaseio.com',
        authDomain: 'flutter-project-8b5ef.firebaseapp.com',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(SyncActionTypeAdapter());
  Hive.registerAdapter(SyncQueueItemAdapter());

  runApp(const ProviderScope(child: MyApp()));
}

/// Runs pending sync once when the app opens so queued items reach Firestore.
class _SyncOnOpenWrapper extends StatefulWidget {
  const _SyncOnOpenWrapper({required this.child});

  final Widget child;

  @override
  State<_SyncOnOpenWrapper> createState() => _SyncOnOpenWrapperState();
}

class _SyncOnOpenWrapperState extends State<_SyncOnOpenWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSyncOnce());
  }

  Future<void> _runSyncOnce() async {
    try {
      final manager = ProviderScope.containerOf(context).read(syncQueueManagerProvider);
      await manager.processQueueOnce();
    } catch (_) {
      // Offline or Firestore not ready; queue will sync when user taps Sync.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      home: const _SyncOnOpenWrapper(child: NotesScreen()),
    );
  }
}
