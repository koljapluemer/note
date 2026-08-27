import 'dart:io';

/// Collapses newlines (and surrounding whitespace) into single spaces —
/// notes are always stored as a single line of plain text.
String collapseNewlines(String text) =>
    text.replaceAll(RegExp(r'\s*\n+\s*'), ' ').trim();

/// A single plain-text note backed by a `.txt` file on disk.
///
/// Optional longer-form [extraContent] lives in a sibling `<name>.extra.txt`
/// sidecar file, created only when there's something to store.
class NoteFile {
  NoteFile({
    required this.file,
    required String body,
    String extraContent = '',
  })  : _body = body,
        _extraContent = extraContent;

  final File file;
  String _body;
  String _extraContent;

  String get body => _body;

  String get extraContent => _extraContent;

  /// Path of the sidecar file holding [extraContent].
  static String extraPathFor(String notePath) =>
      '${notePath.substring(0, notePath.length - '.txt'.length)}.extra.txt';

  File get _extraFile => File(extraPathFor(file.path));

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

  /// Writes [text] to the sidecar file, or deletes the sidecar when [text] is
  /// empty so notes without extra content leave no stray file behind.
  Future<void> setExtraContent(String text) async {
    _extraContent = text;
    final sidecar = _extraFile;
    if (text.isEmpty) {
      if (await sidecar.exists()) await sidecar.delete();
    } else {
      await sidecar.writeAsString(text);
    }
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
    final sidecar = _extraFile;
    if (await sidecar.exists()) await sidecar.delete();
  }
}
