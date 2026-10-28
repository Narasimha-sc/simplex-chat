#!/usr/bin/env python3
"""
Diagnose and repair a corrupted SimpleX Chat database.

Works on an exported archive or on a single database file, and needs nothing
but the database passphrase - no sqlcipher binary, no SimpleX build.

Usage:
  python3 repair-db.py diagnose simplex-chat.2026-09-21T10-00-00Z.zip
  python3 repair-db.py repair   simplex-chat.2026-09-21T10-00-00Z.zip repaired.zip
  python3 repair-db.py diagnose simplex_v1_chat.db
  python3 repair-db.py repair   simplex_v1_chat.db repaired_chat.db

The passphrase is asked for interactively. --passphrase is accepted for
scripting, but anyone else on the machine can read it out of the process list.

Close SimpleX first. A database read while the app is writing to it looks
exactly like failing storage, and the tool cannot tell the difference.

Neither mode ever writes to the file you give it, and nothing appears at the
output path until the result has been read back and checked. Keep the
original until you have confirmed the repaired copy works.

Exit codes, by mode: diagnose exits 0 when it finds no damage and 1 when it
does; repair exits 0 when a verified copy reached the output path and 1 when
it could not be verified and was set aside - a repair that verified can still
have lost rows, and the report is what says so. Both: 2 the arguments, the
paths or the storage would not let the run start or finish (including a full
disk), 3 nothing could be read - a wrong passphrase, not a database, nothing
salvageable, the file changing while it was read, or running out of memory,
4 a bug in this script, 130 interrupted.

diagnose decrypts every page, verifies its SQLCipher HMAC, and runs SQLite's
own integrity check on the decrypted copy. The two results answer different
questions:

  HMAC fails on a page        the stored bytes are damaged - a torn write,
                              or failing storage
  HMAC passes, integrity      the encryption layer is intact and the file
  check fails                 holds an older version of some pages - a lost
                              or reordered write

repair additionally copies every readable row into a fresh database, reading
each table through its own b-tree so damaged index pages are never touched and
stepping around rows that cannot be read; it then recreates the indexes,
re-encrypts with the same passphrase, and reads the result back to prove it is
sound.

This is a SimpleX tool, not a general SQLite one. It assumes what SimpleX's
own schemas guarantee: SQLCipher 4 with 4096-byte pages (the app sets only
"PRAGMA key", so it cannot open anything else), no virtual tables, no COLLATE
on a primary key, no columns named rowid or oid, and a primary key that is an
integer, text or blob. A database that breaks those assumptions is not one
SimpleX wrote. user_version and application_id are not carried over either:
SimpleX never sets them, so they are always zero.

It reaches rows by key, so rows under a damaged interior b-tree page cannot be
reached at all - with widespread damage (a failing disk rather than one bad
write) expect to lose more than the damaged pages themselves. Whatever is lost
is counted and reported; it is never quietly dropped.

Rows whose parent rows were lost are reported, not deleted. SimpleX opens a
database that has them - it does not check foreign keys on opening - but it
runs with foreign_keys = ON, so later operations touching the missing parents
will fail, as will a future migration that rebuilds one of those tables. Pass
--drop-fk-violations to delete them, which removes more than was damaged.
"""

from __future__ import annotations

import argparse
import errno
import getpass
import hashlib
import hmac
import os
import shutil
import sqlite3
import signal
import struct
import sys
import tempfile
import time
import zipfile
from urllib.parse import quote
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Tuple

try:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
except ImportError:
    sys.exit("this script needs the 'cryptography' package: pip install cryptography")

SALT_SZ = 16
IV_SZ = 16
KEY_SZ = 32
HMAC_SALT_MASK = 0x3A
FAST_KDF_ITER = 2
AES_BLOCK = 16

# rows held in memory at once, and rows per INSERT batch
CHUNK = 2000
# how many pages to search for an authentic one when page 1 is damaged
DETECT_SCAN_PAGES = 256
# how long to keep stepping over damage in one table before giving up
SKIP_BUDGET_S = 900
# a damaged cell can claim a payload of gigabytes; these bound what SQLite
# will allocate for one, rather than letting the machine die
SCHEMA_HEAP_LIMIT = 16 * 1024 ** 2
# a real schema entry is a few hundred bytes; anything like this is garbage
MAX_SCHEMA_ENTRY = 1024 ** 2
DATA_HEAP_LIMIT = 1024 * 1024 ** 2
# and for the whole run, so a database of many damaged tables still finishes
RUN_BUDGET_S = 4 * 3600
run_deadline = 0.0

ARCHIVE_DBS = ("simplex_v1_chat.db", "simplex_v1_agent.db")
# a zip entry claiming more than this is not a real SimpleX database
MAX_DB_BYTES = 64 * 1024 ** 3

# SimpleX opens its databases with nothing but "PRAGMA key", so they are
# always SQLCipher 4 at its default settings - a file with any other cipher
# version or page size is one the app itself could not open, and so is not a
# SimpleX database at all.
CIPHER_NAME = "SQLCipher 4"
KDF_ITER = 256000
KDF_HASH = HMAC_HASH = "sha512"
MAC_SZ = 64
PAGE_SIZE = 4096
# IV plus MAC, rounded up to the AES block size
RESERVE = -(-(IV_SZ + MAC_SZ) // AES_BLOCK) * AES_BLOCK
USABLE = PAGE_SIZE - RESERVE

def derive_keys(passphrase: bytes, salt: bytes) -> Tuple[bytes, bytes]:
    key = hashlib.pbkdf2_hmac(KDF_HASH, passphrase, salt, KDF_ITER, KEY_SZ)
    hmac_salt = bytes(b ^ HMAC_SALT_MASK for b in salt)
    hmac_key = hashlib.pbkdf2_hmac(KDF_HASH, key, hmac_salt, FAST_KDF_ITER, KEY_SZ)
    return key, hmac_key


def page_mac(hmac_key: bytes, pgno: int, ciphertext_and_iv: bytes) -> bytes:
    m = hmac.new(hmac_key, digestmod=getattr(hashlib, HMAC_HASH))
    m.update(ciphertext_and_iv)
    m.update(struct.pack("<I", pgno))  # little-endian page number
    return m.digest()


def is_blank(page: bytes) -> bool:
    return not any(page)


def page_authentic(page: bytes, pgno: int, hmac_key: bytes,
                   blank_ok: bool = True) -> bool:
    if len(page) < PAGE_SIZE:
        return False
    if pgno > 1 and is_blank(page):
        # SQLCipher treats an all-zero page as a short read rather than a
        # failure (sqlcipher_page_cipher); calling it damaged would raise a
        # false "your storage is failing". It authenticates nothing, though,
        # so it must never be accepted as proof of the passphrase.
        return blank_ok
    start = SALT_SZ if pgno == 1 else 0
    stored = page[USABLE + IV_SZ : USABLE + IV_SZ + MAC_SZ]
    return page_mac(hmac_key, pgno, page[start : USABLE + IV_SZ]) == stored


def prove_passphrase(path: str, passphrase: bytes) -> Optional[int]:
    """Prove the passphrase by finding a page whose HMAC verifies, and
    return that page's number.

    Page 1 is tried first, but a database whose page 1 is damaged is exactly
    the case this tool exists for, so other pages are searched before
    concluding anything about the passphrase.
    """
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        salt = f.read(SALT_SZ)
        if len(salt) < SALT_SZ:
            return None
        if salt == b"SQLite format 3\x00":
            raise SystemExit(
                f"{path} is a plain, unencrypted SQLite database - there is "
                f"nothing here for this tool to decrypt.\n  A SimpleX "
                f"database is encrypted; this file is not one.")
        if size < PAGE_SIZE:
            return None
        _, hmac_key = derive_keys(passphrase, salt)
        f.seek(0)
        try:
            first = f.read(PAGE_SIZE)
        except OSError:
            first = b""
        if page_authentic(first, 1, hmac_key):
            return 1
        for pgno in range(2, min(size // PAGE_SIZE, DETECT_SCAN_PAGES) + 1):
            f.seek((pgno - 1) * PAGE_SIZE)
            try:
                probe = f.read(PAGE_SIZE)
            except OSError:
                continue
            if page_authentic(probe, pgno, hmac_key, blank_ok=False):
                return pgno
        return None


def decrypt(path: str, passphrase: bytes, out_path: str
            ) -> Tuple[List[int], int, List[int], List[int]]:
    """Decrypt page by page, in constant memory.

    Returns the pages that fail their HMAC, the size of any truncated trailing
    page, the pages that are entirely zeros, and the pages the device refused
    to hand over at all. Damaged pages are decrypted anyway - the goal is to
    salvage."""
    size = os.path.getsize(path)
    n_pages = -(-size // PAGE_SIZE) if size else 0
    tail = size % PAGE_SIZE
    bad: List[int] = []
    blank: List[int] = []
    unread: List[int] = []

    with open(path, "rb") as fin, open(out_path, "wb") as fout:
        salt = fin.read(SALT_SZ)
        key, hmac_key = derive_keys(passphrase, salt)
        fin.seek(0)
        for i in range(n_pages):
            pgno = i + 1
            try:
                page = fin.read(PAGE_SIZE)
            except OSError:
                # an unreadable sector: salvage around it rather than abandon
                # the database, but never mistake it for a blank page - this
                # is the one case where the storage itself is failing
                unread.append(pgno)
                fin.seek((i + 1) * PAGE_SIZE)
                fout.write(b"\x00" * PAGE_SIZE)
                continue
            if len(page) < PAGE_SIZE:
                page += b"\x00" * (PAGE_SIZE - len(page))
            if not page_authentic(page, pgno, hmac_key):
                bad.append(pgno)
            elif pgno > 1 and is_blank(page):
                blank.append(pgno)
                # an all-zero page is a short read, and SQLCipher passes the
                # zeros through rather than decrypting them
                fout.write(page)
                continue
            # page 1 keeps the salt where plaintext SQLite keeps its magic
            start = SALT_SZ if pgno == 1 else 0
            iv = page[USABLE : USABLE + IV_SZ]
            dec = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
            plain = dec.update(page[start : USABLE]) + dec.finalize()
            if pgno == 1:
                fout.write(b"SQLite format 3\x00")
            # the reserve stays in place, so the header's own page size and
            # reserve fields remain correct and the result is a valid database
            fout.write(plain)
            fout.write(b"\x00" * RESERVE)
    return bad, tail, blank, unread


def header_bytes(size_pages: int, schema_cookie: int) -> bytes:
    """SQLite's 100-byte file header, reserving RESERVE bytes per page.

    SQLite has no pragma for the reserve, but it honours what it finds in an
    existing header, so a database seeded with this keeps the layout the
    encrypted form needs. Everything not set here - the freelist, the
    auto-vacuum fields, user_version, application_id - is zero, which is what
    an empty database and a rebuilt header both want.
    """
    head = bytearray(100)
    head[0:16] = b"SQLite format 3\x00"
    struct.pack_into(">H", head, 16, PAGE_SIZE)
    head[18] = head[19] = 1  # write and read version: rollback journal
    head[20] = RESERVE
    head[21], head[22], head[23] = 64, 32, 32  # payload fractions
    struct.pack_into(">I", head, 24, 1)  # change counter
    struct.pack_into(">I", head, 28, size_pages)
    struct.pack_into(">I", head, 40, schema_cookie)
    struct.pack_into(">I", head, 44, 4)  # schema format
    struct.pack_into(">I", head, 56, 1)  # UTF-8
    struct.pack_into(">I", head, 92, 1)  # version valid for
    struct.pack_into(">I", head, 96, sqlite3.sqlite_version_info[0] * 1000000
                     + sqlite3.sqlite_version_info[1] * 1000
                     + sqlite3.sqlite_version_info[2])
    return bytes(head)


def seed_database(path: str) -> None:
    """Write an empty database laid out the way the encrypted form needs."""
    page = bytearray(PAGE_SIZE)
    page[0:100] = header_bytes(1, 0)
    page[100] = 0x0D  # empty leaf table b-tree (the schema table)
    struct.pack_into(">H", page, 105, USABLE)
    with open(path, "wb") as f:
        f.write(bytes(page))


def openable(path: str) -> bool:
    try:
        con = sqlite3.connect(ro_uri(path), uri=True)
        try:
            con.execute("SELECT count(*) FROM sqlite_master").fetchone()
            return True
        finally:
            con.close()
    except (sqlite3.DatabaseError, UnicodeDecodeError):
        # a damaged schema makes SQLite quote raw bytes back in its error
        # message, which the sqlite3 module then fails to decode
        return False


def rebuild_header(path: str) -> bool:
    """Rewrite the 100-byte file header of a decrypted copy.

    Page 1 carries the change counter, so it is rewritten on every commit and
    is the likeliest victim of a torn write - and CBC means one flipped bit
    there garbles the whole header block. The page size and reserve are known
    from the cipher profile, and the rest are constants or derivable, so the
    schema on the rest of page 1 can still be reached.
    """
    size = os.path.getsize(path)
    with open(path, "r+b") as f:
        original = f.read(100)
        if len(original) < 100:
            return False
        f.seek(0)
        f.write(header_bytes(size // PAGE_SIZE, 1))
    if openable(path):
        return True
    # it did not help, so the header was not the problem: put it back rather
    # than discard auto_vacuum for nothing
    with open(path, "r+b") as f:
        f.seek(0)
        f.write(original)
    return False


def encrypt(plain_path: str, out_path: str, passphrase: bytes) -> None:
    size = os.path.getsize(plain_path)
    with open(plain_path, "rb") as fin:
        header = fin.read(24)
    if size % PAGE_SIZE or len(header) < 24 or header[20] != RESERVE:
        found_ps = struct.unpack_from(">H", header, 16)[0] if len(header) >= 18 else 0
        raise SystemExit(
            f"cannot encrypt {plain_path}: expected {PAGE_SIZE}-byte pages "
            f"reserving {RESERVE} bytes, found page size {found_ps} "
            f"reserving {header[20] if len(header) > 20 else '?'}"
        )
    salt = os.urandom(SALT_SZ)
    key, hmac_key = derive_keys(passphrase, salt)
    with open(plain_path, "rb") as fin, open(out_path, "wb") as fout:
        fout.write(salt)
        for i in range(size // PAGE_SIZE):
            pgno = i + 1
            page = fin.read(PAGE_SIZE)
            body = page[SALT_SZ:USABLE] if pgno == 1 else page[:USABLE]
            iv = os.urandom(IV_SZ)
            enc = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
            ct = enc.update(body) + enc.finalize()
            fout.write(ct)
            fout.write(iv)
            fout.write(page_mac(hmac_key, pgno, ct + iv))


def ro_uri(path: str) -> str:
    """A read-only URI for a path. Interpolating the path raw lets '?' or '#'
    truncate it, so SQLite opens - and creates - a different, empty file."""
    return "file:" + quote(os.path.abspath(path), safe="/") + "?mode=ro"


def q(identifier: str) -> str:
    """Quote an identifier. Interpolating one raw turns an odd table name into
    a syntax error that then looks like corruption."""
    return '"' + identifier.replace('"', '""') + '"'


def _class_bound(sample, which: str):
    """The top, bottom or zero of `sample`'s storage class, used as a
    bisection bound when the key at that end cannot itself be read. A bound
    only has to sit beyond the damage; the forward walk still finds the true
    end of the table.

    "zero" exists because searching up from the class floor is useless for
    integers: the floor is 2**63 away from any real key, and bisecting a range
    that wide lands on unrelated damaged pages and discards everything before
    them.
    """
    if isinstance(sample, int):
        # -2**63 and 2**63-1 are SQLite's smallest and largest integers
        return {"ceiling": 2 ** 63 - 1, "zero": 0, "floor": -(2 ** 63)}[which]
    if isinstance(sample, str):
        return "\uffff" * (len(sample) + 1) if which == "ceiling" else ""
    if isinstance(sample, bytes):
        return b"\xff" * (len(sample) + 1) if which == "ceiling" else b""
    return None


SQLITE_CLASS_ORDER = {"null": 0, "integer": 1, "real": 1, "text": 2, "blob": 3}


def sort_key(kinds: tuple, values: tuple) -> tuple:
    """Order a key tuple the way SQLite does: NULL, then numbers, then TEXT,
    then BLOB, comparing TEXT and BLOB byte by byte.

    The storage class comes from the database, not from the Python type: TEXT
    that is not valid UTF-8 arrives as bytes but still sorts as TEXT.

    A damaged page can hand back a structurally valid row whose key is
    nonsense. Following it either skips a range of readable rows or rewinds
    the walk, so every batch is checked against this ordering.
    """
    out = []
    for kind, v in zip(kinds, values):
        if v is None:
            out.append((0, b""))
            continue
        rank = SQLITE_CLASS_ORDER.get(kind, 4)
        # a damaged page can claim a class the value does not have; trust the
        # value, so that two slots of the same rank always compare
        if rank == 1 and not isinstance(v, (int, float)):
            rank = 2 if isinstance(v, str) else 3 if isinstance(v, bytes) else 4
        if rank == 1:
            out.append((1, v))
        elif isinstance(v, str):
            out.append((rank, v.encode("utf-8", "surrogatepass")))
        elif isinstance(v, bytes):
            out.append((rank, v))
        else:
            out.append((rank, repr(v).encode()))
    return tuple(out)


def _text_or_bytes(b: bytes):
    """TEXT that survived decodes normally; damaged TEXT is kept as raw bytes
    and re-inserted with an explicit CAST so it stays TEXT (see Copier)."""
    try:
        return b.decode("utf-8")
    except UnicodeDecodeError:
        return b


def split_row(row: tuple) -> Tuple[tuple, tuple]:
    """Rows are selected as typeof(c1), c1, typeof(c2), c2, ... so that the
    original storage class of every value is known."""
    return row[0::2], row[1::2]


@dataclass
class Loss:
    table: str
    what: object          # a key, or a "from..to" range
    reason: str
    rows: Optional[int]   # None when the number of rows is unknown


@dataclass
class TableResult:
    name: str
    copied: int
    source_rows: Optional[int]
    lost_rows: int
    skipped_ranges: int
    final_rows: Optional[int] = None   # what the finished file holds
    in_dest: Optional[int] = None      # what landed before any FK cleanup


@dataclass
class Salvage:
    tables: List[TableResult] = field(default_factory=list)
    losses: List[Loss] = field(default_factory=list)
    schema_failures: List[Tuple[str, str]] = field(default_factory=list)
    incomplete: List[Tuple[str, str]] = field(default_factory=list)
    notes: List[str] = field(default_factory=list)
    fk_violations: int = 0
    fk_dropped: int = 0


class Copier:
    """Inserts salvaged rows, counting only what actually lands."""

    def __init__(self, dst, table: str, cols: List[str], losses: List[Loss],
                 keep_rowid: bool = False):
        self.dst = dst
        self.table = table
        self.cols = cols
        self.losses = losses
        # a table whose primary key is not an INTEGER PRIMARY KEY still has a
        # rowid; carrying it over keeps the copy identical to the original
        self.keep_rowid = keep_rowid
        names = (["_rowid_"] if keep_rowid else []) + list(cols)
        self.quoted = ", ".join(q(c) for c in names)
        self.n_values = len(names)
        self._sp = 0

    def _insert_sql(self, cast: tuple, ignore: bool) -> str:
        offset = 1 if self.keep_rowid else 0
        marks = ["CAST(? AS TEXT)" if i - offset in cast else "?"
                 for i in range(self.n_values)]
        verb = "INSERT OR IGNORE" if ignore else "INSERT"
        return (f'{verb} INTO {q(self.table)} ({self.quoted}) '
                f'VALUES ({", ".join(marks)})')

    @staticmethod
    def _cast(types: tuple, values: tuple) -> tuple:
        # a TEXT value that is not valid UTF-8 comes back as bytes; inserting
        # it as-is would silently turn it into a BLOB
        return tuple(i for i, (t, v) in enumerate(zip(types, values))
                     if isinstance(v, bytes) and t == "text")

    def store(self, rows: List[tuple], skip: int = 0, n_keys: int = 0) -> int:
        """Insert rows. Each row is the key's storage classes, then the key
        values, then interleaved typeof/value pairs for the columns. Returns
        the number of rows genuinely in the destination afterwards."""
        if not rows:
            return 0
        groups: Dict[tuple, List[tuple]] = {}
        keyed: Dict[tuple, List[tuple]] = {}
        for row in rows:
            types, values = split_row(row[skip:])
            cast = self._cast(types, values)
            if self.keep_rowid:
                values = (row[n_keys],) + values
            groups.setdefault(cast, []).append(values)
            keyed.setdefault(cast, []).append(tuple(row[n_keys:skip]))

        inserted = 0
        for cast, values in groups.items():
            self._sp += 1
            sp = f"copy_{self._sp}"
            self.dst.execute(f"SAVEPOINT {sp}")
            before = self.dst.total_changes
            ok = False
            failure = None
            try:
                self.dst.executemany(self._insert_sql(cast, True), values)
                ok = self.dst.total_changes - before == len(values)
            except sqlite3.DatabaseError as e:
                failure = e
            if ok:
                self.dst.execute(f"RELEASE {sp}")
                inserted += len(values)
                continue
            # something was rejected or silently ignored; undo the batch and
            # redo it row by row so every casualty can be named
            try:
                self.dst.execute(f"ROLLBACK TO {sp}")
                self.dst.execute(f"RELEASE {sp}")
            except sqlite3.DatabaseError:
                # a full disk aborts the whole transaction, savepoint and all;
                # "no such savepoint" is the symptom, and reporting it instead
                # of the cause reads as a bug in this script
                if failure is None:
                    raise
                raise failure
            sql = self._insert_sql(cast, False)
            for value, key in zip(values, keyed[cast]):
                ident = key if len(key) != 1 else key[0]
                marker = self.dst.total_changes
                try:
                    self.dst.execute(sql, value)
                except sqlite3.DatabaseError as e:
                    self.losses.append(Loss(self.table, ident, str(e), 1))
                    continue
                if self.dst.total_changes == marker:
                    self.losses.append(
                        Loss(self.table, ident,
                             "rejected by the destination", 1))
                else:
                    inserted += 1
        return inserted


def scan_table(src, copier: Copier, name: str, typed_cols: str, hint: str,
               losses: List[Loss], skip: int = 0, n_keys: int = 0) -> int:
    """Read a table straight through in windows.

    There is no way to step around damage without a key, but the rows before
    it are still worth having.
    """
    copied, offset = 0, 0
    while True:
        try:
            rows = src.execute(
                f"SELECT {typed_cols} FROM {q(name)}{hint} "
                f"LIMIT {CHUNK} OFFSET {offset}").fetchall()
        except sqlite3.DatabaseError as e:
            losses.append(Loss(name, f"offset {offset}",
                               f"unreadable from here: {e}", None))
            break
        if not rows:
            break
        copied += copier.store(rows, skip, n_keys)
        offset += len(rows)
    return copied


def copy_table(src, copier: Copier, name: str, typed_cols: str,
               keys: List[str], hint: str, losses: List[Loss],
               incomplete: List[Tuple[str, str]]) -> int:
    """Copy a table in key order, in fixed-size windows.

    `keys` is the rowid for an ordinary table and the primary key columns for
    a WITHOUT ROWID one; either way the rows come out of the table's own
    b-tree, so damaged index pages are never touched. Reads are seeks from the
    b-tree root, so a damaged page only blocks the keys that live on it: when
    a read fails, bisect the remaining key space to find the nearest key past
    the damage and carry on from there.
    """
    key_list = ", ".join(keys)
    desc_list = ", ".join(f"{k} DESC" for k in keys)
    n_keys = len(keys)
    lead = keys[0]
    # the storage class of each key travels with it: a TEXT key that is not
    # valid UTF-8 arrives as bytes, and binding it back without a CAST makes
    # it a BLOB, which sorts above every TEXT and silently matches nothing
    key_types = ", ".join(f"typeof({k})" for k in keys)
    projection = f"{key_types}, {key_list}, {typed_cols}"
    skip = 2 * n_keys

    def mark(kind) -> str:
        return "CAST(? AS TEXT)" if kind == "text" else "?"

    def after(kinds, values) -> Tuple[str, tuple]:
        marks = [mark(k) for k in kinds]
        if n_keys > 1:
            return f"({key_list}) > ({', '.join(marks)})", tuple(values)
        return f"{lead} > {marks[0]}", (values[0],)

    def edge(order: str):
        # ORDER BY ... LIMIT 1, never min()/max(): SQLite answers those from a
        # secondary index even under NOT INDEXED, so a damaged index would
        # make a perfectly readable table look empty
        return src.execute(
            f"SELECT typeof({lead}), {lead} FROM {q(name)}{hint} "
            f"ORDER BY {order} LIMIT 1").fetchone()

    lo_row = hi_row = None
    lo_ok = hi_ok = False
    try:
        lo_row, lo_ok = edge(key_list), True
    except sqlite3.DatabaseError:
        pass
    try:
        hi_row, hi_ok = edge(desc_list), True
    except sqlite3.DatabaseError:
        pass
    if (lo_ok and lo_row is None) or (hi_ok and hi_row is None):
        return 0  # the table really is empty

    lead_kind = (lo_row or hi_row or (None, None))[0]
    last_kind = (hi_row or lo_row or (None, None))[0]
    first_key = lo_row[1] if lo_row else None
    last_key = hi_row[1] if hi_row else None
    if first_key is None and last_key is None:
        incomplete.append(
            (name, "neither end of the key range could be read, so it was "
                   "read straight through instead of walked"))
        return scan_table(src, copier, name, projection, hint, losses,
                          skip, n_keys)
    synthetic_floor = first_key is None
    synthetic_ceiling = last_key is None
    ceiling_doubted = False
    if last_key is None:
        last_key = _class_bound(first_key, "ceiling")
    if first_key is None:
        first_key = _class_bound(last_key, "floor")
    if first_key is None or last_key is None:
        incomplete.append(
            (name, "key bounds unreadable and none can be synthesised, so it "
                   "was read straight through instead of walked"))
        return scan_table(src, copier, name, projection, hint, losses,
                          skip, n_keys)

    def read_after(cur: Optional[Tuple[tuple, tuple]], limit: int = CHUNK) -> list:
        """Resume on the FULL key. Using only the leading column here would
        drop the rest of the current key group - in the agent database that
        is the rest of one conversation."""
        if cur is None:
            return src.execute(
                f"SELECT {projection} FROM {q(name)}{hint} "
                f"ORDER BY {key_list} LIMIT {limit}").fetchall()
        where, params = after(cur[0], cur[1])
        return src.execute(
            f"SELECT {projection} FROM {q(name)}{hint} WHERE {where} "
            f"ORDER BY {key_list} LIMIT {limit}", params).fetchall()

    def read_from(key, limit: int = CHUNK) -> list:
        if key is None:
            return read_after(None, limit)
        return src.execute(
            f"SELECT {projection} FROM {q(name)}{hint} "
            f"WHERE {lead} > {mark(lead_kind)} "
            f"ORDER BY {key_list} LIMIT {limit}", (key,)).fetchall()

    copied = 0
    cursor: Optional[Tuple[tuple, tuple]] = None  # (kinds, values) last copied
    lead_from = None                 # or just a leading value to resume past
    pending: Optional[list] = None   # rows a successful probe already read
    started = False
    # scattered damage means one skip per damaged region, and a failing disk
    # can have thousands. Bound the work by time, not by a count of holes.
    deadline = min(time.monotonic() + SKIP_BUDGET_S,
                   run_deadline if run_deadline else float("inf"))

    end_key = (sort_key((last_kind,), (last_key,))
               if last_key is not None else None)

    def beyond_end(kind, value) -> bool:
        """True when a key sorts past the table's real last key. A damaged
        page can yield a structurally valid row whose key is nonsense; taking
        it as the cursor would end the walk and abandon the rest in silence.

        The comparison is in SQLite's ordering, not Python's: a key whose
        storage class is wrong sorts above every real key and would otherwise
        look like a perfectly ordinary increase.
        """
        if synthetic_ceiling or value is None or last_key is None:
            return False
        return sort_key((kind,), (value,)) > end_key

    def usable_prefix(rows, start):
        """The leading run of rows whose keys strictly increase and stay
        inside the table. The first row that breaks either rule came off a
        damaged page and must not become the cursor."""
        prev = start
        good = []
        for row in rows:
            key = sort_key(tuple(row[:n_keys]), tuple(row[n_keys:skip]))
            if prev is not None and key <= prev:
                return good, row, "keys that do not increase"
            if beyond_end(row[0], row[n_keys]):
                return good, row, "keys past the end of the table"
            good.append(row)
            prev = key
        return good, None, None

    def sane(rows) -> bool:
        start = sort_key(cursor[0], cursor[1]) if cursor is not None else None
        good, bad, _why = usable_prefix(rows, start)
        return bad is None and len(good) == len(rows)

    def take(rows) -> bool:
        """Store a batch and advance the cursor. False means the batch came
        off a damaged page, so it must be stepped over rather than followed."""
        nonlocal copied, cursor, lead_from
        start = sort_key(cursor[0], cursor[1]) if cursor is not None else None
        good, bad, why = usable_prefix(rows, start)
        copied += copier.store(good, skip, n_keys)
        if good:
            last = good[-1]
            cursor = (tuple(last[:n_keys]), tuple(last[n_keys:skip]))
            lead_from = None
        if bad is not None:
            losses.append(Loss(
                name, bad[n_keys],
                f"{len(rows) - len(good)} row(s) from a damaged page carry "
                f"{why}", len(rows) - len(good)))
            return False
        return True

    def give_up_now(at) -> None:
        why = (f"the {RUN_BUDGET_S // 3600}-hour limit for the whole database"
               if deadline == run_deadline
               else f"{SKIP_BUDGET_S}s of stepping over damage in this table")
        losses.append(Loss(
            name, at, f"gave up at {why}; the rest of this table was not read",
            None))
        incomplete.append(
            (name, "the walk was abandoned part-way, so this table is "
                   "incomplete"))

    def doubt_ceiling(at) -> bool:
        """The ceiling came from a single cell on the rightmost leaf. If
        nothing at all can be found below it, that cell is what is wrong -
        stop believing it rather than the whole table."""
        nonlocal last_key, end_key, synthetic_ceiling, ceiling_doubted
        if synthetic_ceiling or ceiling_doubted:
            return False
        synthetic_ceiling = ceiling_doubted = True
        last_key = _class_bound(last_key, "ceiling") or last_key
        end_key = sort_key((last_kind,), (last_key,))
        losses.append(Loss(name, at, "the highest key on the last page looks "
                                     "wrong, so it was ignored", None))
        return True

    while True:
        try:
            if pending is not None:
                rows, pending = pending, None
            elif cursor is not None:
                rows = read_after(cursor)
            else:
                rows = read_from(lead_from)
                started = True
        except sqlite3.DatabaseError as e:
            # the bracket must have a real lower bound, otherwise the search
            # starts at the far end of the key space and abandons the table
            if cursor is not None:
                lo = cursor[1][0]
            elif lead_from is not None:
                lo = lead_from
            else:
                lo = first_key
            # Everything below the damage still reads. Shrink the window and
            # retry from the same place first, so the gap ends up the size of
            # the damage rather than the size of a read.
            read_any = False
            limit = CHUNK // 2
            while limit >= 1:
                try:
                    rows = (read_after(cursor, limit) if cursor is not None
                            else read_from(lead_from, limit))
                except sqlite3.DatabaseError:
                    limit //= 2
                    continue
                if not rows:
                    break
                before_cursor = cursor
                ok = take(rows)
                if cursor is not None and cursor != before_cursor:
                    read_any = True
                if not ok:
                    # every row was beyond the end, or the batch came off a
                    # damaged page: fall through to the bounded skip path
                    break
            if read_any:
                started = True
                continue  # re-enter the normal walk from the new cursor

            if time.monotonic() > deadline:
                give_up_now(lo)
                return copied
            skipped, pending = _seek_past_damage(
                read_from, lo, last_key, sane,
                anchor=_class_bound(last_key, "zero") if not started else None)
            if skipped is None and doubt_ceiling(lo):
                continue
            if skipped is None:
                losses.append(Loss(name, lo, f"unreadable from here: {e}", None))
                incomplete.append(
                    (name, "the walk could not get past the damage, so the "
                           "rest of this table was not read"))
                return copied
            where = ("everything before " + repr(skipped)
                     if not started and synthetic_floor
                     else f"{lo!r}..{skipped!r}")
            losses.append(Loss(name, where,
                               f"skipped damaged pages: {e}", None))
            if not started and not synthetic_floor:
                # the lowest key sorts before anything we can seek past, so it
                # can only be fetched on its own
                try:
                    first_rows = src.execute(
                        f"SELECT {projection} FROM {q(name)}{hint} "
                        f"WHERE {lead} = {mark(lead_kind)}",
                        (first_key,)).fetchall()
                    copied += copier.store(first_rows, skip, n_keys)
                except sqlite3.DatabaseError:
                    pass
            started = True
            cursor, lead_from = None, skipped
            continue
        if not rows:
            return copied
        if take(rows):
            continue
        # the batch ran past the end of the table: step over the bad page
        lo = cursor[1][0] if cursor is not None else first_key
        if time.monotonic() > deadline:
            give_up_now(lo)
            return copied
        skipped, pending = _seek_past_damage(read_from, lo, last_key, sane)
        if skipped is None and doubt_ceiling(lo):
            continue
        if skipped is None:
            losses.append(Loss(name, lo, "unreadable past this key", None))
            incomplete.append(
                (name, "the walk could not get past the damage, so the rest "
                       "of this table was not read"))
            return copied
        losses.append(Loss(name, f"{lo!r}..{skipped!r}",
                           "skipped a page whose keys were nonsense", None))
        cursor, lead_from = None, skipped


def _as_int(value, width: int) -> Optional[int]:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        value = value.encode("utf-8", "surrogatepass")
    if isinstance(value, bytes):
        return int.from_bytes(value.ljust(width, b"\x00"), "big")
    return None


def _from_int(n: int, sample, width: int):
    if isinstance(sample, int):
        return n
    if n < 0 or n >= 1 << (8 * width):
        return None
    raw = n.to_bytes(width, "big").rstrip(b"\x00")
    if isinstance(sample, bytes):
        return raw
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return None


def _fraction(lo, hi, k: int):
    """The value 1/2**k of the way from lo to hi, for galloping forward."""
    if type(lo) is not type(hi):
        return None
    def blen(v) -> int:
        if isinstance(v, str):
            return len(v.encode("utf-8", "surrogatepass"))
        return len(v) if isinstance(v, bytes) else 8

    width = max(blen(lo), blen(hi)) + 1
    a, b = _as_int(lo, width), _as_int(hi, width)
    if a is None or b is None or b <= a:
        return None
    cand_i = a + max(1, (b - a) >> k)
    if cand_i >= b:
        return None
    cand = _from_int(cand_i, lo, width)
    if cand is None:
        return None
    return cand if lo < cand < hi else None


def _key_width(lo, hi) -> int:
    """The byte width _fraction does its arithmetic in."""
    def blen(v) -> int:
        if isinstance(v, str):
            return len(v.encode("utf-8", "surrogatepass"))
        return len(v) if isinstance(v, bytes) else 8
    return max(blen(lo), blen(hi)) + 1


def _span_bits(lo, hi) -> int:
    """How many doublings separate a step of one from the whole range.

    A fixed start overshoots whenever the ceiling is synthetic: a text key
    pads to three bytes per character, so "\uffff" repeated spans hundreds of
    bits and even a very large fixed k still steps past the end of the table.
    """
    width = _key_width(lo, hi)
    a, b = _as_int(lo, width), _as_int(hi, width)
    if a is None or b is None or b <= a:
        return 48
    return (b - a).bit_length()


def _text_ladder(lo: str, hi: str):
    """Candidates strictly between two text keys, in increasing jump size.

    Byte-space arithmetic cannot serve a text key: it pads to a fixed width
    and adds, and almost everything that produces is invalid UTF-8 and has to
    be thrown away - 545 of 561 candidates for a 22-character key - so the
    walk can never jump far enough to clear the damage. Incrementing one
    character and dropping the rest gives the same geometric ladder with
    every rung a valid string.
    """
    if lo + "\x01" < hi:
        yield lo + "\x01"
    for p in range(len(lo) - 1, -1, -1):
        point = ord(lo[p]) + 1
        if 0xD800 <= point <= 0xDFFF:      # not a character on its own
            point = 0xE000
        nxt = lo[:p] + chr(point)
        if lo < nxt < hi:
            yield nxt


def _candidates(base, upper):
    """The ladder a gallop climbs, smallest jump first.

    For a text key the two sources are complementary, so both are used: the
    byte arithmetic is fine-grained but yields almost nothing once the
    ceiling is synthetic, and the character ladder is coarse but always
    yields something.
    """
    rungs = [_fraction(base, upper, k)
             for k in range(_span_bits(base, upper), -1, -1)]
    rungs = [c for c in rungs if c is not None]
    if isinstance(base, str) and isinstance(upper, str):
        rungs.extend(_text_ladder(base, upper))
        rungs.sort()
    seen = None
    for cand in rungs:
        if cand != seen:
            seen = cand
            yield cand


def _seek_past_damage(read_from: Callable, lo, hi,
                      valid: Optional[Callable] = None, anchor=None):
    """Find the nearest key past the damage from which reading works again.

    Damage is not one contiguous region - a failing disk scatters it - so a
    plain bisection of [lo, hi] is wrong: a probe can fail because of an
    unrelated bad page further along and push the search right, abandoning
    everything in between. Gallop forward from lo in doubling steps instead,
    so the distance searched is proportional to the real gap, then tighten.

    A probe has three outcomes, and conflating the last two walks off the end
    of the table: unreadable (move right), readable but empty (past the last
    key, so move LEFT), readable with rows (a candidate).
    """
    UNREADABLE, PAST_END = object(), object()

    def probe(x):
        try:
            rows = read_from(x, 1)
        except sqlite3.DatabaseError:
            return UNREADABLE
        if valid is not None and not valid(rows):
            return UNREADABLE
        return rows if rows else PAST_END

    prev_fail = lo
    upper = hi
    found = found_rows = None
    base = lo if anchor is None else anchor

    # Start from a step of one. When the highest key could not be read the
    # ceiling is synthetic, and a step sized to that range is already past the
    # end of a real table: every probe then fails and the whole rest of the
    # table is abandoned.
    for cand in _candidates(base, upper):
        if cand == prev_fail:
            continue
        rows = probe(cand)
        if rows is UNREADABLE:
            prev_fail = cand
            continue
        if rows is PAST_END:
            upper = cand        # the table ends before here; look left
            break
        found, found_rows = cand, rows
        break

    # tighten: give back as few rows as possible between the last failure and
    # the first point that worked (or the point we know is past the end)
    a = prev_fail
    b = found if found is not None else upper
    for _ in range(512):
        mid = _fraction(a, b, 1)
        if mid is None or mid == found:
            break
        rows = probe(mid)
        if rows is UNREADABLE:
            a = mid
        elif rows is PAST_END:
            b = mid
        else:
            found, found_rows, b = mid, rows, mid
    return found, found_rows


def _orphan_deletes(dst, child: str):
    """DELETE statements removing rows of `child` whose parent is missing."""
    try:
        fks = dst.execute(f"PRAGMA foreign_key_list({q(child)})").fetchall()
    except sqlite3.DatabaseError:
        return
    by_id = {}
    for row in fks:
        by_id.setdefault(row[0], []).append(row)
    for _fkid, rows in by_id.items():
        rows.sort(key=lambda row: row[1])
        parent = rows[0][2]
        child_cols = [row[3] for row in rows]
        parent_cols = [row[4] for row in rows]
        if any(c is None for c in parent_cols):
            try:
                info = dst.execute(f"PRAGMA table_info({q(parent)})").fetchall()
            except sqlite3.DatabaseError:
                continue
            pk = [row[1] for row in sorted((row for row in info if row[5]),
                                           key=lambda row: row[5])]
            if len(pk) != len(child_cols):
                continue
            parent_cols = pk
        on = " AND ".join(f"p.{q(pc)} = c.{q(cc)}"
                          for pc, cc in zip(parent_cols, child_cols))
        not_null = " AND ".join(f"c.{q(cc)} IS NOT NULL" for cc in child_cols)
        yield (f"DELETE FROM {q(child)} AS c WHERE {not_null} AND NOT "
               f"EXISTS (SELECT 1 FROM {q(parent)} AS p WHERE {on})")


class Unsalvageable(Exception):
    """The schema itself could not be read, so nothing can be recovered."""


def brief(value) -> str:
    """A short, safe label for a value that may be enormous or not text."""
    if isinstance(value, (str, bytes)):
        value = value[:40]
    return repr(value)[:60]


def cap_heap(con, limit: int) -> None:
    """Stop SQLite allocating without bound for a damaged cell that claims a
    payload of gigabytes: past this it fails the statement instead."""
    for pragma in ("hard_heap_limit", "soft_heap_limit"):
        try:
            con.execute(f"PRAGMA {pragma} = {limit}")
        except (sqlite3.DatabaseError, MemoryError):
            pass


def read_schema(path: str, notes: List[str],
                failures: List[Tuple[str, str]]):
    """Return (connection, schema rows).

    A single damaged CREATE statement makes SQLite refuse to open the whole
    database. PRAGMA writable_schema stops it parsing the schema at all, so
    every table whose definition survived can still be copied.
    """
    con = sqlite3.connect(ro_uri(path), uri=True)
    con.text_factory = _text_or_bytes
    cap_heap(con, SCHEMA_HEAP_LIMIT)
    try:
        rows = con.execute(
            "SELECT type, name, sql FROM sqlite_master ORDER BY rowid"
        ).fetchall()
        return con, rows
    except (sqlite3.DatabaseError, UnicodeDecodeError, MemoryError,
            SystemError):
        con.close()

    con = sqlite3.connect(ro_uri(path), uri=True)
    con.text_factory = _text_or_bytes
    cap_heap(con, SCHEMA_HEAP_LIMIT)
    try:
        con.execute("PRAGMA writable_schema = ON")
    except sqlite3.DatabaseError:
        pass
    try:
        rows = con.execute(
            "SELECT type, name, sql FROM sqlite_master ORDER BY rowid"
        ).fetchall()
        notes.append("SQLite refused to parse the schema, so it was read raw")
        return con, rows
    except (sqlite3.DatabaseError, UnicodeDecodeError, MemoryError,
            SystemError):
        pass

    # the schema itself spans several pages in a database this size, so one
    # damaged page there must not cost every table. Walk it entry by entry.
    rows, cursor, skipped, consecutive = [], 0, 0, 0
    while cursor < 1_000_000:
        if consecutive > 64:
            # nothing readable for a long stretch: this is the end of what can
            # be recovered, not a run of individually damaged entries
            break
        try:
            got = con.execute(
                "SELECT rowid, type, name, sql FROM sqlite_master "
                "WHERE rowid > ? ORDER BY rowid LIMIT 1", (cursor,)).fetchall()
        except (sqlite3.DatabaseError, UnicodeDecodeError, MemoryError,
                SystemError):
            cursor += 1          # step over the unreadable entry
            skipped += 1
            consecutive += 1
            continue
        if not got:
            break
        # the rowid comes off the damaged page too: a forged jump would skip
        # entries without any read failing, so count what it stepped over
        if isinstance(got[0][0], int):
            skipped += max(0, got[0][0] - cursor - 1)
        cursor = got[0][0]
        consecutive = 0
        entry = tuple(got[0][1:])
        if any(isinstance(v, (str, bytes)) and len(v) > MAX_SCHEMA_ENTRY
               for v in entry):
            # a damaged cell claiming a huge payload: step over it rather
            # than hold it in memory
            skipped += 1
            continue
        rows.append(entry)
    if not rows:
        con.close()
        raise Unsalvageable(
            "not one table definition could be read. Page 1 carries the "
            "schema, and too much of it is gone for anything to be recovered "
            "from this copy.")
    notes.append(f"the schema was damaged: {len(rows)} definitions were read "
                 f"entry by entry")
    if skipped:
        # an object whose schema entry was never read is invisible to every
        # other check here, including the table-set comparison
        failures.append(
            ("sqlite_schema",
             "part of the schema could not be read, so tables, indexes or "
             "triggers may be missing from this copy entirely"))
    return con, rows


def index_backed(src, name: str) -> bool:
    """Whether counting this table can be answered from an index, i.e. from a
    b-tree other than the table's own."""
    try:
        plan = src.execute(
            f"EXPLAIN QUERY PLAN SELECT count(*) FROM {q(name)}").fetchall()
    except sqlite3.DatabaseError:
        return False
    return any("INDEX" in str(row[-1]).upper() for row in plan)


def salvage(src_path: str, dst_path: str, drop_fk: bool,
            header_rebuilt: bool, auto_vacuum_read: Optional[int],
            source_healthy: bool) -> Salvage:
    global run_deadline
    run_deadline = time.monotonic() + RUN_BUDGET_S
    r = Salvage()
    src, objs = read_schema(src_path, r.notes, r.schema_failures)
    cap_heap(src, DATA_HEAP_LIMIT)
    # a damaged definition comes back as raw bytes, as a number, or claiming
    # an absurd size; none can be recreated, and all must be named rather
    # than silently dropped
    usable = []
    for entry in objs:
        typ, name, sql = entry
        if any(isinstance(v, (str, bytes)) and len(v) > MAX_SCHEMA_ENTRY
               for v in entry):
            r.schema_failures.append(
                (brief(name), "its schema entry claims an implausible size"))
        elif (not isinstance(typ, str) or not isinstance(name, str)
              or (sql is not None and not isinstance(sql, str))):
            r.schema_failures.append(
                (brief(name), "its definition on page 1 is damaged"))
        else:
            usable.append(entry)
    objs = usable
    try:
        auto_vacuum = src.execute("PRAGMA auto_vacuum").fetchone()[0]
    except sqlite3.DatabaseError:
        auto_vacuum = 0
    if auto_vacuum_read is not None:
        # page 1 authenticated before the header was rebuilt, so this is what
        # SimpleX actually recorded, not a guess
        auto_vacuum = auto_vacuum_read
    elif header_rebuilt:
        # it lived only in the header that was just rewritten, so the copy
        # says nothing about the original. SimpleX runs with auto_vacuum on,
        # and turning it on later is a no-op.
        auto_vacuum = 1
        r.notes.append("auto_vacuum was assumed to be on: the header that "
                       "recorded it was rebuilt")
    seed_database(dst_path)
    dst = sqlite3.connect(dst_path)
    dst.text_factory = _text_or_bytes
    # explicit transaction control: in its legacy mode the sqlite3 module
    # commits implicitly before a statement it does not recognise as DML,
    # which silently turns SAVEPOINT/ROLLBACK TO into no-ops
    dst.isolation_level = None
    # auto_vacuum only takes on an empty database, and only a VACUUM applies
    # it. Do both now: later, a VACUUM would renumber the rowids of any table
    # without an INTEGER PRIMARY KEY, undoing the ones carried over.
    dst.execute(f"PRAGMA auto_vacuum = {int(auto_vacuum)}")
    if int(auto_vacuum):
        try:
            dst.execute("VACUUM")
        except sqlite3.DatabaseError as e:
            r.notes.append(f"auto_vacuum could not be restored: {e}")
    # MEMORY, not OFF: without a rollback journal ROLLBACK TO is a
    # silent no-op, and the batch retry below depends on it
    dst.execute("PRAGMA journal_mode = MEMORY")
    dst.execute("PRAGMA synchronous = OFF")
    dst.execute("PRAGMA foreign_keys = OFF")
    dst.execute("BEGIN")

    tables = [o for o in objs if o[0] == "table" and o[2]
              and not str(o[1]).startswith("sqlite_")]
    # anything the lists below do not claim would be dropped, so name it now
    unclaimed = [o for o in objs
                 if not (o[0] in ("table", "index", "view", "trigger") and o[2])
                 and not str(o[1]).startswith("sqlite_")]
    for typ, name, sql in unclaimed:
        r.schema_failures.append(
            (str(name), f"its schema entry is damaged (type {typ!r}, "
                        f"{'no' if not sql else 'a'} definition)"))
    others = [o for o in objs if o[0] in ("index", "view") and o[2]]
    triggers = [o for o in objs if o[0] == "trigger" and o[2]]
    for _, name, sql in tables:
        try:
            dst.execute(sql)
        except sqlite3.DatabaseError as e:
            r.schema_failures.append((name, str(e)))

    made = {row[0] for row in dst.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table'")}
    missing = [o[1] for o in tables if o[1] not in made]
    for name in missing:
        if not any(n == name for n, _ in r.schema_failures):
            r.schema_failures.append(
                (name, "could not be created in the repaired copy, so none of "
                       "its rows could be saved"))
    declared = {o[1] for o in tables}
    # copying into a table that does not exist yields one failure per row
    tables = [o for o in tables if o[1] in made]

    # a stale page 1 can leave two objects pointing at the same b-tree, so
    # one table's rows are read and reported under another table's name
    try:
        roots = src.execute("SELECT name, rootpage FROM sqlite_master "
                            "WHERE rootpage > 0").fetchall()
    except sqlite3.DatabaseError:
        roots = []
    owner: Dict[int, str] = {}
    for obj_name, root in roots:
        if not isinstance(obj_name, str) or not isinstance(root, int):
            continue
        if root in owner:
            for clashing in (owner[root], obj_name):
                r.schema_failures.append(
                    (clashing, f"its schema entry points at the same pages as "
                               f"{owner[root] if clashing != owner[root] else obj_name}"))
        else:
            owner[root] = obj_name

    for _, name, _sql in tables:
        try:
            info = [row for row in src.execute(f'PRAGMA table_info({q(name)})')]
        except sqlite3.DatabaseError:
            info = []
        if not info:
            # the source connection may have stopped parsing its schema at a
            # damaged page; the destination has just executed the same CREATE
            try:
                info = [row for row in dst.execute(
                    f'PRAGMA table_info({q(name)})')]
            except sqlite3.DatabaseError:
                info = []
        cols = [row[1].decode() if isinstance(row[1], bytes) else row[1]
                for row in info]
        if not cols:
            r.schema_failures.append(
                (name, "its columns could not be read, so no rows were copied"))
            continue
        # storage class is carried alongside every value
        quoted = ", ".join(f"typeof({q(c)}), {q(c)}" for c in cols)
        before_losses = len(r.losses)

        # an ordinary table is walked by rowid; a WITHOUT ROWID table by its
        # primary key, which is its b-tree
        has_rowid = True
        try:
            src.execute(f"SELECT _rowid_ FROM {q(name)} LIMIT 1").fetchall()
        except sqlite3.DatabaseError as e:
            if "no such column" in str(e).lower():
                has_rowid = False
            # any other error is damage, and is handled by the walker

        # NOT INDEXED either way: a dead index must not be able to make a
        # readable table look empty
        hint = " NOT INDEXED"
        if has_rowid:
            keys = ["_rowid_"]
        else:
            pk_info = [row for row in info if row[5]]
            pk = [row[1].decode() if isinstance(row[1], bytes) else row[1]
                  for row in sorted(pk_info, key=lambda row: row[5])]
            keys = [q(c) for c in pk]

        copier = Copier(dst, name, cols, r.losses, keep_rowid=has_rowid)

        # Count the table both ways and keep the larger. Through the table's
        # own b-tree (what the copy walks) and through an index are different
        # readings of the same rows: when a lost write reverts part of one of
        # them, the two disagree, and the bigger number is the one that has
        # not lost rows. Counting only the way the copy reads would make the
        # loss invisible - source and copied would agree perfectly.
        counts = []
        for how in (hint, ""):
            try:
                counts.append(src.execute(
                    f"SELECT count(*) FROM {q(name)}{how}").fetchone()[0])
            except sqlite3.DatabaseError:
                pass
        source_rows = max(counts) if counts else None
        if source_rows is not None and not source_healthy \
                and not index_backed(src, name):
            # both counts walked the same b-tree, and that b-tree is part of
            # an inconsistent database: there is no second opinion to print
            source_rows = None

        if not keys:
            r.incomplete.append(
                (name, "it has no usable key, so it was read straight "
                       "through instead of walked"))
            copied = scan_table(src, copier, name, quoted, hint, r.losses)
        else:
            copied = copy_table(src, copier, name, quoted, keys, hint,
                                r.losses, r.incomplete)
        new = r.losses[before_losses:]
        r.tables.append(TableResult(
            name, copied, source_rows,
            sum(loss.rows or 0 for loss in new),
            sum(1 for loss in new if loss.rows is None)))

    # copying rows into an AUTOINCREMENT table already produced a counter;
    # keep whichever is higher so no id can ever be handed out twice
    if dst.execute("SELECT count(*) FROM sqlite_master "
                   "WHERE name = 'sqlite_sequence'").fetchone()[0]:
        try:
            seqs = src.execute("SELECT name, seq FROM sqlite_sequence").fetchall()
        except sqlite3.DatabaseError as e:
            r.schema_failures.append(("sqlite_sequence", f"unreadable: {e}"))
            seqs = []
        for seq_name, seq in seqs:
            if (not isinstance(seq_name, str) or not isinstance(seq, int)
                    or seq < 0 or seq >= 2 ** 63 - 1):
                r.schema_failures.append(
                    (brief(seq_name), "its AUTOINCREMENT counter is damaged, "
                                      "so row ids could be handed out twice"))
                continue
            if dst.execute("SELECT count(*) FROM sqlite_sequence WHERE name = ?",
                           (seq_name,)).fetchone()[0]:
                dst.execute("UPDATE sqlite_sequence SET seq = max(seq, ?) "
                            "WHERE name = ?", (seq, seq_name))
            else:
                dst.execute("INSERT INTO sqlite_sequence(name, seq) VALUES (?, ?)",
                            (seq_name, seq))

    # an index whose table is gone fails once per index: 40 lines that say
    # nothing except that one table is missing, and the table itself is named
    # nowhere else when its own definition was lost with the damaged schema
    orphaned: Dict[str, int] = {}
    for _, name, sql in others:
        try:
            dst.execute(sql)
        except sqlite3.DatabaseError as e:
            msg = str(e)
            gone = (msg[len("no such table: "):].split(".", 1)[-1]
                    if msg.startswith("no such table: ") else None)
            if gone is not None:
                orphaned[gone] = orphaned.get(gone, 0) + 1
            else:
                r.schema_failures.append((name, msg))
    for gone, n in sorted(orphaned.items()):
        if gone in declared:
            r.schema_failures.append(
                (gone, f"not in the repaired copy, so none of its rows were "
                       f"saved and {n} index(es) on it could not be recreated"))
        else:
            # either the table's own definition was lost with the damaged
            # schema, or these index definitions are the damaged part - the
            # name itself comes from a statement we could not trust
            r.schema_failures.append(
                (gone, f"{n} index(es) name this table, but it is not in the "
                       f"schema at all: either its definition was lost, or "
                       f"those index definitions are damaged"))
    dst.execute("COMMIT")

    # counted before any deletion, so it can be compared against what the
    # copier believes it inserted
    for t in r.tables:
        try:
            t.in_dest = dst.execute(
                f"SELECT count(*) FROM {q(t.name)}").fetchone()[0]
        except sqlite3.DatabaseError:
            t.in_dest = None

    def fk_state():
        """Count violations and name the child tables without materialising a
        row per violation: a lost parent table makes every child row one."""
        try:
            n = dst.execute(
                "SELECT count(*) FROM pragma_foreign_key_check").fetchone()[0]
            if not n:
                return 0, []
            kids = [row[0] for row in dst.execute(
                'SELECT DISTINCT "table" FROM pragma_foreign_key_check')]
            return n, kids
        except sqlite3.DatabaseError as e:
            r.notes.append(f"foreign keys could not be checked: {e}")
            return 0, []

    fk_count, fk_children = fk_state()
    if fk_count and drop_fk:
        # deleting by rowid cannot work here: foreign_key_check reports a NULL
        # rowid for WITHOUT ROWID children, which is most of the agent
        # database. Delete set-wise from the constraint instead.
        for _ in range(100):
            if not fk_count:
                break
            dropped = 0
            dst.execute("BEGIN")
            for child in fk_children:
                for sql in _orphan_deletes(dst, child):
                    try:
                        cur = dst.execute(sql)
                    except sqlite3.DatabaseError as e:
                        r.notes.append(f"{child}: could not delete orphans: {e}")
                    else:
                        # rowcount, not total_changes: triggers would inflate it
                        dropped += max(0, cur.rowcount)
            dst.execute("COMMIT")
            r.fk_dropped += dropped
            fk_count, fk_children = fk_state()
            if not dropped:
                break  # no progress: stop rather than scan forever
    r.fk_violations = fk_count

    dst.execute("BEGIN")
    for _, name, sql in triggers:
        try:
            dst.execute(sql)
        except sqlite3.DatabaseError as e:
            r.schema_failures.append((name, str(e)))
    dst.execute("COMMIT")

    # auto_vacuum cannot be turned on once page 1 exists, so the pragma on the
    # seeded file is a silent no-op; only a VACUUM afterwards applies it, and
    # the app's own "PRAGMA auto_vacuum = FULL" would be a no-op too
    got_av = dst.execute("PRAGMA auto_vacuum").fetchone()[0]
    if got_av != int(auto_vacuum):
        r.notes.append(f"auto_vacuum: source had {int(auto_vacuum)}, "
                       f"repaired copy has {got_av}")

    # counted last, so it reflects deletions and the vacuum
    for t in r.tables:
        try:
            t.final_rows = dst.execute(
                f'SELECT count(*) FROM {q(t.name)}').fetchone()[0]
        except sqlite3.DatabaseError:
            t.final_rows = None
    dst.close()
    src.close()
    return r


def verify_output(enc_path: str, passphrase: bytes, work: str,
                  expected: List[TableResult],
                  schema_failures: List[Tuple[str, str]]) -> List[str]:
    """Read the finished file back the way the app will: decrypt it, check
    every page's HMAC, run SQLite's integrity check, and confirm the row
    counts.

    These are the things that would make the copy untrustworthy. Rows that
    could not be recovered do not belong here: the user's alternative is a
    database that does not open at all, so an incomplete copy is still worth
    delivering, as long as what is missing is stated.
    """
    problems: List[str] = []
    # a constraint that could not be recreated is a silent behaviour change in
    # the app, and integrity_check cannot see a constraint that is not there
    for name, err in schema_failures:
        problems.append(f"{name}: {err}")
    check_plain = os.path.join(work, "verify.plain")
    try:
        bad, tail, _blank, unread = decrypt(enc_path, passphrase, check_plain)
        if unread:
            problems.append(f"{len(unread)} page(s) of the written file could "
                            f"not be read back")
        if bad:
            problems.append(f"{len(bad)} page(s) in the written file fail their "
                            f"HMAC: {bad[:10]}")
        if tail:
            problems.append("the written file has a partial trailing page")
        con = sqlite3.connect(ro_uri(check_plain), uri=True)
        try:
            rows = "\n".join(str(row[0]) for row in
                          con.execute("PRAGMA integrity_check")).splitlines()
            if rows != ["ok"]:
                problems.append("integrity check on the written file: "
                                + "; ".join(rows[:5]))
            for t in expected:
                try:
                    got = con.execute(
                        f'SELECT count(*) FROM {q(t.name)}').fetchone()[0]
                except sqlite3.DatabaseError as e:
                    problems.append(f"{t.name}: unreadable in the written "
                                    f"file ({e})")
                    continue
                expect = t.copied if t.final_rows is None else t.final_rows
                if got != expect:
                    problems.append(f"{t.name}: expected {expect} rows but the "
                                    f"written file holds {got}")
                if t.in_dest is not None and t.in_dest != t.copied:
                    problems.append(f"{t.name}: reported {t.copied} rows "
                                    f"recovered but {t.in_dest} were written")
                if t.source_rows is not None and t.copied > t.source_rows:
                    problems.append(f"{t.name}: recovered {t.copied} rows but "
                                    f"the source holds {t.source_rows}")
        finally:
            con.close()
    except OSError as e:
        if e.errno in (errno.ENOSPC, errno.EFBIG, errno.EDQUOT):
            raise          # the repair may be fine; the disk is not
        problems.append(f"could not read the written file back: {e}")
    except Exception as e:  # noqa: BLE001 - any failure here means "unproven"
        problems.append(f"could not read the written file back: {e}")
    finally:
        if os.path.exists(check_plain):
            os.remove(check_plain)
    return problems


def scan_report(path: str, label: str, passphrase: bytes, work: str
                ) -> Tuple[str, List[int], List[int], bool, bool, int,
                           Optional[int]]:
    proved_by = prove_passphrase(path, passphrase)
    if proved_by is None:
        raise SystemExit(
            f"{label}: no page authenticates with this passphrase.\n"
            f"  Either the passphrase is wrong, this is not a SimpleX "
            f"database, or the damage is far more extensive than a\n"
            f"  few pages. Nothing has been written."
        )
    for sidecar in ("-journal", "-wal"):
        if os.path.exists(path + sidecar):
            print(f"  NOTE: {os.path.basename(path)}{sidecar} exists, so the "
                  f"database was left mid-transaction.\n        SimpleX "
                  f"encrypts that file too, so its contents cannot be applied "
                  f"here.")
    plain = os.path.join(work, f"{label}.plain")
    before = os.stat(path)
    bad, tail, blank, unread = decrypt(path, passphrase, plain)
    after = os.stat(path)
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise SystemExit(
            f"{label} changed while it was being read. Close SimpleX (and any "
            f"other copy of it) first:\n  a database read while it is being "
            f"written looks exactly like failing storage, and the repair would "
            f"be built from a torn snapshot.")
    n_pages = -(-os.path.getsize(path) // PAGE_SIZE)

    print(f"\n{label}  ({CIPHER_NAME}, {n_pages} pages)")
    if proved_by != 1:
        print(f"  NOTE: page 1 is damaged; the passphrase was confirmed "
              f"against page {proved_by}")
    if tail:
        print(f"  NOTE: the file ends mid-page ({tail} trailing bytes) - it "
              f"was truncated, not just corrupted")
    short_by = 0
    header_auto_vacuum = None
    if proved_by == 1:
        with open(plain, "rb") as f:
            head = f.read(100)
        if len(head) >= 96 and head[:16] == b"SQLite format 3\x00":
            # page 1 authenticated, so every field it records is the one
            # SimpleX wrote, even if the file behind it is short
            header_auto_vacuum = (
                1 if struct.unpack_from(">I", head, 52)[0] else 0)
            if (struct.unpack_from(">I", head, 24)[0]
                    == struct.unpack_from(">I", head, 92)[0]):
                short_by = max(0, struct.unpack_from(">I", head, 28)[0] - n_pages)
    if short_by:
        print(f"  NOTE: page 1 records {n_pages + short_by} pages but the file "
              f"holds {n_pages}: it is short by\n        {short_by} page(s), "
              f"so the end of it is missing")
    rebuilt = not openable(plain) and rebuild_header(plain)
    if rebuilt:
        lost = ("" if header_auto_vacuum is not None else
                ", but settings that lived only in that\n        header "
                "(auto_vacuum) could not be recovered")
        print(f"  NOTE: page 1's header was rebuilt from the cipher "
              f"parameters so the file could be\n        opened; the schema "
              f"and data behind it are readable again{lost}")
    if bad:
        print(f"  damaged pages (HMAC failed): {len(bad)} of {n_pages} -> "
              f"{bad[:40]}{' ...' if len(bad) > 40 else ''}")
    else:
        print("  damaged pages (HMAC failed): none - encryption layer intact")
    if unread:
        print(f"  pages this device refused to read: {len(unread)} of "
              f"{n_pages} -> {unread[:40]}{' ...' if len(unread) > 40 else ''}\n"
              f"        The drive returned an error for these, so their "
              f"contents are unknown - they are\n        NOT blank. Stop and "
              f"image the device (ddrescue) before repairing anything.")
    if blank:
        print(f"  pages that are entirely zeros: {len(blank)} of {n_pages} -> "
              f"{blank[:40]}{' ...' if len(blank) > 40 else ''}\n"
              f"        Whatever rows lived there now read as zeros. "
              f"SQLCipher treats a blank page as a\n        short read rather "
              f"than a failure, so they carry no authentication either way.")

    healthy = not bad and not tail and not blank and not unread and not short_by
    con = sqlite3.connect(ro_uri(plain), uri=True)
    con.text_factory = _text_or_bytes
    try:
        rows = "\n".join(str(row[0]) for row in
                          con.execute("PRAGMA integrity_check")).splitlines()
        if rows == ["ok"]:
            print("  structural integrity: ok")
        else:
            healthy = False
            print(f"  structural integrity: {len(rows)} problem(s)")
            for row in rows[:10]:
                print(f"    {row}")
            if len(rows) > 10:
                print(f"    ... and {len(rows) - 10} more")
    except (sqlite3.DatabaseError, UnicodeDecodeError) as e:
        print(f"  structural integrity: unreadable ({e})")
        healthy = False
    con.close()

    if unread:
        print("  => the storage itself is failing: some sectors could not be "
              "read at all")
    elif bad and not (tail and set(bad) <= {n_pages}):
        print("  => the stored bytes were altered after they were written "
              "(a torn write, or failing storage)")
    elif tail or short_by:
        print("  => the bytes that are present are all authentic; the file "
              "was cut short rather than altered")
    else:
        print("  => the stored bytes are all authentic; any problem above "
              "means an older version of a page was left behind (a lost or "
              "reordered write)")
    # zeroed and unreadable pages are decrypted into the salvage copy as
    # zeros, so rows that lived on them come back quietly wrong
    return (plain, bad, sorted(blank + unread), healthy, rebuilt,
            short_by, header_auto_vacuum)


def tables_on_pages(plain: str, pages: List[int]) -> Tuple[Dict[str, int], bool]:
    """Which tables have data on the given pages, via the dbstat virtual
    table. Best effort: dbstat walks the b-trees and can itself fail."""
    hits: Dict[str, int] = {}
    if not pages:
        return hits, True
    try:
        con = sqlite3.connect(ro_uri(plain), uri=True)
        con.text_factory = _text_or_bytes
    except sqlite3.DatabaseError:
        return hits, False
    complete = True
    try:
        wanted = set(pages)
        for name, pageno in con.execute("SELECT name, pageno FROM dbstat"):
            if pageno in wanted:
                key = name.decode() if isinstance(name, bytes) else name
                hits[key] = hits.get(key, 0) + 1
    except (sqlite3.DatabaseError, UnicodeDecodeError):
        complete = False
    finally:
        con.close()
    return hits, complete


def repair_file(path: str, label: str, passphrase: bytes, out_path: str,
                work: str, drop_fk: bool) -> List[str]:
    (plain, bad, suspect, healthy, rebuilt, short_by,
     header_auto_vacuum) = scan_report(path, label, passphrase, work)
    # a lost write is the one diagnosis where every page is authentic AND
    # present; zeroed pages, unreadable pages and a short file are different
    # stories
    stale_page_one = not bad and not suspect and not healthy and not short_by
    clean = os.path.join(work, f"{label}.clean")
    r = salvage(plain, clean, drop_fk, header_rebuilt=rebuilt,
                auto_vacuum_read=header_auto_vacuum, source_healthy=healthy)

    width = max([len(t.name) for t in r.tables] + [20])
    print(f"\n  {'table'.ljust(width)}  {'in file':>10} {'in source':>10} "
          f"{'lost':>8} {'gaps':>6}")
    unknown_source = False
    total_lost = 0
    total_in_file = 0
    empty = []
    for t in r.tables:
        # what the delivered file holds, after any foreign key cleanup - not
        # what the copier inserted before it
        in_file = t.copied if t.final_rows is None else t.final_rows
        total_in_file += in_file
        if (not in_file and not t.lost_rows and not t.skipped_ranges
                and not t.source_rows):
            # a line of zeros for every empty table buries the ones that
            # matter; they are named below instead
            empty.append(t.name)
            if t.source_rows is None:
                unknown_source = True
            continue
        if t.source_rows is None:
            unknown_source = True
            # with no trustworthy source count, any number here would be a
            # guess; a named casualty is a floor, not a total
            src_n = "?"
            lost_n = f">={t.lost_rows}" if t.lost_rows else "?"
        else:
            src_n = str(t.source_rows)
            lost = max(0, t.source_rows - in_file)
            total_lost += lost
            lost_n = str(lost)
        print(f"  {t.name.ljust(width)}  {in_file:>10} {src_n:>10} "
              f"{lost_n:>8} {t.skipped_ranges:>6}")
    total_src = ("?" if unknown_source
                 else str(sum(t.source_rows or 0 for t in r.tables)))
    print(f"  {'TOTAL'.ljust(width)}  {total_in_file:>10} "
          f"{total_src:>10} {('?' if unknown_source else total_lost):>8} "
          f"{sum(t.skipped_ranges for t in r.tables):>6}")
    if empty:
        # A table that was always empty and one whose pages were lost look
        # exactly alike - a reverted root page is a valid empty leaf, and
        # SQLite calls that sound. So name them all rather than count them.
        print(f"\n  {len(empty)} tables hold no rows. A table that was always "
              f"empty and one whose pages\n  were lost look identical here, "
              f"so check any of these you expected to have data:")
        names = sorted(empty)
        for i in range(0, len(names), 4):
            print("    " + ", ".join(names[i:i + 4]))
    if unknown_source:
        print("  ('?' means the source count could not be read because that "
              "table is damaged,\n   so the number of lost rows there is not "
              "knowable - treat it as at least 'gaps')")
    if stale_page_one:
        print("  ('in source' is a lower bound here: the database is "
              "internally inconsistent, so a\n   count taken from it can "
              "itself be short. 'lost' can only be a floor.)")

    if r.fk_dropped:
        print(f"  rows deleted to satisfy foreign keys: {r.fk_dropped}")
    if r.fk_violations:
        print(f"  rows referring to lost parent rows: {r.fk_violations}")
        print("  SimpleX will still open this database - it does not check "
              "foreign keys on opening -\n  but it runs with foreign_keys = "
              "ON, so later operations touching those missing\n  parents will "
              "fail, as will a future migration that rebuilds one of those "
              "tables.")
        if drop_fk:
            print("  they could not be removed automatically: their parent "
                  "tables are gone from the\n  schema, so these rows have to "
                  "be deleted by hand.")
        else:
            print("  re-run with --drop-fk-violations to delete them, which "
                  "removes more than was damaged.")
    for note in r.notes:
        print(f"  note: {note}")
    for loss in r.losses[:20]:
        print(f"  {loss.table}: {brief(loss.what)}: {loss.reason}")
    if len(r.losses) > 20:
        print(f"  ... and {len(r.losses) - 20} more")

    doubtful = sorted(set(bad) | set(suspect))
    if doubtful:
        # a page that failed its HMAC still decrypts to something, and a page
        # that reads as zeros decrypts to zeros; rows on either come back
        # quietly wrong in ways no integrity check sees
        hit, complete = tables_on_pages(plain, doubtful)
        what = ("failed authentication" if not suspect else
                "failed authentication or could not be read")
        print(f"\n  WARNING: {len(doubtful)} page(s) {what}. Rows read from "
              f"them come back with\n  plausible but altered values - no "
              f"integrity check can detect that, so treat the\n  following as "
              f"untrustworthy and compare against your own memory:")
        if hit:
            for name in sorted(hit, key=lambda n: -hit[n]):
                print(f"    {name}: {hit[name]} damaged page(s)")
            if not complete or sum(hit.values()) < len(doubtful):
                print(f"    (this list is incomplete: {len(doubtful)} pages are "
                      f"damaged but only {sum(hit.values())} could be "
                      f"attributed)")
        else:
            print("    (could not map the damaged pages to tables)")

    encrypt(clean, out_path, passphrase)
    if r.incomplete:
        print("\n  INCOMPLETE - these tables were not read in full:")
        for name, why in r.incomplete:
            print(f"    {name}: {why}")
        print("  The rows above are what could be reached. Compare the "
              "counts against what you\n  expect before you rely on this copy.")

    problems = verify_output(out_path, passphrase, work, r.tables,
                             r.schema_failures)
    if problems:
        print("\n  VERIFICATION FAILED - do not trust this file:")
        for problem in problems:
            print(f"    {problem}")
    else:
        print("\n  verified: the written file decrypts, every page "
              "authenticates, SQLite\n  reports it sound, and it holds the "
              "row counts this run produced.")
        if doubtful:
            print("  That confirms the copy was written correctly. It does "
                  "NOT vouch for the\n  values recovered from the damaged "
                  "pages listed above.")
        if stale_page_one:
            print("  Every page authenticated but the database was still "
                  "inconsistent, so an older\n  version of at least one page "
                  "survived. Rows on the pages it used to point at\n  are "
                  "unreachable and may not be counted above, and columns added "
                  "by a recent\n  app update can be missing. Compare a recent "
                  "conversation against your memory\n  before trusting this "
                  "copy, and keep the original either way.")
    return problems


def read_passphrase(args) -> bytes:
    if args.passphrase is not None:
        # fsencode, not encode: a passphrase typed in a legacy-encoded
        # terminal arrives in argv with surrogates
        return os.fsencode(args.passphrase)
    return os.fsencode(getpass.getpass("database passphrase: "))


EXIT_OK = 0
EXIT_UNVERIFIED = 1     # a repair ran, the result must not be trusted
EXIT_USAGE = 2          # bad arguments or unusable paths
EXIT_UNREADABLE = 3     # wrong passphrase, not a database, nothing to salvage
EXIT_INTERNAL = 4       # a bug in this script
EXIT_INTERRUPTED = 130


def no_room(exc: BaseException, where: str) -> int:
    print(f"\nran out of room in {where}: {exc}\n"
          f"This needs about four working copies of the database. "
          f"Use --work-dir to point somewhere with more space.",
          file=sys.stderr)
    return EXIT_USAGE


def out_of_room(exc: BaseException, where: str) -> bool:
    """Whether a failure is really the disk filling up.

    SQLite's message for this changes depending on where it surfaces - a
    swallowed SQLITE_FULL turns into "cannot commit - no transaction is
    active" - so ask the filesystem rather than reading the text.
    """
    if getattr(exc, "errno", None) in (errno.ENOSPC, errno.EFBIG, errno.EDQUOT):
        return True
    if getattr(exc, "sqlite_errorcode", 0) in (13, 10):   # SQLITE_FULL, IOERR
        return True
    text = str(exc)
    if "disk is full" in text or "disk I/O error" in text:
        return True
    try:
        return shutil.disk_usage(where).free < (4 << 20)
    except OSError:
        return False


def preflight_output(path: str) -> Optional[str]:
    """Check the destination before hours of work, not after."""
    for candidate in (path, path + ".unverified"):
        if os.path.exists(candidate):
            return f"{candidate} already exists - refusing to overwrite it"
    parent = os.path.dirname(os.path.abspath(path)) or "."
    if not os.path.isdir(parent):
        return f"{parent} is not a directory"
    if not os.access(parent, os.W_OK):
        return f"{parent} is not writable"
    return None


def readable(path: str) -> bool:
    """Whether the file can actually be read end to end."""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            for offset in (0, max(0, size - (1 << 16))):
                f.seek(offset)
                f.read(1 << 16)
        return True
    except OSError:
        return False


def open_archive(path: str):
    try:
        return zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as e:
        if isinstance(e, OSError) or not readable(path):
            raise SystemExit(
                f"{path} could not be read ({e}).\n  This is the storage, not "
                f"the archive. Copy it elsewhere - with ddrescue if the drive "
                f"is failing - and try again.")
        raise SystemExit(
            f"{path} looks like an archive but its index is damaged ({e}).\n"
            f"  The zip itself is broken, not the databases inside it. Try "
            f"exporting again from the app,\n  or repair the zip first."
        )


def run(args, passphrase: bytes, work: str) -> int:
    """Do the work inside the temp directory; nothing lands at the user's
    output path until it has been verified."""
    problems: List[str] = []
    looks_zip = zipfile.is_zipfile(args.target)
    if not looks_zip and args.target.lower().endswith(".zip"):
        open_archive(args.target)  # raises with a useful message

    if not looks_zip:
        label = os.path.basename(args.target) or "database"
        if args.action == "diagnose":
            _, _, _, healthy, *_ = scan_report(args.target, label,
                                               passphrase, work)
            return EXIT_OK if healthy else EXIT_UNVERIFIED
        staged = os.path.join(work, "repaired.db")
        problems = repair_file(args.target, label, passphrase, staged, work,
                               args.drop_fk_violations)
        return deliver(staged, args.output, problems)

    with open_archive(args.target) as z:
        names = set(z.namelist())
        missing = [d for d in ARCHIVE_DBS if d not in names]
        if missing:
            print(f"{args.target} is missing {', '.join(missing)} - this does "
                  f"not look like a SimpleX export", file=sys.stderr)
            return EXIT_USAGE
        for db in ARCHIVE_DBS:
            info = z.getinfo(db)
            if info.file_size > MAX_DB_BYTES:
                print(f"{db} in the archive claims to be "
                      f"{info.file_size / 1e9:.1f} GB - refusing to unpack it",
                      file=sys.stderr)
                return EXIT_USAGE
            try:
                z.extract(db, work)
            except (OSError, zipfile.BadZipFile) as e:
                if getattr(e, "errno", None) in (
                        errno.ENOSPC, errno.EFBIG, errno.EDQUOT, errno.EIO,
                        errno.ENODEV, errno.ENXIO, errno.ESTALE):
                    raise      # the archive is fine; the device is not
                raise SystemExit(
                    f"{db} could not be unpacked from {args.target} ({e}).\n"
                    f"  The zip itself is damaged, not necessarily the "
                    f"databases inside it. Try exporting again from the app.")

    healthy = True
    repaired = {}
    for db in ARCHIVE_DBS:
        src = os.path.join(work, db)
        if args.action == "diagnose":
            _, _, _, ok, *_ = scan_report(src, db, passphrase, work)
            healthy = healthy and ok
        else:
            dst = os.path.join(work, db + ".repaired")
            problems += repair_file(src, db, passphrase, dst, work,
                                    args.drop_fk_violations)
            repaired[db] = dst
    if args.action == "diagnose":
        return EXIT_OK if healthy else EXIT_UNVERIFIED

    staged = os.path.join(work, "repaired.zip")
    with open_archive(args.target) as zin, \
         zipfile.ZipFile(staged, "w", zipfile.ZIP_DEFLATED) as zout:
        zout.comment = zin.comment
        for item in zin.infolist():
            # the entry is rebuilt from the original, so timestamps, modes and
            # directory entries survive the round trip
            info = zipfile.ZipInfo(item.filename, date_time=item.date_time)
            info.external_attr = item.external_attr
            info.internal_attr = item.internal_attr
            info.create_system = item.create_system
            info.comment = item.comment
            info.compress_type = item.compress_type
            if item.is_dir():
                zout.writestr(info, b"")
            elif item.filename in repaired:
                with open(repaired[item.filename], "rb") as fin, \
                     zout.open(info, "w") as fout:
                    shutil.copyfileobj(fin, fout, 1 << 20)
            else:
                with zin.open(item) as fin, zout.open(info, "w") as fout:
                    shutil.copyfileobj(fin, fout, 1 << 20)
    return deliver(staged, args.output, problems)


def place(staged: str, final: str) -> None:
    """Put the finished file at `final` without ever leaving a partial one
    there. shutil.move across filesystems is a plain copy, so a full disk
    would otherwise leave a truncated database exactly where the user was
    told to expect the repaired one."""
    part = f"{final}.{os.getpid()}.part"
    try:
        shutil.move(staged, part)
        os.replace(part, final)
    except BaseException:
        if os.path.exists(part):
            os.remove(part)
        raise


def deliver(staged: str, out_path: str, problems: List[str]) -> int:
    """Move the finished file into place, or set it aside if it is suspect."""
    if problems:
        quarantine = out_path + ".unverified"
        place(staged, quarantine)
        print(f"\nThe repaired copy did NOT verify, so it was set aside as"
              f"\n  {quarantine}\nKeep your original file and do not import "
              f"the unverified one.")
        return EXIT_UNVERIFIED
    place(staged, out_path)
    print(f"\nwrote {out_path}")
    print("Keep your original file until the repaired copy has opened in the "
          "app and you have checked your messages.")
    print("Import it in the app, then set the same passphrase.")
    return EXIT_OK


def _die_on_signal(signum, _frame):
    raise KeyboardInterrupt(f"signal {signum}")


def main() -> int:
    for sig in (signal.SIGTERM, getattr(signal, "SIGHUP", signal.SIGTERM)):
        try:
            signal.signal(sig, _die_on_signal)
        except (ValueError, AttributeError, OSError):
            pass
    ap = argparse.ArgumentParser(
        description="diagnose and repair a corrupted SimpleX Chat database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("action", choices=("diagnose", "repair"))
    ap.add_argument("target", help="an exported archive (.zip) or a database file")
    ap.add_argument("output", nargs="?", help="where to write the repaired copy")
    ap.add_argument("--passphrase", help="passphrase, for scripting")
    ap.add_argument("--drop-fk-violations", action="store_true",
                    help="delete rows whose parent rows were lost")
    ap.add_argument("--work-dir", help="where to put the temporary copies "
                                       "(needs about 4x the database size; "
                                       "defaults to beside the output)")
    ap.add_argument("--debug", action="store_true",
                    help="show the full traceback if this script fails")
    args = ap.parse_args()

    if args.action == "repair" and not args.output:
        ap.error("repair needs an output path")
    if args.action == "diagnose" and args.output:
        ap.error("diagnose does not take an output path")
    if not os.path.exists(args.target):
        return fail(f"{args.target} does not exist")
    if os.path.isdir(args.target):
        return fail(f"{args.target} is a directory - give the archive or the "
                    f"database file itself")
    if not os.path.isfile(args.target):
        return fail(f"{args.target} is not a regular file")
    if args.output:
        problem = preflight_output(args.output)
        if problem:
            return fail(problem)

    # default the scratch space to the directory the user chose for the
    # result: it is the one place they have already shown has room, whereas
    # TMPDIR is often a small root filesystem
    work_parent = args.work_dir or os.path.dirname(
        os.path.abspath(args.output or args.target)) or "."
    if not os.path.isdir(work_parent):
        return fail(f"{work_parent} is not a directory")
    if not os.access(work_parent, os.W_OK):
        return fail(f"{work_parent} is not writable")
    try:
        passphrase = read_passphrase(args)
    except OSError as e:
        return fail(f"could not read the passphrase: {e}")

    try:
        work = tempfile.mkdtemp(prefix="simplex-repair.", dir=work_parent)
    except OSError as e:
        return fail(f"could not create a working directory in {work_parent}: "
                    f"{e}")
    # a release valve: handling MemoryError needs memory of its own, and the
    # allocation that fails is often the handler's own message
    reserve = bytearray(16 << 20)
    try:
        return run(args, passphrase, work)
    except Unsalvageable as e:
        print(f"\n{e}", file=sys.stderr)
        return EXIT_UNREADABLE
    except SystemExit as e:
        print(e.code, file=sys.stderr)
        return EXIT_UNREADABLE
    except KeyboardInterrupt:
        print("\ninterrupted - nothing was written to the output path",
              file=sys.stderr)
        return EXIT_INTERRUPTED
    except OSError as e:
        if e.errno in (errno.ENOSPC, errno.EFBIG, errno.EDQUOT):
            return no_room(e, work_parent)
        if e.errno in (errno.EIO, errno.EACCES, errno.EPERM, errno.ENOENT,
                       errno.EROFS, errno.ESTALE, errno.ENODEV, errno.ENXIO):
            print(f"\nthe filesystem refused an operation: {e}\n"
                  f"This is your storage, not a fault in this script. Your "
                  f"input file has not been changed.", file=sys.stderr)
            return EXIT_USAGE
        print(f"\nfailed while reading or writing: {e}", file=sys.stderr)
        return EXIT_INTERNAL
    except (MemoryError, SystemError) as e:
        del reserve
        print(f"\nran out of memory reading this database: {e}\n"
              f"Its schema is damaged in a way that makes SQLite ask for far "
              f"more memory than the file could hold.\n  Your input file has "
              f"not been changed.", file=sys.stderr)
        return EXIT_UNREADABLE
    except Exception as e:  # noqa: BLE001
        # SQLite swallows SQLITE_FULL in places and reports it as something
        # else, so a full disk arrives here rather than as an OSError
        if isinstance(e, sqlite3.OperationalError) and out_of_room(e, work_parent):
            return no_room(e, work_parent)
        if args.debug:
            raise
        print(f"\nthis script hit a bug: {type(e).__name__}: {e}\n"
              f"Your input file has not been changed. Re-run with --debug for "
              f"the full traceback.", file=sys.stderr)
        return EXIT_INTERNAL
    finally:
        try:
            shutil.rmtree(work, ignore_errors=True)
            if os.path.exists(work):
                print(f"\ncould not remove {work} - it holds DECRYPTED "
                      f"copies of your database; delete it yourself",
                      file=sys.stderr)
        except BaseException:
            pass  # cleanup must never be what kills the run


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
