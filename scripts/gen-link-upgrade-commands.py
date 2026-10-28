#!/usr/bin/env python3
"""
Generate `/link <ID>:'name'` commands for the SimpleX directory bot, one per
listed group whose *welcome message* still embeds an OLD long connection link
(i.e. it does not use a short link yet).

Data source
-----------
https://directory.simplex.chat/data/listing.json
This is the file the public page https://simplex.chat/directory loads
(see https://simplex.chat/js/directory.js -> simplexDirectoryDataURL).

Detection rule
--------------
Each entry has a `welcomeMessage` (a markdown token list). Old/long links
contain an `smp=` query parameter (they embed the relay server), e.g.
    simplex:/contact#/?v=2-4&smp=smp%3A%2F%2F...
Short links never contain `smp=`, e.g.
    https://smp4.simplex.im/g#-xXBhQRrvRB1ffhxcPpB44Im1_ci4BMIdCHwj8m8IHo
So a group "doesn't use short links yet in its welcome message" iff its
welcome text contains a long link (has `smp=`).

The group ID problem
--------------------
listing.json has NO group IDs, but the bot's `/link` command needs the numeric
GroupId. Get the mapping by running the admin command  `/last 200`  in the
directory bot chat and saving its reply to a file; its lines look like
    ID 123 (Bitcoin)
Pass that file with --ids and the script fills real IDs. Without --ids it emits
`<ID>` placeholders plus the list of names so you can fill them in.

Usage
-----
    # straight from the live directory:
    python3 gen-link-upgrade-commands.py --ids last.txt

    # offline, against a saved listing:
    python3 gen-link-upgrade-commands.py --listing listing.json --ids last.txt
"""

import argparse
import json
import re
import sys
import urllib.request

LISTING_URL = "https://directory.simplex.chat/data/listing.json"

# Long (pre-short-link) connection links embed the relay server as `smp=`.
LONG_LINK_RE = re.compile(r"\bsmp=", re.IGNORECASE)
# `ID 123 (Display Name)` as printed by the directory bot's admin listings
# (Directory/Service.hs: groupReference' = "ID " <> tshow groupId <> " (" <> name <> ")").
ID_LINE_RE = re.compile(r"\bID\s+(\d+)\s+\((.+?)\)\s*$")


def fetch_listing(path):
    if path:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    with urllib.request.urlopen(LISTING_URL, timeout=30) as r:
        return json.load(r)


def welcome_text(entry):
    """Flatten the welcomeMessage markdown token list to plain text."""
    wm = entry.get("welcomeMessage")
    if not wm:
        return ""
    return "".join(tok.get("text", "") for tok in wm)


def load_id_map(path):
    """Parse `/last` admin output into {display_name: group_id}."""
    id_map = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            m = ID_LINE_RE.search(line.strip())
            if m:
                id_map[m.group(2)] = int(m.group(1))
    return id_map


def quote_name(name):
    """Directory bot display-name token: single-quoted (Markdown.hs displayNameTextP)."""
    if "'" in name:
        # The bot's parser stops a quoted name at the first inner quote; flag it.
        print(f"# WARNING: name contains a single quote, command may need manual fixup: {name}",
              file=sys.stderr)
    return f"'{name}'"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--listing", help="path to a saved listing.json (default: fetch live)")
    ap.add_argument("--ids", help="path to saved `/last` bot output (lines: 'ID 123 (Name)')")
    args = ap.parse_args()

    data = fetch_listing(args.listing)
    entries = data.get("entries", [])
    id_map = load_id_map(args.ids) if args.ids else {}

    targets = []  # (name, has_long, has_short)
    for e in entries:
        name = e.get("displayName", "")
        text = welcome_text(e)
        if LONG_LINK_RE.search(text):
            targets.append(name)

    print(f"# {len(targets)} of {len(entries)} groups have a long link in their welcome message",
          file=sys.stderr)

    missing = []
    for name in targets:
        gid = id_map.get(name)
        if gid is None:
            missing.append(name)
            gid_str = "<ID>"
        else:
            gid_str = str(gid)
        print(f"/link {gid_str}:{quote_name(name)}")

    if missing:
        print(f"\n# {len(missing)} group(s) have no ID mapping "
              f"(run `/last 200` in the bot, save it, pass with --ids):",
              file=sys.stderr)
        for name in missing:
            print(f"#   {name}", file=sys.stderr)


if __name__ == "__main__":
    main()
