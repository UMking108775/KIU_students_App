import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Arguments passed to the background isolate that compresses one image.
class _CompressArgs {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  const _CompressArgs(this.bytes, this.maxDimension, this.quality);
}

/// Runs in a background isolate (via [compute]).
/// Fixes EXIF orientation, downscales large photos, and re-encodes as JPEG so
/// the resulting PDF stays small enough to share over WhatsApp/email.
Uint8List _compressImageIsolate(_CompressArgs args) {
  try {
    img.Image? decoded = img.decodeImage(args.bytes);
    if (decoded == null) {
      // Could not decode (unknown format) – embed the original bytes as-is.
      return args.bytes;
    }

    // Apply rotation stored in EXIF so scanned/gallery pages are upright.
    decoded = img.bakeOrientation(decoded);

    final int longestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;

    if (longestSide > args.maxDimension) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: args.maxDimension);
      } else {
        decoded = img.copyResize(decoded, height: args.maxDimension);
      }
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: args.quality));
  } catch (_) {
    // Never fail the whole PDF because one image misbehaved.
    return args.bytes;
  }
}

/// Builds, stores and manages assignment PDFs created from images.
///
/// Created PDFs are auto-saved to a private "KIU PDFs" folder inside the app's
/// documents directory. That folder powers the in-app "My PDFs" history, so a
/// file is never lost even if the student cancels the "Save As" dialog.
class PdfCreatorService {
  static const String _folderName = 'KIU PDFs';

  /// Longest side (px) each page image is scaled down to before embedding.
  static const int _maxDimension = 1600;

  /// JPEG quality used when re-encoding page images.
  static const int _jpegQuality = 80;

  /// The folder where created PDFs live (created on first use).
  Future<Directory> _pdfDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Creates a PDF (one page per image) and auto-saves it to the KIU PDFs
  /// folder. Returns the saved file. Throws if [imagePaths] is empty.
  Future<File> createPdfFromImages({
    required List<String> imagePaths,
    required String fileName,
  }) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('Cannot create a PDF with no pages.');
    }

    final doc = pw.Document();

    for (final path in imagePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final raw = await file.readAsBytes();
      final compressed = await compute(
        _compressImageIsolate,
        _CompressArgs(raw, _maxDimension, _jpegQuality),
      );

      final pageImage = pw.MemoryImage(compressed);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) => pw.Center(
            child: pw.Image(pageImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final bytes = await doc.save();

    final dir = await _pdfDir();
    final safeName = sanitizeFileName(fileName);
    final target = await _uniqueFile(File('${dir.path}/$safeName.pdf'));
    await target.writeAsBytes(bytes);
    return target;
  }

  /// Saves already-built PDF [bytes] into the KIU PDFs library under a unique,
  /// sanitized name. Used by the PDF Organizer. Returns the saved file.
  Future<File> saveBytesToLibrary(List<int> bytes, String fileName) async {
    final dir = await _pdfDir();
    final safeName = sanitizeFileName(fileName);
    final target = await _uniqueFile(File('${dir.path}/$safeName.pdf'));
    await target.writeAsBytes(bytes);
    return target;
  }

  /// All saved PDFs, newest first.
  Future<List<File>> listSavedPdfs() async {
    final dir = await _pdfDir();
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();

    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  /// Permanently deletes a saved PDF.
  Future<void> deletePdf(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Renames a saved PDF (keeps it inside the KIU PDFs folder).
  /// Returns the renamed file (or the original if the name is unchanged).
  Future<File> renamePdf(File file, String newName) async {
    final dir = await _pdfDir();
    final safeName = sanitizeFileName(newName);
    final target = File('${dir.path}/$safeName.pdf');
    if (target.path == file.path) return file;
    final unique = await _uniqueFile(target);
    return file.rename(unique.path);
  }

  /// Opens the system share sheet (WhatsApp, Gmail, Drive, etc.).
  Future<void> sharePdf(File file, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  /// Opens the system "Save As" dialog (file manager) so the student can save
  /// the PDF to a location of their choice. Returns the chosen path, or null if
  /// the student cancelled.
  Future<String?> saveToDevice(File file) async {
    final params = SaveFileDialogParams(sourceFilePath: file.path);
    return FlutterFileDialog.saveFile(params: params);
  }

  /// Removes characters that are illegal in file names and trims a trailing
  /// ".pdf" the student may have typed. Falls back to a timestamped name.
  String sanitizeFileName(String name) {
    var cleaned = name.trim();
    if (cleaned.toLowerCase().endsWith('.pdf')) {
      cleaned = cleaned.substring(0, cleaned.length - 4).trim();
    }
    cleaned = cleaned.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      cleaned = 'Document';
    }
    // Keep file names reasonably short.
    if (cleaned.length > 60) {
      cleaned = cleaned.substring(0, 60).trim();
    }
    return cleaned;
  }

  /// Display name without the ".pdf" extension.
  static String displayName(File file) {
    final base = file.uri.pathSegments.last;
    return base.toLowerCase().endsWith('.pdf')
        ? base.substring(0, base.length - 4)
        : base;
  }

  /// Human readable file size, e.g. "1.2 MB".
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// If [file] already exists, returns the same path with " (1)", " (2)" …
  /// appended so we never silently overwrite a previous PDF.
  Future<File> _uniqueFile(File file) async {
    if (!await file.exists()) return file;

    final dir = file.parent.path;
    final name = file.uri.pathSegments.last;
    final base = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;

    var counter = 1;
    while (true) {
      final candidate = File('$dir/$base ($counter).pdf');
      if (!await candidate.exists()) return candidate;
      counter++;
    }
  }
}
