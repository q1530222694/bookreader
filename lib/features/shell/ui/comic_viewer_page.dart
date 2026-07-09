import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

class ComicViewerPage extends StatefulWidget {
  final String title;
  final String filePath;

  const ComicViewerPage({super.key, required this.title, required this.filePath});

  @override
  State<ComicViewerPage> createState() => _ComicViewerPageState();
}

class _ComicViewerPageState extends State<ComicViewerPage> {
  List<Uint8List> _images = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImages();
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
