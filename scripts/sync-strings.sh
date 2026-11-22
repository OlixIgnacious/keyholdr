#!/bin/bash
set -euo pipefail

# Adds every user-facing string in the menu bar app to the String Catalog
# (Sources/keyholdr/Localizable.xcstrings) and marks strings no longer in the
# code as stale — what Xcode does on build, which `swift build` doesn't.
#
# Run it after adding or changing UI text, then fill in the translations
# (Xcode opens .xcstrings in a table editor). Both build variants are
# scanned, since each has strings the other compiles out (#if MAS_BUILD).
# The CLI is English-only and is not scanned.

cd "$(dirname "$0")/.."
CATALOG="Sources/keyholdr/Localizable.xcstrings"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

extract() { # <variant name> [extra swift build args]
    local name="$1"; shift
    echo "🔎 Extracting strings ($name build)..."
    mkdir -p "$OUT/$name"
    # A separate scratch path, so the regular .build isn't rebuilt with these flags.
    swift build --product keyholdr --scratch-path ".build/strings-$name" "$@" \
        -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$OUT/$name" \
        > "$OUT/$name.log" 2>&1 || { cat "$OUT/$name.log"; exit 1; }
}
extract direct
extract mas -Xswiftc -DMAS_BUILD

# The compiler writes one .stringsdata per source file of every module, named
# after the file alone; keep only the app target's (KeyholdrKit and the
# dependencies stay English). Each file records its source path, which is
# checked: a Kit or dependency file with the same name as an app file would
# otherwise overwrite its strings without a word.
DATA=()
while IFS= read -r src; do
    base="$(basename "$src" .swift)"
    for variant in direct mas; do
        data="$OUT/$variant/$base.stringsdata"
        [[ -f "$data" ]] || continue
        origin="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["source"])' "$data")"
        if [[ "$origin" != "$PWD/$src" ]]; then
            echo "❌ $data came from $origin, not $src — rename one of the two files." >&2
            exit 1
        fi
        DATA+=(--stringsdata "$data")
    done
done < <(find Sources/keyholdr -name '*.swift')

if (( ${#DATA[@]} == 0 )); then
    echo "❌ The compiler extracted no strings; check the logs above." >&2
    exit 1
fi

xcrun xcstringstool sync "$CATALOG" "${DATA[@]}"
echo "✅ Synced $CATALOG"
