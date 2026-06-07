import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/note.dart';

/// Renders a Note as Markdown and as a shareable PDF.
class DocumentService {
  /// Build a clean Markdown document from a thinking note.
  static String toMarkdown(Note note) {
    final b = StringBuffer();
    b.writeln('# ${note.title}');
    b.writeln();
    final meta = <String>[];
    if (note.context.isNotEmpty) meta.add(note.context);
    meta.add(note.type.label);
    meta.add(DateFormat('MMM d, yyyy · HH:mm').format(note.createdAt));
    b.writeln('_${meta.join(' · ')}_');
    b.writeln();

    if (note.summary.isNotEmpty) {
      b.writeln('## Summary');
      b.writeln();
      b.writeln(note.summary);
      b.writeln();
    }

    if (note.arc.isNotEmpty) {
      b.writeln('## The arc of your thinking');
      b.writeln();
      for (final p in note.arc) {
        b.writeln('- **${_arcLabel(p.kind)}** — ${p.text}');
      }
      b.writeln();
    }

    if (note.insights.isNotEmpty) {
      b.writeln('## Miko');
      b.writeln();
      for (final i in note.insights) {
        final src = i.source.isNotEmpty ? '  \n  _source: ${i.source}_' : '';
        b.writeln('- **${_insightLabel(i.kind)}** ${i.text}$src');
      }
      b.writeln();
    }

    if (note.tasks.isNotEmpty) {
      b.writeln('## Tasks');
      b.writeln();
      for (final t in note.tasks) {
        b.writeln('- [${t.done ? 'x' : ' '}] ${t.text}');
      }
      b.writeln();
    }

    if (note.questions.isNotEmpty) {
      b.writeln('## Open questions');
      b.writeln();
      for (final q in note.questions) {
        b.writeln('- ${q.text}');
      }
      b.writeln();
    }

    if (note.tags.isNotEmpty) {
      b.writeln(note.tags.map((t) => '#$t').join(' '));
      b.writeln();
    }

    if (note.rawTranscript.isNotEmpty) {
      b.writeln('---');
      b.writeln();
      b.writeln('### Transcript');
      b.writeln();
      b.writeln('> ${note.rawTranscript}');
    }
    return b.toString();
  }

  static String _arcLabel(String kind) {
    switch (kind) {
      case 'start':
        return 'Started with';
      case 'turn':
        return 'Turned to';
      case 'landing':
        return 'Landed on';
      default:
        return 'Touched on';
    }
  }

  static String _insightLabel(String kind) {
    switch (kind) {
      case 'support':
        return '✓ Supports:';
      case 'correction':
        return '✎ Correction:';
      case 'contradiction':
        return '⚡ Contradiction:';
      case 'question':
        return '? Worth asking:';
      case 'stat':
        return '📊 Stat:';
      default:
        return '•';
    }
  }

  /// Build a PDF document (editorial, clean) and return its bytes.
  static Future<Uint8List> toPdf(Note note) async {
    final doc = pw.Document();
    final accent = PdfColor.fromInt(0xFF7C3AED); // mikoPurple
    final ink = PdfColor.fromInt(0xFF1A1A2E); // deepNavy
    final soft = PdfColor.fromInt(0xFF6B7280); // gameboyGray

    final meta = <String>[];
    if (note.context.isNotEmpty) meta.add(note.context);
    meta.add(note.type.label);
    meta.add(DateFormat('MMM d, yyyy · HH:mm').format(note.createdAt));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text(note.title,
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 4),
          pw.Text(meta.join('  ·  '),
              style: pw.TextStyle(fontSize: 10, color: soft)),
          pw.Divider(color: accent, thickness: 2),
          if (note.summary.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfHeader('SUMMARY', accent),
            pw.Text(note.summary, style: pw.TextStyle(fontSize: 12, color: ink)),
          ],
          if (note.arc.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _pdfHeader('THE ARC OF YOUR THINKING', accent),
            ...note.arc.map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                          text: '${_arcLabel(p.kind)}  ',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: accent)),
                      pw.TextSpan(
                          text: p.text,
                          style: pw.TextStyle(fontSize: 12, color: ink)),
                    ]),
                  ),
                )),
          ],
          if (note.insights.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _pdfHeader('MIKO', accent),
            ...note.insights.map((i) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(children: [
                            pw.TextSpan(
                                text: '${_insightLabel(i.kind)} ',
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: ink)),
                            pw.TextSpan(
                                text: i.text,
                                style: pw.TextStyle(fontSize: 12, color: ink)),
                          ]),
                        ),
                        if (i.source.isNotEmpty)
                          pw.Text('source: ${i.source}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: soft,
                                  fontStyle: pw.FontStyle.italic)),
                      ]),
                )),
          ],
          if (note.tasks.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _pdfHeader('TASKS', accent),
            ...note.tasks.map((t) => pw.Text(
                '${t.done ? '☑' : '☐'} ${t.text}',
                style: pw.TextStyle(fontSize: 12, color: ink))),
          ],
          if (note.questions.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _pdfHeader('OPEN QUESTIONS', accent),
            ...note.questions.map((q) => pw.Text('• ${q.text}',
                style: pw.TextStyle(fontSize: 12, color: ink))),
          ],
          if (note.rawTranscript.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Divider(color: soft),
            _pdfHeader('TRANSCRIPT', soft),
            pw.Text(note.rawTranscript,
                style: pw.TextStyle(
                    fontSize: 10, color: soft, fontStyle: pw.FontStyle.italic)),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _pdfHeader(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: color,
                letterSpacing: 1.2)),
      );

  /// Open the OS share sheet with the note rendered as a PDF.
  static Future<void> sharePdf(Note note) async {
    final bytes = await toPdf(note);
    final safe = note.title.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${safe.isEmpty ? 'ramble-note' : safe}.pdf',
    );
  }
}
