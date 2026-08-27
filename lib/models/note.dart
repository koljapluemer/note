import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Collapses newlines (and surrounding whitespace) into single spaces —
/// notes are always stored as a single line of plain text.
String collapseNewlines(String text) =>
    text.replaceAll(RegExp(r'\s*\n+\s*'), ' ').trim();

/// Largest image file we'll accept. Far bigger than any real photo; the cap
/// only exists so a pathologically huge file can't blow up memory on decode.
const int maxImageBytes = 25 * 1024 * 1024;

/// Image extensions Flutter can decode and display directly. Images are stored
/// verbatim — no format conversion — so anything outside this set is rejected
/// at pick time rather than saved and later failing to render.
const Set<String> supportedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
};

/// A single plain-text note backed by a `.txt` file on disk.
///
/// Optional longer-form [extraContent] lives in a sibling `<name>.extra.txt`
/// sidecar file, created only when there's something to store. An optional
/// image lives in an `images/` subfolder as `<name>-<timestamp><ext>` — the
/// timestamp makes every replacement a brand-new path, side-stepping Flutter's
/// path-keyed image cache.
class NoteFile {
  NoteFile({
    required this.file,
    required String body,
    String extraContent = '',
    String? imagePath,
  })  : _body = body,
        _extraContent = extraContent,
        _imagePath = imagePath;

  final File file;
  String _body;
  String _extraContent;
  String? _imagePath;

  String get body => _body;

  String get extraContent => _extraContent;

  /// Absolute path of the attached image, or null when the note has none.
  String? get imagePath => _imagePath;

  File? get imageFile {
    final path = _imagePath;
    return path == null ? null : File(path);
  }

  bool get hasImage => _imagePath != null;

  /// Path of the sidecar file holding [extraContent].
  static String extraPathFor(String notePath) =>
      '${notePath.substring(0, notePath.length - '.txt'.length)}.extra.txt';

  File get _extraFile => File(extraPathFor(file.path));

  /// Folder that holds every note's image, alongside the notes folder.
  static String imagesDirFor(String notePath) =>
      p.join(p.dirname(notePath), 'images');

  String get _imagesDirPath => imagesDirFor(file.path);

  /// The note's filename without its `.txt` extension — the prefix every one
  /// of its image files shares.
  String get _imageStem => p.basenameWithoutExtension(file.path);

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

  /// Stores [bytes] as this note's image, replacing any current one.
  /// [extension] includes the leading dot and must be in
  /// [supportedImageExtensions].
  Future<void> setImage(Uint8List bytes, String extension) async {
    final dir = Directory(_imagesDirPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    await _deleteImageFiles();
    final name =
        '$_imageStem-${DateTime.now().millisecondsSinceEpoch}$extension';
    final dest = File(p.join(_imagesDirPath, name));
    await dest.writeAsBytes(bytes, flush: true);
    _imagePath = dest.path;
  }

  /// Removes this note's image, if any.
  Future<void> clearImage() async {
    await _deleteImageFiles();
    _imagePath = null;
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
    final sidecar = _extraFile;
    if (await sidecar.exists()) await sidecar.delete();
    await _deleteImageFiles();
  }

  /// Deletes every `images/<stem>-<digits>.<ext>` file for this note — the
  /// current one plus any older leftovers from an interrupted replacement.
  Future<void> _deleteImageFiles() async {
    final dir = Directory(_imagesDirPath);
    if (!await dir.exists()) return;
    final pattern = RegExp('^${RegExp.escape(_imageStem)}-\\d+\$');
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!supportedImageExtensions.contains(ext)) continue;
      if (pattern.hasMatch(p.basenameWithoutExtension(entity.path))) {
        try {
          await entity.delete();
        } catch (_) {
          // Best effort — a leftover file is harmless; the newest timestamp
          // still wins when the folder is rescanned.
        }
      }
    }
  }
}
