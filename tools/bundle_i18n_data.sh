#!/bin/sh
#  Bundle i18n's generated locale data (share/i18n) into this crate's share
#  tree so a deployed `bin/files` finds it at Exe/../share/i18n. The i18n crate
#  ships no committed data -- its pre-build action regenerates share/i18n from
#  the pinned CLDR subset -- so we copy the freshly generated tree here.
#
#  Run as an Alire post-build action. Safe to run repeatedly: it re-copies only
#  when the source is newer. If the source cannot be found (e.g. a build that
#  resolves i18n from the Alire cache rather than the workspace sibling) it
#  warns and leaves the tree untouched; tools/release_check then fails the
#  release if share/i18n is absent, so a broken package cannot ship silently.
set -eu

DEST="share/i18n"
MARKER="formats.i18ndata"

SRC=""
for cand in "${I18N_DATA_DIR:-}" ../i18n/share/i18n ../../i18n/share/i18n; do
   if [ -n "$cand" ] && [ -f "$cand/$MARKER" ]; then
      SRC="$cand"
      break
   fi
done

if [ -z "$SRC" ]; then
   echo "bundle_i18n_data: i18n share/i18n not found (looked for \$I18N_DATA_DIR," >&2
   echo "  ../i18n/share/i18n, ../../i18n/share/i18n); locale data NOT bundled." >&2
   echo "  release_check enforces its presence before a release." >&2
   exit 0
fi

#  Already current: the bundled marker is at least as new as the source.
if [ -f "$DEST/$MARKER" ] && [ ! "$SRC/$MARKER" -nt "$DEST/$MARKER" ]; then
   exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC/." "$DEST/"
echo "bundle_i18n_data: bundled $SRC -> $DEST"
