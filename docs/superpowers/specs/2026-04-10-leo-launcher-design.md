# Leo — Minimal macOS Launcher (MVP Design)

- **Date**: 2026-04-10
- **Owner**: Kisoo Kim
- **Status**: Design approved, ready for implementation planning

## 1. Purpose

Leo is a minimal, Alfred-style launcher for macOS. The user invokes it with a global hotkey (⌥+Space), types a short keyword, and executes a pre-registered action (open folder, open file, run bash command, or perform a parameterized web search).

Leo is a personal utility built for a single user. It is **not** intended to replace Alfred feature-for-feature. It starts with a minimal core and grows incrementally as new needs arise.

## 2. Scope (MVP)

**In scope:**
- Global hotkey (⌥+Space) to toggle a floating search window
- Prefix-based keyword matching against a local config file
- Four action types: `open_folder`, `open_file`, `run_bash`, `web_search`
- Quick Add form window to register new keyword→action mappings without hand-editing JSON
- Menu bar app (no Dock icon) with Launch-at-Login toggle
- Config file as the source of truth (hand-editable), Quick Add writes to it
- Built-in commands: `reload`, `edit`, `quit`, `add`

**Out of scope (deferred):**
- Fuzzy matching
- Result ranking by usage frequency
- Plugin / workflow system
- Clipboard history, calculator, snippets, file search
- Preferences window (JSON file and Quick Add suffice for now)
- Customizable global hotkey
- Multiple browser selection (default browser only)
- Stdout/stderr capture for bash actions
- Distribution beyond the owner's own Macs

## 3. Architecture Overview

```
┌─────────────────────────────────────────────┐
│  Leo.app (menu bar only, LSUIElement=true)  │
│  ┌──────────────────────────────────────┐   │
│  │ AppDelegate                          │   │
│  │ ├─ HotKeyManager  (⌥+Space → toggle) │   │
│  │ ├─ ConfigLoader   (JSON → [Action])  │   │
│  │ ├─ ConfigWriter   (atomic append)    │   │
│  │ ├─ SearchEngine   (prefix + arg mode)│   │
│  │ ├─ ActionRunner   (dispatch by type) │   │
│  │ ├─ SearchWindow   (NSPanel floating) │   │
│  │ └─ QuickAddWindow (NSPanel floating) │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
         ↑
         │ reads / writes
         │
~/.config/leo/actions.json   (chmod 0600)
```

**Key properties:**
- Menu bar only (`LSUIElement = YES`) — no Dock icon, no app switcher entry
- Floating search window built on `NSPanel` (borderless, non-activating, floating level)
- Single process, state kept in memory (action list loaded from JSON at startup and on reload)
- UI: AppKit for the panels and search table view; SwiftUI only for the Quick Add form (embedded via `NSHostingView`)

## 4. Config File

### 4.1 Location

`~/.config/leo/actions.json`

Reasoning: easier to edit with vim/git than `~/Library/Application Support/`, convenient for optional Syncthing-based sync to other Macs.

### 4.2 Schema

```json
{
  "actions": [
    {
      "keyword": "dl",
      "title": "Downloads 폴더 열기",
      "type": "open_folder",
      "path": "~/Downloads"
    },
    {
      "keyword": "todo",
      "title": "오늘 할일 파일 열기",
      "type": "open_file",
      "path": "~/Sharing/Journal/backlog.md"
    },
    {
      "keyword": "backup",
      "title": "문서 백업 스크립트 실행",
      "type": "run_bash",
      "command": "rsync -av ~/Documents /Volumes/Backup/"
    },
    {
      "keyword": "amazon",
      "title": "Amazon 검색",
      "type": "web_search",
      "url_template": "https://www.amazon.com/s?k={query}",
      "fallback_url": "https://www.amazon.com"
    }
  ]
}
```

### 4.3 Field Reference

| Field | Type | Required for | Description |
|---|---|---|---|
| `keyword` | string | all | Search trigger. Prefix-matched against user input. |
| `title` | string | all | Single-line description shown in the result list. |
| `type` | enum | all | `open_folder` / `open_file` / `run_bash` / `web_search` |
| `path` | string | `open_folder`, `open_file` | Filesystem path. `~` is expanded. |
| `command` | string | `run_bash` | Shell command string. Run via `/bin/zsh -l -c`. |
| `url_template` | string | `web_search` | URL with `{query}` placeholder. URL-encoded on substitution. |
| `fallback_url` | string | `web_search` (optional) | Opened when the user types the keyword alone with no argument. |

JSON uses `snake_case`; Swift properties use `camelCase` (e.g., `urlTemplate`, `fallbackURL`). The mapping is handled by `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.

### 4.4 Validation & Error Handling

- On load: validate each entry against its schema. Malformed entries are dropped with an stderr warning. The app does not crash or refuse to start because of one bad entry.
- Duplicate `keyword` values are allowed — they simply appear as multiple rows in the result list.
- File permissions: Leo sets `chmod 0600` on the config file on first write and warns via `NSAlert` if the permissions are looser at load time. This is a soft integrity check against tampering by other local processes.
- Missing file: treated as an empty action list. Leo still runs; built-in commands still work.

### 4.5 Built-in Commands

Built-in commands do not live in the JSON file; they are always available regardless of config state:

| Keyword | Action |
|---|---|
| `reload` | Reload `actions.json` from disk |
| `edit` | `open ~/.config/leo/actions.json` (opens in default editor for `.json`) |
| `add` | Open the Quick Add window |
| `quit` | Terminate the app |

## 5. Search & Matching

### 5.1 Plain Matching (no space in query)

1. Normalize query: trim whitespace, lowercase
2. If query is empty → show no results
3. Otherwise filter: `action.keyword.lowercased().hasPrefix(query)`
4. Sort: exact matches (`keyword == query`) first, then alphabetical by keyword
5. Cap at 8 results visible at once (scroll beyond that)

### 5.2 Argument Mode (query contains a space)

When the user types a space, Leo switches to argument mode:

1. Split query at the first space → `firstWord`, `rest`
2. Find actions where `keyword == firstWord` **and** the action accepts an argument (currently: `web_search`)
3. Show only those actions in the result list. The row's displayed label is computed dynamically as `"Search \(action.title) for '\(rest)'"` (the stored `title` is not mutated; the override is presentation-only).
4. While in argument mode, non-parameterized matches are hidden to keep the UX focused

This means a single keystroke (the space) switches from "pick an action" to "fill in its argument".

### 5.3 Key Bindings (in the search window)

| Key | Action |
|---|---|
| Return / Enter | Execute the selected result, hide the window |
| Escape | Hide the window (state reset) |
| ↓ | Move selection down (no wrap at bottom) |
| ↑ | Move selection up (no wrap at top) |
| Tab | Autocomplete the search field to the selected action's keyword |
| All other keys | Default text field handling |

### 5.4 Result Row Layout

```
┌────────────────────────────────────────────┐
│  [icon]  Downloads 폴더 열기           dl   │  ← selected row highlighted
│  [icon]  문서 백업 실행               backup │
└────────────────────────────────────────────┘
```

- Left: SF Symbol icon per action type (folder, document, terminal, globe)
- Center: `title`
- Right: `keyword` in a dimmer color, monospace font

### 5.5 Empty State

If the query is non-empty but produces zero results, the table shows a single "No matching actions" row (not selectable).

## 6. Action Execution

All executions are dispatched by `ActionRunner` based on `action.type`.

### 6.1 `open_folder` / `open_file`

```swift
let url = URL(fileURLWithPath: (action.path as NSString).expandingTildeInPath)
NSWorkspace.shared.open(url)
```

- `~` expansion via `NSString.expandingTildeInPath`
- Missing path → `NSAlert` with a descriptive error, app stays alive
- `open_folder` and `open_file` share the same implementation; the distinction is semantic (and affects the row icon)

### 6.2 `run_bash`

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/zsh")
process.arguments = ["-l", "-c", action.command]
process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
try process.run()
// fire-and-forget: do not wait, do not capture stdout/stderr
```

- `-l` (login shell) ensures `PATH`, `~/.zshrc`, and other environment are loaded so commands like `brew`, `python`, `node` resolve correctly
- Working directory: home directory
- Fire-and-forget: Leo does not wait for completion or show output in MVP
- `process.run()` throwing → `NSAlert` with the error message

### 6.3 `web_search`

```swift
let trimmed = rest.trimmingCharacters(in: .whitespaces)

// Empty argument path: use fallback if configured
if trimmed.isEmpty {
    if let fallback = action.fallbackURL, let url = URL(string: fallback) {
        NSWorkspace.shared.open(url)
    }
    return
}

// Encode the argument so &, +, =, # don't break the query string
var allowed = CharacterSet.urlQueryAllowed
allowed.remove(charactersIn: "&+=?#")
guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else {
    showError("Failed to encode search argument")
    return
}

let rawURL = action.urlTemplate.replacingOccurrences(of: "{query}", with: encoded)
guard let url = URL(string: rawURL) else {
    showError("Invalid URL produced from template: \(rawURL)")
    return
}
NSWorkspace.shared.open(url)
```

- Opens in the macOS default browser (respects system setting)
- Empty query with `fallbackURL` → open fallback; without it → Enter is a no-op
- URL-encoding uses `.urlQueryAllowed` minus `&+=?#` so search arguments containing those characters do not corrupt the query string
- Malformed URL template (missing `{query}`, or substitution produces an invalid URL) → `NSAlert`, no crash

### 6.4 Common Execution Flow

```
User presses Enter
    → SearchWindow.hide()            // hide immediately for UX responsiveness
    → DispatchQueue.global().async { ActionRunner.run(action) }
    → On throw: DispatchQueue.main.async { NSAlert }
```

### 6.5 Security Notes

- `run_bash` runs arbitrary shell. Leo trusts the config file because it is user-owned.
- Config file is `chmod 0600` (only the user can read/write). Leo warns if it finds looser permissions at load time.
- App Sandbox is **disabled**: a launcher needs unrestricted filesystem and process access.
- Hardened Runtime is **enabled** alongside Developer ID signing.

## 7. Quick Add Flow

### 7.1 Trigger

The user types `add` in the main search window and presses Enter. The main window hides; the Quick Add window opens.

### 7.2 Quick Add Window

- `NSPanel` subclass, borderless, floating, ~400 × 300pt, centered
- Content: SwiftUI `Form` hosted via `NSHostingView`

**Fields:**

| Field | Control | Visibility |
|---|---|---|
| Keyword | `TextField` | always |
| Title | `TextField` | always |
| Type | `Picker` (Folder / File / Bash / Web Search) | always |
| Path | `TextField` + `Browse…` button (opens `NSOpenPanel`) | Folder, File |
| Command | multiline `TextField` | Bash |
| URL Template | `TextField` with placeholder `https://example.com/search?q={query}` | Web Search |
| Fallback URL | `TextField` (optional) | Web Search |

**Buttons:** `Save`, `Cancel`. `Esc` = Cancel. `Cmd+Return` = Save.

### 7.3 Save Behavior

1. Validate inputs:
   - `keyword`, `title`, `type` non-empty
   - Folder/File: `path` non-empty (existence is *not* required — user may plan to create it)
   - Bash: `command` non-empty
   - Web Search: `url_template` non-empty and contains `{query}`
2. `ConfigWriter` reads the current `actions.json`, appends the new action, and writes atomically (temp file + rename)
3. `ConfigLoader.reload()` is invoked
4. Quick Add window closes
5. Main search window also closes (user can re-open with ⌥Space to use the new action)

### 7.4 Atomicity & Conflict Handling

- Write sequence: create temp file in the same directory → `fsync` → `rename()` over the original → reapply `chmod 0600`
- Before writing, `ConfigWriter` captures the file's `st_mtime`. If the on-disk `st_mtime` changed between load and write, show a warning dialog (user may have been editing in vim) and **do not** overwrite. User can retry.

## 8. Window UX & App Lifecycle

### 8.1 Menu Bar

- `NSStatusItem` with SF Symbol icon (`sparkle.magnifyingglass` or a plain "L")
- Menu items:
  - `Show Leo (⌥Space)` — same effect as the hotkey
  - `Edit Config`
  - `Reload Config`
  - `Launch at Login` (toggle; checkmark reflects current state)
  - `Quit Leo`

### 8.2 Global Hotkey

- **⌥+Space** (Option+Space)
- Library: [`soffes/HotKey`](https://github.com/soffes/HotKey) via SPM — thin Swift wrapper over Carbon HotKey API
- Toggle behavior: pressing the hotkey while the window is visible hides it
- Known risk: ⌥Space conflicts with certain IME / 한영 전환 setups. MVP ships with ⌥Space fixed; customization is deferred.

### 8.3 Search Window

- `NSPanel` subclass
- `styleMask = [.borderless, .nonactivatingPanel]`
- `isFloatingPanel = true`, `level = .floating`
- `backgroundColor = .clear`; content is a rounded rectangle with `NSVisualEffectView` (vibrant blur)
- Fixed width 640pt; height is 60pt when empty and grows with the result list (48pt per row, max 8 rows)
- Position: horizontally centered on the screen that contains the mouse cursor, vertically at 1/3 from the top
- Animations: 0.2s fade + subtle scale-up on show; 0.15s fade on hide

### 8.4 Window State Transitions

| Event | Result |
|---|---|
| ⌥Space (hidden) | Show, focus text field, clear previous query |
| ⌥Space (visible) | Hide |
| Escape | Hide |
| Click outside (lose key) | Hide |
| Return with a selected result | Execute, hide |
| Return with no results | No-op |

### 8.5 Quick Add Window

- Same panel style as the search window
- Opens after the main search window closes
- Closes on Save (after successful write) or Cancel

### 8.6 Launch at Login

- `ServiceManagement.SMAppService.mainApp.register()` / `.unregister()` (macOS 13+)
- Controlled by the menu bar toggle
- Included in MVP — a launcher that does not auto-start is friction the owner does not want

## 9. Project Structure

```
Leo/
├── Leo.xcodeproj
├── Leo/
│   ├── LeoApp.swift              # @main; installs AppDelegate
│   ├── AppDelegate.swift         # lifecycle, hotkey, menu bar wiring
│   ├── Info.plist                # LSUIElement = YES
│   │
│   ├── Config/
│   │   ├── Action.swift          # Action enum + Codable
│   │   ├── ConfigLoader.swift    # read, validate, reload
│   │   └── ConfigWriter.swift    # atomic append with mtime check
│   │
│   ├── Search/
│   │   ├── SearchEngine.swift    # prefix match + argument mode split
│   │   └── SearchResult.swift    # result model (plain vs argument)
│   │
│   ├── Actions/
│   │   └── ActionRunner.swift    # dispatch open_folder/open_file/run_bash/web_search
│   │
│   ├── UI/
│   │   ├── SearchWindow.swift          # NSPanel subclass
│   │   ├── SearchViewController.swift  # NSTextField + NSTableView glue
│   │   ├── ResultCellView.swift        # result row view
│   │   ├── QuickAddWindow.swift        # NSPanel subclass
│   │   └── QuickAddView.swift          # SwiftUI Form
│   │
│   ├── System/
│   │   ├── HotKeyManager.swift         # HotKey library wrapper
│   │   ├── MenuBarController.swift     # NSStatusItem management
│   │   └── LoginItemManager.swift      # SMAppService wrapper
│   │
│   └── Assets.xcassets
│
├── LeoTests/
│   ├── SearchEngineTests.swift
│   ├── ConfigLoaderTests.swift
│   └── ConfigWriterTests.swift
│
└── scripts/
    └── build-and-install.sh      # archive, sign, notarize, staple, copy
```

## 10. Dependencies

- **Target**: macOS 13+ (for SMAppService, stable SwiftUI Form)
- **Language**: Swift 5.9+
- **UI**: AppKit (panels, table view) + SwiftUI (Quick Add form via NSHostingView)
- **SPM packages**:
  - [`soffes/HotKey`](https://github.com/soffes/HotKey)
- **System frameworks**: `Foundation`, `AppKit`, `SwiftUI`, `ServiceManagement`, `Carbon` (indirect via HotKey)

## 11. Testing Strategy

- **Unit tests** (XCTest):
  - `SearchEngineTests` — plain match, argument-mode split, sort order, empty query, no matches
  - `ConfigLoaderTests` — valid JSON, missing fields, malformed entries skipped, missing file, permission warning
  - `ConfigWriterTests` — atomic append, mtime conflict rejection, permission reapplied after rename
- `ActionRunner` uses protocol-based dependencies (`WorkspaceOpening`, `ProcessLaunching`) so tests can inject mocks without touching the real workspace or spawning shells
- UI (SearchWindow, QuickAddView) is verified manually in MVP. XCUITest is deferred.

## 12. Build, Signing, Distribution

- **Development**: Xcode Development signing (automatic, personal Apple Developer team)
- **Local install / personal distribution**: Developer ID Application signing + Notarization
- `scripts/build-and-install.sh` automates:
  1. `xcodebuild archive -scheme Leo -archivePath build/Leo.xcarchive`
  2. `xcodebuild -exportArchive …` with a Developer ID export options plist
  3. `xcrun notarytool submit build/Leo.zip --apple-id … --wait`
  4. `xcrun stapler staple build/Leo.app`
  5. `cp -r build/Leo.app /Applications/`
- **Multi-machine**: either sync the notarized `.app` via Syncthing or re-run the build script on each Mac. Notarization makes the app open cleanly on any Mac without Gatekeeper prompts.
- **Entitlements**: App Sandbox off; Hardened Runtime on; allow unsigned executable memory off.

## 13. Future Extensions (Explicitly Deferred)

These are intentionally not in MVP. They are listed so the design can evolve cleanly toward them.

- **More action types**: `open_url` (static URL), `copy_to_clipboard`, `open_application`
- **Preferences window**: full CRUD GUI for the config (builds on Quick Add)
- **Usage history**: rank results by recent/frequent use
- **Customizable hotkey**: replace the ⌥Space default
- **Fuzzy matching** with a scoring function
- **Per-action browser override** for `web_search`
- **Stdout/stderr display** for `run_bash`

## 14. Open Questions

None at design time. All earlier open questions were resolved during brainstorming:
- Fallback for `web_search` keyword with no argument → optional `fallback_url` field
- Browser choice → default browser only
- Developer account usage → Development signing for dev, Developer ID + Notarization for local install
