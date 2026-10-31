# Test: incognito connections (part 1) in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it. `ui relaunch` restarts the app and waits for the chat list.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- No test backend runs: the app uses its preset servers on the internet. Never connect to anyone outside this app's own profiles.

## How to do things in the app

- **Send a message:** tap the message field at the bottom of the chat (its placeholder is "Message"; find it in `ui tree` as the EditText), `ui type "<text>"`, then tap "Send Message" (the round arrow at the right end of the field). While the field is empty the same description "Send Message" belongs to the lightning button that starts a live message: type the text first. Check the message then shows in the chat. `ui type` types ASCII only.
- **Message menu:** `ui long-press <x> <y>` on the message's text (centre from `ui find`). The menu starts with a row of reaction emoji (👍 👎 😀 😂 😢 ❤ 🚀 ✅, left to right; `ui find` can't match emoji, so take their positions from `ui text`), then items such as "Reply", "Copy", "Edit", "Forward", "Info", "Delete", "Moderate", "Select". `ui key BACK` closes it without choosing.
- **Reply:** message menu → "Reply"; the compose area shows the quoted message; type the reply and send it.
- **Edit:** message menu → "Edit"; the message field holds the old text: tap the field, `ui key MOVE_END`, then delete the old text with one `ui key DEL DEL …` (one DEL per character), check the field in `ui tree`, type the new text, and tap "Send Message" (a checkmark while editing).
- **Delete:** message menu → "Delete" → the alert "Delete message?" offers "Delete for me" and, for your own messages, "For everyone".
- **Reopen a chat:** `ui key BACK` to the chat list (press it again if the keyboard was open), then tap the chat again.
- **Chat info:** tap the chat name at the top of the chat. `ui key BACK` closes it and other screens (preferences, member info, a message's info).
- **Profile picker:** tap your profile image in the toolbar (bottom left with the reachable toolbar; its description is "profile image placeholder" until you set an image, and chat rows' images share it, so take the toolbar's one: the lowest on the screen).
- **Add a profile:** profile picker → "Your chat profiles" → "Add profile" (if the alert "Make profile private!" shows, tap "OK"). On "Create profile", tap the first text field below "Enter your name:" (EditText in `ui tree`), type the name, and tap "Create profile" (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Switch profile:** profile picker → tap the other profile's name. The chat list then shows that profile's chats.
- **Connect two profiles (1-time link)**, as the inviting profile A for profile B:
  1. As A: "Start new chat" → "Create 1-time link". Wait for the link under "Share this 1-time invite link"; right of it are two icon buttons without text (copy, then share): tap the first, the copy button (find both in `ui tree` as clickables at the right end of the link's row). `ui key BACK` until the chat list shows; if the alert "Keep unused invitation?" shows, tap "Keep".
  2. Switch to B: "Start new chat" → "Paste link / Scan" → "Tap to paste link" (the emulator has no camera; ignore the scanner area). An alert names A with "Open new chat": tap it. The chat with A opens with a "Connect" button at the bottom: tap it.
  3. Wait up to 120 s (`ui wait "protected by" 120`) until the chat shows the notice "Messages, files and calls are protected by …" and the message field replaces the "Connect" button. The chat list of each profile then shows the other's name.
- **System share sheet** (links shared with "Share link" or "Share address" on Android open Android's own chooser, not the app): find its copy button with `ui text` / `ui tree` (Android's chooser labels it "Copy") and tap it, then `ui key BACK` if the sheet stays open. If the chooser has no copy button, the case that needs the link is SKIPPED with that reason.
- **Create a group** (as its owner): "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type the name and tap "Create group" (the button, not the title "Create secret group"). The next screen invites contacts: tap each contact's row to select it, then "Invite to group" (or "Skip inviting members" when no one is invited yet). The group's chat opens.
- **Invite later:** group info → "Invite members" → tap the contacts' rows → "Invite to group". The "New member role" row sets their role.
- **Join a group by invitation** (as the invitee): in the chat list, tap the group's row → the alert "Join group?" → "Join" (or "Join incognito" for an incognito contact; the alert's other button, "Delete", deletes the invitation). Open the group and wait up to 120 s until the message field is enabled.
- **Settings:** profile picker → "Settings". `ui key BACK` until the chat list shows to close it.
- **Toggles** in Settings and preferences are switches at the right end of their rows (find them in `ui tree` as checkable elements).

## More about this test

- **Incognito is remembered app-wide:** the last profile choice (Incognito or not) becomes the default of every new 1-time link, every new chat opened from a link and the group creation screen. Before each such step, check which profile it shows and set the one the step asks for.
- **Profile of a new 1-time link:** under "Share profile" a row shows the profile that the link shares ("Incognito" or the profile name); tap it → "Select chat profile" → tap "Incognito" or your own profile (the screen closes). With Incognito the footer says "A new random profile will be shared.".
- **Profile of a chat opened from a link:** above its "Connect" or "Join group" button, the section "Your profile" shows the profile that will be used; tap it to list the choices ("Incognito" and the profiles) and tap one.
- **Group with incognito:** the create group screen has the switch "Incognito" below "Create group".
- **SimpleX address:** profile picker → "Create SimpleX address" → "Create SimpleX address". The address shows with "Share address": tap it → Android's share sheet → its copy button (see "System share sheet"). Later the profile picker shows "Your SimpleX address" instead.
- **Contact request, requester's side:** pasting an address shows an alert with "Open new chat"; the chat opens with an "Add message" field and a "Connect" button: tap "Connect"; if the alert "Send contact request?" shows, tap "Send request without message".
- **Contact request, address owner's side:** the request shows in the chat list under the requester's name. `ui long-press` on the row to get its menu ("Accept", "Reject"); or tap the row: the chat opens with "Reject" and "Accept" at the bottom.
- **Group link:** group info → "Create group link" → the link is created and shown with "Share link": tap it → Android's share sheet → its copy button (see "System share sheet"). Pasting a group link (as for a 1-time link) shows an alert with the group's name, "Open group" and "Cancel"; "Open group" opens the group's chat, not yet joined, with a "Join group" button at the bottom.
- **Pasting a link into the message field:** `ui long-press` on the message field and tap "Paste" in Android's text menu (read it with `ui text`).
- **A link inside a message** shows as "SimpleX group link" (or as a card with the group's name): tap it to get the same alert as when pasting.
- **Member info:** group info → tap the member's row.
- **Incognito marks:** an incognito chat shows a mask icon next to its name in the chat list and in the chat's top bar; its chat info has the section "Incognito" with "Your random profile" and the random name.

## The test

The steps build on each other: run them in this order. Four profiles of this app take part, "citester", "cibob", "cicarol" and "cidan"; they connect to each other in different ways, with and without incognito. A profile shared incognito shows to the other side under a random name. Connections go through the app's preset servers on the internet: after switching profile, wait up to 60 s for a connection or message from another profile.

Three rows of this section of the manual table are not in this test: 55.14 and 55.21 contact the SimpleX Chat team, and 55.19 needs accepting a contact request incognito, which this app version offers only for an address without profile data (every address it creates has profile data, so "Accept incognito" is never shown).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before tapping it. The first screen has "Get started": tap it (if a What's new sheet covers it, close it first). Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (R55.1) Incognito mode, citester alone: "Start new chat" → "Create 1-time link" → set the link's profile to "Incognito"; close ("Keep" or "Delete" for the unused link are both fine). Open "Create 1-time link" again and look at "Share profile"; close. `ui relaunch`; open it again and look. Then set the profile to "citester"; close; open again and look; `ui relaunch`; open again and look; close. Check: after setting Incognito, each new link shows "Incognito" under "Share profile", also after the restart; after setting citester, each new link shows "citester", also after the restart.
3. (S2) Add the profiles `cibob`, `cicarol` and `cidan` (in this order); stay in cidan. Create cidan's SimpleX address (see "SimpleX address"); don't copy it yet. Check: cidan's profile picker shows "Your SimpleX address".

**1-time links.**

4. (R55.16) Switch to citester → "Start new chat" → "Create 1-time link" → set the profile to "Incognito", then back to "citester" → copy the link; close. Switch to cibob → make sure new links start Incognito: "Start new chat" → "Create 1-time link" → set the profile to "Incognito"; close (tap "Delete" for this unused link if asked). Paste citester's link → "Open new chat". Check: after switching to Incognito and back, citester's link shows "citester" under "Share profile" without the footer about a random profile; cibob's paste opens a new chat with "citester" (the result of the connection is recorded in R55.18).
5. (R55.18) Continue as cibob in the new chat: look at "Your profile" (don't change it), tap "Connect"; wait for the connection. Switch to citester and look at the chat list. Check: cibob's "Your profile" shows "Incognito" before connecting; cibob's chat shows "citester" (citester's own profile was shared: record this under R55.16) with the mask icon; citester's new chat has a random name (not "cibob"), without a mask.
6. (R55.15) Still as citester: "Start new chat" → "Create 1-time link" (it starts with "citester") → set the profile to "Incognito" → copy the link; close. Check: the footer says "A new random profile will be shared." (the connection is checked in R55.17).
7. (R55.17) As citester: "Start new chat" → "Create 1-time link" → set the profile back to "citester" (this turns the remembered incognito choice off); close and tap "Delete" for this unused link if asked. Switch to cicarol: paste the link copied in R55.15 → "Open new chat"; check "Your profile" shows "cicarol" → "Connect"; wait for the connection. Check: cicarol's new chat has a random name, not "citester": the link made incognito keeps sharing the incognito profile after the choice was turned off (record this under R55.15 too).
8. (R55.5) Switch to citester and look at the chats "cicarol" and the random-named one from R55.18. Check: incognito link (R55.15): citester's chat "cicarol" has the mask icon and cicarol sees a random name; non-incognito link (R55.16): cibob sees "citester".
9. (R55.2) As citester: open the chat "cicarol" → chat info; close; open the chat with cibob's random name. Check: the chat list row "cicarol" and the chat's top bar show the mask icon; chat info shows "Incognito" with "Your random profile" and a random name; the other chat has no mask icon.
10. (R55.4) Switch to cibob: make sure new links start with "cibob" ("Start new chat" → "Create 1-time link" → profile "cibob"); copy this link; close. Switch to cicarol: paste it → "Open new chat" → tap "Your profile" → "Incognito" → "Connect"; wait. Switch to cibob. Check: cibob's new chat has a random name (not "cicarol"); cicarol's chat with "cibob" shows the mask icon. (The non-incognito paste is R55.17: cicarol pasted with "cicarol".)

**Group link, member address and contact requests.**

11. (S3) Switch to citester. Create the group `ci link` with "Incognito" off and "Skip inviting members"; group info → "Create group link" → copy the link (see "Group link"); close. Check: the link screen shows the link and "Share link".
12. (R55.6) Switch to cibob: paste the group link → the alert names "ci link" with "Open group" → tap it → set "Your profile" to "Incognito" → "Join group"; wait up to 120 s until the message field is enabled. Switch to cidan: paste the same link → "Open group" → "Your profile" "cidan" → "Join group"; wait. Switch to citester → "ci link" → group info. Check: citester's member list shows cidan as "cidan" and cibob under a random name; cibob's "ci link" shows the mask icon, cidan's does not. (Scanning the link's QR code needs a camera: not checked.)
13. (R55.13) Switch to cibob → "ci link" → group info → "cidan" → member info: under "Address" tap "Connect" → "Open new chat" → set "Your profile" to "Incognito" → "Connect" (→ "Send request without message" if asked). Switch to citester → "ci link" → group info → "cidan" → "Connect" → "Open new chat" → "Your profile" "citester" → "Connect" (→ "Send request without message"). Switch to cidan and look at the chat list. Check: cidan's member info, seen by cibob and by citester, has the section "Address" with "Connect"; cidan's chat list shows two requests: one from a random name (cibob incognito) and one from "citester".
14. (R55.10) As cidan: `ui long-press` on the random-named request's row. Check: the menu offers "Accept" and "Reject" and no "Accept incognito" (every address of this version holds profile data); tap "Accept"; the chat connects. Accepting incognito cannot be checked: note it, not a failure.
15. (R55.11) As cidan: tap the "citester" request's row; tap "Accept" at the bottom of the chat; wait for the connection. Check: the chat shows "Reject" and "Accept" and no incognito option; after "Accept" the chat connects and shows the encryption notice.

**Contact address (cicarol to cidan).**

16. (R55.20) As cidan: profile picker → "Your SimpleX address" → "Share address" (copy, see "SimpleX address"); close. Switch to cicarol: make new chats start incognito ("Start new chat" → "Create 1-time link" → "Incognito"; close, "Delete"). Paste cidan's address → "Open new chat"; look at "Your profile" → "Connect" (→ "Send request without message"). Switch to cidan: accept the request (tap the row → "Accept"); wait. Check: cicarol's "Your profile" shows "Incognito" before connecting; cidan's new contact has a random name, not "cicarol"; cicarol's chat with "cidan" shows the mask icon.
17. (R55.9) Compare the address connections; then, as cicarol, set new links back to "cicarol" ("Start new chat" → "Create 1-time link" → "cicarol"; close, "Delete"). Check: incognito: R55.20 (cidan sees a random name); not incognito: citester's connection in R55.13 used cidan's address with "citester", and cidan sees "citester".

**Links in messages and group invitations.**

18. (R55.8) Switch to citester. Create the group `ci item` ("Incognito" off, "Skip inviting members"), group info → "Create group link" → copy it. Open the chat with cibob's random name: paste the link into the message field (see "Pasting a link into the message field") and send it. Open the chat "cicarol": paste and send it. Switch to cibob → chat "citester": tap the link in the message → "Open group" → "Your profile" "cibob" → "Join group". Switch to cicarol → the chat with citester's random name: tap the link → "Open group" → "Your profile" "Incognito" → "Join group". Wait; switch to citester → "ci item" → group info. Check: each message shows the group link and tapping it shows the alert for "ci item"; the member list shows "cibob" and a random name for cicarol; cicarol's "ci item" shows the mask icon.
19. (R55.22) As citester: create the group `ci invite` ("Incognito" off), inviting cibob's random-named contact and cidan (role member). Switch to cibob → chat "citester": look at the invitation; `ui long-press` on the chat list row "ci invite" and look at its menu; close the menu with `ui key BACK` (don't tap the row itself here: its alert's other button deletes the invitation). Switch to cidan → chat "citester": look at the invitation. Check: citester's chats show "You sent group invitation"; cibob (incognito contact): "You are invited to group" with "Tap to join incognito", and the row's menu offers "Join incognito"; cidan: "You are invited to group" with "Tap to join".
20. (R55.23) As cidan: tap the chat list row "ci invite" → "Join" in the alert "Join group?" (its other button, "Delete", deletes the invitation). Switch to cibob → chat "citester": tap "Tap to join incognito" in the invitation. Wait; switch to citester → "ci invite" → group info. Check: both join: the member list shows "cidan" and cibob's random name (the incognito invitee joined with the same random profile as its contact); cibob's invitation now reads "You joined this group".


You have at most 600 turns, and the whole test fits in about 330 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- after tapping the message field: `ui do type "bob one" -- click-text "Send Message" -- wait "bob one" -- shot S4`
- `ui do key BACK -- click-text "ci team" 10 -- wait "owner note" 30 -- shot group`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, R55.1, S2, R55.16, R55.18, R55.15, R55.17, R55.5, R55.2, R55.4, S3, R55.6, R55.13, R55.10, R55.11, R55.20, R55.9, R55.8, R55.22, R55.23), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
