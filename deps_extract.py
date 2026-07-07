import pathlib
import re
root = pathlib.Path('lib').resolve()

deps = {}
for path in sorted(root.rglob('*.dart')):
    rel = path.relative_to(root).as_posix()
    imports = []
    for line in path.read_text(encoding='utf-8', errors='ignore').splitlines():
        m = re.match(r"\s*import\s+['\"]([^'\"]+)['\"]", line)
        if not m:
            continue
        imp = m.group(1)
        if imp.startswith('dart:') or imp.startswith('package:'):
            continue
        target = (path.parent / imp).resolve()
        try:
            target = target.relative_to(root)
            imports.append(target.as_posix())
        except Exception:
            continue
    if imports:
        deps[rel] = imports
with open('deps_raw.txt', 'w', encoding='utf-8') as f:
    for k in sorted(deps):
        f.write(k + '\n')
        for imp in deps[k]:
            f.write('  - ' + imp + '\n')
print('wrote deps_raw.txt')
