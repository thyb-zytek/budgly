#!/usr/bin/env bash
set -euo pipefail

# Keep this contract aligned with .github/workflows/main.yml and pubspec.yaml.
# The resolved package graph in pubspec.lock requires Dart 3.13+.
readonly expected_flutter="${FLUTTER_VERSION:-${EXPECTED_FLUTTER_VERSION:-3.47.5}}"
readonly expected_dart="${DART_VERSION:-${EXPECTED_DART_VERSION:-3.13.4}}"

flutter_output="$(flutter --version 2>&1)"
dart_output="$(dart --version 2>&1)"

if ! grep -Eq "^Flutter ${expected_flutter//./\\.}([[:space:]]|$)" <<<"$flutter_output"; then
  printf 'Expected Flutter %s, got:\n%s\n' "$expected_flutter" "$flutter_output" >&2
  exit 1
fi

if ! grep -Eq "Dart SDK version: ${expected_dart//./\\.}([[:space:]]|$)" <<<"$dart_output"; then
  printf 'Expected Dart %s, got:\n%s\n' "$expected_dart" "$dart_output" >&2
  exit 1
fi

if ! grep -Eq '^[[:space:]]*sdk:[[:space:]]*\^3\.13\.0[[:space:]]*$' pubspec.yaml; then
  echo 'pubspec.yaml must declare environment.sdk: ^3.13.0 for the pinned toolchain.' >&2
  exit 1
fi

if ! grep -Eq '^[[:space:]]*dart:[[:space:]]*">=3\.13\.0 <4\.0\.0"[[:space:]]*$' pubspec.lock; then
  echo 'pubspec.lock does not record the expected Dart SDK constraint. Run flutter pub get with the pinned SDK.' >&2
  exit 1
fi

printf 'Toolchain verified: Flutter %s / Dart %s\n' "$expected_flutter" "$expected_dart"
