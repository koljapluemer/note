import 'dart:convert';
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

/// A single note persisted as one `<name>.json` file directly inside the data
/// folder.
///
/// The JSON object always carries `body` (the single line of note text) and,
/// only when non-empty, `extra` (optional long-form content) and `rels` — an
/// opaque string→string map this app never reads, renders, or validates. `rels`
/// exists purely so external tooling can hang metadata off a note; any *other*
/// unrecognised top-level keys are likewise kept and written back untouched, so
/// nothing a third party adds is lost on the next edit.
///
/// An optional image still lives as a real file in the sibling `images/` folder
/// as `<name>-<timestamp><ext>` (the timestamp makes every replacement a
/// brand-new path, side-stepping Flutter's path-keyed image cache). It is found
/// by name during the folder scan, not referenced from the JSON.
class NoteFile {
  NoteFile({
    required this.file,
    required String body,
    String extraContent = '',
    String? imagePath,
    Map<String, String>? rels,
    Map<String, dynamic>? passthroughKeys,
  })  : _body = body,
        _extraContent = extraContent,
        _imagePath = imagePath,
        _rels = {...?rels},
        _passthrough = {...?passthroughKeys};

  /// Builds a note from the decoded JSON object of [file]. Missing or
  /// wrong-typed fields degrade to empty rather than throwing: a note is never
  /// "invalid", it just has less in it.
  factory NoteFile.fromJson(
    File file,
    Map<String, dynamic> json, {
    String? imagePath,
  }) {
    final rawRels = json['rels'];
    final relsIsObject = rawRels is Map;
    final rels = <String, String>{};
    if (relsIsObject) {
      rawRels.forEach((k, v) => rels['$k'] = v is String ? v : '$v');
    }

    // Keys we regenerate from our own fields on write. A malformed `rels`
    // (present but not an object) is deliberately left out of this set so it
    // falls through to [_passthrough] and round-trips untouched.
    final owned = {'body', 'extra', if (relsIsObject) 'rels'};

    return NoteFile(
      file: file,
      body: json['body'] is String ? json['body'] as String : '',
      extraContent: json['extra'] is String ? json['extra'] as String : '',
      imagePath: imagePath,
      rels: rels,
      passthroughKeys: {
        for (final entry in json.entries)
          if (!owned.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  final File file;
  String _body;
  String _extraContent;
  String? _imagePath;
  Map<String, String> _rels;
  final Map<String, dynamic> _passthrough;

  String get body => _body;

  String get extraContent => _extraContent;

  /// Opaque metadata attached by external tooling. Never rendered or validated
  /// by this app — only round-tripped to disk. Returns an unmodifiable view;
  /// use [setRels] to change it.
  Map<String, String> get rels => Map.unmodifiable(_rels);

  /// Absolute path of the attached image, or null when the note has none.
  String? get imagePath => _imagePath;

  File? get imageFile {
    final path = _imagePath;
    return path == null ? null : File(path);
  }

  bool get hasImage => _imagePath != null;

  /// Folder that holds every note's image, alongside the notes folder.
  static String imagesDirFor(String notePath) =>
      p.join(p.dirname(notePath), 'images');

  String get _imagesDirPath => imagesDirFor(file.path);

  /// The note's filename without its `.json` extension — the prefix every one
  /// of its image files shares.
  String get _imageStem => p.basenameWithoutExtension(file.path);

  /// A single-line, whitespace-collapsed, truncated preview of [body].
  /// Used anywhere a note needs a compact label — there's no title field.
  String get preview {
    final collapsed = collapseNewlines(_body);
    if (collapsed.isEmpty) return '(empty note)';
    return collapsed.length > 60 ? '${collapsed.substring(0, 60)}…' : collapsed;
  }

  /// The on-disk JSON object. Passthrough keys are emitted first so the fields
  /// this app owns stay visually grouped at the end of a hand-inspected file;
  /// `extra`/`rels` are omitted entirely when empty.
  Map<String, dynamic> toJson() => {
        ..._passthrough,
        'body': _body,
        if (_extraContent.isNotEmpty) 'extra': _extraContent,
        if (_rels.isNotEmpty) 'rels': _rels,
      };

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Serialises the note and writes it via a temp file + rename so a crash
  /// mid-write can't leave a half-written note behind.
  Future<void> save() async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(_encoder.convert(toJson()));
    await tmp.rename(file.path);
  }

  Future<void> setBody(String text) async {
    _body = text;
    await save();
  }

  Future<void> setExtraContent(String text) async {
    _extraContent = text;
    await save();
  }

  /// Replaces the opaque [rels] map and persists it. The app never calls this
  /// itself; it exists so `rels` is a real read/write property rather than a
  /// write-only passenger.
  Future<void> setRels(Map<String, String> value) async {
    _rels = {...value};
    await save();
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
    final tmp = File('${file.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
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
