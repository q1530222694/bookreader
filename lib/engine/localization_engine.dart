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
    'home': {
      'zh': '主页',
      'en': 'Home',
    },
    'bookshelf': {
      'zh': '书架',
      'en': 'Bookshelf',
    },
    'memory': {
      'zh': '回忆',
      'en': 'Memory',
    },
    'tools': {
      'zh': '工具',
      'en': 'Tools',
    },
    'profile': {
      'zh': '我的',
      'en': 'Profile',
    },
    'daily_sentence': {
      'zh': '每日一句',
      'en': 'Daily Sentence',
    },
    'account_settings': {
      'zh': '账号与设置',
      'en': 'Account & Settings',
    },
    'quick_access': {
      'zh': '快捷入口',
      'en': 'Quick Access',
    },
    'welcome_back': {
      'zh': '欢迎回来！',
      'en': 'Welcome back!',
    },
    'placeholder_description': {
      'zh': '先设置基本入口，后续功能再补齐。',
      'en': 'Set up the basics first, features will follow.',
    },
    'premium': {
      'zh': '开通高级会员',
      'en': 'Activate Premium',
    },
    'membership_center': {
      'zh': '会员中心',
      'en': 'Membership Center',
    },
    'membership_intro': {
      'zh': '高级会员为阅读、记录与AI能力提供更完整的体验。',
      'en': 'Premium membership unlocks a fuller reading, journaling, and AI experience.',
    },
    'membership_architecture': {
      'zh': '会员架构',
      'en': 'Membership Structure',
    },
    'membership_architecture_body': {
      'zh': '会员能力由权限引擎统一调度，服务端配置决定当前是否开放高级权益。',
      'en': 'Membership capabilities are coordinated by the permission engine, and server configuration determines whether premium benefits are enabled.',
    },
    'membership_features': {
      'zh': '会员应有的功能',
      'en': 'Premium Features',
    },
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
    'membership_status_label': {
      'zh': '当前状态',
      'en': 'Current Status',
    },
    'membership_loading': {
      'zh': '正在加载会员状态...',
      'en': 'Loading membership status...',
    },
    'membership_enabled': {
      'zh': '会员功能已启用，会员权限由云端控制。',
      'en': 'Membership features are enabled and permissions are controlled by the server.',
    },
    'membership_disabled': {
      'zh': '会员功能当前未开启，请检查服务器端权限配置。',
      'en': 'Membership features are currently disabled. Please check the server-side permission settings.',
    },
    'membership_vip_status': {
      'zh': '当前为 VIP 用户，等级：',
      'en': 'Current user is VIP, level: ',
    },
    'membership_non_vip_status': {
      'zh': '当前非 VIP 用户，等级：',
      'en': 'Current user is not VIP, level: ',
    },
    'sync': {
      'zh': '同步',
      'en': 'Sync',
    },
    'ai_assistant': {
      'zh': 'AI助手',
      'en': 'AI Assistant',
    },
    'language': {
      'zh': '语言',
      'en': 'Language',
    },
    'appearance': {
      'zh': '外观',
      'en': 'Appearance',
    },
    'theme_color': {
      'zh': '主题配色',
      'en': 'Theme Color',
    },
    'theme_color_blue': {
      'zh': '蓝色',
      'en': 'Blue',
    },
    'theme_color_green': {
      'zh': '绿色',
      'en': 'Green',
    },
    'theme_color_pink': {
      'zh': '粉色',
      'en': 'Pink',
    },
    'theme_color_orange': {
      'zh': '橙色',
      'en': 'Orange',
    },
    'more_settings': {
      'zh': '更多设置',
      'en': 'More Settings',
    },
    'about': {
      'zh': '关于',
      'en': 'About',
    },
    'about_app_title': {
      'zh': '书reader',
      'en': 'Book Reader',
    },
    'about_app_description': {
      'zh': '一款简洁好用的阅读与记录应用，持续优化阅读体验。',
      'en': 'A simple and practical reading and journaling app with continuous experience improvements.',
    },
    'next_page': {
      'zh': '下一页',
      'en': 'Next Page',
    },
    'view_more': {
      'zh': '查看更多',
      'en': 'View More',
    },
    'support_and_links': {
      'zh': '支持与链接',
      'en': 'Support & Links',
    },
    'update_log': {
      'zh': '更新日志',
      'en': 'Update Log',
    },
    'check_update': {
      'zh': '检查更新',
      'en': 'Check Update',
    },
    'qq_group': {
      'zh': 'QQ群',
      'en': 'QQ Group',
    },
    'wechat_group': {
      'zh': '微信群',
      'en': 'WeChat Group',
    },
    'email': {
      'zh': '邮件',
      'en': 'Email',
    },
    'official_website': {
      'zh': '官网',
      'en': 'Official Website',
    },
    'privacy_policy': {
      'zh': '隐私政策',
      'en': 'Privacy Policy',
    },
    'user_agreement': {
      'zh': '用户协议',
      'en': 'User Agreement',
    },
    'update_log_content': {
      'zh': '当前版本为 1.0.0，正在持续优化阅读体验与界面细节。',
      'en': 'The current version is 1.0.0, and the reading experience and interface details are being continuously improved.',
    },
    'update_latest': {
      'zh': '当前已经是最新版本。',
      'en': 'You already have the latest version.',
    },
    'open_failed': {
      'zh': '无法打开该链接，请稍后重试。',
      'en': 'Unable to open the link. Please try again later.',
    },
    'settings': {
      'zh': '设置',
      'en': 'Settings',
    },
    'chinese': {
      'zh': '中文',
      'en': 'Chinese',
      'zh_Hant': '中文',
    },
    'english': {
      'zh': '英文',
      'en': 'English',
      'zh_Hant': '英文',
    },
    'traditional_chinese': {
      'zh': '繁体',
      'en': 'Traditional Chinese',
      'zh_Hant': '繁體',
    },
    'follow_system': {
      'zh': '跟随系统',
      'en': 'Follow System',
    },
    'light_mode': {
      'zh': '亮色模式',
      'en': 'Light Mode',
    },
    'dark_mode': {
      'zh': '暗色模式',
      'en': 'Dark Mode',
    },
    'save': {
      'zh': '保存',
      'en': 'Save',
    },
    'cancel': {
      'zh': '取消',
      'en': 'Cancel',
    },
    'enter_content': {
      'zh': '请输入每日一句内容',
      'en': 'Please enter the daily sentence content',
    },
    'no_sentences': {
      'zh': '尚未添加每日一句内容',
      'en': 'No daily sentences added yet',
    },
    'view_full': {
      'zh': '每日一句全文',
      'en': 'Full daily sentence',
    },
    'font_family': {
      'zh': '字体',
      'en': 'Font Family',
    },
    'system_font': {
      'zh': '系统字体',
      'en': 'System Font',
    },
    'sans_serif': {
      'zh': '无衬线',
      'en': 'Sans Serif',
    },
    'serif': {
      'zh': '有衬线',
      'en': 'Serif',
    },
    'monospace': {
      'zh': '等宽字体',
      'en': 'Monospace',
    },
    'app_appearance': {
      'zh': '应用外观',
      'en': 'App Appearance',
    },
    'theme_mode': {
      'zh': '主题模式',
      'en': 'Theme Mode',
    },
    'theme_color_description': {
      'zh': '选择一个主题配色，应用于整个界面。',
      'en': 'Choose a theme color applied across the app.',
    },
    'startup_page': {
      'zh': '启动页',
      'en': 'Startup Page',
    },
    'startup_page_none': {
      'zh': '不设置（默认主页）',
      'en': 'None (Home)',
    },
    'startup_page_home': {
      'zh': '首页',
      'en': 'Home',
    },
    'startup_page_bookshelf': {
      'zh': '书架',
      'en': 'Bookshelf',
    },
    'startup_page_memory': {
      'zh': '回忆',
      'en': 'Memory',
    },
    'startup_page_tools': {
      'zh': '工具',
      'en': 'Tools',
    },
    'startup_page_profile': {
      'zh': '我的',
      'en': 'Profile',
    },
    'startup_content': {
      'zh': '启动页内容',
      'en': 'Startup Content',
    },
    'startup_content_none': {
      'zh': '不显示',
      'en': 'None',
    },
    'startup_content_text': {
      'zh': '显示文字',
      'en': 'Text',
    },
    'startup_content_text_placeholder': {
      'zh': '在此输入启动页要显示的文字',
      'en': 'Enter startup screen text',
    },
    'startup_content_image': {
      'zh': '显示图片',
      'en': 'Image',
    },
    'startup_content_image_placeholder': {
      'zh': '输入本地文件路径或网络 URL',
      'en': 'Enter local file path or image URL',
    },
    'startup_duration': {
      'zh': '显示时长',
      'en': 'Display Duration',
    },
    'seconds': {
      'zh': '秒',
      'en': 's',
    },
    'duration_picker_title': {
      'zh': '选择显示时长',
      'en': 'Select duration',
    },
    'custom_seconds_label': {
      'zh': '自定义秒数',
      'en': 'Custom seconds',
    },
    'custom_seconds_hint': {
      'zh': '例如 4',
      'en': 'e.g. 4',
    },
    'duration_error': {
      'zh': '请输入大于 0 的整数秒数',
      'en': 'Please enter a positive integer seconds value',
    },
    'language_settings_title': {
      'zh': '语言设置',
      'en': 'Language Settings',
    },
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
      return _translations[key]?[language] ?? _toTraditionalChinese(_translations[key]?['zh'] ?? key);
    }
    return _translations[key]?[language] ?? _translations[key]?['zh'] ?? key;
  }
}
