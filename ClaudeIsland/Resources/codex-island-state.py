#!/usr/bin/env python3
"""
Codex Island Hook
- Sends Codex CLI session state to ClaudeIsland.app via Unix socket
- Monitoring only: no interactive approval flow
"""
import json
import os
import socket
import sys
import uuid

SOCKET_PATH = "/tmp/claude-island.sock"


def get_tty():
    """Get the TTY of the Codex process (parent)"""
    import subprocess

    ppid = os.getppid()

    try:
        result = subprocess.run(
            ["ps", "-p", str(ppid), "-o", "tty="],
            capture_output=True,
            text=True,
            timeout=2
        )
        tty = result.stdout.strip()
        if tty and tty != "??" and tty != "-":
            if not tty.startswith("/dev/"):
                tty = "/dev/" + tty
            return tty
    except Exception:
        pass

    try:
        return os.ttyname(sys.stdin.fileno())
    except (OSError, AttributeError):
        pass
    try:
        return os.ttyname(sys.stdout.fileno())
    except (OSError, AttributeError):
        pass
    return None


def send_event(state):
    """Fire-and-forget send to app"""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(state).encode())
        sock.close()
    except (socket.error, OSError):
        pass


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(1)

    session_id = data.get("session_id", "unknown")
    event = data.get("hook_event_name", "")
    cwd = data.get("cwd", "")

    state = {
        "session_id": session_id,
        "cwd": cwd,
        "event": event,
        "pid": os.getppid(),
        "tty": get_tty(),
        "agent_type": "codex",
    }

    if event == "SessionStart":
        state["status"] = "waiting_for_input"

    elif event == "UserPromptSubmit":
        state["status"] = "processing"

    elif event == "PreToolUse":
        state["status"] = "running_tool"
        state["tool"] = "Bash"
        state["tool_use_id"] = data.get("turn_id") or str(uuid.uuid4())

    elif event == "PostToolUse":
        state["status"] = "processing"
        state["tool"] = "Bash"
        state["tool_use_id"] = data.get("turn_id") or str(uuid.uuid4())

    elif event == "Stop":
        state["status"] = "waiting_for_input"

    else:
        state["status"] = "unknown"

    send_event(state)


if __name__ == "__main__":
    main()
