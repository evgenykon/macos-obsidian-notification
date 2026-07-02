# AGENTS.md — AI Obsidian Todo Bar

macOS menu bar app for AI-powered task notifications from an Obsidian vault.

## Stack

- **Language:** Swift 6
- **UI:** SwiftUI + AppKit (NSStatusBar, NSPopover, NSMenu)
- **Minimum deployment:** macOS 14.0 (Sonoma)
- **AI:** OpenRouter API (any model, configurable)
- **Notifications:** UserNotifications framework
- **Dependencies:** zero (all native)

## Vault

Paths come from `.env` at project root:

```
OBSIDIAN_VAULT_PATH
TASKS_FOLDER
PROMPT_FILE
HISTORY_FILE_PATTERN
OPENROUTER_API_KEY
AI_MODEL
AI_BASE_URL
CHECK_INTERVAL
```

## Architecture

- `SchedulerService` — timer every 30s: scan vault, check for due tasks, trigger notifications
- `TaskStore` — `@Observable` central state
- `AIService` — OpenRouter HTTP client, supports any model ID
- `PromptService` — reads `_prompt_task.md`, substitutes `{tasks}`, `{context}`, `{dateTime}`
- `HistoryService` — appends AI messages to `history-{date}.md`
- `MenuBarManager` — `NSStatusBar` button + `NSPopover` with SwiftUI content + `NSMenu`

## Task Format

Tasks in `.md` files use YAML frontmatter:

```yaml
---
title: Task title
due: 2026-07-01
time: 14:30
recurring: daysOfWeek
days: mon,wed,fri
overrideTime: 16:00
skipDate: 2026-07-01
---

- [ ] Do something
```

- `due` — date for notification
- `time` — optional; defaults to 09:00
- `recurring` — `daily`, `daysOfWeek`, `weekly`, `monthly`
- `days` — comma-separated: `mon,tue,wed,thu,fri,sat,sun`
- `overrideTime` — temporary time override (auto-cleared on next occurrence via `advanceRecurringTask`)
- `skipDate` — skip task for this date (auto-cleared on next occurrence)

## Key Behaviors

- **No file watcher** — simple polling (30s interval)
- **Prompt reload** — only on demand via tray menu "Reload prompt"
- **Mark done** — modifies `.md` file directly (`- [ ]` → `- [x]`); if all tasks in the file are done, moves it to `Archives/Tasks/`
- **Add/Edit task** — native SwiftUI window via `NSHostingController`
- **Per-task menu** — ⋮ button: postpone 1h, skip today, edit, delete
- **Recurring advance** — done in `tick()` only when `isDone || isSkippedToday || dueDate < today`, NOT at notification time (task stays visible in popover)
- **Done recurring reset** — advancing a done task resets checkbox and moves `due` to next date
- **Notification scheduling** — UNUserNotification with custom sound
- **API key** — stored in Keychain

## Menu

```
🔄 Refresh tasks
Reload prompt
Edit prompt in Obsidian
──────────────
✏️ Add task...
Open vault in Obsidian
──────────────
Settings...
──────────────
Quit
```
