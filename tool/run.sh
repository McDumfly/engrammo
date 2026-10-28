#!/bin/sh
# Engrammo indító: a `.env`-be egyszer beírt kulccsal indít,
# így nem kell minden alkalommal begépelni a kulcsot.
# Használat:  sh tool/run.sh   (vagy: ./tool/run.sh)
# Extra flutter-argumentumok továbbadhatók:  sh tool/run.sh -d chrome
set -eu
cd "$(dirname "$0")/.."
ARGS=""
if [ -f .env.json ]; then
  ARGS="--dart-define-from-file=.env.json"
else
  KEY=""
  if [ -f .env ]; then
    KEY=$(grep -E '^[[:space:]]*MODEL_API_KEY[[:space:]]*=' .env | tail -n 1 | cut -d= -f2- | sed "s/^[[:space:]]*//;s/[[:space:]]*\$//;s/^\x27//;s/\x27\$//;s/^\"//;s/\"\$//") || true
    if [ -z "$KEY" ]; then
      KEY=$(grep -E '^[[:space:]]*META_API_KEY[[:space:]]*=' .env | tail -n 1 | cut -d= -f2- | sed "s/^[[:space:]]*//;s/[[:space:]]*\$//;s/^\x27//;s/\x27\$//;s/^\"//;s/\"\$//") || true
    fi
  fi
  if [ -n "$KEY" ]; then
    ARGS="--dart-define=MODEL_API_KEY=$KEY"
  fi
fi
if [ -z "$ARGS" ]; then
  exec flutter run "$@"
else
  exec flutter run "$ARGS" "$@"
fi
