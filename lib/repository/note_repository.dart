import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

const _prefsFolderKey = 'data_folder';

/// Parses every .json file in [folderPath]. Runs in a background isolate via
/// [compute] so scanning thousands of files never blocks the UI thread.
List<Map<String, dynamic>> parseFolderIsolate(String folderPath) {
  final dir = Directory(folderPath);
  final results = <Map<String, dynamic>>[];
  if (!dir.existsSync()) return results;
  for (final entity in dir.listSync()) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
      continue;
    }
    try {
      final decoded = jsonDecode(entity.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        results.add({'path': entity.path, 'data': decoded});
      }
    } catch (_) {
      // Skip unreadable / malformed files.
    }
  }
  return results;
}

class NoteRepository extends ChangeNotifier {
  String? folderPath;
  bool isLoading = false;
  String? loadError;

  List<NoteFile> _notes = [];
  final Random _random = Random();

  NoteFile? _pendingDelete;
  int _interactionsSincePendingDelete = 0;

  int get count => _notes.length;

  bool get hasPendingDelete => _pendingDelete != null;

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
          NoteFile(
            file: File(entry['path'] as String),
            data: entry['data'] as Map<String, dynamic>,
          ),
      ];
    } catch (e) {
      loadError = e.toString();
      _notes = [];
    }

    isLoading = false;
    notifyListeners();
  }

  NoteFile? randomNote() {
    final available = _notes.where(
      (n) => !n.disabled && n != _pendingDelete,
    ).toList();
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }

  Future<void> disableNote(NoteFile note) async {
    await note.disable();
    notifyListeners();
  }

  /// Hides [note] from the queue right away, but only deletes its file once
  /// [registerInteraction] has been called twice without a [cancelPendingDelete].
  void beginPendingDelete(NoteFile note) {
    if (_pendingDelete != null) {
      // Only one delete can be pending at a time; finalize the earlier one
      // immediately rather than silently losing track of it.
      _finalizePendingDelete();
    }
    _pendingDelete = note;
    _interactionsSincePendingDelete = 0;
    notifyListeners();
  }

  void cancelPendingDelete() {
    if (_pendingDelete == null) return;
    _pendingDelete = null;
    notifyListeners();
  }

  void registerInteraction() {
    if (_pendingDelete == null) return;
    _interactionsSincePendingDelete++;
    if (_interactionsSincePendingDelete >= 2) {
      _finalizePendingDelete();
    }
  }

  Future<void> _finalizePendingDelete() async {
    final note = _pendingDelete;
    _pendingDelete = null;
    if (note == null) return;
    await note.delete();
    _notes.remove(note);
    notifyListeners();
  }

  Future<void> addNote(String text) async {
    final folder = folderPath;
    if (folder == null) return;

    final slug = _slugify(text);
    final suffix = _randomHex(6);
    final filename = '${slug.isEmpty ? 'note' : slug}-$suffix.json';
    final file = File(p.join(folder, filename));

    final data = <String, dynamic>{'body': text};
    await file.writeAsString(jsonEncode(data));

    _notes.add(NoteFile(file: file, data: data));
    notifyListeners();
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
