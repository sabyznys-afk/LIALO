# LIALO — Project Agent Rules

## Anti-Hang Watchdog (Max 5 min)

- **Shell Commands (`run_command`)**: Every non-daemon `run_command` MUST set `NotificationTimeoutSeconds <= 300` (for Godot headless runs and tests `<= 120`).
- **On Command Timeout**: Immediately inspect `manage_task(Action="status")`. If the log is stalled or the process is hung, call `manage_task(Action="kill")`, diagnose why it hung, and retry with a different approach (max 2 retries; never blindly re-run the same hung command).
- **Subagents (`invoke_subagent`)**: Every `invoke_subagent` MUST be paired with `schedule(DurationSeconds=300, TimerCondition=<subagent_id>, Prompt="[WATCHDOG 5m] Check subagent status; kill and retry with narrowed scope if stalled.")`. On wakeup, inspect `manage_subagents(Action="list")` and logs; if stalled, `kill` and retry with narrowed scope (max 2 retries, then report).
- **Swarms (`/teamwork`)**: Always include a `monitor` worker using `swarm_monitor` on `*/3 * * * *`.

## Godot Headless Guardrails

- Never run scripts that `await RenderingServer.frame_post_draw` under `Godot --headless` — the dummy renderer never emits `frame_post_draw`, causing an infinite hang.
- Every headless verification script (`tools/verify_*.gd`) should include an internal fail-safe timer (`create_timer(60.0).timeout.connect(func(): quit(124))`) and skip viewport pixel capture when `DisplayServer.get_name() == "headless"`.
