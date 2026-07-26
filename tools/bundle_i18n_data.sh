#!/bin/sh
#  Bundle the i18n dependency's generated locale data (share/i18n) into this
#  crate's share tree, so a deployed `bin/files` finds it at Exe/../share/i18n.
#  The load-only i18n serves formatting from those files at runtime; i18n ships
#  no committed data -- its own pre-build action regenerates share/i18n from the
#  pinned CLDR subset -- so we copy the freshly generated tree from wherever
#  Alire resolved i18n to.
#
#  Source resolution, in order:
#    1. $I18N_DATA_DIR, if it points straight at a share/i18n tree (an explicit
#       override for packaging pipelines).
#    2. The resolved i18n dependency. Alire puts every dependency's project
#       directory on GPR_PROJECT_PATH during the build, so the i18n crate root
#       -- the one carrying i18n.gpr -- is on it whether i18n is a workspace pin
#       or a published crate in the Alire build cache. Its data is the sibling
#       <i18n-root>/share/i18n.
#    3. A workspace sibling (../i18n), for running this script outside a build.
#
#  Run as an Alire post-build action. Idempotent: it re-copies only when the
#  source is newer. If no source is found it warns and leaves the tree alone;
#  tools/release_check then fails the release when share/i18n is absent, so a
#  broken package cannot ship silently.
set -eu

DEST="share/i18n"
MARKER="formats.i18ndata"

find_src() {
   #  1. Explicit override.
   if [ -n "${I18N_DATA_DIR:-}" ] && [ -f "${I18N_DATA_DIR}/$MARKER" ]; then
      printf '%s\n' "$I18N_DATA_DIR"
      return 0
   fi

   #  2. The i18n dependency, located by its i18n.gpr on GPR_PROJECT_PATH.
   #     Runs in the command-substitution subshell, so setting IFS here does
   #     not leak to the rest of the script.
   if [ -n "${GPR_PROJECT_PATH:-}" ]; then
      IFS=:
      for dir in $GPR_PROJECT_PATH; do
         if [ -f "$dir/i18n.gpr" ] && [ -f "$dir/$DEST/$MARKER" ]; then
            printf '%s\n' "$dir/$DEST"
            return 0
         fi
      done
   fi

   #  3. Workspace sibling.
   for cand in ../i18n/share/i18n ../../i18n/share/i18n; do
      if [ -f "$cand/$MARKER" ]; then
         printf '%s\n' "$cand"
         return 0
      fi
   done

   return 1
}

SRC="$(find_src || true)"

if [ -z "$SRC" ]; then
   echo "bundle_i18n_data: i18n share/i18n not found (\$I18N_DATA_DIR, the i18n" >&2
   echo "  dependency on GPR_PROJECT_PATH, or a workspace sibling); locale data" >&2
   echo "  NOT bundled. release_check enforces its presence before a release." >&2
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
