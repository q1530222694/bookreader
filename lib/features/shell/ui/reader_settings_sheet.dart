import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/settings_controller.dart';

void _noopBackgroundColorChanged(Color _) {}
void _noopInt(int _) {}
void _noopBool(bool _) {}
void _noopDouble(double _) {}

class ReaderSettingsSheet extends StatefulWidget {
  final int selectedThemeIndex;
  final double brightness;
  final int selectedFontIndex;
  final int selectedPageMode;
  final Color? selectedBackgroundColor;
  final ValueChanged<int> onThemeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<int> onFontChanged;
  final ValueChanged<int> onPageModeChanged;

  // PDF 专属：布局模式（0 单页 / 1 双页 / 2 单页连续 / 3 双页连续）
  final int selectedLayoutMode;
  final ValueChanged<int> onLayoutModeChanged;
  // PDF 专属：自动裁切
  final bool autoCrop;
  final ValueChanged<bool> onAutoCropChanged;
  // PDF 专属：背景调节（亮度外的对比度 / 饱和度 / 去色 / 去杂色）
  final double contrast;
  final ValueChanged<double> onContrastChanged;
  final double saturation;
  final ValueChanged<double> onSaturationChanged;
  final bool removeColor;
  final ValueChanged<bool> onRemoveColorChanged;
  final bool denoise;
  final ValueChanged<bool> onDenoiseChanged;

  final bool isPdfReader;
  final VoidCallback onClose;
  final VoidCallback? onAddTag;

  const ReaderSettingsSheet({
    super.key,
    required this.selectedThemeIndex,
    required this.brightness,
    required this.selectedFontIndex,
    required this.selectedPageMode,
    this.selectedBackgroundColor,
    required this.onThemeChanged,
    required this.onBrightnessChanged,
    required this.onFontChanged,
    required this.onPageModeChanged,
    this.selectedLayoutMode = 0,
    this.onLayoutModeChanged = _noopInt,
    this.autoCrop = false,
    this.onAutoCropChanged = _noopBool,
    this.contrast = 1.0,
    this.onContrastChanged = _noopDouble,
    this.saturation = 1.0,
    this.onSaturationChanged = _noopDouble,
    this.removeColor = false,
    this.onRemoveColorChanged = _noopBool,
    this.denoise = false,
    this.onDenoiseChanged = _noopBool,
    this.isPdfReader = false,
    this.onBackgroundColorChanged = _noopBackgroundColorChanged,
    required this.onClose,
    this.onAddTag,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  bool _showMoreSettings = false;
  bool _showAppearanceSettings = false;

  Color _resolveThemeColor(String themeColor) {
    switch (themeColor) {
      case SettingsEngine.themeColorGreen:
        return CupertinoColors.activeGreen;
      case SettingsEngine.themeColorPink:
        return CupertinoColors.systemPink;
      case SettingsEngine.themeColorOrange:
        return CupertinoColors.systemOrange;
      case SettingsEngine.themeColorPurple:
        return CupertinoColors.systemIndigo;
      case SettingsEngine.themeColorRed:
        return CupertinoColors.systemRed;
      case SettingsEngine.themeColorBlue:
      default:
        return CupertinoColors.activeBlue;
    }
  }

  Widget _buildPdfReaderSheet(
    BuildContext context,
    Color primaryColor,
    List<_ThemeOption> themeOptions,
    int selectedIndex,
    Color effectiveBackgroundColor,
  ) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);

    // 设置面板最高占屏幕 3/4，内容超出时内部滚动
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        minSize: 0,
                        onPressed: () {},
                        child: Icon(
                          CupertinoIcons.search,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          LocalizationEngine.text('reader_settings'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        minSize: 0,
                        onPressed: widget.onAddTag ?? widget.onClose,
                        child: Icon(
                          CupertinoIcons.add,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_showAppearanceSettings) ...[
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'theme_color'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: themeOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final isSelected = index == selectedIndex;
                          return GestureDetector(
                            onTap: () {
                              widget.onThemeChanged(index);
                              SettingsController.setThemeColor(
                                themeOptions[index].keyValue,
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: themeOptions[index].color,
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : borderColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          size: 16,
                                          color: primaryColor,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 54,
                                  child: Text(
                                    themeOptions[index].label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: secondaryColor,
                                      fontSize: 11,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle(context, 'reader_background'),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildBackgroundOptions(
                          effectiveBackgroundColor,
                          primaryColor,
                          secondaryColor,
                          borderColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle(context, 'reader_brightness'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(CupertinoIcons.sun_max,
                            size: 18, color: primaryColor),
                        Expanded(
                          child: CupertinoSlider(
                            value: widget.brightness,
                            min: 0.3,
                            max: 1.5,
                            onChanged: widget.onBrightnessChanged,
                            activeColor: primaryColor,
                            thumbColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 翻页方式：由「更多」移入「外观」，置于亮度下方
                    _sectionTitle(context, 'reader_page_turn'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PageModeChip(
                          icon: CupertinoIcons.book,
                          label: LocalizationEngine.text(
                            'reader_page_turn_horizontal',
                          ),
                          selected: widget.selectedPageMode == 0,
                          onPressed: () => widget.onPageModeChanged(0),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: CupertinoIcons.square_stack_3d_up,
                          label: LocalizationEngine.text(
                            'reader_page_turn_vertical',
                          ),
                          selected: widget.selectedPageMode == 1,
                          onPressed: () => widget.onPageModeChanged(1),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: CupertinoIcons.sparkles,
                          label: LocalizationEngine.text(
                            'reader_page_turn_simulation',
                          ),
                          selected: widget.selectedPageMode == 2,
                          onPressed: () => widget.onPageModeChanged(2),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.motion_photos_on,
                          label: LocalizationEngine.text('reader_page_turn_none'),
                          selected: widget.selectedPageMode == 3,
                          onPressed: () => widget.onPageModeChanged(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 布局模式：与翻页方式风格一致
                    _sectionTitle(context, 'reader_layout'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PageModeChip(
                          icon: Icons.filter_1,
                          label: LocalizationEngine.text('reader_layout_single'),
                          selected: widget.selectedLayoutMode == 0,
                          onPressed: () => widget.onLayoutModeChanged(0),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.filter_2,
                          label: LocalizationEngine.text('reader_layout_double'),
                          selected: widget.selectedLayoutMode == 1,
                          onPressed: () => widget.onLayoutModeChanged(1),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.view_stream,
                          label: LocalizationEngine.text(
                            'reader_layout_single_continuous',
                          ),
                          selected: widget.selectedLayoutMode == 2,
                          onPressed: () => widget.onLayoutModeChanged(2),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.view_module,
                          label: LocalizationEngine.text(
                            'reader_layout_double_continuous',
                          ),
                          selected: widget.selectedLayoutMode == 3,
                          onPressed: () => widget.onLayoutModeChanged(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_showMoreSettings) ...[
                    const SizedBox(height: 12),
                    // 自动裁切
                    _SwitchRow(
                      label: LocalizationEngine.text('pdf_auto_crop'),
                      description: LocalizationEngine.text('pdf_auto_crop_desc'),
                      value: widget.autoCrop,
                      onChanged: widget.onAutoCropChanged,
                    ),
                    const SizedBox(height: 12),
                    // 背景调节（仅 PDF 扫描件）
                    _sectionTitle(context, 'pdf_bg_adjust'),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: LocalizationEngine.text('pdf_bg_contrast'),
                      value: widget.contrast,
                      min: 0.5,
                      max: 2.0,
                      displayValue: widget.contrast.toStringAsFixed(2),
                      onChanged: widget.onContrastChanged,
                    ),
                    const SizedBox(height: 10),
                    _SliderRow(
                      label: LocalizationEngine.text('pdf_bg_saturation'),
                      value: widget.saturation,
                      min: 0.0,
                      max: 2.0,
                      displayValue: widget.saturation.toStringAsFixed(2),
                      onChanged: widget.onSaturationChanged,
                    ),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      label: LocalizationEngine.text('pdf_bg_remove_color'),
                      description:
                          LocalizationEngine.text('pdf_bg_remove_color_desc'),
                      value: widget.removeColor,
                      onChanged: widget.onRemoveColorChanged,
                    ),
                    const SizedBox(height: 8),
                    _SwitchRow(
                      label: LocalizationEngine.text('pdf_bg_denoise'),
                      description: LocalizationEngine.text('pdf_bg_denoise_desc'),
                      value: widget.denoise,
                      onChanged: widget.onDenoiseChanged,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BottomNavItem(
                        icon: CupertinoIcons.book,
                        label: LocalizationEngine.text('reader_nav_catalog'),
                      ),
                      _BottomNavItem(
                        icon: CupertinoIcons.chart_bar_circle,
                        label: LocalizationEngine.text('reader_nav_progress'),
                      ),
                      _BottomNavItem(
                        icon: CupertinoIcons.square_list,
                        label: LocalizationEngine.text('reader_nav_notes'),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _showAppearanceSettings = !_showAppearanceSettings;
                          if (_showAppearanceSettings) {
                            _showMoreSettings = false;
                          }
                        }),
                        child: _BottomNavItem(
                          icon: CupertinoIcons.paintbrush,
                          label: LocalizationEngine.text('appearance'),
                          active: _showAppearanceSettings,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _showMoreSettings = !_showMoreSettings;
                          if (_showMoreSettings) {
                            _showAppearanceSettings = false;
                          }
                        }),
                        child: _BottomNavItem(
                          icon: CupertinoIcons.ellipsis,
                          label: LocalizationEngine.text('reader_nav_more'),
                          active: _showMoreSettings,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 设置分区标题（统一字号 / 字重 / 主题色，无硬编码）。
  Widget _sectionTitle(BuildContext context, String key) {
    return Text(
      LocalizationEngine.text(key),
      style: TextStyle(
        color: CupertinoColors.label.resolveFrom(context),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  List<Widget> _buildBackgroundOptions(
    Color effectiveBackgroundColor,
    Color primaryColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    final backgroundOptions = <_BackgroundColorOption>[
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_white'),
        color: const Color(0xFFFFFFFF),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_beige'),
        color: const Color(0xFFF3E5D6),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_gray'),
        color: const Color(0xFFF2F2F2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_yellow'),
        color: const Color(0xFFF7F0C3),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_green'),
        color: const Color(0xFFE4F2E2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_blue'),
        color: const Color(0xFFE7F1FC),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_dark'),
        color: const Color(0xFF2C2C2C),
      ),
    ];

    return backgroundOptions.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = effectiveBackgroundColor == option.color;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          key: ValueKey('reader_background_color_$index'),
          onTap: () {
            widget.onBackgroundColorChanged(option.color);
            SettingsController.setReaderBackgroundColor(option.color);
          },
          child: SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.color,
                    border: Border.all(
                      color: isSelected ? primaryColor : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 9,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final effectiveBackgroundColor =
        widget.selectedBackgroundColor ?? SettingsController.readerBackgroundColor.value;

    final themeOptions = <_ThemeOption>[
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_blue'),
        color: _resolveThemeColor(SettingsEngine.themeColorBlue),
        keyValue: SettingsEngine.themeColorBlue,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_green'),
        color: _resolveThemeColor(SettingsEngine.themeColorGreen),
        keyValue: SettingsEngine.themeColorGreen,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_pink'),
        color: _resolveThemeColor(SettingsEngine.themeColorPink),
        keyValue: SettingsEngine.themeColorPink,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_orange'),
        color: _resolveThemeColor(SettingsEngine.themeColorOrange),
        keyValue: SettingsEngine.themeColorOrange,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_purple'),
        color: _resolveThemeColor(SettingsEngine.themeColorPurple),
        keyValue: SettingsEngine.themeColorPurple,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_red'),
        color: _resolveThemeColor(SettingsEngine.themeColorRed),
        keyValue: SettingsEngine.themeColorRed,
      ),
    ];

    final resolvedSelectedIndex = themeOptions.indexWhere(
      (option) => option.keyValue == SettingsController.themeColor.value,
    );
    final selectedIndex = resolvedSelectedIndex >= 0
        ? resolvedSelectedIndex
        : widget.selectedThemeIndex.clamp(0, themeOptions.length - 1);

    if (widget.isPdfReader) {
      return _buildPdfReaderSheet(
        context,
        primaryColor,
        themeOptions,
        selectedIndex,
        effectiveBackgroundColor,
      );
    }

    final backgroundOptions = <_BackgroundColorOption>[
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_white'),
        color: const Color(0xFFFFFFFF),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_beige'),
        color: const Color(0xFFF3E5D6),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_gray'),
        color: const Color(0xFFF2F2F2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_yellow'),
        color: const Color(0xFFF7F0C3),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_green'),
        color: const Color(0xFFE4F2E2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_blue'),
        color: const Color(0xFFE7F1FC),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_dark'),
        color: const Color(0xFF2C2C2C),
      ),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.themeColor,
      builder: (context, currentThemeColor, child) {
        final resolvedSelectedIndex = themeOptions.indexWhere(
          (option) => option.keyValue == currentThemeColor,
        );
        final selectedIndex = resolvedSelectedIndex >= 0
            ? resolvedSelectedIndex
            : widget.selectedThemeIndex.clamp(0, themeOptions.length - 1);

        return ValueListenableBuilder<Color>(
          valueListenable: SettingsController.readerBackgroundColor,
          builder: (context, currentBackgroundColor, child) {
            return ColoredBox(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(4),
                            minSize: 0,
                            onPressed: () {},
                            child: Icon(
                              CupertinoIcons.search,
                              size: 20,
                              color: primaryColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              LocalizationEngine.text('reader_settings'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(4),
                            minSize: 0,
                            onPressed: widget.onAddTag ?? widget.onClose,
                            child: Icon(
                              CupertinoIcons.add,
                              size: 20,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocalizationEngine.text('theme_color'),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 70,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: themeOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final isSelected = index == selectedIndex;
                            return GestureDetector(
                              onTap: () {
                                widget.onThemeChanged(index);
                                SettingsController.setThemeColor(
                                  themeOptions[index].keyValue,
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: themeOptions[index].color,
                                      border: Border.all(
                                        color: isSelected ? primaryColor : borderColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color: primaryColor,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: 54,
                                    child: Text(
                                      themeOptions[index].label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 11,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocalizationEngine.text('reader_background'),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: backgroundOptions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = effectiveBackgroundColor == option.color;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                key: ValueKey('reader_background_color_$index'),
                                onTap: () {
                                  widget.onBackgroundColorChanged(option.color);
                                  SettingsController.setReaderBackgroundColor(option.color);
                                },
                                child: SizedBox(
                                  width: 46,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: option.color,
                                          border: Border.all(
                                            color: isSelected ? primaryColor : borderColor,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        option.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: secondaryColor,
                                          fontSize: 9,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocalizationEngine.text('reader_brightness'),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(CupertinoIcons.sun_max, size: 18, color: primaryColor),
                          Expanded(
                            child: CupertinoSlider(
                              value: widget.brightness,
                              onChanged: widget.onBrightnessChanged,
                              activeColor: primaryColor,
                              thumbColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (_showMoreSettings) ...[
                        const SizedBox(height: 10),
                        if (!widget.isPdfReader) ...[
                          Text(
                            LocalizationEngine.text('reader_font'),
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _FontChip(
                                label: LocalizationEngine.text('reader_font_default'),
                                selected: widget.selectedFontIndex == 0,
                                onPressed: () => widget.onFontChanged(0),
                              ),
                              const SizedBox(width: 10),
                              _FontChip(
                                label: '100%',
                                selected: widget.selectedFontIndex == 1,
                                onPressed: () => widget.onFontChanged(1),
                              ),
                              const SizedBox(width: 10),
                              _FontChip(
                                label: LocalizationEngine.text('reader_font_large'),
                                selected: widget.selectedFontIndex == 2,
                                onPressed: () => widget.onFontChanged(2),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          LocalizationEngine.text('reader_page_turn'),
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _PageModeChip(
                              icon: CupertinoIcons.book,
                              label: LocalizationEngine.text(
                                'reader_page_turn_horizontal',
                              ),
                              selected: widget.selectedPageMode == 0,
                              onPressed: () => widget.onPageModeChanged(0),
                            ),
                            const SizedBox(width: 8),
                            _PageModeChip(
                              icon: CupertinoIcons.square_stack_3d_up,
                              label: LocalizationEngine.text('reader_page_turn_vertical'),
                              selected: widget.selectedPageMode == 1,
                              onPressed: () => widget.onPageModeChanged(1),
                            ),
                            const SizedBox(width: 8),
                            _PageModeChip(
                              icon: CupertinoIcons.sparkles,
                              label: LocalizationEngine.text(
                                'reader_page_turn_simulation',
                              ),
                              selected: widget.selectedPageMode == 2,
                              onPressed: () => widget.onPageModeChanged(2),
                            ),
                            const SizedBox(width: 8),
                            _PageModeChip(
                              icon: Icons.motion_photos_on,
                              label: LocalizationEngine.text('reader_page_turn_none'),
                              selected: widget.selectedPageMode == 3,
                              onPressed: () => widget.onPageModeChanged(3),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _BottomNavItem(
                              icon: CupertinoIcons.book,
                              label: LocalizationEngine.text('reader_nav_catalog'),
                            ),
                            _BottomNavItem(
                              icon: CupertinoIcons.chart_bar_circle,
                              label: LocalizationEngine.text('reader_nav_progress'),
                            ),
                            _BottomNavItem(
                              icon: CupertinoIcons.square_list,
                              label: LocalizationEngine.text('reader_nav_notes'),
                            ),
                            _BottomNavItem(
                              icon: CupertinoIcons.paintbrush,
                              label: LocalizationEngine.text('appearance'),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showMoreSettings = !_showMoreSettings),
                              child: _BottomNavItem(
                                icon: CupertinoIcons.ellipsis,
                                label: LocalizationEngine.text('reader_nav_more'),
                                active: _showMoreSettings,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ThemeOption {
  final String label;
  final Color color;
  final String keyValue;

  const _ThemeOption({
    required this.label,
    required this.color,
    required this.keyValue,
  });
}

class _BackgroundColorOption {
  final String label;
  final Color color;

  const _BackgroundColorOption({required this.label, required this.color});
}

class _FontChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _FontChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.12)
                : CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? primaryColor : borderColor),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? primaryColor
                  : CupertinoColors.label.resolveFrom(context),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _PageModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.12)
                : CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? primaryColor : borderColor),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? primaryColor
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? primaryColor
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _BottomNavItem({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final color = active ? primaryColor : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, color: color)),
      ],
    );
  }
}

/// 带标题与描述的开关行（用于自动裁切 / 去除颜色 / 智能去杂色）。
class _SwitchRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: TextStyle(color: secondaryColor, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: primaryColor,
        ),
      ],
    );
  }
}

/// 带数值显示的滑块行（用于对比度 / 饱和度）。
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              displayValue,
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CupertinoSlider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: primaryColor,
          thumbColor: primaryColor,
        ),
      ],
    );
  }
}
