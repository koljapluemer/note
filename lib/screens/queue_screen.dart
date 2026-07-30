import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _noteController = TextEditingController();
  NoteFile? _current;
  bool _saving = false;
  bool _showingDeleteSnackbar = false;

  @override
  void initState() {
    super.initState();
    _current = widget.repository.randomNote();
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (_showingDeleteSnackbar && !widget.repository.hasPendingDelete) {
      _showingDeleteSnackbar = false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _skip() {
    setState(() {
      _current = widget.repository.randomNote();
      _noteController.clear();
    });
  }

  Future<void> _save() async {
    final note = _current;
    if (note == null) return;
    final text = _noteController.text.trim();

    setState(() => _saving = true);
    if (text.isNotEmpty) {
      await note.appendNote(text);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _current = widget.repository.randomNote();
      _noteController.clear();
    });
  }

  Future<void> _disable() async {
    final note = _current;
    if (note == null) return;

    setState(() => _saving = true);
    await widget.repository.disableNote(note);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _current = widget.repository.randomNote();
      _noteController.clear();
    });
  }

  void _delete() {
    final note = _current;
    if (note == null) return;

    widget.repository.beginPendingDelete(note);
    setState(() {
      _current = widget.repository.randomNote();
      _noteController.clear();
    });

    _showingDeleteSnackbar = true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          duration: const Duration(days: 1),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: widget.repository.cancelPendingDelete,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final note = _current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add a note…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _skip,
                  child: const Text('Skip'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving || note == null ? null : _disable,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Disable'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving || note == null ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: note == null
                ? const Center(child: Text('No notes found'))
                : Markdown(
                    key: ValueKey(note.file.path),
                    data: note.body.isEmpty ? '_(empty note)_' : note.body,
                    selectable: true,
                  ),
          ),
        ],
      ),
    );
  }
}
