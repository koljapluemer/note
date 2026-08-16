import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';
import 'note_form_screen.dart';

/// Full, searchable list of every note, with per-row edit/delete actions.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  Future<void> _edit(NoteFile note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Edit note')),
          body: SafeArea(
            child: NoteFormScreen(repository: widget.repository, note: note),
          ),
        ),
      ),
    );
  }

  void _delete(NoteFile note) {
    final id = widget.repository.beginPendingDeleteNote(note);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.repository.cancelPending(id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.repository.notes
        .where((n) => !widget.repository.isPendingDeleteNote(n))
        .where((n) => _query.isEmpty || n.body.toLowerCase().contains(_query))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Filter notes…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('No notes found'))
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return ListTile(
                        title: Text(note.preview),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () => _edit(note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _delete(note),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
