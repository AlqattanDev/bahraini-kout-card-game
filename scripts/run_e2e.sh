#!/usr/bin/env bash
set -euo pipefail
# Start Firebase emulators and run E2E tests
firebase emulators:exec --only auth,firestore,functions \
  'flutter test test/e2e/ --concurrency=1'
