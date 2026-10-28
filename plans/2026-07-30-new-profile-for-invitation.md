# New profile for an invitation

## Problem
The invitation profile pickers (prepared chat from a link, "Share profile" on a one-time link) list only
existing profiles and Incognito; to use a new one, the user leaves for Settings and opens the link again.

## Cause
- `CreateActiveUser` always activated the new user (now `Commands.hs:476-485`); `APIChangePreparedContactUser`
  resolves the chat under the active user (`Commands.hs:2250`, `withUser`): a reassign after create fails.
- Out of scope: a contact request (already in a queue of the address owner; queues cannot change agent user);
  legacy connect alerts (links without short-link data, follow-up); a contact card's address (needs
  re-preparing a contact); group invitations (no choice exists); share-into-chat (a new profile has no chats).

## Fix
- Core: `NewUser.keepActiveUser :: BoolDef` (`Types.hs:161`): when true and an active user exists, the new
  user stays inactive (`activateNewUser`, `Commands.hs:476`). Omitted means false; the apps send true only
  from the invitation flow; `/create user`, `/create bot` and bots set false, so they are unchanged. Bot API
  types regenerated; `api.ts`, `api.py` edited by hand; the TS client pins types `^0.3.0` (no such field).
- UI: "Add profile" row in both pickers (New chat: only when `contactConnection != null`): create with
  `keepActiveUser`, add to the users list, run the existing selection: `changeProfile` (prepared chat) or
  `selectProfile` (one-time link; commit 1 moves the row's `onSelected` body there as is). Row: last in
  Kotlin (`reverseLayout`, `ComposeContextProfilePickerView.kt:251`), first on iOS (height `users.count + 2`).
- Kotlin form in `ModalManager.fullscreen` (desktop: `center` closes the invitation chat, `end` leaves the
  picker usable beside it, `start` disposes the share list). iOS `.sheet`: on the body chain (prepared chat)
  or on `profilePicker()`'s List (share list, never swapped out), so it outlives the rows. The form closes on
  success only; `submitting` disables Create during the request (on iOS, also dismiss). `keepingChatId` keeps
  the list position, opens no chat (its id survives reassignment); reassignment can rename the contact.
- A remote host on 7.1.0.11-7.1.0.14 activates the new profile anyway: `createProfileForInvitation` then
  switches the desktop to it and does not reassign; the user switches back to continue the invitation.
- Limitations: no progress on the Android share list after create (picker disposed under the form, rows
  tappable for one round trip); an iOS reassignment alert during the ~350 ms sheet dismiss can be lost;
  `filteredProfiles` keys on search text only (`NewChatView.kt:303`; fix: key on `chatModel.users.size` too);
  process death between create and reassign leaves an empty profile; a CLI controller's raw `/_create user`
  with the flag caches the inactive user as current (Terminal `Input.hs`, `Output.hs`; display only).

## Approaches considered
- Switch back, reassign, switch forward: fails for a hidden current profile; core and UI active users differ.
- Re-prepare the link: `PreparedContact` keeps only `connLinkToConnect`; needs a network fetch, fails offline.
- Combined core command (create + reassign): atomic, but one per chat type and a larger API.
- Chosen: `keepActiveUser`: create, reassign while the owner is still active, switch once.

## Tests
- Added `testCreateUserKeepingActiveUser`, `testCreateUserWithoutKeepActiveUser` (`ChatTests/Profiles.hs`);
  they and `Bot API docs` (must leave the tree unchanged) run in CI only; not run locally.
- Desktop AppImages, master vs PR: rows shown; Connect uses the new profile; duplicate name keeps the form;
  new link from the share list works; search keeps the row; Settings > Add profile unchanged; sf-combo4: pass.
- Not run: hidden current profile, avatar choice, cancelling the form, share-into-chat, onboarding, CLI
  `/create user`, reassignment offline, Android, iOS (not compiled). Older remote host: code reading only.

## Open questions
- Separate PRs for pre-existing bugs? `changeActiveUser_` after a failed reassignment
  (`ComposeContextProfilePickerView.kt:101`); `close()` after one (`NewChatView.kt:356`); incognito preference
  set before a call that can fail (`NewChatView.kt:400`); avatar as `description` (`WelcomeView.kt:386`).
- iOS: build on a Mac; with one profile, is "Add profile" visible without scrolling?
- Android: test with an APK built with this PR's core before marking ready?
