import 'package:flutter/material.dart';

import '../repository/note_repository.dart';
import 'list_screen.dart';
import 'note_form_screen.dart';
import 'queue_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      NoteFormScreen(repository: widget.repository),
      QueueScreen(repository: widget.repository),
      ListScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.add), label: 'Add'),
                NavigationDestination(icon: Icon(Icons.layers), label: 'Queue'),
                NavigationDestination(icon: Icon(Icons.list), label: 'List'),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}
