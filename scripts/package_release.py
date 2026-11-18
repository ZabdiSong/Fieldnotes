#!/usr/bin/env python3
"""Package only distributable source/assets and the built app, never local planner data."""
from pathlib import Path
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)

files = [ROOT / name for name in ("README.md", "Info.plist", ".gitignore")]
files += sorted(ROOT.glob("*.swift"))
files += sorted(ROOT.glob("*.command"))
files += sorted((ROOT / "Assets").glob("*"))
files += [Path(__file__).resolve()]
files = sorted({path for path in files if path.is_file()})

source_zip = DIST / "Fieldnotes-GitHub.zip"
with zipfile.ZipFile(source_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in files:
        archive.write(path, str(Path("Fieldnotes") / path.relative_to(ROOT)))

bundle = ROOT / "build/Fieldnotes.app"
if not (bundle / "Contents/MacOS/Fieldnotes").is_file():
    raise SystemExit("Build the app with zsh build.command before packaging.")
app_zip = DIST / "Fieldnotes-macOS.zip"
with zipfile.ZipFile(app_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(bundle.rglob("*")):
        if path.is_file() and path.name != ".DS_Store" and not path.name.startswith("._"):
            archive.write(path, str(Path(bundle.name) / path.relative_to(bundle)))

for path in (source_zip, app_zip):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        names = archive.namelist()
        assert not any("__MACOSX" in name or "/.private/" in name or name.endswith("planner.json") for name in names)
    print(json.dumps({"file": str(path), "bytes": path.stat().st_size, "entries": len(names)}))
