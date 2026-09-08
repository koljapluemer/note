import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/note.dart';
import '../repository/note_repository.dart';
import '../widgets/delete_note_notification.dart';
import '../widgets/image_viewer.dart';
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
  final _searchFocus = FocusNode();
  String _query = '';

  /// Reseeded whenever [_query] changes so the random order of main-content
  /// matches stays stable across unrelated rebuilds (deletes, etc.).
  int _shuffleSeed = 0;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    // Filter on blur/submit rather than on every keystroke.
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _applyFilter();
    });
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query == _query) return;
    setState(() {
      _query = query;
      _shuffleSeed = DateTime.now().microsecondsSinceEpoch;
    });
  }

  void _onRepositoryChanged() => setState(() {});

  /// Opens the note's full body in a modal, rendered as Markdown.
  Future<void> _open(NoteFile note) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Markdown(
            data: note.body.trim().isEmpty ? '_(empty note)_' : note.body,
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
          ),
        ),
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
    DeleteNoteNotification(
      context: context,
      repository: widget.repository,
      pendingId: id,
    );
  }

  /// All non-pending notes matching [_query]. With a query, notes matched in
  /// the main content come first (in a per-query random order), followed by
  /// notes matched only in the extra content.
  List<NoteFile> _visibleNotes() {
    final visible = widget.repository.notes
        .where((n) => !widget.repository.isPendingDeleteNote(n));
    if (_query.isEmpty) return visible.toList();

    final inBody = <NoteFile>[];
    final inExtraOnly = <NoteFile>[];
    for (final note in visible) {
      if (note.body.toLowerCase().contains(_query)) {
        inBody.add(note);
      } else if (note.extraContent.toLowerCase().contains(_query)) {
        inExtraOnly.add(note);
      }
    }
    inBody.shuffle(Random(_shuffleSeed));
    return [...inBody, ...inExtraOnly];
  }

  @override
  Widget build(BuildContext context) {
    final notes = _visibleNotes();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applyFilter(),
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
                ? Center(
                    child: Text(
                      widget.repository.isLoading
                          ? 'Loading notes…'
                          : 'No notes found',
                    ),
                  )
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return ListTile(
                        leading: note.hasImage
                            ? GestureDetector(
                                onTap: () => showImageViewer(
                                  context,
                                  FileImage(note.imageFile!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(
                                    note.imageFile!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    cacheWidth: 96,
                                  ),
                                ),
                              )
                            : null,
                        title: note.body.trim().isEmpty && note.hasImage
                            ? null
                            : Text(note.preview),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_full),
                              tooltip: 'Open',
                              onPressed: () => _open(note),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
