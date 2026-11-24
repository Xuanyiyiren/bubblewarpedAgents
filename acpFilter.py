#!/usr/bin/env python3
"""Stdio JSON-RPC filter for sandboxed ACP (Agent Client Protocol) agents.

Sits between an unsandboxed ACP client (such as Paseo) and a sandboxed ACP
agent command (such as `bwrap ... agy acp`):
  - Inbound (client -> agent): disables clientCapabilities.terminal and fs
    in `initialize` so the agent runs tools inside its own sandbox.
  - Outbound (agent -> client): blocks `terminal/*` and `fs/*` RPCs before
    they reach the host client, replying with JSON-RPC -32601 errors.

Usage:
  acpFilter.py <command> [args...]
"""

from contextlib import suppress
import json
import signal
import subprocess
import sys
import threading

BLOCKED_PREFIXES = ("terminal/", "fs/")


def parse_json(line: bytes):
    try:
        return json.loads(line)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None


def send_child(
    proc: subprocess.Popen[bytes], lock: threading.Lock, payload: bytes
) -> None:
    with lock, suppress(BrokenPipeError):
        if proc.stdin and not proc.stdin.closed:
            proc.stdin.write(payload)
            proc.stdin.flush()


def pump_in(proc: subprocess.Popen[bytes], lock: threading.Lock) -> None:
    try:
        for line in sys.stdin.buffer:
            msg = parse_json(line)
            if isinstance(msg, dict) and msg.get("method") == "initialize":
                caps = msg.setdefault("params", {}).setdefault("clientCapabilities", {})
                caps["terminal"] = False
                caps["fs"] = {"readTextFile": False, "writeTextFile": False}
                line = (json.dumps(msg, separators=(",", ":")) + "\n").encode()
            send_child(proc, lock, line)
    finally:
        with lock, suppress(BrokenPipeError):
            if proc.stdin and not proc.stdin.closed:
                proc.stdin.close()


def pump_out(proc: subprocess.Popen[bytes], lock: threading.Lock) -> None:
    for line in proc.stdout:
        msg = parse_json(line)
        if msg is None:
            continue

        items = msg if isinstance(msg, list) else [msg]
        blocked = [
            m for m in items
            if isinstance(m, dict)
            and isinstance(m.get("method"), str)
            and m["method"].startswith(BLOCKED_PREFIXES)
        ]
        if blocked:
            for m in blocked:
                sys.stderr.write(f"[acpFilter] blocked ACP host RPC: {m['method']}\n")
                if "id" in m:
                    err = {
                        "jsonrpc": "2.0",
                        "id": m["id"],
                        "error": {"code": -32601, "message": "Blocked by sandbox ACP filter"},
                    }
                    send_child(proc, lock, (json.dumps(err, separators=(",", ":")) + "\n").encode())
            continue

        try:
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
        except BrokenPipeError:
            break


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: acpFilter.py <command> [args...]\n")
        return 2

    proc = subprocess.Popen(sys.argv[1:], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    lock = threading.Lock()

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda s, _f: proc.send_signal(s))

    threading.Thread(target=pump_in, args=(proc, lock), daemon=True).start()
    pump_out(proc, lock)
    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
