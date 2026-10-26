from pathlib import Path
import plistlib,xml.etree.ElementTree as ET,json,re
root=Path.cwd()
info=plistlib.loads((root/'ios/Runner/Info.plist').read_bytes())
assert info['NSCameraUsageDescription']
assert 'NSMicrophoneUsageDescription' not in info
assert 'NSPhotoLibraryUsageDescription' not in info
assert 'NSAllowsArbitraryLoads' not in info.get('NSAppTransportSecurity',{})
for base in ['ios','android/app/src']:
 for p in (root/base).rglob('*'):
  if p.suffix in ['.xml','.plist','.storyboard','.xcscheme','.xcworkspacedata']:
   if 'ephemeral' not in p.parts:
    ET.parse(p)
project=(root/'ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8-sig')
assert 'IPHONEOS_DEPLOYMENT_TARGET = 15.5;' in project
assert 'FlutterGeneratedPluginSwiftPackage' not in project
clean=re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"','',project,flags=re.S)
for a,b in [('{','}'),('(',')')]: assert clean.count(a)==clean.count(b),(a,b)
manifest=(root/'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8-sig')
assert 'android:allowBackup="false"' in manifest
assert 'android.permission.RECORD_AUDIO" tools:node="remove"' in manifest
assert 'enableAudio: false' in (root/'lib/platform/capture_camera.dart').read_text(encoding='utf-8')
lib='\n'.join(p.read_text(encoding='utf-8-sig') for p in (root/'lib').rglob('*.dart'))
assert not re.search(r'\b(HttpClient|WebSocket|Dio|FirebaseStorage)\b',lib)
print('PASS: iOS plist/XML, deployment target and project structure; Android privacy manifest; capture audio disabled; no application upload client.')
