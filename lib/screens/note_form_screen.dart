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
  late String _extraContent = widget.note?.extraContent ?? '';
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _extraContent = '';
    });
  }

  Future<void> _editExtraContent() async {
    final controller = TextEditingController(text: _extraContent);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extra content'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 6,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Extra content…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) setState(() => _extraContent = result.trim());
  }

  Future<void> _save() async {
    final text = collapseNewlines(_controller.text);
    if (text.isEmpty) return;

    setState(() => _saving = true);
    final note = widget.note;
    if (note != null) {
      await note.setBody(text);
      await note.setExtraContent(_extraContent);
    } else {
      final created = await widget.repository.addNote(text);
      if (_extraContent.isNotEmpty) await created.setExtraContent(_extraContent);
    }
    if (!mounted) return;

    if (note != null) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = false;
      _controller.clear();
      _extraContent = '';
    });
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
              const SizedBox(width: 12),
              IconButton.outlined(
                onPressed: _saving ? null : _editExtraContent,
                tooltip: 'Extra content',
                isSelected: _extraContent.isNotEmpty,
                icon: Icon(
                  _extraContent.isEmpty
                      ? Icons.notes_outlined
                      : Icons.notes,
                ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
