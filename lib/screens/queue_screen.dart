import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';
import 'note_form_screen.dart';

/// Shows a batch of random notes with per-note edit/delete actions, and a
/// single "Next" button to draw a fresh batch.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  static const _batchSize = 3;

  List<NoteFile> _current = [];
  int? _pendingDeleteId;

  @override
  void initState() {
    super.initState();
    _current = widget.repository.randomNotes(_batchSize);
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    final id = _pendingDeleteId;
    if (id != null && !widget.repository.isPendingActive(id)) {
      _pendingDeleteId = null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _next() {
    setState(() => _current = widget.repository.randomNotes(_batchSize));
  }

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
    setState(() => _current = _current.where((n) => n != note).toList());

    _pendingDeleteId = id;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _current.isEmpty
                ? const Center(child: Text('No notes found'))
                : ListView.separated(
                    itemCount: _current.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) =>
                        _buildNoteRow(_current[index]),
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _next, child: const Text('Next')),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNoteRow(NoteFile note) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(note.body.isEmpty ? '(empty note)' : note.body),
          ),
        ),
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
    );
  }
}
