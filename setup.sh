#!/usr/bin/env bash
# One-time setup: generates the android/ios folders around the app code, then patches them.
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "Flutter not found. Install it first: https://docs.flutter.dev/get-started/install"; exit 1; }

mkdir -p .keep && cp -R lib pubspec.yaml .keep/
flutter create --org com.voicetasks --project-name voice_tasks --platforms=android,ios .
rm -rf lib && cp -R .keep/lib lib && cp .keep/pubspec.yaml pubspec.yaml && rm -rf .keep
rm -f test/widget_test.dart

python3 tools/patch_platforms.py
flutter pub get
echo
echo "Done. Plug in a phone (USB debugging on) and run:  flutter run"
