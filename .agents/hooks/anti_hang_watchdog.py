import json
import os
import re
import sys
import tempfile
import time

MAX_TIMEOUT_SEC = 300
HEADLESS_TEST_TIMEOUT_SEC = 120


def _state_path(conv_id: str) -> str:
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "_", conv_id or "default")
    return os.path.join(tempfile.gettempdir(), f"agy_watchdog_{safe_id}.json")


def _load_state(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _save_state(path: str, state: dict) -> None:
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(state, f)
    except Exception:
        pass


def _handle_pre_tool_use(payload: dict) -> dict:
    tool_call = payload.get("toolCall") or {}
    if tool_call.get("name") != "run_command":
        return {"decision": "allow"}

    args = tool_call.get("args") or {}
    if bool(args.get("IsDaemon", False)):
        return {"decision": "allow"}

    cmd = str(args.get("CommandLine", ""))
    cmd_low = cmd.lower()
    default_cap = (
        HEADLESS_TEST_TIMEOUT_SEC
        if ("godot" in cmd_low and "--headless" in cmd_low)
        else MAX_TIMEOUT_SEC
    )

    cur = args.get("NotificationTimeoutSeconds")
    if cur is None or isinstance(cur, bool) or not isinstance(cur, (int, float)) or int(cur) <= 0:
        return {
            "decision": "allow",
            "overwrite": {"NotificationTimeoutSeconds": default_cap},
        }

    if int(cur) > MAX_TIMEOUT_SEC:
        return {
            "decision": "allow",
            "overwrite": {"NotificationTimeoutSeconds": MAX_TIMEOUT_SEC},
        }

    return {"decision": "allow"}


def _handle_post_tool_use(payload: dict) -> dict:
    tool_call = payload.get("toolCall") or {}
    tool_name = str(tool_call.get("name", ""))
    args = tool_call.get("args") or {}
    state_file = _state_path(str(payload.get("conversationId", "default")))

    if tool_name == "invoke_subagent":
        state = _load_state(state_file)
        state["pending_subagent_watchdog"] = True
        subs = state.get("active_subagents")
        if not isinstance(subs, list):
            subs = []
        subs.append({"ts": time.time(), "role": str(args.get("Role", "subagent"))})
        state["active_subagents"] = subs
        _save_state(state_file, state)
    elif tool_name == "schedule":
        state = _load_state(state_file)
        state["pending_subagent_watchdog"] = False
        state["last_schedule_ts"] = time.time()
        _save_state(state_file, state)
    elif tool_name == "manage_subagents" and args.get("Action") in ("kill", "kill_all"):
        state = _load_state(state_file)
        state["pending_subagent_watchdog"] = False
        state["active_subagents"] = []
        _save_state(state_file, state)

    return {}


def _handle_pre_invocation(payload: dict) -> dict:
    state_file = _state_path(str(payload.get("conversationId", "default")))
    if not os.path.exists(state_file):
        return {}

    state = _load_state(state_file)
    if state.get("pending_subagent_watchdog"):
        state["pending_subagent_watchdog"] = False
        _save_state(state_file, state)
        return {
            "injectSteps": [
                {
                    "systemMessage": {
                        "systemMessage": (
                            "[ANTI-HANG WATCHDOG] You launched a subagent without a 5-minute watchdog timer. "
                            "Immediately pair it with schedule(DurationSeconds=300, TimerCondition=<subagent_id>, "
                            "Prompt='[WATCHDOG 5m] Check subagent status; if stuck, kill via manage_subagents and "
                            "retry with adjusted approach (max 2 retries).')."
                        )
                    }
                }
            ]
        }

    now = time.time()
    last_sched = float(state.get("last_schedule_ts", 0) or 0)
    subs = state.get("active_subagents")
    if isinstance(subs, list) and subs:
        stale = [
            s for s in subs
            if isinstance(s, dict)
            and (now - float(s.get("ts", now))) > MAX_TIMEOUT_SEC
            and last_sched < float(s.get("ts", 0))
        ]
        if stale:
            roles = ", ".join(str(s.get("role", "subagent")) for s in stale)
            state["active_subagents"] = []
            _save_state(state_file, state)
            return {
                "injectSteps": [
                    {
                        "systemMessage": {
                            "systemMessage": (
                                f"[ANTI-HANG WATCHDOG ALERT] Subagent(s) ({roles}) have been silent for over "
                                "5 minutes without an active schedule watchdog. Run manage_subagents(Action='list') "
                                "now, inspect logs, and kill/retry any stalled subagent (max 2 retries)."
                            )
                        }
                    }
                ]
            }

    return {}


def main() -> None:
    raw = ""
    event_name = ""
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
        if not isinstance(payload, dict):
            payload = {}
        event_name = str(payload.get("hookEventName", ""))
        if event_name == "PreToolUse":
            out = _handle_pre_tool_use(payload)
        elif event_name == "PostToolUse":
            out = _handle_post_tool_use(payload)
        elif event_name == "PreInvocation":
            out = _handle_pre_invocation(payload)
        else:
            out = {}
    except Exception:
        out = {"decision": "allow"} if "PreToolUse" in raw or event_name == "PreToolUse" else {}

    sys.stdout.write(json.dumps(out))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
