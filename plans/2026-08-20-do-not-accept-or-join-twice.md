# Accepting an invitation twice

Two unrelated failures with the same shape - a second accept or join reaching the core - plus the
client state that let users produce them.

## Problem

### Contact request

Accepting a contact request that was already accepted fails with an agent error:

```
Error accepting contact request:
error agent: error agent CMD PROHIBITED SEInvitationNotFound acceptContact, invitationId = "..."
```

Reported after accepting from a notification and then, while the request still looked pending,
opening the chat and accepting again. The first accept completed normally, so the contact connected
regardless — the second accept only produced the error.

### Group

Joining a group via a link twice fails with a raw SQLite error, reported far more often:

```
chat db error: SEDBException {message = "SQLite3 returned ErrorConstraint while attempting to
perform step: UNIQUE constraint failed: group_members.group_id, group_members.member_id"}
```

The user does not have to tap twice. Joining a channel whose relays are unreachable throws a
`BROKER` error, the client offers Retry, and the retry re-sends the same command - see fix 2.
Connecting twice on a group link that is not relayed fails the same way on
`connections.group_member_id`.

## Cause

`acceptContactRequest` (`Library/Internal.hs`) unconditionally ends with the agent call, using the
invitation id stored on the request:

```haskell
(ct,conn,) <$> withAgent (\a -> acceptContact a nm (aUserId user) (aConnId conn) True invId dm pqSup' subMode)
```

Its `Just conn` branch already recognises that the contact has a connection and skips creating one,
but still calls the agent with the invitation the first accept consumed.

Nothing marks the request as accepted at the chat level:

- `deleteContactRequestRec` was removed from the accept path by `cc643e5ae`
  ("core: rework contact requests so that they are always created with entity", #6011), so the
  `contact_requests` row now survives acceptance;
- `deleteContactRequest` is called only from `APIRejectContact`;
- `createContactFromRequest` only sets `contact_requests.contact_id`;
- there is no accepted flag on the table.

So a repeat accept passes every chat-side check and reaches the agent. Before #6011 it failed early
with `SEContactRequestNotFound`.

On the client, nothing recorded that an accept was under way. The only in-progress state was private
to `ComposeContextContactRequestActionsView` — a `rememberSaveable` flag that is additionally reset
on chat change — while the notification action and the chat list menu passed none. Opening the chat
after accepting from a notification therefore composed a fresh, fully enabled Accept button.

## Fix

**1. Core: report an invitation the agent already used** (`Library/Internal.hs`).

The chat layer cannot tell an accepted request from an accept that failed. `acceptContactRequest`
commits the contact connection with status `ConnNew` (`createAcceptedContactConn`) and only then
calls `acceptContact`, so a connection existing means the accept was *attempted*; and nothing
advances `ConnNew` on success either - it stays `ConnNew` until the peer's `CONF` arrives. A guard
on the connection would reject retrying an accept that failed, which
`retry connecting via contact link` covers.

The agent can tell, because it owns the invitation and flips the flag in the right order
(`acceptContact'`):

```haskell
Invitation {connReq} <- withStore c $ \db -> getInvitation db "acceptContact'" invId  -- WHERE accepted = 0
r <- joinConn c nm userId connId enableNtfs connReq ownConnInfo pqSupport subMode      -- fallible
withStore' c $ \db -> acceptInvitation db invId ownConnInfo                            -- accepted = 1
```

So `SEInvitationNotFound` from `acceptContact` means the request was accepted, and a join that
failed leaves `accepted = 0` for the retry to find. The error it surfaces as - `CMD PROHIBITED`,
mapped in `Agent/Client.hs` - is translated to a chat command error instead of reaching the user as
`error agent CMD PROHIBITED SEInvitationNotFound acceptContact, invitationId = "..."`. Within
`acceptContact'` that is the only source of `CMD PROHIBITED`: every other one in the agent belongs
to a command not reachable from here, and `joinConn` fails with `BROKER` or `SMP`.

`throwCmdError` is used rather than a new `ChatErrorType` constructor: it matches the other command
preconditions in this handler and avoids fanning a new error type through Kotlin, Swift, the
TypeScript/python SDKs and the generated bot docs. A structured, localizable error can replace it
later if wanted.

**2. Core: joining a prepared group is idempotent** (`Library/Commands.hs`, `Store/Groups.hs`).

This is a different failure from the contact request one, and it is the one behind the reports of a
duplicate SQL error for groups. `APIConnectPreparedGroup` creates the link owner members inside
`withFastStore` **before** the relay loop, and throws when every relay fails. That error is an agent
`BROKER` error, which `retryableNetworkErrorAlert` matches, so the client offers Retry and
`sendCmdWithRetry` re-sends the identical command — which re-inserted the same owner members:

```
UNIQUE constraint failed: group_members.group_id, group_members.member_id
```

`createLinkOwnerMember` is now reached through `getCreateLinkOwnerMember`, matching
`getCreateRelayForMember` in the same module, whose comment already says "Save relayLink to re-use
relay member record on retry". The relay loop and the direct join were already retry-safe:
`joinContact` advances the connection past `ConnPrepared` only after the agent call returns, so a
join that failed is resumed by the `ConnPrepared -> joinPreparedConn'` branch rather than repeated.
Owner member creation was the only step in the command that was not.

Reaching that branch with a connection **past** `ConnPrepared` therefore means the join already
succeeded, and `connect'` would create a second connection for the same member:

```
UNIQUE constraint failed: connections.group_member_id
```

That is now `throwCmdError "group is already being joined"`, replacing a `connect'` call the code
itself questioned (`-- why not "already connected" for host member?`). It cannot be reached by a
retry, only by connecting again after the first connect succeeded. Two connects via a group link
that is not relayed, sent at once, usually do not reach it (see "Not covered"); fix 5 stops the
Android and desktop composer from sending them on a double click.

**3. Client: do not offer to accept or join while accepting or joining** (android, desktop, ios).

An invitation being accepted is a fact about the invitation, not about the view that shows it, but
every view kept its own flag: `ComposeContextContactRequestActionsView` a `rememberSaveable`,
`CIGroupInvitationView` a `remember`, `ChatListNavLinkView` a third that was threaded as a
`MutableState<Boolean>` parameter through `groupChatAction` → `acceptGroupInvitationAlertDialog` and
through `GroupMenuItems` → `JoinGroupAction`, and the notification action, `ContactRequestMenuItems`
and the chat list row's `contactRequestAlertDialog` none at all.
So the chat list Join and the in-chat "tap to join" for the same group could not see each other, and
accepting from a notification left the in-chat banner fully enabled.

`ChatModel.acceptingContactRequests` and `ChatModel.joiningGroups` now hold the ids, keyed by
contact request id and group id — not by chat id, because the same request appears under
`ChatInfo.ContactRequest` (`<@N`) in the chat list and under `ChatInfo.Direct` (`@N`) in the chat,
and those two views must agree. They are maintained by the shared `acceptContactRequest` and by a
new shared `joinGroup`, so every caller participates without changing its call site and a failed
accept re-enables the buttons. The views this change covers derive from the record instead of owning
a flag, which deletes the parameter chain, the per-view flags and the `KeyChangeEffect` that existed
only to reset them on chat change. The contacts list is not covered - see "Not covered".

On Android and desktop the id is recorded before the request is sent rather than inside the
background coroutine, and `acceptContactRequest` and `joinGroup` return when their id is already
recorded. The handlers that start the accept or join do not check the record before calling them -
the views stop showing the action only when they are recomposed - so, without these returns, a
double click on the banner, the chat list menu, the invitation alert or the chat item sent the
accept or join twice, and the second failed with `contact request already accepted` or
`groupAlreadyJoined`. `groupChatAction` also opens the "Join group?" alert only when no alert is
shown: two clicks on the chat list row handled before the alert was drawn opened two alerts, one
over the other, and confirming the second failed with `groupAlreadyJoined`.

The chat list long-press menu offers no Accept while an accept is in flight, matching what
`GroupMenuItems` already did for Join. Reject stays, so the menu is never empty.

**4. Client: the connect composer does not render in a group's support scope** (`ComposeView.kt`).

`ChatView` owns its `composeState`, and `MemberSupportChatView` opens a second `ChatView` for the
same group in `ModalManager.end`. In the desktop two-pane layout both composers are visible at once,
and the condition at `ComposeView.kt` had no scope check, so a prepared group showed two independent
Join buttons. The connect composer belongs to the chat itself, not to a scope within it.

**5. Client: a second click on the connect composer is ignored** (`ComposeView.kt`).

`connectPreparedGroup` and `sendConnectPreparedContact` return when `composeState.value.inProgress` is
true. Each click handler launches a coroutine on the main thread (`withApi`), and the first sets
`inProgress` before its first suspension point, so the second call returns at the check - without
this, "Join group" on
a group link sent the connect twice (`UNIQUE constraint failed: connections.group_member_id`, or the
host received a second join request), and "Connect" on a one-time link failed with
`connection is not RcvDirectMsgConnection: ...`. On a contact address, the composer's Connect and send
buttons open the "Send contact request?" alert only when no alert is shown: a double click opened two
alerts, one over the other, and confirming the second ran the connect again, which returned
`contactAlreadyExists`, shown as a connection error.

**6. Client: the progress indicator appears after 0.5s instead of 1s** (android, desktop, ios).

Accepting a request or joining a group usually takes longer than 1s, so the button looked inert for
a second before anything acknowledged the tap - which is what prompts a second tap. The threshold is
per view; extracting the effect the views share was considered and left out, to keep the change to
the timing.

## Alternatives considered and rejected

**Guarding the accept on the contact connection** (reject when the contact reached via a request
already has a connection that is not `ConnPrepared`). This was the first shape of the fix and it is
wrong: the connection is committed before the agent call that can fail, so the guard also rejects
retrying an accept that failed with a network error, which `retry connecting via contact link`
exercises. Nothing on the connection distinguishes the two - a successful accept leaves it at
`ConnNew` as well. The same mistake produced the group half of this plan.


**Reordering the notification action to accept before switching profile.** Would have removed the
window in the cross-profile case entirely, since during the accept the user is still on the other
profile where the request is not displayed. Rejected: it requires `APIAcceptContact` to work for a
non-active user (reverted in #5978, see PR #7316), it delays the visible profile switch by the
accept round trip, and it does nothing for the active-profile case that the in-flight guard covers
anyway.

**Fixing `nextAcceptContactRequest` so the button disappears when the accept lands.** The predicate
treats `connStatus == New` as "not yet accepted", but a non-`sqSecured` accept leaves the connection
at `ConnNew` until the peer's `CONF` arrives, so the button can stay offered after a fully
successful accept. Deferred, not rejected: the window requires a peer whose invitation cannot be
secured immediately (`sendWelcomeMsg` only runs when `sqSecured`, and in the added test the contact
is ready the moment the accept returns), while the change spans Kotlin and Swift, ~8 read sites per
platform, and is shared with the group direct invitation flow whose pre-accept connection state
would need verifying first.

**Blocking the UI for the duration of the accept** (holding the switch-user progress overlay across
the accept). Rejected: it makes a full-screen, input-blocking spinner depend on a network round
trip.

## Not covered

**`sendCmdWithRetry` re-sends the command.** On a retryable `BROKER` error it shows a Retry alert and
re-issues the same command (`SimpleXAPI.kt`). `apiAcceptContactRequest`, `apiJoinGroup` and
`apiAcceptMemberContact` pass no `inProgress`, unlike `apiConnectPlan`, so a retry can re-send an
accept whose first attempt may have partially landed. No button is involved, so nothing in this
change addresses it.

**iOS has the double-click gaps that the early returns in fixes 3 and 5 close on Android and
desktop** - `acceptContactRequest` and `joinGroup` do not return when the id is already recorded,
`acceptContactRequest` records it only inside `await MainActor.run`, and the connect composer sets
`inProgress` inside its `Task`. This change leaves them as they are; it was not built or tested on
iOS.

**Two connects of a prepared group via a link that is not relayed, or of a contact via its address,
that reach the core at once** can both pass its checks: `APIConnectPreparedGroup` and
`APIConnectPreparedContact` read the host member or the contact before `withInvitationLock` is
taken. For a channel the second connect fails with `group is already being joined`. The Android and desktop apps no longer send
them on a double click, but iOS (see above), the CLI, bots and other clients can; a core change that
runs the whole command under the lock is left for a separate change.

**An id can stay recorded until the app restarts.** `sendCmdWithRetry` waits for its Retry alert to
be answered; when the alert is removed without an answer - `hideAllAlerts` after a critical or
internal agent error, on a remote host switch or on self-destruct, or a `hideAlert` that removes the
top alert - `sendCmdWithRetry` never returns, so the `finally` in `acceptContactRequest` or
`joinGroup` never runs, and that request or group stays
recorded: its Accept or Join is not offered again, and where it still is (the contacts list, the
notification action) `acceptContactRequest` returns without accepting. Removing an alert this way
was not reproduced in testing (locking the app did not leave an id recorded).

**Other alerts and sends with the same double-click shape are not guarded**: the chat list contact
request row's `contactRequestAlertDialog`, the banner's `showAcceptRequestAlert` when the address
has no short link data, and `sendMemberContactInvitation`. In testing the contact request row opened
the chat rather than an alert, and an address without short link data could not be created, so
neither was reproduced; `sendMemberContactInvitation` was not tested.

**`acceptMemberContact` and `apiAcceptMember`** keep their per-view flags; they are the same shape
but were left out of scope.

**The contacts list still offers Accept while an accept is in flight** - `ContactListNavView.kt`
opens `contactRequestAlertDialog` without checking, and `ContactListNavLink.swift` has its own
buttons rather than the ones this change gates. It is the same defect in one more view on each
platform, left out to keep the change small; its Accept does nothing while an accept is in flight,
because `acceptContactRequest` returns, and after the accept completed it fails with the error from
fix 1 rather than the agent error. The contacts list is a sheet, so the other views are not tappable
behind it.

## Testing

- `connecting to channel twice fails` (`tests/ChatTests/Groups.hs`) and `prepare group and connect
  twice` (`tests/ChatTests/Profiles.hs`): join, then `/_connect group #1` again and expect
  `bad chat command: group is already being joined`, then exchange messages to show the connection
  from the first join is intact. Both reproduce the reported SQL errors without the fix — the
  channel test fails on `group_members.group_id, group_members.member_id` (owner members) and the
  direct one on `connections.group_member_id` — and both reach the new guard only because owner
  member creation became idempotent.
- `retry connecting to group via short link` and the rest of the `short links` group (34 examples)
  pass unchanged, which is what shows a real retry after a connection failure still completes.
- `accepting contact request twice fails` (`tests/ChatTests/Profiles.hs`): accept, wait for the
  contact to connect, then `/_accept 1` again and expect
  `bad chat command: contact request already accepted`, then exchange messages to show the
  connection established by the first accept is intact. The expected string exists only in the guard
  and the test, so the test cannot pass without the fix.
- `cabal build lib:simplex-chat` and `:common:compileKotlinDesktop` build clean.
- The in-flight state is not covered by an automated test — it is UI state, reached by a double click
  or by two views of the same invitation open at once; the double-click cases were tested by hand in
  the desktop app.

### Manual check

1. Receive a contact request. Open the chat and the chat list side by side (desktop). Accept from
   the chat list menu — the composer banner greys out at the same moment, and the menu stops
   offering Accept.
2. Accept a contact request from a notification, then open the chat: the banner is already greyed,
   where before it was fully enabled.
3. Receive a group invitation. Open the direct chat with the inviter and the chat list side by side.
   Tap to join in the chat item — the chat list row greys out too, and its long-press menu stops
   offering Join.
4. In each case the progress indicator appears after 0.5s rather than 1s.
5. Double click, with the app paused between the clicks so that both are handled before it redraws
   (`kill -STOP`, two clicks, `kill -CONT` on desktop): Accept on the banner and in the chat list
   menu, Join in the chat list menu, in the "Join group?" alert and on the chat item, the chat list
   row of an invited group, "Join group" on a group link, and Connect on a one-time link and on a
   contact address. In each case the app accepts, joins or connects once, opens at most one alert,
   and shows no error.
