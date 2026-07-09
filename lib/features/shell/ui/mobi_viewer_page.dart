import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MobiViewerPage extends StatefulWidget {
  final String title;
  final String filePath;

  const MobiViewerPage({super.key, required this.title, required this.filePath});

  @override
  State<MobiViewerPage> createState() => _MobiViewerPageState();
}

class _MobiViewerPageState extends State<MobiViewerPage> {
  String? _textData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final utf8Text = _decodeUtf8(bytes);
      final lower = utf8Text.toLowerCase();
      if (lower.contains('<html') || lower.contains('<body')) {
        _textData = _stripHtml(utf8Text);
      } else {
        final fallback = latin1.decode(bytes);
        final newlineCount = '\n'.allMatches(fallback).length;
        _textData = newlineCount > 5 ? fallback : utf8Text;
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '无法解析 MOBI：$e';
      });
    }
  }

  String _stripHtml(String html) {
    final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!))
            : _textData == null
                ? const Center(child: CupertinoActivityIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _textData!,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
      ),
    );
  }
}
