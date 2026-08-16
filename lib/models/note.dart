import 'dart:io';

/// Collapses newlines (and surrounding whitespace) into single spaces —
/// notes are always stored as a single line of plain text.
String collapseNewlines(String text) =>
    text.replaceAll(RegExp(r'\s*\n+\s*'), ' ').trim();

/// A single plain-text note backed by a `.txt` file on disk.
class NoteFile {
  NoteFile({required this.file, required String body}) : _body = body;

  final File file;
  String _body;

  String get body => _body;

  /// A single-line, whitespace-collapsed, truncated preview of [body].
  /// Used anywhere a note needs a compact label — there's no title field.
  String get preview {
    final collapsed = collapseNewlines(_body);
    if (collapsed.isEmpty) return '(empty note)';
    return collapsed.length > 60 ? '${collapsed.substring(0, 60)}…' : collapsed;
  }

  Future<void> setBody(String text) async {
    _body = text;
    await file.writeAsString(text);
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
  }
}
