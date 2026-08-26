import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';
import '../widgets/delete_note_notification.dart';
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

  final _filterController = TextEditingController();

  List<NoteFile> _current = [];

  @override
  void initState() {
    super.initState();
    _current = widget.repository.randomNotes(_batchSize);
    _filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(
      () => _current = widget.repository.randomNotes(
        _batchSize,
        query: _filterController.text,
      ),
    );
  }

  void _next() {
    setState(
      () => _current = widget.repository.randomNotes(
        _batchSize,
        query: _filterController.text,
      ),
    );
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

    DeleteNoteNotification(
      context: context,
      repository: widget.repository,
      pendingId: id,
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
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _filterController,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _next,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
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
