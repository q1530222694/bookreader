from pathlib import Path
from datetime import date

changelog_path = Path('docs/CHANGELOG.md')
entry = '''---

### [2026-07-07] 更新：重置并同步当前文件依赖关系
**【AI 架构依赖树 (Architecture Context)】**
- `docs/不同文件的依赖关系.md`
  └─ 重置 ➔ 更新为当前 `lib/` 代码实际依赖关系
- `lib/core/theme/font_manager.dart`
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`
- `lib/engine/permission_engine.dart`
  └─ 依赖 ➔ `lib/engine/config.dart`
- `lib/engine/settings_engine.dart`
  └─ 依赖 ➔ `lib/engine/config.dart`
- `lib/engine/theme_engine.dart`
  └─ 依赖 ➔ `lib/core/theme/font_manager.dart`
- `lib/features/shell/ui/shell_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/bookshelf_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/home_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/memory_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/profile_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/tools_page.dart`
**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
'''

existing = changelog_path.read_text(encoding='utf-8')
changelog_path.write_text(existing + '\n' + entry, encoding='utf-8')
print('Changlog updated')
