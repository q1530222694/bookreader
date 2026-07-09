import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TxtViewerPage extends StatefulWidget {
  final String title;
  final String filePath;

  const TxtViewerPage({super.key, required this.title, required this.filePath});

  @override
  State<TxtViewerPage> createState() => _TxtViewerPageState();
}

class _TxtViewerPageState extends State<TxtViewerPage> {
  String? _content;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      if (!mounted) return;
      setState(() {
        _content = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _content = '无法读取文本文件：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(
        child: _content == null
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
