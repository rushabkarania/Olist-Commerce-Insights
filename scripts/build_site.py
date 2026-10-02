"""Build the deployable GitHub Pages folder and native Power BI download."""
from pathlib import Path
import shutil, zipfile, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(ROOT / 'scripts/build_web_data.py')], check=True)
dest = ROOT / 'dist'
if dest.exists():
    shutil.rmtree(dest)
shutil.copytree(ROOT / 'web', dest)
(dest / 'downloads').mkdir(exist_ok=True)
with zipfile.ZipFile(dest / 'downloads/Olist_PowerBI.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted((ROOT / 'powerbi').rglob('*')):
        if p.is_file() and '.pbi' not in p.parts:
            z.write(p, p.relative_to(ROOT / 'powerbi'))
(dest / '.nojekyll').touch()
print('Site built in', dest)
