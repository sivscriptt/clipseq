#!/bin/bash
# Double-click me.
# The list lives in list.txt next to this file. First run creates that file
# (seeded from your clipboard if you already copied a list) and opens it for
# editing. Every run after that just uses it.
cd "$(dirname "$0")" || exit 1

# Anything that arrived by download/AirDrop/Telegram is tagged by macOS.
# We are already running, so clear the tag off our neighbours quietly.
xattr -dr com.apple.quarantine . 2>/dev/null

# The source sits next to this file, or in source/ when shared as a zip.
SRC=clipseq.swift
[ -f source/clipseq.swift ] && SRC=source/clipseq.swift

# Build once, rebuild only when the source changes.
if [ ! -x ./clipseq ] || [ "$SRC" -nt ./clipseq ]; then
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "clipseq needs Apple's Command Line Tools to build itself (one time, free)."
    echo
    echo "  1. Copy this line:  xcode-select --install"
    echo "  2. Paste it in Terminal and press return, then let it finish."
    echo "  3. Double-click clipseq.command again."
    echo
    echo "Press return to close."
    read -r; exit 1
  fi
  echo "Building clipseq..."
  xcrun swiftc -O -o clipseq "$SRC" || { echo "Build failed."; read -r; exit 1; }
fi

if [ $# -gt 0 ]; then
  ./clipseq "$@"
  echo; echo "Press return to close."; read -r; exit 0
fi

LIST_FILE=list.txt
MARKER="REPLACE THIS LINE WITH YOUR OWN LIST"

# First run: always create the list file. Seed it from the clipboard when
# something list-shaped is already copied, otherwise from a template.
if [ ! -f "$LIST_FILE" ]; then
  CLIP="$(pbpaste 2>/dev/null)"
  if [ -n "$CLIP" ] && printf '%s' "$CLIP" | grep -q ';'; then
    printf '%s\n' "$CLIP" > "$LIST_FILE"
    echo "Created list.txt from what you had copied."
  else
    printf '%s\n' "$MARKER;separate every item;with a semicolon;like this" > "$LIST_FILE"
    echo "Created list.txt for you."
  fi
  echo
  echo "Opening it now. Check it, edit it, save with CMD+S,"
  echo "then double-click clipseq.command again."
  echo
  open -e "$LIST_FILE"
  echo "Press return to close."
  read -r
  exit 0
fi

# Still untouched: send them back to the file rather than running nonsense.
if [ ! -s "$LIST_FILE" ] || grep -q "$MARKER" "$LIST_FILE"; then
  echo "list.txt still needs your list — opening it."
  echo "Save it with CMD+S, then double-click clipseq.command again."
  echo
  open -e "$LIST_FILE"
  echo "Press return to close."
  read -r
  exit 0
fi

echo "Using list.txt  —  edit that file any time to change the list."
echo
./clipseq -f "$LIST_FILE"

echo
echo "Press return to close."
read -r
