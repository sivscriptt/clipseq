# clipseq

Paste a list of things in order, one `CMD+V` at a time. macOS only.

You give it a list separated by semicolons:

```
Ahmed Ali;7712345;ahmed@mail.mv;Ma. Rocksdale
```

The first item goes on your clipboard. Every `CMD+V` pastes the current item
and quietly loads the next one — so filling a long form becomes
`CMD+V`, tab, `CMD+V`, tab, `CMD+V`.

`CMD+Z` steps back an item, `CMD+X` steps forward. Neither one pastes.

## Install

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/sivscriptt/clipseq/main/install.sh | bash
```

It puts clipseq in `~/Desktop/clipseq` and builds it. Because Terminal wrote
the files, macOS never tags them — no "damaged" message, nothing to unblock.

Two things it may ask for, both normal and both one-time:

- **Command Line Tools** — clipseq compiles itself on your Mac. If they're
  missing, run `xcode-select --install`, let it finish, run the install line again.
- **Accessibility permission** — this is what lets clipseq notice `CMD+V`.
  Approve **Terminal** in System Settings → Privacy & Security → Accessibility,
  then double-click `clipseq.command` again. If Terminal is already listed but
  the keys do nothing, toggle it off and on — the permission goes stale after a rebuild.

## Using it

Your list lives in `list.txt`, next to `clipseq.command`.

The first run creates that file and opens it in TextEdit (seeded from your
clipboard if you already had a semicolon list copied). Put your list in, save
with `CMD+S`, and double-click `clipseq.command` again. Every run after that
just reads the file — edit and save it any time to change the list.

Then click into the first field and start pasting. The Terminal window shows
where you are, like `[7/32]`. Leave that window open; closing it stops clipseq.

### Keys while it's running

| Keys | Does |
| --- | --- |
| `CMD+V` | paste this item, load the next one |
| `CMD+Z` | back one item |
| `CMD+X` | forward one item |
| `CMD+CTRL+OPT+R` | jump back to item 1 |
| `CMD+CTRL+OPT+P` | pause / resume — gives you real undo and cut back |
| `CMD+CTRL+OPT+Q` | quit, restoring your original clipboard |

### Worth knowing

While clipseq runs it owns `CMD+Z` and `CMD+X` everywhere on your Mac, so undo
and cut stop working until you pause or quit. `CMD+SHIFT+Z` (redo) is untouched.
If that's disruptive, use different keys:

```bash
cd ~/Desktop/clipseq && ./clipseq --prev "[" --next "]"
```

If an app pastes the item you just used instead of the next one, it's reading
the clipboard slowly — give it longer:

```bash
cd ~/Desktop/clipseq && ./clipseq --delay 350 -f list.txt
```

Everything else: `./clipseq --help`

### If you were sent a zip instead

macOS tags anything arriving by Telegram, WhatsApp, AirDrop or download and
refuses to run it, reporting the file as **damaged**. It isn't, and
right-click → Open does not fix this particular block. Either use the install
line above, or clear the tag once: in Terminal type
`xattr -dr com.apple.quarantine ` (keep the trailing space), drag the clipseq
folder onto the Terminal window, and press return.

## Privacy

clipseq watches for three key combinations and writes to your clipboard. It has
no networking code of any kind — no `URLSession`, no sockets, no URLs. It is one
readable Swift file; read it before granting Accessibility if you'd rather check
than trust.

## License

MIT
