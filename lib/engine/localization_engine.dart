import 'settings_engine.dart';

/// LocalizationEngine provides minimal translation support for Chinese and English.
class LocalizationEngine {
  LocalizationEngine._();

  static final Map<String, String> _traditionalChineseMap = <String, String>{
    '页': '頁',
    '书': '書',
    '架': '架',
    '回': '回',
    '忆': '憶',
    '录': '錄',
    '具': '具',
    '账': '帳',
    '号': '號',
    '与': '與',
    '设': '設',
    '置': '置',
    '欢': '歡',
    '迎': '迎',
    '来': '來',
    '后': '後',
    '续': '續',
    '补': '補',
    '齐': '齊',
    '开': '開',
    '通': '通',
    '级': '級',
    '会': '會',
    '员': '員',
    '为': '為',
    '权': '權',
    '限': '限',
    '云': '雲',
    '端': '端',
    '决': '決',
    '定': '定',
    '启': '啟',
    '检': '檢',
    '查': '查',
    '务': '務',
    '器': '器',
    '户': '戶',
    '径': '徑',
    '网': '網',
    '络': '絡',
    '显': '顯',
    '示': '示',
    '符': '符',
    '秒': '秒',
    '义': '義',
    '请': '請',
    '输': '輸',
    '时': '時',
    '长': '長',
    '选': '選',
    '择': '擇',
    '应': '應',
    '个': '個',
    '于': '於',
    '动': '動',
    '丰': '豐',
    '富': '富',
    '优': '優',
    '序': '序',
    '页': '頁',
    '简': '簡',
    '体': '體',
    '应': '應',
    '文': '文',
    '配': '配',
    '色': '色',
    '设': '設',
    '置': '置',
    '程': '程',
    '式': '式',
    '始': '始',
    '页': '頁',
    '信': '信',
    '息': '息',
    '息': '息',
    '容': '容',
    '周': '週',
    '到': '到',
    '版': '版',
    '本': '本',
    '目': '目',
    '录': '錄',
    '窗': '窗',
    '口': '口',
    '场': '場',
    '景': '景',
    '强': '強',
    '制': '制',
    '度': '度',
    '计': '計',
    '算': '算',
    '外': '外',
    '观': '觀',
    '感': '感',
    '应': '應',
    '用': '用',
    '整': '整',
    '体': '體',
  };

  static const Map<String, Map<String, String>> _translations = {
    'home': {'zh': '主页', 'en': 'Home'},
    'bookshelf': {'zh': '书架', 'en': 'Bookshelf'},
    'memory': {'zh': '回忆', 'en': 'Memory'},
    'tools': {'zh': '工具', 'en': 'Tools'},
    // 工具页分类与工具文案（数据驱动，避免 UI 硬编码中文）
    'tools_cat_ebook': {'zh': '电子书转换', 'en': 'E-Book'},
    'tools_cat_pdf': {'zh': '转 PDF', 'en': 'To PDF'},
    'tool_txt_epub_title': {'zh': 'TXT 转 EPUB', 'en': 'TXT to EPUB'},
    'tool_txt_epub_sub': {'zh': '文本文件转电子书', 'en': 'Convert text files to e-book'},
    'tool_doc_pdf_title': {'zh': 'DOC 转 PDF', 'en': 'DOC to PDF'},
    'tool_doc_pdf_sub': {'zh': 'Word 文档转 PDF', 'en': 'Convert Word documents to PDF'},
    'tool_ppt_pdf_title': {'zh': 'PPT 转 PDF', 'en': 'PPT to PDF'},
    'tool_ppt_pdf_sub': {'zh': '幻灯片转 PDF', 'en': 'Convert slides to PDF'},
    'tool_xls_pdf_title': {'zh': 'Excel 转 PDF', 'en': 'Excel to PDF'},
    'tool_xls_pdf_sub': {'zh': '表格转 PDF', 'en': 'Export spreadsheets to PDF'},
    'tool_img_pdf_title': {'zh': '图片转 PDF', 'en': 'Image to PDF'},
    'tool_img_pdf_sub': {'zh': '图片合并导出', 'en': 'Merge images into PDF'},
    // 统一转换页文案（txt/doc/ppt/excel/image 五页共用，避免 UI 硬编码）
    'conv_tab_convert': {'zh': '转换', 'en': 'Convert'},
    'conv_tab_records': {'zh': '记录', 'en': 'Records'},
    'conv_select_file': {'zh': '选择文件', 'en': 'Select File'},
    'conv_select_txt': {'zh': '选择 TXT 文件', 'en': 'Select TXT File'},
    'conv_select_doc': {'zh': '选择 DOC / DOCX 文件', 'en': 'Select DOC / DOCX File'},
    'conv_select_ppt': {'zh': '选择 PPT / PPTX 文件', 'en': 'Select PPT / PPTX File'},
    'conv_select_excel': {'zh': '选择 XLS / XLSX 文件', 'en': 'Select XLS / XLSX File'},
    'conv_select_images': {'zh': '选择图片（支持多选）', 'en': 'Select Images (multi-select)'},
    'conv_start': {'zh': '开始转换', 'en': 'Start Convert'},
    'conv_converting': {'zh': '转换中…', 'en': 'Converting…'},
    'conv_selected_file': {'zh': '已选择文件', 'en': 'Selected file'},
    'conv_open': {'zh': '打开', 'en': 'Open'},
    'conv_view': {'zh': '查看', 'en': 'View'},
    'conv_add_shelf': {'zh': '加入书架', 'en': 'Add to Shelf'},
    'conv_added_shelf': {'zh': '已加入书架', 'en': 'Added to Shelf'},
    'conv_no_record': {'zh': '还没有转换记录', 'en': 'No conversion records yet'},
    'conv_delete': {'zh': '删除', 'en': 'Delete'},
    'conv_delete_confirm_title': {'zh': '删除记录', 'en': 'Delete Record'},
    'conv_delete_confirm_msg': {
      'zh': '确定要删除这条记录及其文件吗？此操作不可撤销。',
      'en': 'Delete this record and its file? This cannot be undone.'
    },
    'conv_cancel': {'zh': '取消', 'en': 'Cancel'},
    'conv_open_failed': {'zh': '打开失败', 'en': 'Failed to open'},
    'conv_file_not_found': {'zh': '文件不存在', 'en': 'File not found'},
    'conv_tip_txt': {
      'zh': '选择一个 TXT 文本文件，即可快速生成可在阅读器中打开的 EPUB 电子书。',
      'en': 'Pick a TXT file to quickly generate an EPUB e-book for the reader.'
    },
    'conv_tip_doc': {
      'zh': '选择 Word 文档（DOC / DOCX），转换为可分享的 PDF 文件。',
      'en': 'Pick a Word document (DOC / DOCX) and convert it to a shareable PDF.'
    },
    'conv_tip_ppt': {
      'zh': '选择演示文稿（PPT / PPTX），提取内容并生成 PDF。',
      'en': 'Pick a presentation (PPT / PPTX) to extract content into a PDF.'
    },
    'conv_tip_excel': {
      'zh': '选择电子表格（XLS / XLSX），导出为 PDF 文件。',
      'en': 'Pick a spreadsheet (XLS / XLSX) and export it as a PDF.'
    },
    'conv_tip_image': {
      'zh': '选择多张图片，将按显示顺序合并为一个 PDF。拖动可重新排序，点按右上角 × 可移除。',
      'en': 'Select multiple images to merge into one PDF in order. Drag to reorder, tap × to remove.'
    },
    'conv_selected_count': {'zh': '已选择 %d 张图片', 'en': '%d image(s) selected'},
    'conv_image_count': {'zh': '%d 张图片', 'en': '%d image(s)'},
    'conv_convert_failed': {'zh': '转换失败', 'en': 'Conversion failed'},
    'profile': {'zh': '我的', 'en': 'Profile'},
    'daily_sentence': {'zh': '每日一句', 'en': 'Daily Sentence'},
    'recently_reading': {'zh': '最近阅读', 'en': 'Recently Read'},
    'reader_settings': {'zh': '阅读设置', 'en': 'Reading Settings'},
    'reader_reset': {'zh': '重置', 'en': 'Reset'},
    'reader_theme': {'zh': '主题', 'en': 'Theme'},
    'reader_theme_system': {'zh': '跟随系统', 'en': 'System'},
    'reader_theme_light': {'zh': '浅色', 'en': 'Light'},
    'reader_theme_eyegreen': {'zh': '护眼绿', 'en': 'Eye Green'},
    'reader_theme_beige': {'zh': '米色', 'en': 'Beige'},
    'reader_theme_dark': {'zh': '深色', 'en': 'Dark'},
    'reader_brightness': {'zh': '亮度', 'en': 'Brightness'},
    'reader_font': {'zh': '字体', 'en': 'Font'},
    'reader_font_system': {'zh': '系统字体', 'en': 'System Font'},
    'reader_font_default': {'zh': 'A-', 'en': 'A-'},
    'reader_font_large': {'zh': 'A+', 'en': 'A+'},
    'reader_page_turn': {'zh': '翻页方式', 'en': 'Page Turn'},
    'reader_page_turn_swipe_h': {'zh': '左右滑动', 'en': 'Swipe L/R'},
    'reader_page_turn_swipe_v': {'zh': '上下滑动', 'en': 'Swipe U/D'},
    'reader_page_turn_tap_h': {'zh': '左右单击', 'en': 'Tap L/R'},
    'reader_page_turn_tap_v': {'zh': '上下单击', 'en': 'Tap U/D'},
    'reader_page_turn_tap_scroll': {'zh': '单击滚动', 'en': 'Tap & Scroll'},
    'reader_page_animation': {'zh': '翻页动画', 'en': 'Page Animation'},
    'reader_page_animation_none': {'zh': '无动画', 'en': 'None'},
    'reader_page_animation_simulation': {'zh': '仿真动画', 'en': 'Simulation'},
    'reader_page_animation_fade': {'zh': '淡入淡出', 'en': 'Fade'},
    'reader_page_animation_overlap': {'zh': '叠加', 'en': 'Overlap'},
    'reader_page_animation_jump': {'zh': '跃动', 'en': 'Jump'},
    'reader_page_animation_rotate': {'zh': '旋转', 'en': 'Rotate'},
    'reader_page_animation_carousel': {'zh': '旋转木马', 'en': 'Carousel'},
    'reader_page_animation_cylinder': {'zh': '模仿圆筒', 'en': 'Cylinder'},
    'reader_page_animation_flip': {'zh': '反转', 'en': 'Flip'},
    'pdf_reflow_exit': {'zh': '退出重排', 'en': 'Exit Reflow'},
    'pdf_reflow_font_size': {'zh': '字体大小', 'en': 'Font Size'},
    'pdf_reflow_line_spacing': {'zh': '行距', 'en': 'Line Spacing'},
    'pdf_reflow_letter_spacing': {'zh': '字距', 'en': 'Letter Spacing'},
    'pdf_reflow_para_spacing': {'zh': '段距', 'en': 'Paragraph Spacing'},
    'pdf_reflow_loading': {'zh': '正在重排…', 'en': 'Reflowing…'},
    'pdf_reflow_ocr_loading': {
      'zh': '正在识别扫描件…',
      'en': 'Recognizing scanned pages…'
    },
    'pdf_reflow_ocr_unavailable': {
      'zh': '未内置 OCR 模型，无法重排扫描件',
      'en': 'OCR models not bundled; cannot reflow scanned pages'
    },
    'pdf_reflow_ocr_failed': {
      'zh': '扫描件识别失败',
      'en': 'Scan recognition failed'
    },
    'pdf_ocr_eager_pages': {
      'zh': 'OCR 预扫页数',
      'en': 'OCR Prefetch Pages'
    },
    'pdf_reflow_ocr_page_failed': {
      'zh': '部分页面识别失败，已跳过',
      'en': 'Some pages failed to recognize (skipped)'
    },
    'pdf_reflow_empty': {
      'zh': '该文档无可重排文本（扫描件需 OCR 模型）',
      'en': 'No reflowable text (scanned pages need OCR models)'
    },
    'pdf_reflow_on_desc': {
      'zh': '点击退出重排，恢复原始版式',
      'en': 'Tap to exit reflow and restore original layout'
    },
    'pdf_ocr_reader_exit': {
      'zh': '退出 OCR 阅读',
      'en': 'Exit OCR Reader'
    },
    'pdf_ocr_reader_stop': {
      'zh': '停止识别',
      'en': 'Stop Recognizing'
    },
    'pdf_ocr_reader_background': {
      'zh': '后台识别中…（已识别 %d / %d 页）',
      'en': 'Recognizing in background… (%d / %d pages)'
    },
    'pdf_ocr_edit_title': {
      'zh': '编辑识别文本',
      'en': 'Edit recognized text'
    },
    'pdf_ocr_no_content': {
      'zh': '未识别到内容（请检查 OCR 模型是否内置）',
      'en': 'No content recognized (check OCR models are bundled)'
    },
    'pdf_ocr_view_reflow': {
      'zh': '重排',
      'en': 'Reflow'
    },
    'pdf_ocr_view_original': {
      'zh': '原图',
      'en': 'Original'
    },
    'pdf_ocr_image_failed': {
      'zh': '（图片无法显示）',
      'en': '(image unavailable)'
    },
    'reader_nav_catalog': {'zh': '目录', 'en': 'Catalog'},
    'reader_nav_progress': {'zh': '进度', 'en': 'Progress'},
    'reader_nav_notes': {'zh': '笔记', 'en': 'Notes'},
    'reader_nav_search': {'zh': '搜索', 'en': 'Search'},
    'reader_nav_more': {'zh': '更多', 'en': 'More'},
    'reader_landscape': {'zh': '横屏模式', 'en': 'Landscape'},
    'reader_landscape_desc': {'zh': '锁定为横屏阅读', 'en': 'Lock to landscape'},
    'reader_add_note': {'zh': '添加笔记', 'en': 'Add Note'},
    'reader_add_bookmark': {'zh': '添加书签', 'en': 'Add Bookmark'},
    'reader_bookmarks': {'zh': '书签', 'en': 'Bookmarks'},
    'reader_notes_empty': {'zh': '暂无笔记，点击下方按钮添加', 'en': 'No notes yet'},
    'reader_bookmarks_empty': {'zh': '暂无书签', 'en': 'No bookmarks'},
    'reader_catalog_empty': {'zh': '本书无目录', 'en': 'No catalog'},
    'reader_search_placeholder': {'zh': '搜索全书文字', 'en': 'Search text'},
    'reader_search_empty': {'zh': '未找到匹配内容', 'en': 'No matches'},
    'reader_searching': {'zh': '搜索中…', 'en': 'Searching…'},
    'reader_go_to_page': {'zh': '跳转', 'en': 'Go'},
    'reader_return_before': {'zh': '返回跳转前', 'en': 'Return'},
    'reader_note_hint': {'zh': '输入笔记内容…', 'en': 'Note content…'},
    'reader_note_view_full': {'zh': '笔记全文', 'en': 'Note Full Text'},
    'reader_note_jump': {'zh': '跳转', 'en': 'Jump'},
    'reader_bookmark_rename': {'zh': '重命名书签', 'en': 'Rename Bookmark'},
    'reader_bookmark_name_placeholder': {
      'zh': '输入书签名称（留空则仅显示页码）',
      'en': 'Bookmark name (empty = page number only)'
    },
    'reader_bookmark_add_time': {'zh': '添加时间', 'en': 'Added'},
    'reader_bookmark_default': {'zh': '书签', 'en': 'Bookmark'},
    'reader_bookmarks_all': {'zh': '全部书签', 'en': 'All Bookmarks'},
    'reader_previous_page': {'zh': '上一页', 'en': 'Prev'},
    'reader_next_page': {'zh': '下一页', 'en': 'Next'},
    'reader_search_tab': {'zh': '搜索', 'en': 'Search'},
    'reader_bookmark_tab': {'zh': '书签', 'en': 'Bookmark'},
    'just_now': {'zh': '刚刚', 'en': 'Just now'},
    'account_settings': {'zh': '账号与设置', 'en': 'Account & Settings'},
    'premium': {'zh': '开通高级会员', 'en': 'Activate Premium'},
    // ───────── 数据管理（导出/导入阅读数据 + 云盘同步）─────────
    'data_manager': {'zh': '数据管理', 'en': 'Data Manager'},
    'data_manager_working': {'zh': '处理中…', 'en': 'Working…'},
    'data_manager_export': {'zh': '导出阅读数据', 'en': 'Export Reading Data'},
    'data_manager_export_desc': {
      'zh': '将书籍、笔记、书签与阅读记录导出为备份文件',
      'en': 'Export books, notes, bookmarks and reading history to a backup file'
    },
    'data_manager_import': {'zh': '导入阅读数据', 'en': 'Import Reading Data'},
    'data_manager_import_desc': {
      'zh': '从备份文件恢复阅读数据（合并到现有数据）',
      'en': 'Restore reading data from a backup file (merged into existing data)'
    },
    'data_manager_import_confirm': {
      'zh': '导入将合并到现有数据，确定继续？',
      'en': 'Import will merge into existing data. Continue?'
    },
    'data_manager_export_success': {'zh': '导出成功', 'en': 'Export succeeded'},
    'data_manager_export_fail': {'zh': '导出失败', 'en': 'Export failed'},
    'data_manager_import_success': {'zh': '导入成功', 'en': 'Import succeeded'},
    'data_manager_import_fail': {'zh': '导入失败', 'en': 'Import failed'},
    'data_manager_books_count': {'zh': '本书', 'en': 'books'},
    'data_manager_sessions_count': {'zh': '次阅读会话', 'en': 'reading sessions'},
    'data_manager_cloud_sync': {'zh': '云盘同步', 'en': 'Cloud Sync'},
    'data_manager_cloud_sync_desc': {
      'zh': '配置网盘或 NAS 后，可一键同步阅读数据备份',
      'en': 'After configuring a cloud drive or NAS, sync your reading backup with one tap'
    },
    'data_manager_no_drive': {
      'zh': '尚未配置任何网盘，无法同步',
      'en': 'No cloud drive configured yet, sync disabled'
    },
    'data_manager_no_drive_hint': {
      'zh': '尚未配置网盘，添加后可在此同步',
      'en': 'No cloud drive added yet'
    },
    'data_manager_sync_gate_hint': {
      'zh': '需先配置至少一个网盘/NAS 才能同步',
      'en': 'Configure at least one cloud drive or NAS to enable sync'
    },
    'data_manager_sync_now': {'zh': '立即同步', 'en': 'Sync Now'},
    'data_manager_sync_success': {'zh': '同步成功', 'en': 'Sync succeeded'},
    'data_manager_sync_fail': {'zh': '同步失败', 'en': 'Sync failed'},
    'data_manager_sync_in_progress': {
      'zh': '正在同步到云盘…',
      'en': 'Syncing to cloud drive…'
    },
    'data_manager_drive_ok': {'zh': '成功', 'en': 'Success'},
    'data_manager_drive_fail': {'zh': '失败', 'en': 'Failed'},
    'data_manager_sync_not_supported': {
      'zh': '当前未配置支持同步的网盘（WebDAV），请添加 WebDAV 网盘或 NAS',
      'en':
          'No WebDAV-capable drive configured; add a WebDAV drive or NAS to sync'
    },
    'data_manager_add_drive': {'zh': '添加网盘', 'en': 'Add Cloud Drive'},
    'data_manager_edit_drive': {'zh': '编辑网盘', 'en': 'Edit Cloud Drive'},
    'data_manager_drive_name': {'zh': '名称', 'en': 'Name'},
    'data_manager_drive_name_ph': {'zh': '如：我的 NAS', 'en': 'e.g. My NAS'},
    'data_manager_drive_name_required': {
      'zh': '请填写网盘名称',
      'en': 'Please enter a name'
    },
    'data_manager_drive_type': {'zh': '类型', 'en': 'Type'},
    'data_manager_drive_type_webdav': {'zh': 'WebDAV', 'en': 'WebDAV'},
    'data_manager_drive_type_other': {'zh': '其他', 'en': 'Other'},
    'data_manager_drive_url': {'zh': '服务器地址', 'en': 'Server URL'},
    'data_manager_drive_url_ph': {
      'zh': 'https://nas.example.com/remote.php/webdav',
      'en': 'https://nas.example.com/remote.php/webdav'
    },
    'data_manager_drive_user': {'zh': '账号', 'en': 'Account'},
    'data_manager_drive_user_ph': {
      'zh': 'WebDAV 用户名',
      'en': 'WebDAV username'
    },
    'data_manager_drive_pass': {'zh': '密码', 'en': 'Password'},
    'data_manager_drive_pass_ph': {
      'zh': 'WebDAV 密码',
      'en': 'WebDAV password'
    },
    'data_manager_drive_path': {'zh': '远程目录', 'en': 'Remote Path'},
    'data_manager_drive_path_ph': {
      'zh': '如：/bookreader（可留空）',
      'en': 'e.g. /bookreader (optional)'
    },
    'data_manager_save': {'zh': '保存', 'en': 'Save'},
    'data_manager_delete': {'zh': '删除', 'en': 'Delete'},
    'data_manager_tip': {'zh': '提示', 'en': 'Tip'},
    'ok': {'zh': '确定', 'en': 'OK'},
    'membership_center': {'zh': '会员中心', 'en': 'Membership Center'},
    'membership_intro': {
      'zh': '高级会员为阅读、记录与AI能力提供更完整的体验。',
      'en':
          'Premium membership unlocks a fuller reading, journaling, and AI experience.',
    },
    'membership_architecture': {'zh': '会员架构', 'en': 'Membership Structure'},
    'membership_architecture_body': {
      'zh': '会员能力由权限引擎统一调度，服务端配置决定当前是否开放高级权益。',
      'en':
          'Membership capabilities are coordinated by the permission engine, and server configuration determines whether premium benefits are enabled.',
    },
    'membership_features': {'zh': '会员应有的功能', 'en': 'Premium Features'},
    'membership_feature_1': {
      'zh': '无限制的阅读与笔记增强能力',
      'en': 'Unlimited reading and note enhancement capabilities',
    },
    'membership_feature_2': {
      'zh': '更丰富的AI助手与内容总结',
      'en': 'Richer AI assistant and content summarization',
    },
    'membership_feature_3': {
      'zh': '优先同步与个性化主题体验',
      'en': 'Priority sync and personalized theme experience',
    },
    'membership_status_label': {'zh': '当前状态', 'en': 'Current Status'},
    'membership_loading': {
      'zh': '正在加载会员状态...',
      'en': 'Loading membership status...',
    },
    'membership_enabled': {
      'zh': '会员功能已启用，会员权限由云端控制。',
      'en':
          'Membership features are enabled and permissions are controlled by the server.',
    },
    'membership_disabled': {
      'zh': '会员功能当前未开启，请检查服务器端权限配置。',
      'en':
          'Membership features are currently disabled. Please check the server-side permission settings.',
    },
    'membership_vip_status': {
      'zh': '当前为 VIP 用户，等级：',
      'en': 'Current user is VIP, level: ',
    },
    'membership_non_vip_status': {
      'zh': '当前非 VIP 用户，等级：',
      'en': 'Current user is not VIP, level: ',
    },
    'sync': {'zh': '同步', 'en': 'Sync'},
    'ai_assistant': {'zh': 'AI助手', 'en': 'AI Assistant'},
    'language': {'zh': '语言', 'en': 'Language'},
    'appearance': {'zh': '外观', 'en': 'Appearance'},
    'theme_color': {'zh': '主题配色', 'en': 'Theme Color'},
    'reader_background': {'zh': '阅读背景', 'en': 'Reading Background'},
    'reader_background_white': {'zh': '白', 'en': 'White'},
    'reader_background_beige': {'zh': '米白', 'en': 'Beige'},
    'reader_background_gray': {'zh': '灰', 'en': 'Gray'},
    'reader_background_yellow': {'zh': '浅黄', 'en': 'Cream'},
    'reader_background_green': {'zh': '浅绿', 'en': 'Mint'},
    'reader_background_blue': {'zh': '浅蓝', 'en': 'Blue'},
    'reader_background_dark': {'zh': '深灰', 'en': 'Dark'},
    'reader_layout': {'zh': '布局', 'en': 'Layout'},
    'reader_layout_single': {'zh': '单页', 'en': 'Single'},
    'reader_layout_double': {'zh': '双页', 'en': 'Double'},
    'reader_layout_single_continuous': {
      'zh': '单页连续',
      'en': 'Single Continuous'
    },
    'reader_layout_double_continuous': {
      'zh': '双页连续',
      'en': 'Double Continuous'
    },
    'pdf_auto_crop': {'zh': '自动裁切', 'en': 'Auto Crop'},
    'pdf_auto_crop_desc': {
      'zh': '去除页面四周空白边距',
      'en': 'Remove white margins around pages'
    },
    'pdf_bg_adjust': {'zh': '背景调节', 'en': 'Background Adjust'},
    'pdf_bg_contrast': {'zh': '对比度', 'en': 'Contrast'},
    'pdf_bg_saturation': {'zh': '色彩饱和度', 'en': 'Saturation'},
    'pdf_bg_remove_color': {'zh': '去除颜色', 'en': 'Remove Color'},
    'pdf_bg_remove_color_desc': {
      'zh': '仅显示黑白灰',
      'en': 'Show only black, white and gray'
    },
    'pdf_bg_denoise': {'zh': '智能去杂色', 'en': 'Smart Denoise'},
    'pdf_bg_denoise_desc': {
      'zh': '去除影响阅读的小黑点、杂点',
      'en': 'Remove small dots and noise that affect reading'
    },
    // 画面增强（对比度 / 饱和度 / 色温 / 去除颜色 / 去杂色，统一分区）
    'pdf_enhance': {'zh': '画面增强', 'en': 'Image Enhancement'},
    'pdf_enhance_sharpness': {'zh': '清晰度', 'en': 'Sharpness'},
    'pdf_enhance_contrast': {'zh': '对比度', 'en': 'Contrast'},
    'pdf_enhance_brightness': {'zh': '亮度', 'en': 'Brightness'},
    'pdf_enhance_saturation': {'zh': '饱和度', 'en': 'Saturation'},
    'pdf_enhance_color_temp': {'zh': '色温', 'en': 'Color Temp'},
    'pdf_enhance_remove_color': {'zh': '去除颜色', 'en': 'Remove Color'},
    // 页面裁切（自动 / 手动 / 框选）
    'pdf_crop': {'zh': '页面裁切', 'en': 'Page Crop'},
    'pdf_crop_auto': {'zh': '智能自动裁边（去除白边）', 'en': 'Smart Auto Crop (Remove White Edges)'},
    'pdf_crop_manual': {'zh': '手动裁边', 'en': 'Manual Crop'},
    'pdf_crop_select': {'zh': '框选裁边', 'en': 'Select Crop'},
    'pdf_crop_select_page': {'zh': '第 %d 页', 'en': 'Page %d'},
    'pdf_crop_select_hint': {'zh': '在页面上拖拽绘制裁切区域', 'en': 'Drag on page to draw crop area'},
    'pdf_crop_odd_even_title': {'zh': '奇偶页分开裁边', 'en': 'Odd/Even Page Separate Crop'},
    'pdf_crop_odd_even_all': {'zh': '统一', 'en': 'All Pages'},
    'pdf_crop_odd_even_odd': {'zh': '仅奇数页', 'en': 'Odd Only'},
    'pdf_crop_odd_even_even': {'zh': '仅偶数页', 'en': 'Even Only'},
    'pdf_crop_left_right': {'zh': '左右裁切', 'en': 'Left/Right Crop'},
    'pdf_crop_top_bottom': {'zh': '上下裁切', 'en': 'Top/Bottom Crop'},
    'pdf_crop_left': {'zh': '左', 'en': 'L'},
    'pdf_crop_right': {'zh': '右', 'en': 'R'},
    'pdf_crop_top': {'zh': '上', 'en': 'T'},
    'pdf_crop_bottom': {'zh': '下', 'en': 'B'},
    'pdf_crop_reset': {'zh': '一键还原', 'en': 'Reset All'},
    // 双屏模式
    'pdf_dual_screen': {'zh': '双屏模式', 'en': 'Dual Screen'},
    'pdf_dual_screen_desc': {
      'zh': '左右分屏，独立滑动对比阅读',
      'en': 'Split screen for side-by-side comparison'
    },
    // 双击放大
    'pdf_double_tap_zoom': {'zh': '双击放大', 'en': 'Double-tap Zoom'},
    'pdf_double_tap_zoom_desc': {
      'zh': '双击在 1×/2×/3× 间循环放大，并支持双指捏合缩放',
      'en': 'Double-tap cycles 1×/2×/3×, plus pinch-to-zoom'
    },
    'pdf_fill_screen_scroll': {'zh': '撑满全屏（滚动）', 'en': 'Fill Screen (Scroll)'},
    'pdf_fill_screen_scroll_desc': {
      'zh': '仅上下滚动（连续）时生效：每页按裁切后真实宽高比铺满，消除逐页跳动；左右翻页不生效',
      'en': 'Only in vertical scroll (continuous): each page fills width by its cropped aspect to stop per-page jitter; disabled for swipe page-turn'
    },
    'pdf_reflow': {'zh': '重排', 'en': 'Reflow'},
    'pdf_reflow_desc': {
      'zh': '提取正文重新排版，可调字体大小/行距/字距',
      'en': 'Extract text and re-typeset; adjustable font size/spacing'
    },
    'pdf_reflow_ocr_progress': {'zh': '识别第 %d / %d 页', 'en': 'Recognizing page %d / %d'},
    'pdf_enhance_smart_clarity': {'zh': '智能清晰度', 'en': 'Smart Clarity'},
    'pdf_enhance_smart_clarity_running': {'zh': '正在分析…', 'en': 'Analyzing…'},
    // 扫描件质检（OQC）：整本质量检查
    'pdf_oqc_title': {'zh': '扫描件质检', 'en': 'Scan QC'},
    'pdf_oqc_desc': {
      'zh': '对整本 PDF 做质量检查：空白页 / 模糊 / 黑边 / 倾斜 / 重影',
      'en': 'Whole-PDF quality check: blank / blur / black margin / skew / ghost'
    },
    'pdf_oqc_running': {'zh': '正在质检第 %d / %d 页', 'en': 'Checking page %d / %d'},
    'pdf_oqc_running_hint': {
      'zh': '逐页渲染并做像素统计，请稍候',
      'en': 'Rendering each page and analyzing pixels, please wait'
    },
    'pdf_oqc_failed': {'zh': '质检失败', 'en': 'QC failed'},
    'pdf_oqc_summary': {'zh': '质检概览', 'en': 'Summary'},
    'pdf_oqc_total': {'zh': '总页数', 'en': 'Pages'},
    'pdf_oqc_blank': {'zh': '空白页', 'en': 'Blank'},
    'pdf_oqc_blurry': {'zh': '模糊', 'en': 'Blurry'},
    'pdf_oqc_margin': {'zh': '黑边', 'en': 'Black Margin'},
    'pdf_oqc_ghost': {'zh': '重影', 'en': 'Ghost'},
    'pdf_oqc_skew': {'zh': '倾斜', 'en': 'Skew'},
    'pdf_oqc_no_issue': {'zh': '未发现明显问题', 'en': 'No issues found'},
    'pdf_oqc_issue_hint': {
      'zh': '共 %d 页存在需要关注的问题',
      'en': '%d pages may need attention'
    },
    'pdf_oqc_page': {'zh': '第 %d 页', 'en': 'Page %d'},
    'reader_add_tag': {'zh': '添加标签', 'en': 'Add Tag'},
    'reader_add_tag_placeholder': {'zh': '输入标签', 'en': 'Enter tag'},
    'add': {'zh': '添加', 'en': 'Add'},
    'theme_color_blue': {'zh': '蓝色', 'en': 'Blue'},
    'theme_color_green': {'zh': '绿色', 'en': 'Green'},
    'theme_color_pink': {'zh': '粉色', 'en': 'Pink'},
    'theme_color_orange': {'zh': '橙色', 'en': 'Orange'},
    'more_settings': {'zh': '更多设置', 'en': 'More Settings'},
    'about': {'zh': '关于', 'en': 'About'},
    'about_app_title': {'zh': '书reader', 'en': 'Book Reader'},
    'about_app_description': {
      'zh': '一款简洁好用的阅读与记录应用，持续优化阅读体验。',
      'en':
          'A simple and practical reading and journaling app with continuous experience improvements.',
    },
    'about_app_mission': {
      'zh': '专注阅读，让每一次打开都值得',
      'en': 'Focus on reading, make every opening worthwhile.',
    },
    'next_page': {'zh': '下一页', 'en': 'Next Page'},
    'view_more': {'zh': '查看更多', 'en': 'View More'},
    'support_and_links': {'zh': '支持与链接', 'en': 'Support & Links'},
    'update_log': {'zh': '更新日志', 'en': 'Update Log'},
    'check_update': {'zh': '检查更新', 'en': 'Check Update'},
    'qq_group': {'zh': 'QQ群', 'en': 'QQ Group'},
    'wechat_group': {'zh': '微信群', 'en': 'WeChat Group'},
    'email': {'zh': '邮件', 'en': 'Email'},
    'official_website': {'zh': '官网', 'en': 'Official Website'},
    'privacy_policy': {'zh': '隐私政策', 'en': 'Privacy Policy'},
    'user_agreement': {'zh': '用户协议', 'en': 'User Agreement'},
    'update_log_content': {
      'zh': '当前版本为 1.0.0，正在持续优化阅读体验与界面细节。',
      'en':
          'The current version is 1.0.0, and the reading experience and interface details are being continuously improved.',
    },
    'update_latest': {
      'zh': '当前已经是最新版本。',
      'en': 'You already have the latest version.',
    },
    'open_failed': {
      'zh': '无法打开该链接，请稍后重试。',
      'en': 'Unable to open the link. Please try again later.',
    },
    'settings': {'zh': '设置', 'en': 'Settings'},
    'chinese': {'zh': '中文', 'en': 'Chinese', 'zh_Hant': '中文'},
    'english': {'zh': '英文', 'en': 'English', 'zh_Hant': '英文'},
    'traditional_chinese': {
      'zh': '繁体',
      'en': 'Traditional Chinese',
      'zh_Hant': '繁體',
    },
    'follow_system': {'zh': '跟随系统', 'en': 'Follow System'},
    'light_mode': {'zh': '亮色模式', 'en': 'Light Mode'},
    'dark_mode': {'zh': '暗色模式', 'en': 'Dark Mode'},
    'save': {'zh': '保存', 'en': 'Save'},
    'edit': {'zh': '编辑', 'en': 'Edit'},
    'cancel': {'zh': '取消', 'en': 'Cancel'},
    'confirm': {'zh': '确认', 'en': 'Confirm'},
    'done': {'zh': '完成', 'en': 'Done'},
    'bookshelf_import_single': {'zh': '单本导入', 'en': 'Import Single'},
    'bookshelf_import_multiple': {'zh': '多选导入', 'en': 'Import Multiple'},
    'bookshelf_scan_import': {'zh': '扫描导入', 'en': 'Scan Import'},
    'bookshelf_scan_import_title': {'zh': '扫描到的书籍', 'en': 'Scanned Books'},
    'bookshelf_scan_import_description': {
      'zh': '系统会扫描下载、文档与桌面目录中的支持格式书籍，选择后即可导入',
      'en':
          'We will scan your Downloads, Documents, and Desktop folders for supported books, then you can import the selected ones',
    },
    'bookshelf_scan_import_import': {'zh': '导入所选', 'en': 'Import Selected'},
    'bookshelf_scan_import_empty': {
      'zh': '当前没有扫描到可导入的书籍',
      'en': 'No supported books were found to import',
    },
    'bookshelf_import_duplicate': {
      'zh': '该书籍已导入，无需重复导入',
      'en': 'This book is already imported and will not be imported again',
    },
    'bookshelf_import_duplicate_skipped': {
      'zh': '已跳过重复导入的书籍',
      'en': 'Duplicate imported books were skipped',
    },
    'bookshelf_random_read': {'zh': '随机读书', 'en': 'Random Read'},
    'bookshelf_search_placeholder': {
      'zh': '搜索已导入的书籍',
      'en': 'Search imported books',
    },
    'bookshelf_empty_error': {'zh': '当前书架中暂无书籍', 'en': 'No books in bookshelf'},
    'bookshelf_empty_title': {'zh': '你的书架还空着', 'en': 'Your bookshelf is empty'},
    'bookshelf_empty_subtitle': {
      'zh': '去发现好书，充实你的知识库',
      'en': 'Find great books to enrich your knowledge',
    },
    'bookshelf_import_button': {'zh': '导入书籍', 'en': 'Import Book'},
    'bookshelf_scan_folder': {'zh': '扫描文件夹', 'en': 'Scan Folder'},
    'bookshelf_scan_folder_pick': {
      'zh': '选择一个文件夹以扫描其中的书籍，点按文件夹即可导入其下全部书籍',
      'en': 'Pick a folder to scan its books, tap a folder to import all books inside',
    },
    'bookshelf_scan_folder_empty': {
      'zh': '该文件夹下没有可导入的书籍',
      'en': 'No importable books were found in this folder',
    },
    'bookshelf_folder_title': {'zh': '选择要扫描的文件夹', 'en': 'Select a folder to scan'},
    'bookshelf_import_progress_title': {'zh': '正在导入书籍…', 'en': 'Importing books…'},
    'bookshelf_import_progress_current': {
      'zh': '正在导入：%s（第 %cur% / %tot% 本）',
      'en': 'Importing: %s (%cur%/%tot%)',
    },
    'bookshelf_import_progress_percent': {'zh': '%d%', 'en': '%d%'},
    'bookshelf_import_progress_eta': {'zh': '预计剩余 %d 秒', 'en': 'About %d sec left'},
    'bookshelf_import_done': {'zh': '已成功导入 %d 本书', 'en': 'Successfully imported %d books'},
    'bookshelf_permission_folder_title': {'zh': '需要文件夹访问权限', 'en': 'Folder access required'},
    'bookshelf_permission_folder_message': {
      'zh': '为了扫描并导入文件夹内的书籍，需要您授权访问该文件夹。是否前往系统设置开启权限？',
      'en': 'To scan and import books inside a folder, please grant folder access. Open system settings?',
    },
    'bookshelf_permission_open_settings': {'zh': '前往设置', 'en': 'Open Settings'},
    'bookshelf_scan_import_dialog_title': {'zh': '导入书籍', 'en': 'Import Books'},
    'bookshelf_selected_count': {'zh': '已选择 %d 本', 'en': 'Selected %d'},
    'bookshelf_confirm_import': {'zh': '确认导入 (%d)', 'en': 'Confirm Import (%d)'},
    'bookshelf_no_match_books': {
      'zh': '没有找到匹配的书籍',
      'en': 'No matching books found',
    },
    'bookshelf_scan_add_dir': {'zh': '添加扫描目录', 'en': 'Add Scan Directory'},
    'bookshelf_scanning_title': {'zh': '正在扫描书籍…', 'en': 'Scanning books…'},
    'bookshelf_scanning_count': {'zh': '已扫描 %d 个文件', 'en': 'Scanned %d files'},
    'bookshelf_scan_found_count': {'zh': '已找到 %d 本', 'en': 'Found %d books'},
    'bookshelf_scan_root_added': {'zh': '已添加扫描目录', 'en': 'Scan directory added'},
    'bookshelf_scan_search_placeholder': {
      'zh': '搜索扫描到的书籍',
      'en': 'Search scanned books'
    },
    'bookshelf_delete': {'zh': '删除', 'en': 'Delete'},
    'bookshelf_add_favorite': {'zh': '收藏', 'en': 'Favorite'},
    'bookshelf_remove_favorite': {'zh': '取消收藏', 'en': 'Remove Favorite'},
    'bookshelf_mark_reading': {'zh': '设为在读', 'en': 'Mark as Reading'},
    'bookshelf_mark_finished': {'zh': '设为已读', 'en': 'Mark as Finished'},
    'bookshelf_mark_unread': {'zh': '设为未读', 'en': 'Mark as Unread'},
    'memory_reading_duration_hint': {
      'zh': '阅读时长统计将显示在此处',
      'en': 'Reading duration statistics will appear here',
    },
    'reading_statistics': {'zh': '阅读统计', 'en': 'Reading Statistics'},
    'total_reading_duration': {'zh': '总阅读时长', 'en': 'Total Reading Time'},
    'daily_average': {'zh': '日均', 'en': 'Daily Avg'},
    'vs_previous_period': {'zh': '较上一周期', 'en': 'vs Previous Period'},
    'today_reading': {'zh': '今日阅读', 'en': 'Today'},
    'this_week_reading': {'zh': '本周阅读', 'en': 'This Week'},
    'reading_time_distribution': {
      'zh': '阅读时长分布',
      'en': 'Reading Time Distribution',
    },
    'reading_trend': {'zh': '阅读趋势', 'en': 'Reading Trend'},
    'trend_summary': {'zh': '趋势总结', 'en': 'Trend Summary'},
    'reading_trend_insight': {
      'zh': '本周阅读时长持续提升，集中在晚间和周末，说明你的阅读节奏已经稳定。',
      'en':
          'Reading time kept rising this week, especially in the evenings and on weekends, showing a steady routine.',
    },
    'chart_hint': {
      'zh': '点击数据点查看详细时长',
      'en': 'Tap a point to inspect detailed reading time',
    },
    'hours_short': {'zh': '小时', 'en': 'h'},
    'hour_unit': {'zh': '时', 'en': 'h'},
    'minutes_short': {'zh': '分钟', 'en': 'm'},
    'days_short': {'zh': '天', 'en': 'd'},
    'books_short': {'zh': '本', 'en': 'books'},
    'longest_reading_day': {'zh': '最长阅读一天', 'en': 'Longest Reading Day'},
    'continuous_reading': {'zh': '连续阅读', 'en': 'Streak'},
    'continuous_reading_label': {'zh': '连续阅读', 'en': 'Reading Streak'},
    'cumulative_reading': {'zh': '累计阅读', 'en': 'Accumulated Reading'},
    'cumulative_reading_days': {'zh': '累计阅读天数', 'en': 'Reading Days'},
    'average_daily_reading': {'zh': '平均每天阅读', 'en': 'Average Daily Reading'},
    'completed_books': {'zh': '阅读完成书籍', 'en': 'Completed Books'},
    'app_launch_count': {'zh': '打开次数', 'en': 'App Launches'},
    'launch_unit': {'zh': '次', 'en': 'times'},
    'period_day': {'zh': '日', 'en': 'Day'},
    'period_week': {'zh': '周', 'en': 'Week'},
    'period_month': {'zh': '月', 'en': 'Month'},
    'period_year': {'zh': '年', 'en': 'Year'},
    'calendar_january': {'zh': '一月', 'en': 'Jan'},
    'calendar_february': {'zh': '二月', 'en': 'Feb'},
    'calendar_march': {'zh': '三月', 'en': 'Mar'},
    'calendar_april': {'zh': '四月', 'en': 'Apr'},
    'calendar_may': {'zh': '五月', 'en': 'May'},
    'calendar_june': {'zh': '六月', 'en': 'Jun'},
    'calendar_july': {'zh': '七月', 'en': 'Jul'},
    'calendar_august': {'zh': '八月', 'en': 'Aug'},
    'calendar_september': {'zh': '九月', 'en': 'Sep'},
    'calendar_october': {'zh': '十月', 'en': 'Oct'},
    'calendar_november': {'zh': '十一月', 'en': 'Nov'},
    'calendar_december': {'zh': '十二月', 'en': 'Dec'},
    'calendar_sunday': {'zh': '日', 'en': 'Sun'},
    'calendar_monday': {'zh': '一', 'en': 'Mon'},
    'calendar_tuesday': {'zh': '二', 'en': 'Tue'},
    'calendar_wednesday': {'zh': '三', 'en': 'Wed'},
    'calendar_thursday': {'zh': '四', 'en': 'Thu'},
    'calendar_friday': {'zh': '五', 'en': 'Fri'},
    'calendar_saturday': {'zh': '六', 'en': 'Sat'},
    'enter_content': {
      'zh': '请输入每日一句内容',
      'en': 'Please enter the daily sentence content',
    },
    'no_sentences': {'zh': '尚未添加每日一句内容', 'en': 'No daily sentences added yet'},
    'view_full': {'zh': '每日一句全文', 'en': 'Full daily sentence'},
    // 每日一句：刷新按钮与内置开关
    'daily_sentence_refresh': {'zh': '换一句', 'en': 'Refresh'},
    'daily_sentence_use_builtin': {
      'zh': '启用内置每日一句',
      'en': 'Enable Built-in Sentences',
    },
    'daily_sentence_use_builtin_desc': {
      'zh': '关闭后只显示你自定义的每日一句',
      'en': 'When off, only your custom sentences are shown',
    },
    'daily_sentence_empty_custom': {
      'zh': '还没有自定义每日一句，开启内置每日一句获取灵感吧',
      'en': 'No custom sentences yet. Enable built-in sentences for inspiration.',
    },
    // 每日一句列表页（截图改版）
    'my_sentences': {'zh': '我的语句', 'en': 'My Sentences'},
    'today_preview': {'zh': '今天可能会看到', 'en': "Today's preview"},
    'refresh_one': {'zh': '换一个', 'en': 'Refresh'},
    'add_new_sentence': {'zh': '添加新的语句', 'en': 'Add New Sentence'},
    'batch_add_hint': {
      'zh': '支持批量添加：每行一句，按回车换行可一次添加多条',
      'en': 'Batch supported: one sentence per line, press Enter to add multiple at once',
    },
    'long_press_reorder': {
      'zh': '点击「···」可上移 / 下移排序',
      'en': 'Tap "···" to move up / down to reorder',
    },
    'sentence_delete_confirm': {
      'zh': '确认删除此句？',
      'en': 'Delete this sentence?',
    },
    'sentence_deleted': {
      'zh': '已删除',
      'en': 'Deleted',
    },
    'move_up': {'zh': '上移', 'en': 'Move Up'},
    'move_down': {'zh': '下移', 'en': 'Move Down'},
    'no_recently_reading': {
      'zh': '尚未有最近阅读记录，先添加一本书籍开始阅读吧。',
      'en': 'No recent reads yet. Add a book to get started.',
    },
    'greeting_title': {'zh': '下午好，万志豪！', 'en': 'Good afternoon, Wanzhihau!'},
    'greeting_title_morning': {
      'zh': '上午好，万志豪！',
      'en': 'Good morning, Wanzhihau!',
    },
    'greeting_title_afternoon': {
      'zh': '下午好，万志豪！',
      'en': 'Good afternoon, Wanzhihau!',
    },
    'greeting_title_evening': {
      'zh': '晚上好，万志豪！',
      'en': 'Good evening, Wanzhihau!',
    },
    'greeting_title_late_night': {
      'zh': '很晚了，万志豪！',
      'en': 'It is very late, Wanzhihau!',
    },
    'greeting_subtitle': {'zh': '今天继续阅读吧', 'en': "Continue your reading today"},
    'greeting_subtitle_morning': {
      'zh': '上午开始新的一天吧',
      'en': 'Start a new day this morning',
    },
    'greeting_subtitle_afternoon': {
      'zh': '今天继续阅读吧',
      'en': 'Continue your reading today',
    },
    'greeting_subtitle_evening': {
      'zh': '今晚也可以安心阅读',
      'en': 'Enjoy a relaxing reading session tonight',
    },
    'greeting_subtitle_late_night': {
      'zh': '请注意休息，保护好眼睛。',
      'en': 'Please rest well and protect your eyes.',
    },
    'reading_progress_label': {'zh': '阅读进度', 'en': 'Reading Progress'},
    'continue_reading': {'zh': '继续阅读', 'en': 'Continue'},
    'import_pdf': {'zh': '导入书籍', 'en': 'Import Books'},
    'recent_files': {'zh': '最近文件', 'en': 'Recent Files'},
    'reading_stats': {'zh': '阅读统计', 'en': 'Reading Stats'},
    'favorites': {'zh': '我的收藏', 'en': 'Favorites'},
    'monthly_reading': {'zh': '本月阅读', 'en': 'This Month'},
    'yearly_reading': {'zh': '今年阅读', 'en': 'This Year'},
    'font_family': {'zh': '字体', 'en': 'Font Family'},
    'system_font': {'zh': '系统字体', 'en': 'System Font'},
    'sans_serif': {'zh': '无衬线', 'en': 'Sans Serif'},
    'serif': {'zh': '有衬线', 'en': 'Serif'},
    'monospace': {'zh': '等宽字体', 'en': 'Monospace'},
    'app_appearance': {'zh': '应用外观', 'en': 'App Appearance'},
    'theme_mode': {'zh': '主题模式', 'en': 'Theme Mode'},
    'theme_color_description': {
      'zh': '选择一个主题配色，应用于整个界面。',
      'en': 'Choose a theme color applied across the app.',
    },
    'theme_color_purple': {'zh': '紫色', 'en': 'Purple'},
    'theme_color_red': {'zh': '红色', 'en': 'Red'},
    'custom_theme_color': {'zh': '自定义配色', 'en': 'Custom Colors'},
    'custom_color_pick': {'zh': '选择颜色', 'en': 'Pick a Color'},
    'custom_color_palette': {'zh': '调色板', 'en': 'Palette'},
    'custom_color_name': {'zh': '名称', 'en': 'Name'},
    'custom_color_add': {'zh': '添加配色', 'en': 'Add Color'},
    'custom_color_delete': {'zh': '删除配色', 'en': 'Delete Color'},
    'custom_color_delete_confirm': {
      'zh': '确认删除该配色？',
      'en': 'Delete this custom color?',
    },
    'custom_color_section_hint': {
      'zh': '点击色块应用配色，长按可编辑或删除。',
      'en': 'Tap a swatch to apply; long-press to edit or delete.',
    },
    'custom_color_membership_hint': {
      'zh': '自定义配色为会员功能，开通会员后可创建专属配色。',
      'en':
          'Custom colors are a premium feature. Activate membership to create your own.',
    },
    'startup_page': {'zh': '启动页', 'en': 'Startup Page'},
    'startup_page_none': {'zh': '不设置（默认主页）', 'en': 'None (Home)'},
    'startup_page_home': {'zh': '首页', 'en': 'Home'},
    'startup_page_bookshelf': {'zh': '书架', 'en': 'Bookshelf'},
    'startup_page_memory': {'zh': '回忆', 'en': 'Memory'},
    'startup_page_tools': {'zh': '工具', 'en': 'Tools'},
    'startup_page_profile': {'zh': '我的', 'en': 'Profile'},
    'splash_settings': {'zh': '启动页设置', 'en': 'Splash Settings'},
    'splash_content_type': {'zh': '内容类型', 'en': 'Content Type'},
    'splash_image_settings': {'zh': '图片设置', 'en': 'Image Settings'},
    'splash_current_image': {'zh': '当前图片', 'en': 'Current Image'},
    'splash_change_image': {'zh': '点击更换图片', 'en': 'Tap to change image'},
    'splash_display_duration': {'zh': '显示时长', 'en': 'Display Duration'},
    'splash_duration_1s': {'zh': '1秒', 'en': '1s'},
    'splash_duration_3s': {'zh': '3秒', 'en': '3s'},
    'splash_duration_5s': {'zh': '5秒', 'en': '5s'},
    'splash_duration_always': {'zh': '永久', 'en': 'Always'},
    'splash_entry_mode': {'zh': '进入方式', 'en': 'Entry Mode'},
    'splash_auto_home': {'zh': '自动', 'en': 'Auto'},
    'splash_wait_click': {'zh': '点击', 'en': 'Tap'},
    'splash_jump_page': {'zh': '启动后跳转页面', 'en': 'Target Page'},
    'splash_text_settings_left': {'zh': '图片设置', 'en': 'Image Settings'},
    'splash_text_settings_right': {'zh': '文字设置', 'en': 'Text Settings'},
    'splash_current_text': {'zh': '当前文字', 'en': 'Current Text'},
    'splash_change_text': {'zh': '点击更换文字', 'en': 'Tap to change text'},
    'splash_preview_title': {
      'zh': '探索阅读的世界',
      'en': 'Explore the World of Reading',
    },
    'splash_preview_subtitle': {
      'zh': '让每一次阅读都更有价值',
      'en': 'Make every reading session more valuable',
    },
    'splash_skip': {'zh': '3s 跳过', 'en': 'Skip in 3s'},
    // 启动设置页·交互文案（图片选择 / 文字编辑 / 跳转页 / 预览）
    'splash_edit_text': {'zh': '编辑启动文字', 'en': 'Edit Splash Text'},
    'splash_text_placeholder': {
      'zh': '输入启动页要显示的文字',
      'en': 'Enter the text to show on splash',
    },
    'splash_save': {'zh': '保存', 'en': 'Save'},
    'splash_image_empty': {'zh': '尚未选择图片', 'en': 'No image selected'},
    'splash_text_empty': {'zh': '尚未设置文字', 'en': 'No text set'},
    'splash_image_failed': {'zh': '图片选择失败', 'en': 'Failed to pick image'},
    'splash_permission_denied': {
      'zh': '没有访问相册的权限，无法选择图片',
      'en': 'No permission to access photos',
    },
    'splash_preview_none': {
      'zh': '未配置启动页（将直接打开应用）',
      'en': 'Splash disabled (app opens directly)',
    },
    'splash_jump_select': {'zh': '选择启动后打开的页面', 'en': 'Select startup page'},
    'splash_skip_now': {'zh': '跳过', 'en': 'Skip'},
    'splash_tap_enter_now': {'zh': '点击进入', 'en': 'Tap to enter'},
    'splash_auto_countdown': {'zh': '%d 秒后跳过', 'en': 'Skip in %d s'},
    'splash_tap_countdown': {'zh': '%d 秒后进入', 'en': 'Enter in %d s'},
    'startup_content': {'zh': '启动页内容', 'en': 'Startup Content'},
    'startup_content_none': {'zh': '不显示', 'en': 'None'},
    'startup_content_text': {'zh': '显示文字', 'en': 'Text'},
    'startup_content_text_placeholder': {
      'zh': '在此输入启动页要显示的文字',
      'en': 'Enter startup screen text',
    },
    'startup_content_image': {'zh': '显示图片', 'en': 'Image'},
    'startup_content_image_placeholder': {
      'zh': '输入本地文件路径或网络 URL',
      'en': 'Enter local file path or image URL',
    },
    'startup_duration': {'zh': '显示时长', 'en': 'Display Duration'},
    'seconds': {'zh': '秒', 'en': 's'},
    'duration_picker_title': {'zh': '选择显示时长', 'en': 'Select duration'},
    'custom_seconds_label': {'zh': '自定义秒数', 'en': 'Custom seconds'},
    'custom_seconds_hint': {'zh': '例如 4', 'en': 'e.g. 4'},
    'duration_error': {
      'zh': '请输入大于 0 的整数秒数',
      'en': 'Please enter a positive integer seconds value',
    },
    'language_settings_title': {'zh': '语言设置', 'en': 'Language Settings'},
    'view_all': {'zh': '查看全部 >', 'en': 'View All >'},
    'bookshelf_tab_all': {'zh': '全部', 'en': 'All'},
    'bookshelf_tab_other': {'zh': '其他', 'en': 'Other'},
    'bookshelf_all_label': {'zh': '全部', 'en': 'All'},
    'bookshelf_favorites_label': {'zh': '收藏', 'en': 'Favorites'},
    'bookshelf_reading_label': {'zh': '在读', 'en': 'Reading'},
    'bookshelf_finished_label': {'zh': '已读', 'en': 'Finished'},
    'bookshelf_unread': {'zh': '未读', 'en': 'Unread'},
    'reading_status_read': {'zh': '已读', 'en': 'Read'},
    'file_type_pdf': {'zh': 'PDF', 'en': 'PDF'},
    'file_type_epub': {'zh': 'EPUB', 'en': 'EPUB'},
    'file_type_txt': {'zh': 'TXT', 'en': 'TXT'},
    // 去年的今天卡片（MemoryMainPage）
    'last_year_today': {'zh': '去年的今天', 'en': 'This Day Last Year'},
    // 随机回忆 / 本周阅读时长 / 阅读时间轴 卡片标题（MemoryMainPage）
    'random_memory': {'zh': '随机回忆', 'en': 'Random Memory'},
    'weekly_reading_duration': {'zh': '本周阅读时长', 'en': 'Weekly Reading'},
    'weekly_compare_prefix': {'zh': '比上周', 'en': 'vs last week'},
    'reading_timeline': {'zh': '阅读时间轴', 'en': 'Reading Timeline'},
    // 阅读统计卡片（MemoryMainPage）
    'stats_reading_hours_label': {
      'zh': '阅读时长(小时)',
      'en': 'Reading Hours',
    },
    'stats_reading_books_label': {
      'zh': '阅读书籍(本)',
      'en': 'Books Read',
    },
    'stats_reading_pages_label': {
      'zh': '阅读页数(页)',
      'en': 'Pages Read',
    },
    'stats_notes_count_label': {
      'zh': '收藏笔记(条)',
      'en': 'Bookmarks',
    },
    'stats_tab_week': {'zh': '周', 'en': 'Week'},
    'stats_tab_month': {'zh': '月', 'en': 'Month'},
    'stats_tab_year': {'zh': '年', 'en': 'Year'},
    'stats_tab_all': {'zh': '全部', 'en': 'All'},
    'stats_tab_day': {'zh': '日', 'en': 'Day'},
    // 阅读热力图卡片（MemoryMainPage）
    'heatmap_month_btn': {'zh': '本月', 'en': 'This Month'},
    'heatmap_legend_few': {'zh': '少', 'en': 'Less'},
    'heatmap_legend_many': {'zh': '多', 'en': 'More'},
    'reading_heatmap': {'zh': '阅读热力图', 'en': 'Reading Heatmap'},
    'heatmap_block_hint': {
      'zh': '每格 4 块 = 当日的 4 个 6 小时段阅读情况',
      'en': 'Each cell split into 4 = the day’s four 6-hour reading blocks'
    },
    'heatmap_day_block_hint': {
      'zh': '4 行 = 当日 4 个 6 小时段；每行 6 小时 × 4 个小方格，每格 = 15 分钟，颜色越深读得越多',
      'en': '4 rows = the day’s four 6-hour blocks; 6 hours × 4 squares per row, each square = 15 min'
    },
    // 阅读统计详情页新增指标卡
    'app_open_count_label': {'zh': '打开次数', 'en': 'App Opens'},
    'cumulative_reading_days_label': {
      'zh': '累计阅读天数',
      'en': 'Reading Days'
    },
    'daily_avg_reading_label': {'zh': '日均阅读', 'en': 'Daily Avg'},
    'today_reading_label': {'zh': '今日阅读', 'en': 'Today'},
    // 遗忘的书籍卡片（MemoryMainPage）
    'forgotten_books_title': {'zh': '遗忘的书籍', 'en': 'Forgotten Books'},
    'forgotten_view_now': {'zh': '立即查看', 'en': 'View Now'},
    'forgotten_view_more': {'zh': '查看更多', 'en': 'More'},
    'forgotten_days_label': {
      'zh': '未打开 {days} 天',
      'en': 'Not opened for {days} days',
    },
    'forgotten_never_opened': {'zh': '从未打开', 'en': 'Never opened'},
    'forgotten_empty': {
      'zh': '没有遗漏的书籍，继续保持！',
      'en': 'No forgotten books. Keep it up!',
    },
    // 阅读统计详情页（MemoryPage）—— 区块标题与分类/时段标签
    'detail_trend_title': {
      'zh': '阅读时长趋势',
      'en': 'Reading Trend',
    },
    'detail_type_distribution': {
      'zh': '阅读类型分布',
      'en': 'Reading Type Distribution',
    },
    'detail_time_distribution': {
      'zh': '阅读时间分布',
      'en': 'Reading Time Distribution',
    },
    'detail_monthly_records': {
      'zh': '阅读记录',
      'en': 'Reading Records',
    },
    'type_tech': {'zh': '技术编程', 'en': 'Tech / Programming'},
    'type_thought': {'zh': '思想认知', 'en': 'Thought / Philosophy'},
    'type_novel': {'zh': '文学小说', 'en': 'Literature / Fiction'},
    'type_other': {'zh': '其他', 'en': 'Other'},
    'time_morning': {'zh': '白天(6:00-12:00)', 'en': 'Morning (6-12)'},
    'time_afternoon': {'zh': '午后(12:00-18:00)', 'en': 'Afternoon (12-18)'},
    'time_evening': {'zh': '晚上(18:00-24:00)', 'en': 'Evening (18-24)'},
    'time_night': {'zh': '深夜(0:00-6:00)', 'en': 'Late Night (0-6)'},
    'time_tab_period': {'zh': '时段', 'en': 'Period'},
    'time_tab_alt': {'zh': '频率', 'en': 'Frequency'},
    // 全部阅读记录页（ReadingRecordsPage）与记录行文案
    'all_reading_records': {'zh': '全部阅读记录', 'en': 'All Reading Records'},
    'record_duration_label': {'zh': '阅读时长', 'en': 'Duration'},
    'record_read_on': {'zh': '阅读于', 'en': 'Read on'},
    'records_empty': {'zh': '暂无阅读记录', 'en': 'No reading records yet'},
    // 阅读统计详情页（MemoryPage）—— 周期导航与图表/分布补充键
    'year_unit': {'zh': '年', 'en': 'Year'},
    'month_unit': {'zh': '月', 'en': 'Month'},
    'trend_chart_bar': {'zh': '条形', 'en': 'Bar'},
    'trend_chart_line': {'zh': '折线', 'en': 'Line'},
    'freq_under_1h': {'zh': '1小时内', 'en': '< 1h'},
    'freq_1_2h': {'zh': '1-2小时', 'en': '1-2h'},
    'freq_2_3h': {'zh': '2-3小时', 'en': '2-3h'},
    'freq_3h_plus': {'zh': '3小时以上', 'en': '> 3h'},
    'records_finished': {'zh': '看完了', 'en': 'Finished'},
    'records_reading': {'zh': '在读', 'en': 'Reading'},
    'record_progress_prefix': {'zh': '读到', 'en': 'Read to'},
    'record_done_label': {'zh': '已读完', 'en': 'Completed'},
    // 阅读记录重设计（会话级数据）：概览 + 阅读明细 + 读完汇总
    'records_session_count': {'zh': '阅读次数', 'en': 'Sessions'},
    'records_finished_count': {'zh': '读完', 'en': 'Finished'},
    'records_finished_time': {'zh': '读完耗时', 'en': 'Time Finished'},
    'records_detail': {'zh': '阅读明细', 'en': 'Reading Detail'},
    'records_detail_empty': {'zh': '该区间暂无阅读明细', 'en': 'No reading detail in this period'},
    'unknown_book': {'zh': '未知书籍', 'en': 'Unknown Book'},
    'session_start_suffix': {'zh': '开始', 'en': ' started'},
    'session_read_prefix': {'zh': '读了', 'en': 'read '},
    // 阅读时间轴（按月记录真实数据，MemoryMainPage + ReadingTimelinePage）
    'timeline_summary': {
      'zh': '阅读 {books} 本书 · {hours} 小时 · 收藏 {fav} 条',
      'en': 'Read {books} books · {hours} h · {fav} saved',
    },
    'timeline_finished_prefix': {'zh': '读完：', 'en': 'Finished: '},
    'timeline_started_prefix': {'zh': '开始：', 'en': 'Started: '},
    'timeline_book_sep': {'zh': '、', 'en': ', '},
    'timeline_etc': {'zh': '等', 'en': '…'},
    'stats_page_enter': {'zh': '统计页', 'en': 'Stats'},
  };

  static String _toTraditionalChinese(String value) {
    var result = value;
    for (final entry in _traditionalChineseMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String text(String key) {
    final language = SettingsEngine.language;
    if (language == SettingsEngine.languageTraditionalChinese) {
      return _translations[key]?[language] ??
          _toTraditionalChinese(_translations[key]?['zh'] ?? key);
    }
    return _translations[key]?[language] ?? _translations[key]?['zh'] ?? key;
  }
}
