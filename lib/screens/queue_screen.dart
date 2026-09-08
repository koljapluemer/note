import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';
import '../widgets/delete_note_notification.dart';
import '../widgets/image_viewer.dart';
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
  final _filterFocus = FocusNode();

  List<NoteFile> _current = [];

  @override
  void initState() {
    super.initState();
    _current = widget.repository.randomNotes(_batchSize);
    widget.repository.addListener(_onRepositoryChanged);
    // Filter on blur/submit rather than on every keystroke.
    _filterFocus.addListener(() {
      if (!_filterFocus.hasFocus) _onFilterChanged();
    });
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _filterController.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  /// The first batch is drawn in [initState], which on a cold start runs before
  /// the background load has any notes. Draw one once notes arrive; leave a
  /// batch the user is already looking at untouched.
  void _onRepositoryChanged() {
    if (!mounted || _current.isNotEmpty) return;
    setState(() {
      _current = widget.repository.randomNotes(
        _batchSize,
        query: _filterController.text,
      );
    });
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
    // The edit mutates the same NoteFile instance in place, so the batch
    // already holds the new content — rebuild so the row reflects it.
    if (mounted) setState(() {});
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
                ? Center(
                    child: Text(
                      widget.repository.isLoading
                          ? 'Loading notes…'
                          : 'No notes found',
                    ),
                  )
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
                child: TextField(
                  controller: _filterController,
                  focusNode: _filterFocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _onFilterChanged(),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: _next,
                tooltip: 'Next',
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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
    // An image-only note skips the "(empty note)" placeholder — the image
    // itself is the content.
    final showText = note.body.isNotEmpty || !note.hasImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: showText
                    ? (note.body.isEmpty
                        ? const Text('(empty note)')
                        : MarkdownBody(data: note.body))
                    : const SizedBox.shrink(),
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
        ),
        if (note.hasImage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 3,
              ),
              child: GestureDetector(
                onTap: () =>
                    showImageViewer(context, FileImage(note.imageFile!)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    note.imageFile!,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
