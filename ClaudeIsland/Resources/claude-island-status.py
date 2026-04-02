#!/usr/bin/env python3
"""
Claude Island StatusLine Script
- Receives Claude Code statusLine JSON on stdin
- Sends context window data to ClaudeIsland.app via Unix socket
- Chains to any original statusLine command if configured
"""
import json
import os
import socket
import subprocess
import sys

SOCKET_PATH = "/tmp/claude-island.sock"


def send_to_socket(state):
    """Fire-and-forget send to app"""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(state).encode())
        sock.close()
    except (socket.error, OSError):
        pass


def main():
    raw_input = sys.stdin.read()

    # Parse and send context data to socket
    try:
        data = json.loads(raw_input)

        ctx = data.get("context_window", {})
        current = ctx.get("current_usage") or {}
        cost = data.get("cost", {})
        model = data.get("model", {})

        state = {
            "session_id": data.get("session_id", ""),
            "cwd": data.get("cwd", ""),
            "event": "StatusUpdate",
            "status": "status_update",
            "ctx_window_size": ctx.get("context_window_size"),
            "ctx_used_percentage": ctx.get("used_percentage"),
            "ctx_input_tokens": current.get("input_tokens"),
            "ctx_output_tokens": current.get("output_tokens"),
            "ctx_total_cost_usd": cost.get("total_cost_usd"),
            "ctx_model_id": model.get("id"),
            "ctx_model_name": model.get("display_name"),
        }

        send_to_socket(state)
    except (json.JSONDecodeError, KeyError):
        pass

    # Chain to original statusLine command if configured
    chain_cmd = os.environ.get("NOTCH_ISLAND_CHAIN_CMD")
    if chain_cmd:
        try:
            result = subprocess.run(
                chain_cmd,
                shell=True,
                input=raw_input,
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.stdout:
                print(result.stdout, end="")
        except (subprocess.TimeoutExpired, OSError):
            pass


if __name__ == "__main__":
    main()
