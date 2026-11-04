#!/usr/bin/env python3

import base64
import hashlib
import json
import os
import re
import socket
import struct
import subprocess
import sys
import threading
import time
from collections import OrderedDict

USAGE = """Peer, flood and judge for pr-scenario.sh (messages received while their chat is opening).
  pr-openmsg.py peer <port> <dir>                         runs a WebSocket client of the CLI's chat server (simplex-chat -p),
                                                          logs every message to <dir>/events.jsonl, sends what <dir>/in/*.cmd hold
  pr-openmsg.py cmd <dir> <id> <command> [secs]           sends a chat command through the peer, prints the response
  pr-openmsg.py flood <dir> <tag> <contact id> <count> <interval> <text>
                                                          sends "<text> 0001".. to the contact, one every interval seconds
  pr-openmsg.py flood-reached <dir> <tag> <n> [secs]      waits until n flood messages have responses
  pr-openmsg.py stop <dir> <tag>                          stops the flood
  pr-openmsg.py flood-wait <dir> <tag> [secs]             waits for the stopped flood's responses, prints the counts
  pr-openmsg.py load-time <app log> <byte offset> [secs]  "<request> <response> <type>": the first apiGetChat after the offset
  pr-openmsg.py event <dir> <type> [secs]                 prints the first event of this type
  pr-openmsg.py tap <x> <y>                               taps the point with axe, prints the time before and after the tap
  pr-openmsg.py page <ocr file> <image> <word> <n>        "<numbers> <lowest> <highest> <older texts 0|1> <signature>" of one page
  pr-openmsg.py judge <dir> <tag> <word> <n> <apiGetChat request> <apiGetChat response> <ocr file>
                                                          the numbers "<word> <n> number NNNN" lost from the pages read
  pr-openmsg.py shown <ocr file> <word> <n> <numbers>     which of the comma-separated numbers the pages show"""

TEXT_RE = re.compile(r"\b(Wave|Reload)\s*([0-9]+)\s*number\s*([0-9OoIl|]{4})", re.I)
OTHER_RE = re.compile(r"Hello from Bob", re.I)
DIGITS = str.maketrans("OoIl|", "00111")


def write_atomic(path, data):
    with open(path + ".tmp", "wb") as f:
        f.write(data)
    os.rename(path + ".tmp", path)


class WebSocket:
    def __init__(self, port, secs):
        deadline = time.time() + secs
        while True:
            try:
                self.sock = socket.create_connection(("127.0.0.1", port), 5)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(1)
        self.sock.settimeout(None)
        self.lock = threading.Lock()
        key = base64.b64encode(os.urandom(16)).decode()
        request = (
            "GET / HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
            "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n" % (port, key)
        )
        self.sock.sendall(request.encode())
        self.buf = b""
        while b"\r\n\r\n" not in self.buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise EOFError("the connection closed during the handshake")
            self.buf += chunk
        head, self.buf = self.buf.split(b"\r\n\r\n", 1)
        status = head.split(b"\r\n", 1)[0]
        if b" 101" not in status:
            raise EOFError("handshake refused: %r" % status)

    def exact(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise EOFError("the connection closed")
            self.buf += chunk
        data, self.buf = self.buf[:n], self.buf[n:]
        return data

    def frame(self, opcode, payload):
        n = len(payload)
        if n < 126:
            head = struct.pack("!BB", 0x80 | opcode, 0x80 | n)
        elif n < 65536:
            head = struct.pack("!BBH", 0x80 | opcode, 0x80 | 126, n)
        else:
            head = struct.pack("!BBQ", 0x80 | opcode, 0x80 | 127, n)
        mask = os.urandom(4)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        with self.lock:
            self.sock.sendall(head + mask + masked)

    def send(self, obj):
        self.frame(1, json.dumps(obj).encode())

    def recv(self):
        parts = []
        while True:
            b0, b1 = self.exact(2)
            opcode = b0 & 0x0F
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack("!H", self.exact(2))[0]
            elif n == 127:
                n = struct.unpack("!Q", self.exact(8))[0]
            mask = self.exact(4) if b1 & 0x80 else None
            data = self.exact(n)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if opcode == 8:
                raise EOFError("the server closed the connection")
            if opcode == 9:
                self.frame(10, data)
                continue
            if opcode == 10:
                continue
            parts.append(data)
            if b0 & 0x80:
                return b"".join(parts)


def response_ok(msg):
    resp = msg.get("resp") if isinstance(msg, dict) else None
    return isinstance(resp, dict) and resp.get("type") not in ("chatCmdError", "chatError")


STOPPED = set()


def flood(ws, d, tag, contact_id, count, interval, text):
    count, interval = int(count), float(interval)
    start = time.time()
    with open(os.path.join(d, "flood-%s.sent" % tag), "w") as f:
        for i in range(1, count + 1):
            if tag in STOPPED:
                break
            delay = start + (i - 1) * interval - time.time()
            if delay > 0:
                time.sleep(delay)
            ws.send({"corrId": "f%s-%d" % (tag, i), "cmd": "/_send @%s text %s %04d" % (contact_id, text, i)})
            f.write("%d\t%.3f\n" % (i, time.time()))
            f.flush()
    write_atomic(os.path.join(d, "flood-%s.done" % tag), b"")


def peer(port, d):
    inbox = os.path.join(d, "in")
    os.makedirs(inbox, exist_ok=True)
    ws = WebSocket(int(port), 180)
    events = open(os.path.join(d, "events.jsonl"), "a")

    def read():
        try:
            while True:
                raw = ws.recv()
                t = time.time()
                try:
                    msg = json.loads(raw)
                except ValueError:
                    msg = {"raw": raw.decode("utf-8", "replace")}
                events.write(json.dumps({"ts": round(t, 3), "msg": msg}) + "\n")
                events.flush()
                corr = msg.get("corrId") if isinstance(msg, dict) else None
                if not isinstance(corr, str):
                    continue
                if corr.startswith("f"):
                    tag, _, i = corr[1:].rpartition("-")
                    with open(os.path.join(d, "flood-%s.resp" % tag), "a") as f:
                        f.write("%s\t%.3f\t%s\n" % (i, t, "ok" if response_ok(msg) else "error"))
                else:
                    write_atomic(os.path.join(d, "resp-%s.json" % corr), raw)
        except (EOFError, OSError) as e:
            write_atomic(os.path.join(d, "peer-closed"), str(e).encode())
            os._exit(1)

    threading.Thread(target=read, daemon=True).start()
    write_atomic(os.path.join(d, "peer-ready"), b"")
    print("connected to the chat server on port %s" % port, flush=True)
    while True:
        for name in sorted(os.listdir(inbox)):
            if not name.endswith(".cmd"):
                continue
            path = os.path.join(inbox, name)
            with open(path) as f:
                kind, _, rest = f.read().strip().partition(" ")
            os.remove(path)
            print("%s: %s %s" % (name, kind, rest[:200]), flush=True)
            if kind == "QUIT":
                os._exit(0)
            elif kind == "CMD":
                ws.send({"corrId": name[:-4], "cmd": rest})
            elif kind == "STOP":
                STOPPED.add(rest)
            elif kind == "FLOOD":
                threading.Thread(target=flood, args=(ws, d) + tuple(rest.split(" ", 4)), daemon=True).start()
        time.sleep(0.02)


def wait_file(d, path, secs):
    deadline = time.time() + secs
    while not os.path.exists(path):
        if os.path.exists(os.path.join(d, "peer-closed")):
            sys.exit("the peer is not connected: " + open(os.path.join(d, "peer-closed")).read())
        if time.time() > deadline:
            sys.exit("no %s after %s s" % (os.path.basename(path), secs))
        time.sleep(0.1)


def cmd(d, ident, command, secs=60):
    write_atomic(os.path.join(d, "in", ident + ".cmd"), ("CMD " + command).encode())
    path = os.path.join(d, "resp-%s.json" % ident)
    wait_file(d, path, float(secs))
    print(open(path).read())


def start_flood(d, tag, contact_id, count, interval, text):
    write_atomic(os.path.join(d, "in", "%s.cmd" % tag), ("FLOOD %s %s %s %s %s" % (tag, contact_id, count, interval, text)).encode())


def flood_responses(d, tag):
    path = os.path.join(d, "flood-%s.resp" % tag)
    rows = {}
    if os.path.exists(path):
        for line in open(path):
            parts = line.split("\t")
            if len(parts) == 3 and parts[0].isdigit():
                rows[int(parts[0])] = (float(parts[1]), parts[2].strip())
    return rows


def flood_reached(d, tag, n, secs=60):
    deadline = time.time() + float(secs)
    while len(flood_responses(d, tag)) < int(n):
        if time.time() > deadline:
            sys.exit("fewer than %s responses to flood %s after %s s" % (n, tag, secs))
        time.sleep(0.05)


def stop_flood(d, tag):
    write_atomic(os.path.join(d, "in", "stop-%s.cmd" % tag), ("STOP " + tag).encode())


def sent_count(d, tag):
    path = os.path.join(d, "flood-%s.sent" % tag)
    return sum(1 for _ in open(path)) if os.path.exists(path) else 0


def flood_wait(d, tag, secs=60):
    deadline = time.time() + float(secs)
    while True:
        rows = flood_responses(d, tag)
        done = os.path.exists(os.path.join(d, "flood-%s.done" % tag))
        sent = sent_count(d, tag)
        errors = sum(1 for v in rows.values() if v[1] != "ok")
        if done and len(rows) >= sent:
            print("sent=%d responses=%d errors=%d" % (sent, len(rows), errors))
            return
        if time.time() > deadline:
            print("sent=%d responses=%d errors=%d done=%s timeout" % (sent, len(rows), errors, done))
            sys.exit(1)
        time.sleep(0.2)


LOG_TIME = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)(\.\d+)")


def log_time(line):
    m = LOG_TIME.match(line)
    if not m:
        return None
    return time.mktime(time.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")) + float(m.group(2))


def load_time(app_log, offset, secs=120):
    deadline = time.time() + float(secs)
    offset = int(offset)
    request = None
    with open(app_log, "rb") as f:
        while True:
            f.seek(offset)
            while True:
                raw = f.readline()
                if not raw.endswith(b"\n"):
                    break
                offset += len(raw)
                line = raw.decode("utf-8", "replace").rstrip("\n")
                if line.endswith("chatSendCmd apiGetChat") and request is None:
                    request = log_time(line)
                elif "chatSendCmd apiGetChat: " in line and request is not None:
                    print("%.3f %.3f %s" % (request, log_time(line) or 0, line.rsplit(": ", 1)[-1]))
                    return
            if time.time() > deadline:
                sys.exit("no apiGetChat response in %s within %s s" % (app_log, secs))
            time.sleep(0.1)


def find_type(obj, kind):
    if isinstance(obj, dict):
        if obj.get("type") == kind:
            return obj
        if isinstance(obj.get(kind), dict):
            return obj[kind]
        for v in obj.values():
            found = find_type(v, kind)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for v in obj:
            found = find_type(v, kind)
            if found is not None:
                return found
    return None


def event(d, kind, secs=60):
    path = os.path.join(d, "events.jsonl")
    deadline = time.time() + float(secs)
    offset = 0
    while True:
        if os.path.exists(path):
            with open(path, "rb") as f:
                f.seek(offset)
                while True:
                    line = f.readline()
                    if not line.endswith(b"\n"):
                        break
                    offset += len(line)
                    found = find_type(json.loads(line).get("msg"), kind)
                    if found is not None:
                        print(json.dumps(found))
                        return
        if time.time() > deadline:
            sys.exit("no %s event after %s s" % (kind, secs))
        time.sleep(0.5)


def tap(x, y):
    t0 = time.time()
    subprocess.run(["axe", "tap", "-x", x, "-y", y, "--udid", os.environ["SIM_UDID"]], check=True, stdout=subprocess.DEVNULL)
    print("%.3f %.3f" % (t0, time.time()))


def ocr_pages(path):
    pages = OrderedDict()
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.rstrip("\n").split("\t", 2)
        if len(parts) < 3:
            continue
        image, y, text = parts
        rows = pages.setdefault(image, [])
        if y.lstrip("-").isdigit():
            rows.append((int(y), text))
    return pages


def numbers(rows, word, n):
    found = []
    for y, text in rows:
        for m in TEXT_RE.finditer(text):
            if m.group(1).lower() == word.lower() and int(m.group(2)) == n:
                found.append((y, int(m.group(3).translate(DIGITS))))
    return found


def other_ys(rows, word, n):
    ys = []
    for y, text in rows:
        if OTHER_RE.search(text) or any(m.group(1).lower() != word.lower() or int(m.group(2)) != n for m in TEXT_RE.finditer(text)):
            ys.append(y)
    return ys


def page(ocr_file, image, word, n):
    rows = ocr_pages(ocr_file).get(image, [])
    found = [v for _, v in numbers(rows, word, int(n))]
    signature = hashlib.sha1("\n".join(sorted(t for _, t in rows)).encode()).hexdigest()[:12]
    older = 1 if other_ys(rows, word, int(n)) else 0
    if found:
        print("%d %d %d %d %s" % (len(found), min(found), max(found), older, signature))
    else:
        print("0 - - %d %s" % (older, signature))


def bubbles_between(image, y_low, y_high):
    path = os.path.splitext(image)[0] + ".json"
    if not os.path.exists(path):
        return "?"
    count = 0

    def walk(obj):
        nonlocal count
        if isinstance(obj, dict):
            frame = obj.get("frame") or {}
            if obj.get("type") == "StaticText" and obj.get("AXLabel") == "" and 20 <= frame.get("height", 0) <= 200 and frame.get("width", 0) > 40:
                centre = frame.get("y", 0) + frame.get("height", 0) / 2
                if y_low + 8 < centre < y_high - 8:
                    count += 1
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for v in obj:
                walk(v)

    walk(json.load(open(path)))
    return str(count)


def judge(d, tag, word, n, request, response, ocr_file):
    n, request, response = int(n), float(request), float(response)
    count = sent_count(d, tag)
    window_end = max(response, request + 0.25) + 0.2
    pages = ocr_pages(ocr_file)
    shown, candidates = set(), set()
    gap_pages, tree_notes = [], []
    violations = 0
    for image, rows in pages.items():
        found = numbers(rows, word, n)
        if not found:
            continue
        ordered = [v for _, v in sorted(found)]
        violations += sum(1 for a, b in zip(ordered, ordered[1:]) if b <= a)
        values = set(ordered)
        shown |= values
        low, high = min(values), max(values)
        page_missing = [k for k in range(low + 1, high) if k not in values]
        y_low = min(y for y, v in found if v == low)
        if low > 1 and any(y < y_low for y in other_ys(rows, word, n)):
            page_missing = list(range(1, low)) + page_missing
        if page_missing:
            gap_pages.append(os.path.basename(image))
            by_value = {v: y for y, v in found}
            for k in page_missing:
                below = max((v for v in values if v < k), default=None)
                above = min((v for v in values if v > k), default=None)
                if below is not None and above is not None:
                    tree_notes.append("%d:%s" % (k, bubbles_between(image, by_value[below], by_value[above])))
        candidates |= set(page_missing)
    missing = sorted(candidates - shown)
    responses = flood_responses(d, tag)
    in_window = sorted(k for k, (t, _) in responses.items() if request <= t <= window_end)
    before = max((k for k, (t, _) in responses.items() if t < request), default=0)
    after = sum(1 for t, _ in responses.values() if t > response)
    valid = before > 0 and after > 0
    if missing:
        outcome = "bug"
    elif valid and all(k in shown for k in in_window):
        outcome = "ok"
    else:
        outcome = "invalid"
    tail = [k for k in range(max(shown, default=0) + 1, count + 1)]
    times = sorted(t for t, _ in responses.values())
    rate = (len(times) - 1) / (times[-1] - times[0]) if len(times) > 1 and times[-1] > times[0] else 0.0
    lost = ",".join("%d(%+.2fs)" % (k, responses[k][0] - request) if k in responses else str(k) for k in missing)
    print("%s %s %s %s" % (outcome, ",".join(map(str, missing)) or "-", gap_pages[0] if gap_pages else "-", "valid" if valid else "not-valid"))
    print(
        "outcome=%s missing=%s shown=%d range=%s load=%.2fs window=%s sent_before_load=%d sent_after_load=%d rate=%.1f/s tail_absent=%s order_violations=%d pages=%d gap_pages=%s tree_bubbles_between=%s errors=%d"
        % (
            outcome,
            lost or "none",
            len(shown),
            "%d-%d" % (min(shown), max(shown)) if shown else "none",
            response - request,
            "%d-%d" % (in_window[0], in_window[-1]) if in_window else "none",
            before,
            after,
            rate,
            ",".join(map(str, tail)) or "none",
            violations,
            len(pages),
            ",".join(gap_pages) or "none",
            ",".join(tree_notes) or "none",
            sum(1 for v in responses.values() if v[1] != "ok"),
        )
    )


def shown_numbers(ocr_file, word, n, wanted):
    shown = set()
    for rows in ocr_pages(ocr_file).values():
        shown |= {v for _, v in numbers(rows, word, int(n))}
    want = [int(k) for k in wanted.split(",") if k.strip().isdigit()]
    now_shown = [k for k in want if k in shown]
    still = [k for k in want if k not in shown]
    verdict = "all" if want and not still else ("none" if not now_shown else "partial")
    print("%s shown=%s still_missing=%s" % (verdict, ",".join(map(str, now_shown)) or "none", ",".join(map(str, still)) or "none"))


COMMANDS = {
    "peer": peer,
    "cmd": cmd,
    "flood": start_flood,
    "flood-reached": flood_reached,
    "flood-wait": flood_wait,
    "stop": stop_flood,
    "load-time": load_time,
    "event": event,
    "tap": tap,
    "page": page,
    "judge": judge,
    "shown": shown_numbers,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(USAGE)
    COMMANDS[sys.argv[1]](*sys.argv[2:])
