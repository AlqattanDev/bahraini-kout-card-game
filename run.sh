#!/bin/bash
# Run the macOS app, auto-cleaning stale Xcode caches if needed.
set -e

cd "$(dirname "$0")"

# Try building first; if it fails with a .pcm error, clean and retry.
if ! flutter run -d macos --dart-define=WORKER_URL=http://localhost:8787 "$@" 2>&1; then
  echo ""
  echo "Build failed — cleaning stale Xcode caches and retrying..."
  flutter clean
  flutter pub get
  (cd macos && pod install)
  flutter run -d macos --dart-define=WORKER_URL=http://localhost:8787 "$@"
fi
