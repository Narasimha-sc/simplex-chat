# Test: receipts, post-quantum encryption, address change, voice preferences (part 1) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons or emoji; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
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

- **Message status:** a sent message shows a status icon after its time: one checkmark when sent, two checkmarks when the recipient's app confirmed delivery (a delivery receipt). Judge them from a screenshot, zoomed on the message.
- **Delivery receipts settings:** Settings → "Your privacy" → "More privacy" → the section "Send delivery receipts to" with the switches "Contacts" and "Small groups (max 20)". They belong to the active profile. Changing a switch while some chats override it shows an alert: for contacts "Enable receipts?" with "Enable (keep overrides)", "Enable for all" and "Cancel"; for groups "Enable receipts for groups?" with "Enable (keep group overrides)", "Enable for all groups" and "Cancel" (and the "Disable" counterparts).
- **Send receipts of one chat:** chat info (or group info) → the row "Send receipts", a dropdown with "yes", "no" and "default (yes)" / "default (no)".
- **Message info:** message menu → "Info"; the tab "Delivery" lists the group members with a status icon each. Close it with Escape.
- **Live message:** with the message field empty, a lightning button shows right of the microphone at the right end of the field (OCR can't read icons: find it on the screenshot); click it; the first time, confirm the alert "Live message!" with "Send". Type, and click the send button (a checkmark) to finish.
- **Voice button:** with the message field empty, a microphone button shows at the right end of the field (OCR can't read it: find it on the screenshot). When voice messages are not allowed it is grey and clicking it shows an alert. Never click it while it is enabled: that starts a recording.

## The test

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; each pair is connected, citester owns the group "ci team" (cibob and cicarol are members) and two groups without members, "ci g1" and "ci g2". Messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link; switch to citester and connect citester (A) and cicarol (B); then switch to cibob and connect cibob (A) and cicarol (B). Check: citester has the chats "cibob" and "cicarol"; cibob has "citester" and "cicarol"; cicarol has "citester" and "cibob".
4. (S4) Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member). Switch to cibob and join "ci team"; switch to cicarol and join "ci team". Check: cibob and cicarol each have "ci team" with an enabled message field.
5. (S5) Switch to citester. Create the group `ci g1` and then `ci g2`, each with "Skip inviting members". Check: citester's chat list shows "ci g1" and "ci g2".

**Post-quantum encryption and address change (chat citester–cibob).**

6. (R6.1) As citester → chat "cibob": look at the encryption notice; open chat info and find the row "E2E encryption". Switch to cibob → chat "citester" and do the same. Check: on both the notice says "Messages, files and calls are protected by quantum resistant e2e encryption …" and "E2E encryption" shows "Quantum resistant".
7. (R2.29) Switch to citester → chat "cibob" → chat info: note the host under "Receiving via"; click "Change receiving address" → the alert "Change receiving address?" → "Change". Close chat info and wait up to 120 s for "you changed address". Open chat info again and note "Receiving via". Send `after my switch`; switch to cibob, check it arrived and reply `got it`. Check: the chat shows "changing address…" and then "you changed address"; "Receiving via" shows a different server host than before (the same host is a finding, not a failure); `after my switch` arrives on cibob and `got it` on citester.
8. (R2.30) As cibob → chat "citester" → chat info → "Change receiving address" → "Change"; wait up to 120 s for "you changed address". Switch to citester → chat "cibob"; send `after bob switch`; switch to cibob, check it, reply `ok bob`. Check: citester's chat shows "changed address for you"; both messages arrive.
9. (R2.31) Switch to citester → chat "cibob" → chat info → "Change receiving address" → "Change", then at once click "Abort changing address" in chat info → the alert "Abort changing address?" → "Abort". Check: while the change is in progress "Abort changing address" shows in chat info, and the alert says "Address change will be aborted. Old receiving address will be used."; after "Abort" no "you changed address" appears for this change. Both profiles run in one app, so the change can complete before the click: if "Abort changing address" is gone or disabled before you click it, mark SKIPPED with that reason.
10. (R2.32) As cibob → chat "citester": the same as R2.31 from cibob's side; then switch to citester and look at the chat. Check: as R2.31, from the contact's side; citester's chat shows no "changed address for you" for the aborted change (SKIPPED under the same condition).

**Delivery receipts.**

11. (R7.9) Switch to citester → chat "cibob": send `receipt one`; wait 20 s. Check: `receipt one` shows two checkmarks.
12. (R7.1) Switch to cibob → delivery receipts settings: turn "Contacts" off. Switch to citester → chat "cibob": send `no receipt`; wait 20 s. Switch to cibob → turn "Contacts" on. Switch to citester: send `receipt again`; wait 20 s. Check: no alert when switching (no contact overrides); `no receipt` keeps one checkmark; `receipt again` shows two.
13. (R7.3) Switch to cibob → chat "citester" → chat info → "Send receipts" → "no". Switch to citester → chat "cibob": send `override no`; wait 20 s. Switch to cicarol → chat "cibob": send `carol to bob`; wait 20 s. Check: `override no` keeps one checkmark; `carol to bob` shows two (the override affects only citester).
14. (R7.5) Switch to cibob → delivery receipts settings: turn "Contacts" off (no alert: the override is "no" too), then on again. Check: turning on shows the alert "Enable receipts?" with "Sending receipts is disabled for 1 contacts" and "Enable (keep overrides)", "Enable for all", "Cancel"; click "Enable (keep overrides)"; cibob's chat info for citester still shows "Send receipts" "no".
15. (R7.6) As cibob: turn "Contacts" off, then on again; in the alert click "Enable for all". Open the chat "citester" → chat info. Check: "Send receipts" now shows "default (yes)".
16. (R7.11) Switch to citester → chat "cibob": send `keep my receipt`; wait 20 s; edit it to `keep my receipt edited`. Then send a live message `live receipt` (see "Live message"); wait 20 s. Check: `keep my receipt edited` still shows two checkmarks after the edit; the finished live message shows two checkmarks.
17. (R7.10) Open "ci team": send `group receipt`; wait 30 s; message menu → "Info" → "Delivery". Check: the tab lists cibob and cicarol, each with a status icon showing received (two checkmarks).
18. (R7.2) As citester → delivery receipts settings: turn "Small groups (max 20)" off; open "ci g1" → group info → "Send receipts"; close. Turn "Small groups (max 20)" on again; look at "Send receipts" of "ci g1" again. Check: no alert either way; "Send receipts" reads "default (no)" while the switch is off and "default (yes)" after it is on.
19. (R7.4) "ci g1" → group info → "Send receipts" → "no". Open "ci g2" → group info. Check: "ci g1" shows "no"; "ci g2" still shows "default (yes)".
20. (R7.7) Delivery receipts settings: turn "Small groups (max 20)" off, then on again; in the alert click "Enable (keep group overrides)". Open "ci g1" → group info. Check: turning on shows the alert "Enable receipts for groups?" with "Sending receipts is disabled for 1 groups"; afterwards "ci g1" still shows "no".
21. (R7.8) Turn "Small groups (max 20)" off, then on again; in the alert click "Enable for all groups". Open "ci g1" → group info. Check: "ci g1" shows "default (yes)".

**Voice messages (chat citester–cibob and "ci team").**

22. (R40.38) Switch to cibob → chat "citester" → chat info → "Contact preferences" → "Voice messages": set "You allow" to "no" → "Save and notify contact". Switch to citester → chat "cibob": click the microphone button once. Check: the microphone button is grey; the alert "Voice messages prohibited!" says "Please ask your contact to enable sending voice messages.".
23. (R40.39) Switch to cibob → chat "citester": click the microphone button once; click "Allow" in the alert. Switch to citester → chat "cibob" and look at the microphone button (do not click it). Check: on cibob the alert "Allow voice messages?" says "You need to allow your contact to send voice messages to be able to send them."; after "Allow" cibob's microphone button is no longer grey; on citester it is no longer grey either. (The change cannot arrive while the same profile has the chat open: one app.)
24. (R40.40) As citester → "ci team" → group info → "Group preferences" → turn "Voice messages" off → "Save and notify group members". Switch to cibob → "ci team": click the microphone button once. Check: the alert "Voice messages prohibited!" says "Only group owners can enable voice messages.". (The alerts for a user's own and a contact's prohibition were seen in R40.39 and R40.38.)

**Profile update with an image (compression).**

25. (R6.3) Switch to citester: profile picker → click your own name at the top of the menu → "Your current profile" opens → the camera button on the profile image ("Edit image") → "From Gallery" → in the file dialog click its "File Name" field, type the absolute path of `images/test-card.jpg` in your working directory and press Return → "Save and notify contacts"; close it. Switch to cibob and look at the chat list. Check: citester's profile image shows the test card; cibob's chat list shows citester with the new image. The ~15 KB text message of this row is not checked here: `ui type` types too slowly for 15000 characters (xdotool types 50 ms per character).


You have at most 900 turns, and the whole test fits in about 280 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, S4, S5, R6.1, R2.29, R2.30, R2.31, R2.32, R7.9, R7.1, R7.3, R7.5, R7.6, R7.11, R7.10, R7.2, R7.4, R7.7, R7.8, R40.38, R40.39, R40.40, R6.3), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
