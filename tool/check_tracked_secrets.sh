#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r file; do
  case "$file" in
    android/key.properties|android/*.jks|android/*.keystore|assets/.env|android/app/google-services.json)
      echo "Tracked secret-bearing file detected: $file" >&2
      exit 1
      ;;
    *.pem|*.p12|*.pfx|*.keystore|*.jks)
      echo "Tracked signing/certificate material detected: $file" >&2
      exit 1
      ;;
  esac
done < <(git ls-files)

echo 'Tracked-secret guard: OK'
