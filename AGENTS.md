# AGENTS.md — AI Obsidian Todo Bar

macOS menu bar app for AI-powered task notifications from an Obsidian vault.

## Stack

- **Language:** Swift 6
- **UI:** SwiftUI + AppKit (NSStatusBar, NSPopover, NSMenu)
- **Minimum deployment:** macOS 14.0 (Sonoma)
- **AI:** OpenRouter API (any model, configurable)
- **Notifications:** UserNotifications framework
- **Widget:** WidgetKit
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

Tasks in `.md` files use **Obsidian Tasks plugin format** (or plain `- [ ]` checkboxes):

```yaml
---
title: Task file title
due: 2025-12-01
time: 14:30
---
- [ ] Do something
- [x] Done thing
```

- `due` — date for notification
- `time` — optional; defaults to 09:00

## Key Behaviors

- **No file watcher** — simple polling (30s interval)
- **Prompt reload** — only on demand via tray menu "Reload prompt"
- **Mark done** — modifies `.md` file directly (`- [ ]` → `- [x]`)
- **Notification scheduling** — UNUserNotification with custom sound
- **API key** — stored in Keychain

## Health Strategy («Стратегия 90 лет»)

Located in `Areas/Здоровье/Стратегия 90 лет/`. Age-bracketed plans:

| File | Focus |
|------|-------|
| `Стратегия 40–45.md` | Foundation: Ozempic, weight, diet, screenings, metformin, NMN, rapamycin prep |
| `Стратегия 45–50.md` | Consolidation: rapamycin start, TERT evaluation |
| `Стратегия 50–60.md` | Maintenance: OSK reprogramming, cognitive reserve, CAC scan |
| `Стратегия 60–70.md` | Healthy aging: mobility, cognition, CRC/vision/hearing |
| `Стратегия 70–80.md` | Healthspan: falls prevention, immunity, polypharmacy review |
| `Стратегия 80–90.md` | QALY: independence, cognition, social engagement |

## Tray Menu

```
🔔 AI Obsidian Todo Bar
[task list with checkboxes]

[recent AI notifications]
──────────────────────
🔄 Reload prompt
📝 Edit prompt in Obsidian
⚙️ Settings...
Open tasks folder
Quit
```
