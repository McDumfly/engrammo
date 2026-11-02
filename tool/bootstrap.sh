#!/bin/sh
# One-time setup for a fresh clone: creates the two gitignored files the
# build needs, without overwriting real ones.
set -e
cd "$(dirname "$0")/.."
[ -f .env ] || { cp .env.example .env; echo "Created .env (empty key -> local AI fallback)."; }
[ -f lib/firebase_options.dart ] || { cp lib/firebase_options.example.dart lib/firebase_options.dart; echo "Created local-only lib/firebase_options.dart."; }
flutter pub get
