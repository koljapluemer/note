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

  int get count => _notes.length;

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
    if (_notes.isEmpty) return null;
    return _notes[_random.nextInt(_notes.length)];
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
