import 'dart:convert';
import 'dart:io';

/// A single note backed by a JSON file on disk.
///
/// Keeps the full decoded JSON so unrelated properties (e.g. `rels`,
/// `extraData`) round-trip untouched when only `notes` is updated.
class NoteFile {
  NoteFile({required this.file, required this.data});

  final File file;
  final Map<String, dynamic> data;

  String get body => data['body'] as String? ?? '';

  List<String> get notes {
    final raw = data['notes'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<void> appendNote(String note) async {
    final updated = List<String>.from(notes)..add(note);
    data['notes'] = updated;
    await file.writeAsString(jsonEncode(data));
  }
}
