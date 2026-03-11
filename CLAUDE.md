# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make build    # build binary to ./claude-dashboard
make run      # build and run
make test     # go test ./...
make lint     # golangci-lint run ./...
make install  # go install to $GOPATH/bin
make clean    # remove binary
```

Run a single test:
```bash
go test ./internal/tmux/... -run TestParsePanes
```

## Architecture

`claude-dashboard` is a terminal dashboard (Bubble Tea TUI) that monitors active Claude Code sessions running inside tmux panes. It reads session state written as JSON files to `~/.claude/sessions/` (one file per session, named `<session_id>.json`) and renders them grouped by project.

### JSON session format

```json
{
  "session_id": "4db8ad6f-a362-46b8-99cf-62b2635e9a2b",
  "work_dir": "/Users/philbalchin",
  "project_name": "philbalchin",
  "tmux_socket": "default",
  "tmux_session": "home",
  "tmux_window": 2,
  "tmux_pane": 5,
  "status": "waiting_input",
  "current_tool": "",
  "message": "Claude is waiting for your input",
  "started_at": "2026-03-09T17:47:08Z",
  "updated_at": "2026-03-11T12:40:24Z",
  "ended_at": null,
  "version": 35
}
```

### Data flow

1. **`internal/schema`** — defines `SessionState` (the JSON schema written by Claude Code hooks) and `Status` constants (`idle`, `thinking`, `tool_use`, `waiting_input`, `dead`).

2. **`internal/store`** — thread-safe in-memory store (`Store`) keyed by `SessionID`. The `Watcher` (backed by `fsnotify`) watches the sessions directory, loading/upserting on file writes and marking sessions dead on file removal. The store signals changes by closing and replacing an `updates` channel, which the TUI listens to via a blocking Bubble Tea `Cmd`.

3. **`internal/tmux`** — thin wrappers around the `tmux` CLI: `ListPanes` (used by the reaper to detect gone panes) and `SwitchToPane` (switches or attaches to a session's pane on `enter`).

4. **`internal/tui`** — Bubble Tea model/view. Sessions are displayed in `group_view.go` (grouped by project) and `session_row.go` (individual row rendering). Styles are centralised in `styles.go`. A reaper goroutine in `main.go` runs every 30 seconds to mark dead any session whose tmux pane has disappeared.

### Key design decisions

- The `Store.notify()` mechanism (close + replace channel) lets the TUI block on a channel read rather than polling, keeping CPU usage near zero between updates.
- Session liveness is checked both by file removal (watcher) and by explicit tmux pane enumeration (reaper), so sessions are cleaned up even if the JSON file persists.
- The `--sessions-dir` flag overrides the default `~/.claude/sessions` path, useful for testing with a fixture directory.
