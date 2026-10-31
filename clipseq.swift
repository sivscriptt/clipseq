#!/usr/bin/env swift
//
//  clipseq — paste a list of items in order, one CMD+V at a time.
//
//  Feed it a list separated by ";". The first item is copied to the clipboard.
//  Every CMD+V pastes the current item, then the next one is auto-copied in the
//  background so the following CMD+V pastes item 2, then 3, and so on.
//  CMD+Z / CMD+X step backwards / forwards through the list without pasting.
//
//  Run:  swift clipseq.swift "one; two; three"
//  Help: swift clipseq.swift --help
//

import Cocoa
import CoreGraphics

// ---------------------------------------------------------------- key names

let keyCodes: [String: Int64] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
    "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
    "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
    "n": 45, "m": 46, ".": 47, "`": 50,
    "space": 49, "left": 123, "right": 124, "down": 125, "up": 126,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98,
    "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
]

let kV: Int64 = 9
let kR: Int64 = 15
let kP: Int64 = 35
let kQ: Int64 = 12

// ---------------------------------------------------------------- options

struct Options {
    var separator = ";"
    var trim = true
    var keepEmpty = false
    var wrap = false
    var delayMs = 200
    var prevKey: Int64 = 6   // z
    var nextKey: Int64 = 7   // x
    var text: String?
    var file: String?
    var dryRun = false
}

func usage() -> String {
    return """
    clipseq — paste a list in order, one CMD+V at a time.

    USAGE
      swift clipseq.swift "item one; item two; item three"
      swift clipseq.swift -f list.txt
      pbpaste | swift clipseq.swift          # read the list from stdin
      swift clipseq.swift                    # prompts for the list

    HOTKEYS (while running)
      CMD+V              paste current item, then auto-copy the next one
      CMD+Z              step back one item   (rebind with --prev)
      CMD+X              step forward one item (rebind with --next)
      CMD+CTRL+OPT+R     jump back to item 1
      CMD+CTRL+OPT+P     pause / resume interception (gives you back real undo/cut)
      CMD+CTRL+OPT+Q     quit and restore your original clipboard

    OPTIONS
      -f, --file PATH    read the list from a file
      --sep S            separator (default ";")
      --wrap             wrap around at both ends instead of stopping
      --delay MS         ms to wait after CMD+V before swapping the clipboard
                         (default 200; raise it if a slow app pastes the wrong item)
      --prev KEY         key used with CMD to go back (default z)
      --next KEY         key used with CMD to go forward (default x)
      --no-trim          keep leading/trailing whitespace on each item
      --keep-empty       keep empty items
      --dry-run          print how the list splits, then exit
      -h, --help         this text

    NOTE
      Needs Accessibility permission for whatever runs it (Terminal, iTerm...):
      System Settings > Privacy & Security > Accessibility.
      While running, CMD+Z and CMD+X are taken over globally — undo and cut stop
      working in every app until you pause (CMD+CTRL+OPT+P) or quit.
    """
}

func parseArgs() -> Options {
    var o = Options()
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    func value(_ flag: String) -> String {
        i += 1
        guard i < args.count else {
            FileHandle.standardError.write("clipseq: \(flag) needs a value\n".data(using: .utf8)!)
            exit(2)
        }
        return args[i]
    }
    func keyCode(_ flag: String, _ name: String) -> Int64 {
        guard let c = keyCodes[name.lowercased()] else {
            FileHandle.standardError.write("clipseq: unknown key '\(name)' for \(flag)\n".data(using: .utf8)!)
            exit(2)
        }
        return c
    }
    while i < args.count {
        let a = args[i]
        switch a {
        case "-h", "--help":     print(usage()); exit(0)
        case "-f", "--file":     o.file = value(a)
        case "--sep":            o.separator = value(a)
        case "--wrap":           o.wrap = true
        case "--no-trim":        o.trim = false
        case "--keep-empty":     o.keepEmpty = true
        case "--dry-run":        o.dryRun = true
        case "--delay":          o.delayMs = max(0, Int(value(a)) ?? 200)
        case "--prev":           o.prevKey = keyCode(a, value(a))
        case "--next":           o.nextKey = keyCode(a, value(a))
        default:
            if a.hasPrefix("-") && a.count > 1 {
                FileHandle.standardError.write("clipseq: unknown option \(a)\n".data(using: .utf8)!)
                exit(2)
            }
            o.text = (o.text.map { $0 + " " } ?? "") + a
        }
        i += 1
    }
    return o
}

// ---------------------------------------------------------------- input

func readList(_ o: Options) -> [String] {
    var raw: String
    if let f = o.file {
        guard let s = try? String(contentsOfFile: (f as NSString).expandingTildeInPath, encoding: .utf8) else {
            FileHandle.standardError.write("clipseq: cannot read \(f)\n".data(using: .utf8)!)
            exit(1)
        }
        raw = s
    } else if let t = o.text {
        raw = t
    } else if isatty(FileHandle.standardInput.fileDescriptor) == 1 {
        print("Paste your list (separated by \"\(o.separator)\") and hit return:")
        raw = readLine(strippingNewline: true) ?? ""
    } else {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        raw = String(data: data, encoding: .utf8) ?? ""
    }
    if o.file != nil || o.text == nil {
        raw = raw.trimmingCharacters(in: .newlines)
    }
    var items = raw.components(separatedBy: o.separator)
    if o.trim { items = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    if !o.keepEmpty { items = items.filter { !$0.isEmpty } }
    return items
}

// ---------------------------------------------------------------- sequencer

final class Sequencer {
    let items: [String]
    let opts: Options
    var index = 0
    var paused = false
    var pendingAdvance: DispatchWorkItem?
    let pasteboard = NSPasteboard.general
    let originalClipboard: String?

    init(items: [String], opts: Options) {
        self.items = items
        self.opts = opts
        self.originalClipboard = NSPasteboard.general.string(forType: .string)
    }

    func preview(_ s: String) -> String {
        var p = s.replacingOccurrences(of: "\n", with: "⏎")
        if p.count > 60 { p = String(p.prefix(59)) + "…" }
        return p
    }

    func copyCurrent(_ note: String) {
        let item = items[index]
        pasteboard.clearContents()
        _ = pasteboard.setString(item, forType: .string)
        print("[\(index + 1)/\(items.count)] \(note) \(preview(item))")
        fflush(stdout)
    }

    func step(_ delta: Int, note: String) {
        let n = items.count
        var next = index + delta
        if opts.wrap {
            next = ((next % n) + n) % n
        } else if next < 0 {
            next = 0
            if index == 0 { print("— start of list"); fflush(stdout); return }
        } else if next >= n {
            next = n - 1
            if index == n - 1 { print("— end of list (CMD+V repeats the last item)"); fflush(stdout); return }
        }
        index = next
        copyCurrent(note)
    }

    func reset() {
        index = 0
        copyCurrent("reset →")
    }

    /// CMD+V passes through untouched; we swap in the next item once the paste has landed.
    func schedulePasteAdvance() {
        pendingAdvance?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.paused else { return }
            self.step(1, note: "next →")
        }
        pendingAdvance = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(opts.delayMs), execute: work)
    }

    func togglePause() {
        paused.toggle()
        if paused {
            pendingAdvance?.cancel()
            print("|| paused — CMD+Z / CMD+X / CMD+V are back to normal. CMD+CTRL+OPT+P resumes.")
        } else {
            print("▶ resumed")
            copyCurrent("at")
        }
        fflush(stdout)
    }

    func quit() -> Never {
        pendingAdvance?.cancel()
        if let original = originalClipboard {
            pasteboard.clearContents()
            _ = pasteboard.setString(original, forType: .string)
            print("\nclipseq: stopped, original clipboard restored.")
        } else {
            print("\nclipseq: stopped.")
        }
        exit(0)
    }
}

// ---------------------------------------------------------------- event tap

var seq: Sequencer!
var tapRef: CFMachPort?

let plainCmd: CGEventFlags = .maskCommand
let hyper: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
let watched: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]

func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = tapRef { CGEvent.tapEnable(tap: t, enable: true) }
        return nil
    }
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }

    let key = event.getIntegerValueField(.keyboardEventKeycode)
    let mods = event.flags.intersection(watched)
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

    // Control hotkeys work even while paused.
    if mods == hyper && !isRepeat {
        switch key {
        case kP: seq.togglePause(); return nil
        case kQ: seq.quit()
        case kR: if !seq.paused { seq.reset() }; return nil
        default: break
        }
    }

    guard !seq.paused, mods == plainCmd, !isRepeat else {
        return Unmanaged.passUnretained(event)
    }

    switch key {
    case kV:
        seq.schedulePasteAdvance()
        return Unmanaged.passUnretained(event)   // let the paste through
    case seq.opts.prevKey:
        seq.step(-1, note: "← prev")
        return nil                               // swallowed: no undo fires
    case seq.opts.nextKey:
        seq.step(1, note: "next →")
        return nil                               // swallowed: no cut fires
    default:
        return Unmanaged.passUnretained(event)
    }
}

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    return handle(type, event)
}

// ---------------------------------------------------------------- main

let options = parseArgs()
let items = readList(options)

guard !items.isEmpty else {
    FileHandle.standardError.write("clipseq: empty list — nothing to paste.\n".data(using: .utf8)!)
    exit(1)
}

if options.dryRun {
    for (n, item) in items.enumerated() { print("[\(n + 1)/\(items.count)] \(item)") }
    exit(0)
}

let trusted = AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
if !trusted {
    FileHandle.standardError.write("""
    clipseq: Accessibility permission is required to watch CMD+V / CMD+Z / CMD+X.
    Approve the app running this script (Terminal, iTerm, ...) in
    System Settings > Privacy & Security > Accessibility, then run clipseq again.

    """.data(using: .utf8)!)
    exit(1)
}

seq = Sequencer(items: items, opts: options)

let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                  place: .headInsertEventTap,
                                  options: .defaultTap,
                                  eventsOfInterest: mask,
                                  callback: tapCallback,
                                  userInfo: nil) else {
    FileHandle.standardError.write("clipseq: could not create the event tap (Accessibility permission?)\n".data(using: .utf8)!)
    exit(1)
}
tapRef = tap
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler { seq.quit() }
sigint.resume()

let prevName = keyCodes.first { $0.value == options.prevKey }?.key.uppercased() ?? "?"
let nextName = keyCodes.first { $0.value == options.nextKey }?.key.uppercased() ?? "?"
print("""
clipseq: \(items.count) items loaded.
  CMD+V pastes and advances · CMD+\(prevName) prev · CMD+\(nextName) next
  CMD+CTRL+OPT+R reset · CMD+CTRL+OPT+P pause · CMD+CTRL+OPT+Q quit (or Ctrl+C here)
""")
seq.copyCurrent("ready:")

CFRunLoopRun()
