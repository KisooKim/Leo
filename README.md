# Leo

Minimal Alfred-style macOS launcher in Swift + AppKit.

Press `⌥Space`, type a keyword, hit Enter. Leo opens folders, files, runs bash commands, or searches the web — whatever you wire into a small JSON config.

## Why

Alfred and Raycast are great, but for a personal utility the essential loop — _keyword → action_ — is small enough to own. Leo is ~1,500 lines of Swift, has no plugin system, no settings window, no subscription, and starts instantly.

## Features

- **Global hotkey**: `⌥Space` toggles a floating search window
- **Prefix matching**: type the start of a keyword, exact matches float to the top
- **Four action types**:
  - `open_folder` — open a directory in Finder
  - `open_file` — open a file with its default app
  - `run_bash` — fire a shell command via `/bin/zsh -l -c` (login shell, so your PATH works)
  - `web_search` — URL template with `{query}` placeholder, opens in the default browser
- **Argument mode**: `amazon desk` → searches Amazon for "desk". Trailing space + Enter opens an optional fallback URL.
- **Quick Add form**: type `add` + Enter to register a new action without hand-editing the JSON
- **Built-in commands**: `reload`, `edit`, `add`, `quit`
- **Launch at Login** via `SMAppService`
- **Menu bar only** (`LSUIElement=YES`) — no Dock icon, no app switcher entry
- **Atomic config writes** with mtime conflict detection (won't clobber concurrent vim edits)

## Requirements

- macOS 13+ (Ventura)
- Xcode 15+ to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to regenerate the project from `project.yml`

## Build from source

```bash
git clone https://github.com/KisooKim/Leo.git
cd Leo
xcodegen generate
xcodebuild build -scheme Leo -destination 'platform=macOS' -configuration Debug -derivedDataPath build
open build/Build/Products/Debug/Leo.app
```

First launch may prompt for Accessibility permission — grant it in System Settings → Privacy & Security → Accessibility so the global hotkey works.

## Configuration

Config lives at `~/.config/leo/actions.json` (chmod 0600). Missing file is treated as an empty action list, so first launch is fine without one.

Example:

```json
{
  "actions": [
    {
      "keyword": "dl",
      "title": "Open Downloads",
      "type": "open_folder",
      "path": "~/Downloads"
    },
    {
      "keyword": "todo",
      "title": "Today's todo list",
      "type": "open_file",
      "path": "~/Documents/todo.md"
    },
    {
      "keyword": "backup",
      "title": "Rsync Documents to backup drive",
      "type": "run_bash",
      "command": "rsync -av ~/Documents /Volumes/Backup/"
    },
    {
      "keyword": "amazon",
      "title": "Amazon",
      "type": "web_search",
      "url_template": "https://www.amazon.com/s?k={query}",
      "fallback_url": "https://www.amazon.com"
    }
  ]
}
```

### Field reference

| Field | Required for | Description |
|---|---|---|
| `keyword` | all | Search trigger, prefix-matched |
| `title` | all | Display label in the result row |
| `type` | all | `open_folder` / `open_file` / `run_bash` / `web_search` |
| `path` | folder, file | Filesystem path, `~` is expanded |
| `command` | bash | Shell command string |
| `url_template` | web_search | URL with `{query}` placeholder, URL-encoded on substitution |
| `fallback_url` | web_search (optional) | Opened when user types the keyword alone with no argument |

### Built-in keywords

| Keyword | Action |
|---|---|
| `reload` | Reload `actions.json` from disk |
| `edit` | Open the config file in the default editor for `.json` |
| `add` | Open the Quick Add form |
| `quit` | Terminate Leo |

## Release install (signed + notarized)

The included `scripts/build-and-install.sh` archives, signs with Developer ID, notarizes via `notarytool`, staples, and installs to `/Applications`:

```bash
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="XXXXXXXXXX" \
APPLE_APP_PASSWORD="abcd-efgh-ijkl-mnop" \
./scripts/build-and-install.sh
```

For quick iteration without notarization:

```bash
APPLE_ID=... APPLE_TEAM_ID=... SKIP_NOTARIZE=1 ./scripts/build-and-install.sh
```

Generate an app-specific password at https://account.apple.com/account/manage.

## Architecture

```
Leo/
├── Config/           # Action model, ConfigLoader, ConfigWriter
├── Search/           # SearchEngine (prefix + argument-mode matching)
├── Actions/          # ActionRunner with URLOpener / ShellRunning protocols
├── UI/               # SearchWindow, QuickAddWindow (NSPanel + SwiftUI)
├── System/           # HotKeyManager, MenuBarController, LoginItemManager
└── AppDelegate.swift # wires everything
```

Pure logic layers (`Config`, `Search`, `Actions`) have 53 unit tests and no AppKit dependencies. UI and system integration are verified manually.

The design spec and implementation plan are in [`docs/superpowers/`](docs/superpowers/).

## License

MIT — see [LICENSE](LICENSE).
