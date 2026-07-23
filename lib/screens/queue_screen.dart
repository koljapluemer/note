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

  @override
  void initState() {
    super.initState();
    _current = widget.repository.randomNote();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
