import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';

/// Add/edit form for a single note. When [note] is null this is the "Add"
/// tab: saving writes a new file and clears the field so another note can
/// be added right away. When [note] is set, saving overwrites that note's
/// body and pops back to whichever screen jumped here.
class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({super.key, required this.repository, this.note});

  final NoteRepository repository;
  final NoteFile? note;

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  late final _controller = TextEditingController(text: widget.note?.body ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    setState(_controller.clear);
  }

  Future<void> _save() async {
    final text = collapseNewlines(_controller.text);
    if (text.isEmpty) return;

    setState(() => _saving = true);
    final note = widget.note;
    if (note != null) {
      await note.setBody(text);
    } else {
      await widget.repository.addNote(text);
    }
    if (!mounted) return;

    if (note != null) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = false;
      _controller.clear();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Note saved')));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: isEdit,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Write a note…',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : (isEdit ? () => Navigator.pop(context) : _clear),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isEdit ? 'Cancel' : 'Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isEdit ? 'Save' : 'Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
