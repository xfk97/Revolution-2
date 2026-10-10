"""
Revolution 2 Core Library
Shared data persistence, IPC, and utility functions for CLI and MCP server
"""

import sys
import os
import time
import json
import socket
import uuid
import datetime
from pathlib import Path

TMP_DIR = Path("/tmp/revolution")
TMP_CHATS_FILE = TMP_DIR / "chats.json"

def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def get_data_dir() -> Path:
    env_dir = os.environ.get("REVOLUTION_DATA_DIR")
    if env_dir:
        p = Path(env_dir)
        p.mkdir(parents=True, exist_ok=True)
        return p
    
    home = Path.home()
    candidates = [
        home / ".revolution",
        home / "Library" / "Application Support" / "Revolution 2",
        TMP_DIR
    ]
    for c in candidates:
        try:
            c.mkdir(parents=True, exist_ok=True)
            test_file = c / ".test_write"
            test_file.touch()
            test_file.unlink()
            return c
        except Exception:
            continue
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    return TMP_DIR

DATA_DIR = get_data_dir()
CHATS_FILE = DATA_DIR / "chats.json"
STATUS_FILE = DATA_DIR / "app_status.json"
SOCKET_PATH = os.environ.get("REVOLUTION_SOCK_PATH", "/tmp/revolution.sock")

def send_ipc(action: str, **kwargs) -> dict:
    """Attempt to send command via Unix Domain Socket to running app."""
    if not os.path.exists(SOCKET_PATH):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.5)
        s.connect(SOCKET_PATH)
        payload = {"action": action, **kwargs}
        s.sendall(json.dumps(payload).encode("utf-8") + b"\n")
        data = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break
        s.close()
        if data:
            return json.loads(data.decode("utf-8").strip())
    except Exception:
        pass
    return None

def _latest_chats_file() -> Path:
    """Return whichever chats.json (DATA_DIR or /tmp/revolution) is newer."""
    p1 = CHATS_FILE if CHATS_FILE.exists() else None
    p2 = TMP_CHATS_FILE if TMP_CHATS_FILE.exists() else None
    if p1 and p2 and p1 != p2:
        try:
            return p1 if p1.stat().st_mtime >= p2.stat().st_mtime else p2
        except Exception:
            return p1
    return p1 or p2 or CHATS_FILE

def read_store() -> dict:
    target = _latest_chats_file()
    if not target.exists():
        p1 = "John"
        p2 = "Paul"
        c_id = str(uuid.uuid4()).upper()
        ts = now_iso()
        default_data = {
            "version": "1.0.1",
            "activeChatId": c_id,
            "preferences": {
                "defaultPerson1": "John",
                "defaultPerson2": "Paul",
                "fontSize": 13.0,
                "showTimestamps": True,
                "soundEnabled": False
            },
            "chats": [
                {
                    "id": c_id,
                    "title": "Revolution 2",
                    "person1": p1,
                    "person2": p2,
                    "nextSpeaker": p1,
                    "createdAt": ts,
                    "updatedAt": ts,
                    "messages": [
                        {
                            "id": str(uuid.uuid4()).upper(),
                            "chatId": c_id,
                            "sender": p1,
                            "text": "You say you want a revolution? Well, you know...",
                            "timestamp": ts
                        },
                        {
                            "id": str(uuid.uuid4()).upper(),
                            "chatId": c_id,
                            "sender": p2,
                            "text": "We all want to change the world. Every sent message passes the turn to the other person!",
                            "timestamp": ts
                        }
                    ]
                }
            ]
        }
        write_store(default_data)
        return default_data
    try:
        with open(target, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading {target}: {e}", file=sys.stderr)
        return {
            "version": "1.0.1",
            "activeChatId": None,
            "chats": [],
            "preferences": {
                "defaultPerson1": "John",
                "defaultPerson2": "Paul",
                "fontSize": 13.0,
                "showTimestamps": True,
                "soundEnabled": False
            }
        }

def write_store(data: dict):
    encoded = json.dumps(data, indent=2, sort_keys=True)
    for dest in {CHATS_FILE, TMP_CHATS_FILE}:
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            tmp = dest.with_name(f"{dest.name}.tmp.{uuid.uuid4().hex[:8]}")
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(encoded)
            tmp.replace(dest)
        except Exception:
            pass

def resolve_chat(chats: list, active_id: str, chat_query: str = None) -> dict:
    if not chats:
        return None
    if chat_query:
        for c in chats:
            if c["id"].lower().startswith(chat_query.lower()):
                return c
        for c in chats:
            if chat_query.lower() in c["title"].lower():
                return c
        return None
    if active_id:
        for c in chats:
            if c["id"].lower() == active_id.lower():
                return c
    return chats[0]

def wait_for_reply(chat_query: str = None, after_count: int = None, expected_turn: str = None, timeout: float = 300.0) -> dict:
    """Block until a new message arrives in the conversation or the turn changes to expected_turn."""
    start = time.time()
    if after_count is None:
        ipc_res = send_ipc("get_chat", chatId=chat_query)
        if ipc_res and ipc_res.get("status") == "ok" and ipc_res.get("chat"):
            chat = ipc_res["chat"]
        else:
            store = read_store()
            chat = resolve_chat(store.get("chats", []), store.get("activeChatId"), chat_query)
        after_count = len(chat.get("messages", [])) if chat else 0

    while (time.time() - start) < timeout:
        time.sleep(0.3)
        ipc_res = send_ipc("get_chat", chatId=chat_query)
        if ipc_res and ipc_res.get("status") == "ok" and ipc_res.get("chat"):
            chat = ipc_res["chat"]
        else:
            store = read_store()
            chat = resolve_chat(store.get("chats", []), store.get("activeChatId"), chat_query)
        if not chat:
            continue
        msgs = chat.get("messages", [])
        if len(msgs) > after_count:
            if expected_turn is None or chat.get("nextSpeaker", "").lower() == expected_turn.lower():
                return {
                    "chat": chat,
                    "reply": msgs[-1],
                    "nextSpeaker": chat.get("nextSpeaker")
                }
        elif expected_turn and chat.get("nextSpeaker", "").lower() == expected_turn.lower() and len(msgs) > 0:
            return {
                "chat": chat,
                "reply": msgs[-1],
                "nextSpeaker": chat.get("nextSpeaker")
            }
    return None
