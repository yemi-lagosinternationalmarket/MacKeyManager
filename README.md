# MacKeyManager

A native macOS app for managing environment variables across your system. Browse, search, and edit global variables (`~/.zshrc`) and project-local variables (`.env` files) from a single interface.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange) ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)

## Features

- **Three-column interface** — sidebar navigation, variable list with search/sort, and detail editor
- **Global variable management** — parses `export KEY=VALUE` from `~/.zshrc` while preserving comments, aliases, and functions
- **Project `.env` support** — import any project folder and manage its `.env` file
- **Safe `.zshrc` editing** — diff preview before saving, timestamped backups on every write
- **Value masking** — values hidden by default, revealed on click
- **Cross-project search** — catalog indexes all variables for quick lookup
- **Menu bar popover** — quick access to pinned/recent variables without opening the main window
- **Clipboard auto-clear** — copied values cleared from clipboard after 60 seconds
- **File watching** — detects external changes and auto-reloads
- **Keyboard shortcuts** — Cmd+N (add), Cmd+S (save), Cmd+F (search)

## Architecture

```
Sources/
├── MacKeyManagerLib/          # Core logic (library target)
│   ├── Models/                # EnvironmentVariable, Project, CatalogEntry
│   ├── Utilities/             # ShellParser, EnvFileParser, Validators, Errors
│   ├── Services/              # ZshrcService, DotEnvService, CatalogService, FileWatcher
│   └── ViewModels/            # EnvVarListViewModel, ProjectViewModel
├── MacKeyManager/             # SwiftUI app (executable target)
│   ├── App/                   # MacKeyManagerApp, AppState
│   └── Views/                 # Sidebar, EnvVarList, EnvVarDetail, MenuBar
└── Tests/MacKeyManagerTests/  # 61 tests covering parsers, services, validators
```

**Key design decisions:**
- Files are the source of truth — the app parses into `[ParsedLine]`, modifies in-memory, and reconstructs the full file on save (preserving comments, blank lines, aliases)
- `@Observable` (Observation framework) for all state management
- JSON-file catalog for cross-project variable indexing
- Atomic file writes with backup-before-save for `.zshrc`

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+
- Xcode 15+ (for full GUI) or Swift Command Line Tools (for building/testing)

## Getting Started

### Run in Xcode (recommended)

```bash
open Package.swift
```

Then press **Cmd+R** to build and run.

### Build from command line

```bash
swift build
```

### Run tests

```bash
swift run MacKeyManagerTests
```

## Usage

1. **Global variables** load automatically from `~/.zshrc` on launch
2. Click **Add Project** in the sidebar to import a project folder with a `.env` file
3. **Search** across all variables using the search bar or menu bar popover
4. **Edit** a variable by selecting it and modifying the detail panel
5. **Save** — `.zshrc` changes show a diff preview first; `.env` changes save directly
6. **Pin** frequently used variables in the menu bar for quick access

## License

MIT
