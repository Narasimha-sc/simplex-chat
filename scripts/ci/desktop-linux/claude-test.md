# Test: incognito connections (part 1) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons or emoji; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop` (except in R55.1, as it says). Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730: the search field "Search or paste SimpleX link" appears once there is a chat. The toolbar is at the bottom of the left pane.
- No test backend runs: the app uses its preset servers on the internet. Never connect to anyone outside this app's own profiles.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (its placeholder is "Message"), `ui type "<text>"`, then `ui key Return`. Check the message then shows in the chat.
- **Type an emoji:** `ui type "😀"` into the message field. If the field stays empty, click the emoji button left of the message field (a smiley icon), type the emoji's name into the picker's search field (for 😀 `grinning`, for 😂 `tears of joy`) and click the emoji; press Escape to close the picker.
- **Message menu:** `ui right-click <x> <y>` on the message's text (centre from `ui find`). The menu starts with a row of reaction emoji (👍 👎 😀 😂 😢 ❤ 🚀 ✅, left to right; OCR can't read them, so click them by position, judged from the screenshot), then items such as "Reply", "Copy", "Edit", "Forward", "Info", "Delete", "Moderate", "Select". Press Escape to close it without choosing.
- **Reply:** message menu → "Reply"; the compose area shows the quoted message; type the reply and press Return.
- **Edit:** message menu → "Edit"; the message field holds the old text: `ui key ctrl+a`, type the new text (it replaces the selection), `ui key Return`.
- **Delete:** message menu → "Delete" → the alert "Delete message?" offers "Delete for me" and, for your own messages, "For everyone".
- **Reopen a chat:** click another chat in the chat list, then click this chat again (Escape does not close a chat on desktop).
- **Chat info:** click the chat name at the top of the right pane. Press Escape to close it and other panes (preferences, member info, a message's info) and get back to the chat.
- **Add a profile:** profile picture (about 27,730) → "Your chat profiles" → "Add profile" (if the alert "Make profile private!" shows, click "OK"). On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want. The chat list then shows that profile's chats.
- **Connect two profiles (1-time link)**, as the inviting profile A for profile B:
  1. As A: the pencil (about 363,730) → "Create 1-time link". Wait for the link under "Share this 1-time invite link" and click the link's text: the toast "Copied to clipboard" shows. Press Escape until the chat list shows; if the alert "Keep unused invitation?" shows, click "Keep".
  2. Switch to B: the pencil → "Paste link" → "Tap to paste link". An alert names A with "Open new chat": click it. The chat with A opens with a "Connect" button at the bottom: click it.
  3. Wait up to 120 s (`ui wait "protected by" 120`) until the chat shows the notice "Messages, files and calls are protected by …" and the message field replaces the "Connect" button. The chat list of each profile then shows the other's name.
- **Create a group** (as its owner): the pencil → "Create group". Click the field about 40 px below the text "Enter group name:", type the name, and click "Create group" (the button, not the title "Create secret group"). The next screen invites contacts: click each contact's row to select it, then "Invite to group" (or "Skip inviting members" when no one is invited yet). The group's chat opens.
- **Invite later:** group info → "Invite members" → click the contacts' rows → "Invite to group". The "New member role" row sets their role.
- **Join a group by invitation** (as the invitee): in the chat list, click the group's row → the alert "Join group?" → "Join" (or "Join incognito" for an incognito contact; the alert's other button, "Delete", deletes the invitation). Open the group and wait up to 120 s until the message field is enabled.
- **Settings:** profile picture (about 27,730) → "Settings". Press Escape until the chat list shows to close it.
- **Toggles** in Settings and preferences are switches at the right end of their rows (about x 335 in the left pane); click the switch, not the text.

## More about this test

- **Incognito is remembered app-wide:** the last profile choice (Incognito or not) becomes the default of every new 1-time link, every new chat opened from a link and the group creation screen. Before each such step, check which profile it shows and set the one the step asks for.
- **Profile of a new 1-time link:** under "Share profile" a row shows the profile that the link shares ("Incognito" or the profile name); click it → "Select chat profile" → click "Incognito" or your own profile (the screen closes). With Incognito the footer says "A new random profile will be shared.".
- **Profile of a chat opened from a link:** above its "Connect" or "Join group" button, the section "Your profile" shows the profile that will be used; click it to list the choices ("Incognito" and the profiles) and click one.
- **Group with incognito:** the create group screen has the switch "Incognito" below "Create group".
- **SimpleX address:** profile picker → "Create SimpleX address" → "Create SimpleX address". The address shows with "Share address": click it: the toast "Copied to clipboard" shows (the address is copied). Later the profile picker shows "Your SimpleX address" instead.
- **Contact request, requester's side:** pasting an address shows an alert with "Open new chat"; the chat opens with an "Add message" field and a "Connect" button: click "Connect"; if the alert "Send contact request?" shows, click "Send request without message".
- **Contact request, address owner's side:** the request shows in the chat list under the requester's name. `ui right-click` on the row to get its menu ("Accept", "Reject"); or click the row: the chat opens with "Reject" and "Accept" at the bottom.
- **Group link:** group info → "Create group link" → the link is created and shown with "Share link": click it: the toast "Copied to clipboard" shows (the link is copied). Pasting a group link (as for a 1-time link) shows an alert with the group's name, "Open group" and "Cancel"; "Open group" opens the group's chat, not yet joined, with a "Join group" button at the bottom.
- **Pasting a link into the message field:** click the message field and press `ui key ctrl+v`.
- **A link inside a message** shows as "SimpleX group link" (or as a card with the group's name): click it to get the same alert as when pasting.
- **Member info:** group info → click the member's row.
- **Incognito marks:** an incognito chat shows a mask icon next to its name in the chat list and in the chat's top bar; its chat info has the section "Incognito" with "Your random profile" and the random name.

## The test

The steps build on each other: run them in this order. Four profiles of this app take part, "citester", "cibob", "cicarol" and "cidan"; they connect to each other in different ways, with and without incognito. A profile shared incognito shows to the other side under a random name. Connections go through the app's preset servers on the internet: after switching profile, wait up to 60 s for a connection or message from another profile.

Three rows of this section of the manual table are not in this test: 55.14 and 55.21 contact the SimpleX Chat team, and 55.19 needs accepting a contact request incognito, which this app version offers only for an address without profile data (every address it creates has profile data, so "Accept incognito" is never shown).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profiles `cibob`, `cicarol` and `cidan` (in this order); stay in cidan. Create cidan's SimpleX address (see "SimpleX address"); don't copy it yet. Check: cidan's profile picker shows "Your SimpleX address".

**1-time links.**

3. (R55.16) Switch to citester → the pencil (about 363,730) → "Create 1-time link" → set the profile to "Incognito", then back to "citester" → copy the link; close. Switch to cibob → make sure new links start Incognito: the pencil (about 363,730) → "Create 1-time link" → set the profile to "Incognito"; close (click "Delete" for this unused link if asked). Paste citester's link → "Open new chat". Check: after switching to Incognito and back, citester's link shows "citester" under "Share profile" without the footer about a random profile; cibob's paste opens a new chat with "citester" (the result of the connection is recorded in R55.18).
4. (R55.18) Continue as cibob in the new chat: look at "Your profile" (don't change it), click "Connect"; wait for the connection. Switch to citester and look at the chat list. Check: cibob's "Your profile" shows "Incognito" before connecting; cibob's chat shows "citester" (citester's own profile was shared: record this under R55.16) with the mask icon; citester's new chat has a random name (not "cibob"), without a mask.
5. (R55.15) Still as citester: the pencil (about 363,730) → "Create 1-time link" (it starts with "citester") → set the profile to "Incognito" → copy the link; close. Check: the footer says "A new random profile will be shared." (the connection is checked in R55.17).
6. (R55.17) As citester: the pencil (about 363,730) → "Create 1-time link" → set the profile back to "citester" (this turns the remembered incognito choice off); close and click "Delete" for this unused link if asked. Switch to cicarol: paste the link copied in R55.15 → "Open new chat"; check "Your profile" shows "cicarol" → "Connect"; wait for the connection. Check: cicarol's new chat has a random name, not "citester": the link made incognito keeps sharing the incognito profile after the choice was turned off (record this under R55.15 too).
7. (R55.5) Switch to citester and look at the chats "cicarol" and the random-named one from R55.18. Check: incognito link (R55.15): citester's chat "cicarol" has the mask icon and cicarol sees a random name; non-incognito link (R55.16): cibob sees "citester".
8. (R55.2) As citester: open the chat "cicarol" → chat info; close; open the chat with cibob's random name. Check: the chat list row "cicarol" and the chat's top bar show the mask icon; chat info shows "Incognito" with "Your random profile" and a random name; the other chat has no mask icon.
9. (R55.4) Switch to cibob: make sure new links start with "cibob" (the pencil (about 363,730) → "Create 1-time link" → profile "cibob"); copy this link; close. Switch to cicarol: paste it → "Open new chat" → click "Your profile" → "Incognito" → "Connect"; wait. Switch to cibob. Check: cibob's new chat has a random name (not "cicarol"); cicarol's chat with "cibob" shows the mask icon. (The non-incognito paste is R55.17: cicarol pasted with "cicarol".)

**Group link, member address and contact requests.**

10. (S3) Switch to citester. Create the group `ci link` with "Incognito" off and "Skip inviting members"; group info → "Create group link" → copy the link (see "Group link"); close. Check: the link screen shows the link and "Share link".
11. (R55.6) Switch to cibob: paste the group link → the alert names "ci link" with "Open group" → click it → set "Your profile" to "Incognito" → "Join group"; wait up to 120 s until the message field is enabled. Switch to cidan: paste the same link → "Open group" → "Your profile" "cidan" → "Join group"; wait. Switch to citester → "ci link" → group info. Check: citester's member list shows cidan as "cidan" and cibob under a random name; cibob's "ci link" shows the mask icon, cidan's does not. (Scanning the link's QR code needs a camera: not checked.)
12. (R55.13) Switch to cibob → "ci link" → group info → "cidan" → member info: under "Address" click "Connect" → "Open new chat" → set "Your profile" to "Incognito" → "Connect" (→ "Send request without message" if asked). Switch to citester → "ci link" → group info → "cidan" → "Connect" → "Open new chat" → "Your profile" "citester" → "Connect" (→ "Send request without message"). Switch to cidan and look at the chat list. Check: cidan's member info, seen by cibob and by citester, has the section "Address" with "Connect"; cidan's chat list shows two requests: one from a random name (cibob incognito) and one from "citester".
13. (R55.10) As cidan: `ui right-click` on the random-named request's row. Check: the menu offers "Accept" and "Reject" and no "Accept incognito" (every address of this version holds profile data); click "Accept"; the chat connects. Accepting incognito cannot be checked: note it, not a failure.
14. (R55.11) As cidan: click the "citester" request's row; click "Accept" at the bottom of the chat; wait for the connection. Check: the chat shows "Reject" and "Accept" and no incognito option; after "Accept" the chat connects and shows the encryption notice.

**Contact address (cicarol to cidan).**

15. (R55.20) As cidan: profile picker → "Your SimpleX address" → "Share address" (copy, see "SimpleX address"); close. Switch to cicarol: make new chats start incognito (the pencil (about 363,730) → "Create 1-time link" → "Incognito"; close, "Delete"). Paste cidan's address → "Open new chat"; look at "Your profile" → "Connect" (→ "Send request without message"). Switch to cidan: accept the request (click the row → "Accept"); wait. Check: cicarol's "Your profile" shows "Incognito" before connecting; cidan's new contact has a random name, not "cicarol"; cicarol's chat with "cidan" shows the mask icon.
16. (R55.9) Compare the address connections; then, as cicarol, set new links back to "cicarol" (the pencil (about 363,730) → "Create 1-time link" → "cicarol"; close, "Delete"). Check: incognito: R55.20 (cidan sees a random name); not incognito: citester's connection in R55.13 used cidan's address with "citester", and cidan sees "citester".

**Links in messages and group invitations.**

17. (R55.8) Switch to citester. Create the group `ci item` ("Incognito" off, "Skip inviting members"), group info → "Create group link" → copy it. Open the chat with cibob's random name: paste the link into the message field (see "Pasting a link into the message field") and send it. Open the chat "cicarol": paste and send it. Switch to cibob → chat "citester": click the link in the message → "Open group" → "Your profile" "cibob" → "Join group". Switch to cicarol → the chat with citester's random name: click the link → "Open group" → "Your profile" "Incognito" → "Join group". Wait; switch to citester → "ci item" → group info. Check: each message shows the group link and clicking it shows the alert for "ci item"; the member list shows "cibob" and a random name for cicarol; cicarol's "ci item" shows the mask icon.
18. (R55.22) As citester: create the group `ci invite` ("Incognito" off), inviting cibob's random-named contact and cidan (role member). Switch to cibob → chat "citester": look at the invitation; `ui right-click` on the chat list row "ci invite" and look at its menu; close the menu with Escape (don't click the row itself here: its alert's other button deletes the invitation). Switch to cidan → chat "citester": look at the invitation. Check: citester's chats show "You sent group invitation"; cibob (incognito contact): "You are invited to group" with "Tap to join incognito", and the row's menu offers "Join incognito"; cidan: "You are invited to group" with "Tap to join".
19. (R55.23) As cidan: click the chat list row "ci invite" → "Join" in the alert "Join group?" (its other button, "Delete", deletes the invitation). Switch to cibob → chat "citester": click "Tap to join incognito" in the invitation. Wait; switch to citester → "ci invite" → group info. Check: both join: the member list shows "cidan" and cibob's random name (the incognito invitee joined with the same random profile as its contact); cibob's invitation now reads "You joined this group".

**Incognito mode, last (it restarts the app).**

20. (R55.1) Switch to citester. The pencil → "Create 1-time link" → set the link's profile to "Incognito"; close ("Keep" or "Delete" for the unused link are both fine). Open "Create 1-time link" again and look at "Share profile"; close. Restart the app. This is the only step where `ui stop` and `ui start` are allowed: `ui stop`, then `ui start <app dir>`, where <app dir> is the folder `app/simplex` next to your working directory, written out in full (your working directory is `<temp>/claude-test`, so the app is `<temp>/app/simplex`, for example `/home/runner/work/_temp/app/simplex`; the helper refuses `$` and `~`). `ui start` waits for the app's window; the app keeps its data and opens with the last active profile. If `ui start` fails, record its output, mark the step SKIPPED and end the test. Then open "Create 1-time link" again and look; set the profile to "citester"; close; open again and look; close. Check: after setting Incognito, each new link shows "Incognito" under "Share profile", also after the restart; after setting citester, the next link shows "citester". (Its persistence over a second restart is not checked on desktop.)


You have at most 600 turns, and the whole test fits in about 320 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click-text "Message" -- type "bob one" -- key Return -- wait "bob one" -- shot S4`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`

## Anything unusual

You are looking for regressions, not only running checks. Besides each case's checks, watch for anything a user would consider wrong, on every screen you pass through:

- a crash, the app closing or restarting, a frozen screen;
- an error alert or dialog of any kind ("View crashed", "Error", "Unexpected error", "Connection error", an error code or exception text);
- an action that takes over 30 s, or a spinner that never ends;
- text cut off, overlapping, garbled, untranslated or showing a raw key (such as `chat_item_…`), wrong plurals, empty labels;
- a control that does nothing, a duplicated or missing item, an item in the wrong place or order;
- a state that differs after a restart or after switching profile;
- anything that differs from how the row or the step describes it.

Record each in `report.md` under a heading `## Unusual`, with the case it happened in and the screenshot names, even when every check passes. A case passes only when its checks pass and nothing unusual happened in it; otherwise mark it FAIL and say why. Never stop at a failure: go on with the next case.

## Report

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, R55.16, R55.18, R55.15, R55.17, R55.5, R55.2, R55.4, S3, R55.6, R55.13, R55.10, R55.11, R55.20, R55.9, R55.8, R55.22, R55.23, R55.1), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
