# AI Obsidian Todo Bar — Architecture Plan

## What

A macOS menu bar app that:
- Monitors `Inbox/tasks/` in an Obsidian vault
- Generates **AI-powered supportive notifications** via OpenRouter
- Shows a **macOS-native popover** with task list + recent AI messages
- **Syncs checkboxes** back to `.md` files (mark done from tray)
- Logs all AI notifications to `Inbox/tasks/history-{date}.md`
- Editable prompt template in `Inbox/tasks/_prompt.md`
- Desktop widget via WidgetKit

## Principles

- **No file watcher** — simple polling every 30s via `SchedulerService`
- **Prompt** re-read only on demand ("Reload prompt" command)
- **Zero external dependencies** — all parsing is custom (YAML is limited/simple)
- **macOS 14+** (Sonoma) — WidgetKit support

## Flow

```
App launch → MenuBarManager
                │
                ├── TaskStore (@Observable, shared state)
                │       │
                │       ├── SchedulerService (30s tick)
                │       │       ├── VaultReader → FrontmatterParser → TaskParser
                │       │       └── check: time to notify?
                │       │               │
                │       │               ▼ if yes
                │       │           AIService
                │       │               ├── PromptService (reads _prompt.md)
                │       │               └── OpenRouter API
                │       │               │
                │       │               ▼
                │       │           NotificationService (UNNotification + sound)
                │       │           HistoryService (append to history-{date}.md)
                │       │
                │       └── PopoverContentView (SwiftUI)
                │               ├── TaskListView (macOS-style)
                │               ├── NotificationHistoryView
                │               └── Menu: Reload | Edit | Settings | Quit
                │
                ├── NSStatusBar icon
                └── NSPopover → PopoverContentView
```

## Project Structure

```
macos-obsidian-notification/
├── ObsidianTodoBar.xcodeproj
└── ObsidianTodoBar/
    ├── ObsidianTodoBarApp.swift        # @main SwiftUI App
    ├── MenuBarManager.swift            # NSStatusBar + popover + tray menu
    ├── Models/
    │   ├── TaskItem.swift              # title, dueDate, filePath, lineNumber
    │   └── AppConfig.swift             # vaultPath, apiKey, model, checkInterval
    ├── Parsing/
    │   ├── VaultReader.swift           # async — scan .md in Inbox/tasks/
    │   ├── FrontmatterParser.swift     # YAML → due:, date:, time:
    │   └── TaskParser.swift            # - [ ] → TaskItem[]
    ├── Services/
    │   ├── TaskStore.swift             # @Observable — all state
    │   ├── SchedulerService.swift      # 30s tick: check & notify
    │   ├── PromptService.swift         # read _prompt.md + substitute variables
    │   ├── AIService.swift             # OpenRouter HTTP client
    │   ├── NotificationService.swift   # UNUserNotification + sound
    │   └── HistoryService.swift        # append to history-{date}.md
    ├── UI/
    │   ├── PopoverContentView.swift    # popover root
    │   ├── TaskListView.swift          # grouped: Today, Tomorrow, Overdue
    │   ├── TaskRowView.swift           # checkbox + title + time
    │   ├── NotificationHistoryView.swift
    │   └── SettingsView.swift          # vault path, API key, model
    └── Resources/
        ├── Assets.xcassets/
        └── AppConfig.swift
```

## Vault Files

Paths come from `.env` at project root:

| File | Path (from `.env`) | Purpose |
|------|---------------------|---------|
| `_prompt.md` | `$PROMPT_FILE` | AI prompt template with `{tasks}`, `{context}`, `{dateTime}` |
| `history-{date}.md` | `$HISTORY_FILE_PATTERN` | Daily log of AI notifications |

## Config (AppConfig)

```swift
struct AppConfig {
    var vaultPath: String           // from $OBSIDIAN_VAULT_PATH
    var tasksFolder: String         // from $TASKS_FOLDER
    var openRouterApiKey: String    // in Keychain
    var model: String               // from $DEFAULT_AI_MODEL
    var checkInterval: TimeInterval // from $CHECK_INTERVAL
    var defaultNotificationHour: Int // 9
}
```

## Tray Menu

```
┌──────────────────────────────┐
│  🔔 AI Obsidian Todo Bar     │
├──────────────────────────────┤
│  [Task list with checkboxes] │
│                               │
│  ─── Recent notifications ── │
│  [AI message text]           │
│                               │
├──────────────────────────────┤
│  🔄 Reload prompt             │
│  📝 Edit prompt in Obsidian   │
│  ⚙️ Settings...               │
│  Open tasks folder            │
│                               │
│  Quit                         │
└──────────────────────────────┘
```

## API: OpenRouter

```
POST https://openrouter.ai/api/v1/chat/completions
Authorization: Bearer {apiKey}
{
  "model": "openai/gpt-4o-mini",
  "messages": [{"role": "system", "content": "{prompt from _prompt.md}"}],
  "max_tokens": 200,
  "temperature": 0.8
}
```

## Implementation Order

| # | Step | What |
|---|------|------|
| 1 | Xcode project | macOS SwiftUI App, deploy target 14.0 |
| 2 | Models | `TaskItem`, `AppConfig` |
| 3 | Parsers | `FrontmatterParser`, `TaskParser`, `VaultReader` |
| 4 | TaskStore | `@Observable` state container |
| 5 | PromptService | read `_prompt.md` + substitute `{...}` |
| 6 | AIService | OpenRouter HTTP + fallback |
| 7 | SchedulerService | Timer + check loop |
| 8 | NotificationService | UNNotification + sound |
| 9 | HistoryService | append to `history-{date}.md` |
| 10 | MenuBarManager | NSStatusBar + NSPopover + NSMenu |
| 11 | Popover UI | TaskListView, TaskRowView |
| 12 | Mark done | reverse sync `- [ ]` → `- [x]` in .md |
| 13 | Tray menu | Reload, Edit, Settings, Quit |
| 14 | Settings UI | vault path, API key, model |
| 15 | Widget | WidgetKit extension |
| 16 | Logging | console + optional file |

## Dependencies

Zero external. All native:
- `SwiftUI` + `AppKit` — UI
- `URLSession` — HTTP
- `Codable` — JSON
- `UserNotifications` — alerts
- `WidgetKit` — widget
- Custom minimal YAML parser (frontmatter only)
