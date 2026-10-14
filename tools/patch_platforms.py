#!/usr/bin/env python3
"""Applies the platform settings Voice Tasks needs (Android manifest, desugaring, iOS permissions)."""
import pathlib, plistlib, re, shutil

root = pathlib.Path(__file__).resolve().parent.parent

# --- Android manifest
dst = root / 'android/app/src/main/AndroidManifest.xml'
shutil.copy(root / 'tools/AndroidManifest.xml', dst)
print('✓ AndroidManifest.xml (permissions, notification receivers, speech query)')

# --- Android desugaring (needed by flutter_local_notifications)
gradle = None
for name, kts in (('build.gradle.kts', True), ('build.gradle', False)):
    f = root / 'android/app' / name
    if f.exists():
        gradle, is_kts = f, kts
        break
if gradle is None:
    print('! android/app/build.gradle not found, see README step 3')
else:
    s = gradle.read_text()
    if 'esugaring' in s:
        print('✓ desugaring already enabled')
    else:
        flag = 'isCoreLibraryDesugaringEnabled = true' if is_kts else 'coreLibraryDesugaringEnabled true'
        s2, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        ' + flag, s, count=1)
        dep = ('\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n'
               if is_kts else
               "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n")
        if n == 0:
            print('! compileOptions block not found, see README step 3')
        else:
            gradle.write_text(s2 + dep)
            print('✓ desugaring enabled in', gradle.name)

# --- iOS permission texts
plist = root / 'ios/Runner/Info.plist'
if plist.exists():
    with open(plist, 'rb') as fh:
        d = plistlib.load(fh)
    d['NSMicrophoneUsageDescription'] = 'Voice Tasks listens when you hold the button to capture your tasks.'
    d['NSSpeechRecognitionUsageDescription'] = 'Voice Tasks turns what you say into tasks.'
    d['NSCalendarsUsageDescription'] = 'Voice Tasks adds your tasks to your calendar.'
    d['NSCalendarsFullAccessUsageDescription'] = 'Voice Tasks adds your tasks to your calendar.'
    with open(plist, 'wb') as fh:
        plistlib.dump(d, fh)
    print('✓ iOS Info.plist permissions')
