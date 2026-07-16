import 'dart:io';

import 'package:bookreader/engine/localization_engine.dart';
import 'package:bookreader/engine/settings_engine.dart';
import 'package:bookreader/features/shell/controller/settings_controller.dart';
import 'package:bookreader/features/shell/ui/book_viewer_page.dart';
import 'package:bookreader/features/shell/ui/reader_settings_sheet.dart';
import 'package:bookreader/features/shell/ui/txt_viewer_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _noopInt(int _) {}
void _noopDouble(double _) {}
void _noopColor(Color _) {}
void _noopBool(bool _) {}
void _noop() {}

void main() {
  testWidgets(
    'TxtViewerPage renders the loaded text content',
    (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('txt_viewer_test');
      addTearDown(() async => tempDir.delete(recursive: true));

      final file = File('${tempDir.path}/sample.txt');
      await file.writeAsString('这是一本可阅读的书');

      await tester.pumpWidget(
        CupertinoApp(
          home: TxtViewerPage(title: 'Sample', filePath: file.path, bookId: 'dummy'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SelectableText), findsOneWidget);
    },
  );

  testWidgets(
    'TxtViewerPage shows the reader settings sheet when tapped near the center',
    (tester) async {
      final tempDir = await Directory.systemTemp.createTemp(
        'txt_viewer_test_sheet',
      );
      addTearDown(() async => tempDir.delete(recursive: true));

      final file = File('${tempDir.path}/sample.txt');
      await file.writeAsString('这是一本可阅读的书');

      await tester.pumpWidget(
        CupertinoApp(
          home: TxtViewerPage(title: 'Sample', filePath: file.path, bookId: 'dummy'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('txt_reader_center_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('阅读设置'), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    },
  );

  testWidgets('BookViewerPage hides top return bar and bottom page controls', (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('book_viewer_test_pdf');
    addTearDown(() async => tempDir.delete(recursive: true));

    final file = File('${tempDir.path}/sample.pdf');
    await file.writeAsString('not-a-real-pdf');

    await tester.pumpWidget(
      CupertinoApp(
        home: BookViewerPage(
          title: 'Sample PDF',
          filePath: file.path,
          bookId: 'book-1',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(CupertinoIcons.back), findsNothing);
    expect(find.byIcon(CupertinoIcons.forward), findsNothing);
    expect(find.text('--/--'), findsNothing);
  });

  testWidgets('ReaderSettingsSheet uses compact layout spacing', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: ReaderSettingsSheet(
            selectedThemeIndex: 1,
            brightness: 0.8,
            selectedFontIndex: 0,
            selectedPageMode: 0,
            selectedBackgroundColor: const Color(0xFFFFFFFF),
            onThemeChanged: _noopInt,
            onBrightnessChanged: _noopDouble,
            onFontChanged: _noopInt,
            onPageModeChanged: _noopInt,
            onBackgroundColorChanged: _noopColor,
            onClose: _noop,
            bookId: 'test',
            totalPages: 100,
            currentPage: 1,
            onJumpToPage: _noopInt,
            onToggleLandscape: _noopBool,
          ),
        ),
      ),
    );

    final outerPadding = tester.widgetList<Padding>(find.byType(Padding)).firstWhere(
      (widget) =>
          widget.padding is EdgeInsets &&
          (widget.padding as EdgeInsets).left == 16 &&
          (widget.padding as EdgeInsets).right == 16 &&
          (widget.padding as EdgeInsets).top == 6 &&
          (widget.padding as EdgeInsets).bottom == 12,
      orElse: () => const Padding(padding: EdgeInsets.zero),
    );

    final edgeInsets = outerPadding.padding as EdgeInsets;
    expect(edgeInsets.top, lessThan(10));
    expect(edgeInsets.bottom, lessThan(16));
  });

  testWidgets('ReaderSettingsSheet syncs theme color with app settings', (tester) async {
    SettingsController.setThemeColor(SettingsEngine.themeColorBlue);

    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: ReaderSettingsSheet(
            selectedThemeIndex: 0,
            brightness: 0.8,
            selectedFontIndex: 0,
            selectedPageMode: 0,
            selectedBackgroundColor: Color(0xFFFFFFFF),
            onThemeChanged: _noopInt,
            onBrightnessChanged: _noopDouble,
            onFontChanged: _noopInt,
            onPageModeChanged: _noopInt,
            onBackgroundColorChanged: _noopColor,
            onClose: _noop,
            bookId: 'test',
            totalPages: 100,
            currentPage: 1,
            onJumpToPage: _noopInt,
            onToggleLandscape: _noopBool,
          ),
        ),
      ),
    );

    await tester.tap(find.text(LocalizationEngine.text('theme_color_green')));
    await tester.pump();

    expect(SettingsController.themeColor.value, SettingsEngine.themeColorGreen);
  });

  testWidgets('ReaderSettingsSheet allows selecting a reading background color', (tester) async {
    Color? selectedColor;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ReaderSettingsSheet(
            selectedThemeIndex: 0,
            brightness: 0.8,
            selectedFontIndex: 0,
            selectedPageMode: 0,
            selectedBackgroundColor: const Color(0xFFFFFFFF),
            onThemeChanged: _noopInt,
            onBrightnessChanged: _noopDouble,
            onFontChanged: _noopInt,
            onPageModeChanged: _noopInt,
            onBackgroundColorChanged: (color) => selectedColor = color,
            onClose: _noop,
            bookId: 'test',
            totalPages: 100,
            currentPage: 1,
            onJumpToPage: _noopInt,
            onToggleLandscape: _noopBool,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('reader_background_color_1')));
    await tester.pump();

    expect(selectedColor, const Color(0xFFF3E5D6));
  });
}
