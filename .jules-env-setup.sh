#!/usr/bin/env bash
set -e

# Install Dart SDK
sudo apt-get update -qq
sudo apt-get install -y -qq apt-transport-https
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt-get update -qq
sudo apt-get install -y -qq dart
export PATH="$PATH:/usr/lib/dart/bin:$HOME/.pub-cache/bin"

# Install Flutter
dart pub global activate flutter
export PATH="$PATH:$HOME/.pub-cache/bin"
flutter pub get
