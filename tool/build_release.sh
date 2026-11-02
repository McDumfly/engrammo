#!/bin/sh
# Engrammo release build: Dart-kód obfuszkálással.
# Kulcs TILOS release-be (--dart-define és `.env` asset útján is):
# a felhasználó a Beállítások → Meta AI alatt adja meg a saját
# kulcsát (az titkosított tárolóba mentődik a készüléken).
# Használat:  sh tool/build_release.sh [apk|appbundle] [további flagek]
# Példa:      sh tool/build_release.sh appbundle
set -eu
cd "$(dirname "$0")/.."
TARGET="appbundle"
case "${1:-appbundle}" in
  apk|appbundle) TARGET="$1"; shift ;;
  -*) ;;
  *) echo "Ismeretlen cél: $1 (apk|appbundle)" >&2; exit 1 ;;
esac
# A `.env` dev-asset: a build idejére félretesszük a valódit, üres
# helyőrzővel buildelünk (az asset-deklaráció miatt kell a fájl),
# majd visszaállítjuk — build-hiba esetén is.
HAD_ENV="no"
if [ -f .env ]; then
  HAD_ENV="yes"
  mv .env .env.local.keep
fi
RESTORED="no"
restore_env() {
  if [ "$RESTORED" = "no" ]; then
    if [ "$HAD_ENV" = "yes" ] && [ -f .env.local.keep ]; then
      mv .env.local.keep .env
    elif [ "$HAD_ENV" = "no" ]; then
      rm -f .env
    fi
  fi
  RESTORED="yes"
}
trap restore_env EXIT INT TERM
: > .env
set +e
flutter build "$TARGET" --release \
  --obfuscate --split-debug-info=build/debug-info "$@"
STATUS=$?
set -e
restore_env
trap - EXIT INT TERM
exit $STATUS
