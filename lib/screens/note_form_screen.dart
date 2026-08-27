import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/note.dart';
import '../repository/note_repository.dart';
import '../widgets/image_viewer.dart';

/// Add/edit form for a single note. When [note] is null this is the "Add"
/// tab: saving writes a new file and clears the field so another note can
/// be added right away. When [note] is set, saving overwrites that note's
/// body and pops back to whichever screen jumped here.
class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({super.key, required this.repository, this.note});

  final NoteRepository repository;
  final NoteFile? note;

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  late final _controller = TextEditingController(text: widget.note?.body ?? '');
  late String _extraContent = widget.note?.extraContent ?? '';

  /// The note's already-saved image, if any.
  late String? _imagePath = widget.note?.imagePath;

  /// A freshly picked image that hasn't been written to disk yet.
  String? _pickedImagePath;

  /// Set when the user removes an existing image; applied on save.
  bool _imageRemoved = false;

  bool _saving = false;

  /// Held-down timer for the clear/cancel button — it must be pressed for
  /// [_resetHoldDuration] before it fires, so a stray tap can't wipe the form.
  static const _resetHoldDuration = Duration(milliseconds: 300);
  Timer? _resetHoldTimer;

  bool get _hasImage =>
      _pickedImagePath != null || (_imagePath != null && !_imageRemoved);

  ImageProvider? get _imageProvider {
    final picked = _pickedImagePath;
    if (picked != null) return FileImage(File(picked));
    final saved = _imagePath;
    if (saved != null && !_imageRemoved) return FileImage(File(saved));
    return null;
  }

  @override
  void dispose() {
    _resetHoldTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startResetHold() {
    if (_saving) return;
    _resetHoldTimer?.cancel();
    _resetHoldTimer = Timer(_resetHoldDuration, () {
      _resetHoldTimer = null;
      if (!mounted || _saving) return;
      if (widget.note != null) {
        Navigator.pop(context);
      } else {
        _clear();
      }
    });
  }

  void _cancelResetHold() {
    _resetHoldTimer?.cancel();
    _resetHoldTimer = null;
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _extraContent = '';
      _pickedImagePath = null;
      _imageRemoved = true;
    });
  }

  Future<void> _editExtraContent() async {
    final controller = TextEditingController(text: _extraContent);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extra content'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 6,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Extra content…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) setState(() => _extraContent = result.trim());
  }

  /// Tapping the image button: with no image, jump straight to the picker;
  /// with one, offer view / replace / remove.
  Future<void> _manageImage() async {
    if (!_hasImage) {
      await _pickImage();
      return;
    }
    final provider = _imageProvider!;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Image'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: Image(image: provider, fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'view'),
            child: const Text('View'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: const Text('Replace'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'remove'),
            child: const Text('Remove'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'close'),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'view':
        await showImageViewer(context, provider);
      case 'replace':
        await _pickImage();
      case 'remove':
        setState(() {
          _pickedImagePath = null;
          _imageRemoved = true;
        });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (!mounted) return;
    final path = result?.files.single.path;
    if (path == null) return;
    final ext = p.extension(path).toLowerCase();
    if (!supportedImageExtensions.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported image type')),
      );
      return;
    }
    final length = await File(path).length();
    if (!mounted) return;
    if (length > maxImageBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large')),
      );
      return;
    }
    setState(() {
      _pickedImagePath = path;
      _imageRemoved = false;
    });
  }

  Future<void> _applyImage(NoteFile note) async {
    final picked = _pickedImagePath;
    if (picked != null) {
      final bytes = await File(picked).readAsBytes();
      await note.setImage(bytes, p.extension(picked).toLowerCase());
    } else if (_imageRemoved && note.hasImage) {
      await note.clearImage();
    }
  }

  Future<void> _save() async {
    final text = collapseNewlines(_controller.text);
    if (text.isEmpty && !_hasImage) return;

    setState(() => _saving = true);
    final note = widget.note;
    final NoteFile target;
    if (note != null) {
      await note.setBody(text);
      await note.setExtraContent(_extraContent);
      target = note;
    } else {
      target = await widget.repository.addNote(text);
      if (_extraContent.isNotEmpty) await target.setExtraContent(_extraContent);
    }
    await _applyImage(target);
    if (!mounted) return;

    if (note != null) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = false;
      _controller.clear();
      _extraContent = '';
      _pickedImagePath = null;
      _imageRemoved = false;
      _imagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    final imageProvider = _imageProvider;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: isEdit,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Write a note…',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Listener(
                onPointerDown: (_) => _startResetHold(),
                onPointerUp: (_) => _cancelResetHold(),
                onPointerCancel: (_) => _cancelResetHold(),
                child: IconButton.outlined(
                  // The hold timer does the work; this keeps the button
                  // enabled-looking and gives tap feedback.
                  onPressed: _saving ? null : () {},
                  tooltip: isEdit ? 'Hold to cancel' : 'Hold to clear',
                  icon: Icon(isEdit ? Icons.close : Icons.backspace_outlined),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _saving ? null : _editExtraContent,
                tooltip: 'Extra content',
                isSelected: _extraContent.isNotEmpty,
                icon: Icon(
                  _extraContent.isEmpty ? Icons.notes_outlined : Icons.notes,
                ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _saving ? null : _manageImage,
                tooltip: 'Image',
                isSelected: _hasImage,
                icon: imageProvider == null
                    ? const Icon(Icons.image_outlined)
                    : SizedBox(
                        width: 24,
                        height: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image(image: imageProvider, fit: BoxFit.cover),
                        ),
                      ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const Spacer(),
              IconButton.filled(
                onPressed: _saving ? null : _save,
                tooltip: isEdit ? 'Save' : 'Add',
                icon: Icon(isEdit ? Icons.check : Icons.add),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
