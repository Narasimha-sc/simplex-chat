# Forwarding in large groups holds the chat database for seconds (SQLite)

## Problem

In a group without relays, an admin forwards each message from a member to the members that the admin introduced to the sender and that have not confirmed the connection yet. On SQLite, every forwarded message loaded those recipients with one query per recipient, all in one transaction on the single chat database connection. Every other database operation of the app waited until it finished: opening chats, sending, receiving.

Measured on a copy of a 40,005-member group, SQLCipher 4 / SQLite 3.39.2 as bundled with the app, desktop x86-64 CPU, warm cache, median of 5 runs:

| recipients by index | per-member queries (before) | one query (after) |
|---|---|---|
| 100 | 14 ms | 1.3 ms |
| 1,000 | 199 ms | 52 ms |
| 5,000 | 799 ms | 124 ms |
| 20,000 | 2,973 ms | 263 ms |

Messages in member support chats (`DJSMemberSupport`) used the same loop with a role filter in the query:

| recipients by index | before | after |
|---|---|---|
| 100 | 15 ms | 0.3 ms |
| 1,000 | 177 ms | 17 ms |
| 5,000 | 798 ms | 35 ms |
| 20,000 | 3,069 ms | 54 ms |

These numbers are for the SQL statements only. Decoding the returned rows in Haskell happens before and after the change and was not measured. Phones are slower than this desktop CPU.

## Cause

`runDeliveryJobWorker` (Subscriber.hs), branch for groups without relays: `buildMemberList` reads the sender's relations vector, takes the indexes with `MRIntroduced` (`getRelationsIndexes`), and passes them to `getGroupMembersByIndexes` or, for a support scope, `getSupportScopeMembersByIndexes`. On Postgres both use one `index_in_group IN ?` query. On SQLite both ran `mapM` over the indexes with `getGroupMemberByIndex` / `getSupportScopeMemberByIndex`, one `groupMemberQuery` each, inside one `withStore'`.

Each of those queries uses the unique index `(group_id, index_in_group)`, so an index does not make them cheaper. The cost is their number. A statement prepared once and reset for every index costs 53 ms instead of 199 ms for 1,000 indexes, and 299 ms instead of 2,973 ms for 20,000, so 73–90% of the time went to preparing the same 90-column, 4-table statement again for every member.

## Fix

The SQLite branch runs the same predicate as Postgres in one statement, with the indexes passed as one JSON array:

```sql
WHERE m.group_id = ? AND m.index_in_group IN (SELECT value FROM json_each(?))
```

`encodeJSON` encodes the `[Int64]` list. The plan is unchanged for the member table (`SEARCH m USING INDEX idx_group_members_group_id_index_in_group`), with the list as an `IN` subquery. `getGroupMemberByIndex` and `getSupportScopeMemberByIndex` have no other callers and are removed. `chat_query_plans.txt` changes accordingly.

Same members returned:

- An index with no member: before, the query returned no row and `rights` dropped the error; after, no row is returned.
- Removed, left and pending members, and the user's own row: returned by both forms, because neither filters on status or contact. The caller filters by `memberCurrent` / `memberCurrentOrPending` and by `readyMemberConn` as before.
- Duplicate indexes: the old loop would return the member twice, `IN` returns it once. `getRelationsIndexes` lists each vector position once, so the list has no duplicates.
- Empty list: no rows in both forms. `buildMemberList` returns `[]` for an empty list without calling the store functions, so it costs no query on either database (the old SQLite `mapM` over `[]` ran none either, and the list is usually empty once members are connected). The store functions themselves still run the query for an empty list.
- Order: before, ascending index order. After, the same on SQLite (the `IN` list is read in sorted order). On Postgres the order was and is unspecified. No caller depends on it: `deliver` sends the body with the first connection in the list and references it for the rest, whatever the order.

Alternatives considered:

- `index_in_group IN (?,?,…)` with one placeholder per index, in chunks below `SQLITE_MAX_VARIABLE_NUMBER` (32,766 in the bundled SQLite): same speed (124 ms for 5,000 in chunks of 500 or in one chunk). But the query text then depends on the list length. `DB.query` records statistics per query text, and the test suite writes every executed query text into `chat_query_plans.txt`, so each list length would add an entry.
- A fixed-size `IN (?,…,?)` padded with `NULL` up to a constant number of placeholders (repeated in chunks for longer lists): the query text stays constant and no JSON functions are needed, but it needs more code (padding and chunking) than `json_each`.
- Keeping one query per index with a statement prepared once (`per-member, statement reused` in the measurements): about the same speed as one query, but it needs the low-level statement API, which no other store function uses, and it would not go through `DB.query` statistics.
- For support scopes, loading moderators with `getGroupModerators` and keeping those whose index is in the introduced set: 0.6 ms with the unmerged `member_role` index (`idx_group_members_user_id_member_role`), 42 ms without it, at any number of indexes. It changes the delivery worker instead of the store function, needs the scope member loaded separately and de-duplicated, and depends on an index that is not merged. Left as a possible follow-up.
- Filtering by member status or connection in SQL: fewer rows, but the same number of statements unless combined with the change above. The caller's filters already do this in memory.

## Measurements

Harness: a C program linked with the SQLCipher 4 object built from the same `direct-sqlcipher` sources (SQLite 3.39.2). It opens the database with the app's pragmas and runs each strategy 6 times inside `BEGIN IMMEDIATE` … `COMMIT`. The first run is dropped and the median of the other 5 is reported. Each statement selects the full `groupMemberQuery` column list with its joins. Each per-member query is prepared, bound, stepped and finalized, as `sqlite-simple` does.

Database: a copy of a desktop profile with a group of 40,005 members (40,000 filler members). Each filler was given a ready member connection, and 30 random fillers were made moderators or admins. No `ANALYZE` (the app does not run it). The index sets are random, ascending, and drawn from the filler indexes.

| strategy | 100 | 1,000 | 5,000 | 20,000 |
|---|---|---|---|---|
| per-member query (before) | 14.3 | 199.4 | 798.6 | 2,973.4 |
| per-member, statement reused | 1.4 | 53.3 | 128.8 | 298.7 |
| `IN (?,…)` chunks of 500 | 1.3 | 51.6 | 124.7 | 277.8 |
| `IN (?,…)` one chunk | 1.4 | 50.3 | 126.8 | 271.4 |
| `json_each` (after) | 1.3 | 51.9 | 123.3 | 263.1 |
| support, per-member (before) | 15.0 | 176.6 | 798.4 | 3,068.9 |
| support, `json_each` (after) | 0.3 | 16.6 | 34.8 | 53.5 |
| support, moderators + intersection, with `member_role` index | 0.6 | 0.6 | 0.6 | 0.6 |
| support, moderators + intersection, without it | 41.9 | 44.0 | 43.2 | 41.4 |

All values are in ms.

The support-scope timings measure the lookup with almost no rows returned: the scope member id was never in the random index sets, so only the moderators that happened to be drawn were fetched. They are not a measure of row fetching.

## Open questions

- Groups with relays (`useRelays'`), on SQLite: `getGroupMembersByCursor` loads every recipient with a separate `getGroupMemberById` query, 10,000 (`deliveryBucketSize`) per transaction. One such transaction took 1.5 s on the same copy. Relays may run on Postgres, where this is one query.
- Support scopes in groups with relays call `getGroupModerators` for every message. Without the `member_role` index this scans all members of the group: 42 ms at 40,000 members.
- `SEGroupMemberNotFoundByIndex` is no longer produced. It is kept because `StoreError` is part of the API encoding.
