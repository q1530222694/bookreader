import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../controller/bookshelf_controller.dart';
import '../service/reading_session_service.dart';

class EpubViewerPage extends StatefulWidget {
  final String title;
  final String filePath;
  final String bookId;
  final BookshelfController? controller;

  const EpubViewerPage({
    super.key,
    required this.title,
    required this.filePath,
    required this.bookId,
    this.controller,
  });

  @override
  State<EpubViewerPage> createState() => _EpubViewerPageState();
}

class _EpubViewerPageState extends State<EpubViewerPage>
    with WidgetsBindingObserver {
  String? _content;
  String? _error;
  final ReadingSessionTracker _session = ReadingSessionTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.start();
    _load();
  }

  @override
  void dispose() {
    _pauseSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pauseSession();
    }
  }

  /// 结束本次阅读会话并记录（开始时间 / 时长 / 是否读完）。
  void _pauseSession() {
    _session.stop(
      bookId: widget.bookId,
      isFinished: () =>
          (widget.controller?.getBook(widget.bookId)?.progress ?? 0) >= 1.0,
      onDuration: (s) => widget.controller?.updateBookReadingDuration(
        widget.bookId,
        s,
      ),
    );
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final htmlFiles = archive.files.where((file) {
        final name = file.name.toLowerCase();
        return file.isFile && (name.endsWith('.xhtml') || name.endsWith('.html') || name.endsWith('.htm'));
      }).toList();

      if (htmlFiles.isEmpty) {
        throw 'EPUB 内未找到可渲染内容';
      }

      htmlFiles.sort((a, b) => a.name.compareTo(b.name));
      final chapter = htmlFiles.first;
      final contentBytes = chapter.content as List<int>;
      final raw = _decodeText(contentBytes);
      final text = _stripHtml(raw);

      if (!mounted) return;
      setState(() {
        _content = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '无法打开 EPUB：$e';
      });
    }
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _stripHtml(String html) {
    final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!))
            : _content == null
                ? const Center(child: CupertinoActivityIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _content!,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
      ),
    );
  }
}
