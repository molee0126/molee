from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parent.parent
out=root/'dist'; out.mkdir(exist_ok=True)
archive=out/'FaceAI_iOS_Source_20261026.zip'
folders=['lib','test','ios','android','scripts','docs','.github']
root_files=['pubspec.yaml','pubspec.lock','analysis_options.yaml','.flutter-version','.metadata','.gitignore','README.md']
skip_dirs={'.git','.gradle','.kotlin','.symlinks','Pods','build','ephemeral','xcuserdata','__pycache__'}
skip_files={'local.properties','key.properties','Generated.xcconfig','flutter_export_environment.sh','GeneratedPluginRegistrant.java','GeneratedPluginRegistrant.h','GeneratedPluginRegistrant.m','.DS_Store'}
files=[]
for name in folders:
 for p in (root/name).rglob('*'):
  if p.is_file() and not any(part in skip_dirs for part in p.relative_to(root).parts) and p.name not in skip_files:
   files.append(p)
files += [root/name for name in root_files]
files=sorted(set(files))
manifest={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files: z.write(p,'FaceAI/'+p.relative_to(root).as_posix())
 z.writestr('FaceAI/SOURCE_MANIFEST.json',json.dumps(manifest,ensure_ascii=False,indent=2))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert 'FaceAI/lib/main.dart' in z.namelist()
 assert 'FaceAI/.github/workflows/ios.yml' in z.namelist()
 assert not any('/.tooling/' in n or '/Payload/' in n for n in z.namelist())
sha=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/'SHA256.txt').write_text(f'{sha}  {archive.name}\n',encoding='utf-8')
print(f'Created {archive.name}: {len(files)} source files, {archive.stat().st_size} bytes; archive integrity verified.')
