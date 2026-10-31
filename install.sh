#!/bin/bash
# clipseq installer.
#   curl -fsSL https://raw.githubusercontent.com/sivscriptt/clipseq/main/install.sh | bash
#
# Downloading with curl means Terminal writes the files, so macOS never tags
# them as quarantined and never claims clipseq is "damaged".
set -euo pipefail

RAW=https://raw.githubusercontent.com/sivscriptt/clipseq/main
DEST="${CLIPSEQ_DIR:-$HOME/Desktop/clipseq}"

echo "Installing clipseq to $DEST"
mkdir -p "$DEST"
curl -fsSL "$RAW/clipseq.swift"   -o "$DEST/clipseq.swift"
curl -fsSL "$RAW/clipseq.command" -o "$DEST/clipseq.command"
chmod +x "$DEST/clipseq.command"

if xcrun --find swiftc >/dev/null 2>&1; then
  echo "Building..."
  xcrun swiftc -O -o "$DEST/clipseq" "$DEST/clipseq.swift"
else
  echo
  echo "Apple's Command Line Tools aren't installed yet (one time, free)."
  echo "Run this, let it finish, then run the install line again:"
  echo
  echo "    xcode-select --install"
  echo
  exit 1
fi

[ "${CLIPSEQ_OPEN:-1}" = "1" ] && open "$DEST"

cat <<EOF

Done. clipseq is in $DEST

Next:
  1. Double-click clipseq.command
  2. It creates list.txt and opens it — put your list in, separated by ";"
     save with CMD+S, and double-click clipseq.command again
  3. Approve Accessibility for Terminal when macOS asks — that is what
     lets clipseq notice you pressing CMD+V

Then CMD+V pastes item 1, the next CMD+V pastes item 2, and so on.
CMD+Z steps back, CMD+X steps forward.
EOF
