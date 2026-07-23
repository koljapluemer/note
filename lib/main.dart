import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'repository/note_repository.dart';
import 'screens/home_shell.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const NoteApp());
}

class NoteApp extends StatefulWidget {
  const NoteApp({super.key});

  @override
  State<NoteApp> createState() => _NoteAppState();
}

class _NoteAppState extends State<NoteApp> {
  final _repository = NoteRepository();
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _repository.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  Future<void> _bootstrap() async {
    if (Platform.isAndroid) {
      // Full disk access, so the notes folder can live anywhere on device.
      await Permission.manageExternalStorage.request();
    }
    await _repository.init();
    if (!mounted) return;
    setState(() => _bootstrapped = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_bootstrapped) {
      return const _LoadingScaffold(message: 'Starting…');
    }
    if (_repository.folderPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose a data folder')),
        body: SettingsScreen(repository: _repository),
      );
    }
    if (_repository.isLoading) {
      return const _LoadingScaffold(message: 'Loading notes…');
    }
    return HomeShell(repository: _repository);
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
