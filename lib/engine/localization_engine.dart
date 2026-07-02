import 'settings_engine.dart';

/// LocalizationEngine provides minimal translation support for Chinese and English.
class LocalizationEngine {
  LocalizationEngine._();

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
    'more_settings': {
      'zh': '更多设置',
      'en': 'More Settings',
    },
    'about': {
      'zh': '关于',
      'en': 'About',
    },
    'settings': {
      'zh': '设置',
      'en': 'Settings',
    },
    'chinese': {
      'zh': '中文',
      'en': 'Chinese',
    },
    'english': {
      'zh': '英文',
      'en': 'English',
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
  };

  static String text(String key) {
    final language = SettingsEngine.language;
    return _translations[key]?[language] ?? _translations[key]?['zh'] ?? key;
  }
}
