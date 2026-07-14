import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../controller/bookshelf_controller.dart';
import '../service/reading_session_service.dart';

class ComicViewerPage extends StatefulWidget {
  final String title;
  final String filePath;
  final String bookId;
  final BookshelfController? controller;

  const ComicViewerPage({
    super.key,
    required this.title,
    required this.filePath,
    required this.bookId,
    this.controller,
  });

  @override
  State<ComicViewerPage> createState() => _ComicViewerPageState();
}

class _ComicViewerPageState extends State<ComicViewerPage>
    with WidgetsBindingObserver {
  List<Uint8List> _images = [];
  String? _error;
  final ReadingSessionTracker _session = ReadingSessionTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.start();
    _loadImages();
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

  Future<void> _loadImages() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final imageEntries = archive
          .where((e) => !e.isFile ? false : _isImageName(e.name))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final imgs = <Uint8List>[];
      for (final entry in imageEntries) {
        final data = entry.content as List<int>;
        imgs.add(Uint8List.fromList(data));
      }

      if (!mounted) return;
      setState(() {
        _images = imgs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '无法打开漫画：$e';
      });
    }
  }

  bool _isImageName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!))
            : _images.isEmpty
                ? const Center(child: CupertinoActivityIndicator())
                : PageView.builder(
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Image.memory(
                          _images[index],
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
