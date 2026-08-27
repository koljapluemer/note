import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

const _prefsFolderKey = 'data_folder';

/// Reads and JSON-decodes every `*.json` note file in [folderPath]. Runs in a
/// background isolate via [compute] so scanning thousands of files never blocks
/// the UI thread. Files that don't parse to a JSON object are skipped, never
/// fatal.
///
/// Each entry has three keys: `path` (the file's path), `image` (its resolved
/// image path, or an empty string) and `note` (the decoded JSON object). All
/// values are plain maps/lists/strings so the result crosses the isolate
/// boundary cleanly.
List<Map<String, dynamic>> parseFolderIsolate(String folderPath) {
  final dir = Directory(folderPath);
  final results = <Map<String, dynamic>>[];
  if (!dir.existsSync()) return results;

  // Index `images/` once: note-stem -> newest matching image path. Filenames
  // are `<stem>-<timestamp><ext>`, so the highest timestamp is the live one.
  final imageByStem = <String, String>{};
  final imageTsByStem = <String, int>{};
  final imagesDir = Directory(p.join(folderPath, 'images'));
  if (imagesDir.existsSync()) {
    final namePattern = RegExp(r'^(.+)-(\d+)$');
    for (final entity in imagesDir.listSync()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!supportedImageExtensions.contains(ext)) continue;
      final match =
          namePattern.firstMatch(p.basenameWithoutExtension(entity.path));
      if (match == null) continue;
      final stem = match.group(1)!;
      final ts = int.tryParse(match.group(2)!) ?? 0;
      if (ts >= (imageTsByStem[stem] ?? -1)) {
        imageTsByStem[stem] = ts;
        imageByStem[stem] = entity.path;
      }
    }
  }

  for (final entity in dir.listSync()) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
      continue;
    }
    try {
      final decoded = jsonDecode(entity.readAsStringSync());
      if (decoded is! Map) continue; // not a note object — skip, don't fail
      results.add({
        'path': entity.path,
        'image': imageByStem[p.basenameWithoutExtension(entity.path)] ?? '',
        'note': Map<String, dynamic>.from(decoded),
      });
    } catch (_) {
      // Skip unreadable / unparseable files.
    }
  }
  return results;
}

/// A pending note deletion awaiting either an explicit undo
/// ([NoteRepository.cancelPending]) or two more app-wide interactions
/// ([NoteRepository.registerInteraction]) before it's actually applied.
class _PendingDelete {
  _PendingDelete({required this.id, required this.note});

  final int id;
  final NoteFile note;
  int interactions = 0;
}

class NoteRepository extends ChangeNotifier {
  String? folderPath;
  bool isLoading = false;
  String? loadError;

  List<NoteFile> _notes = [];
  final Random _random = Random();

  final List<_PendingDelete> _pending = [];
  int _nextPendingId = 0;

  int get count => _notes.length;

  List<NoteFile> get notes => List.unmodifiable(_notes);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    folderPath = prefs.getString(_prefsFolderKey);
    if (folderPath != null) {
      await loadFromDisk();
    }
  }

  Future<void> setFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsFolderKey, path);
    folderPath = path;
    await loadFromDisk();
  }

  Future<void> loadFromDisk() async {
    if (folderPath == null) return;
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final parsed = await compute(parseFolderIsolate, folderPath!);
      _notes = [
        for (final entry in parsed)
          NoteFile.fromJson(
            File(entry['path'] as String),
            Map<String, dynamic>.from(entry['note'] as Map),
            imagePath: (entry['image'] as String).isEmpty
                ? null
                : entry['image'] as String,
          ),
      ];
    } catch (e) {
      loadError = e.toString();
      _notes = [];
    }

    isLoading = false;
    notifyListeners();
  }

  List<NoteFile> get _available =>
      _notes.where((n) => !isPendingDeleteNote(n)).toList();

  NoteFile? randomNote() {
    final available = _available;
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }

  /// Up to [count] distinct random notes (fewer if not enough are available),
  /// optionally restricted to notes whose body or extra content contains
  /// [query].
  List<NoteFile> randomNotes(int count, {String query = ''}) {
    final q = query.trim().toLowerCase();
    final available = _available
        .where(
          (n) =>
              q.isEmpty ||
              n.body.toLowerCase().contains(q) ||
              n.extraContent.toLowerCase().contains(q),
        )
        .toList()
      ..shuffle(_random);
    return available.take(count).toList();
  }

  /// Hides [note] right away, but only deletes its file once
  /// [registerInteraction] has been called twice without a matching
  /// [cancelPending]. Returns an id to pass to [cancelPending] for undo, or
  /// to [isPendingActive] to check status.
  int beginPendingDeleteNote(NoteFile note) {
    for (final a in _pending) {
      if (a.note == note) return a.id;
    }
    final id = _nextPendingId++;
    _pending.add(_PendingDelete(id: id, note: note));
    notifyListeners();
    return id;
  }

  bool isPendingDeleteNote(NoteFile note) =>
      _pending.any((a) => a.note == note);

  bool isPendingActive(int id) => _pending.any((a) => a.id == id);

  void cancelPending(int id) {
    final index = _pending.indexWhere((a) => a.id == id);
    if (index == -1) return;
    _pending.removeAt(index);
    notifyListeners();
  }

  void registerInteraction() {
    if (_pending.isEmpty) return;
    final ready = <_PendingDelete>[];
    for (final a in _pending) {
      a.interactions++;
      if (a.interactions >= 2) ready.add(a);
    }
    if (ready.isEmpty) return;
    for (final a in ready) {
      _pending.remove(a);
    }
    _finalize(ready);
  }

  Future<void> _finalize(List<_PendingDelete> actions) async {
    for (final a in actions) {
      await a.note.delete();
      _notes.remove(a.note);
    }
    notifyListeners();
  }

  Future<NoteFile> addNote(String text) async {
    final folder = folderPath;
    if (folder == null) {
      throw StateError('addNote called with no data folder set');
    }

    final slug = _slugify(text);
    final suffix = _randomHex(6);
    final filename = '${slug.isEmpty ? 'note' : slug}-$suffix.json';
    final file = File(p.join(folder, filename));

    final note = NoteFile(file: file, body: text);
    await note.save();
    _notes.add(note);
    notifyListeners();
    return note;
  }

  String _slugify(String input) {
    final firstWords = input.trim().split(RegExp(r'\s+')).take(6).join(' ');
    final lower = firstWords.toLowerCase();
    final dashed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = dashed.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }
}
