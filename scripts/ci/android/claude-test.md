# Test: live and disappearing messages, message info, link previews (part 1) in the SimpleX Chat Android app

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

- **Live message from an empty field:** while the message field is empty, a lightning button shows right of the microphone at the right end of the field (its description is "Send Message", like the send button's); tap it. The first time, the alert "Live message!" asks to confirm with "Send". Then type: the message is sent at once and updated about every 3 s while you type; the send button turns into a checkmark; tap it to finish the live message.
- **Send button menu:** with text (or an attachment) in the compose area, `ui long-press` on the send button at the right end of the field opens its menu: "Send live message" and "Disappearing message". "Disappearing message" opens a menu headed "Send disappearing message" with "30 seconds", "1 minute", "5 minutes" and "Custom time"; "Custom time" opens the dialog "Delete after" with a "Send" button below two wheels for the number and the unit (seconds, minutes, hours, days, weeks, months); turn a wheel one value with `ui scroll <x> <y> down 1` or `up 1` over it and check the selected values in `ui text`.
- **Timer mark:** a disappearing message shows a timer icon next to its time; when its time differs from the chat's timer it also shows the time in short form ("30s", "5m", "2h", "12mth").
- **Message info:** message menu → "Info" opens the message's details titled "Sent message" or "Received message", with "Sent at" / "Received at", "Disappears at" for a disappearing message, "File servers" for a file, "Share" and "Copy", and tabs at the bottom such as "History", "In reply to" and "Delivery". Close it with `ui key BACK`.
- **Attaching the test card:** tap "Attach" (left of the message field) → "Image". Android's picker opens (not the app): find `test-card.jpg` (under Pictures, Images or Recent; its thumbnail shows colour bars and "1080") and choose it, then confirm the choice if the picker has a button for it ("Add", "Select", "Done"). The compose area then shows the image above the field.
- **Waiting a fixed time:** `ui wait "<a text that never shows>" <secs>` returns after <secs> seconds; its "not on screen" result is expected there.

## The test

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" that both join. The chat citester–cibob has no chat-level timer; the chat citester–cicarol gets one in R10.39. Messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before tapping it. The first screen has "Get started": tap it (if a What's new sheet covers it, close it first). Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link; then, as cibob in the chat "citester", send `bob hi`. Check: citester's chat "cibob" shows `bob hi`.
4. (S4) Switch to citester. Connect citester (A) and cicarol (B) by a 1-time link. Check: cicarol's chat "citester" shows the encryption notice and a message field.
5. (S5) Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member). Switch to cibob and join "ci team"; switch to cicarol and join "ci team". Check: cibob and cicarol each have "ci team" with an enabled message field.

**Live messages (chat citester–cibob).**

6. (R10.19) Switch to citester → chat "cibob". With the message field empty, tap the lightning button. Check: the alert "Live message!" says "Send a live message - it will update for the recipient(s) as you type it" and offers "Send"; tap "Send".
7. (R10.20) Continue the live message: type `live hello`; wait 5 s; take two shots a second apart. Then open the live message's menu and look at its items; close the menu. Check: the live message shows the header "LIVE" and animated dots after its text (the typing indicator); its menu has no "Edit", no "Delete" and no "Reply" (record this under R10.22, R10.23 and R10.24 too). The recipient's side cannot be watched while citester types (one app): that part is not checked.
8. (R10.18) Continue: type ` world`; wait 5 s; tap the send button (a checkmark) to finish. Check: the message shows `live hello world` without the "LIVE" header. (The recipient is checked in R10.21.)
9. (R10.27) Type `typed then live` (do not send), `ui long-press` on the send button → "Send live message". Type ` more`, wait 5 s, tap the checkmark. Check: no alert this time; while live the message shows "LIVE"; finished, it reads `typed then live more`.
10. (R10.28) Attach the test card; `ui long-press` on the send button → "Send live message"; type `live with image`; wait 5 s; tap the checkmark. Check: the menu offers "Send live message" with an image attached; the chat then shows the image with the text `live with image`.
11. (R10.21) Switch to cibob → chat "citester". Check: cibob shows `live hello world`, `typed then live more` and the image with `live with image` (record these under R10.18, R10.27 and R10.28), each without "LIVE" and without an edited mark (pencil icon); citester's copies had no edited mark either.
12. (R10.22) Switch to citester → chat "cibob": edit `live hello world` to `live edited`. Check: after the live message was finished, "Edit" is in its menu and the edit works: `live edited` shows with an edited mark. (While live, "Edit" was absent: R10.20.)
13. (R10.24) Message menu of `live edited` → "Reply", send `quote live`. Check: `quote live` shows a quote of `live edited`. (While live, "Reply" was absent.)
14. (R10.23) Message menu of `typed then live more` → "Delete" → "Delete for me". Check: the message is gone. (While live, "Delete" was absent.)

**Disappearing messages.**

15. (R10.37) As citester: chat "cibob" → chat info → "Contact preferences": look at "Disappearing messages"; close it. Type `custom check`, `ui long-press` on the send button. Check: "You allow" is on and "Delete after" is "off" (no chat timer), messages sent normally (`bob hi`, `quote live`) have no timer icon, and the send button's menu still offers "Disappearing message".
16. (R10.36) Continue: "Disappearing message" → "Custom time" → set 2 and "minutes" → "Send". Check: `custom check` shows the timer icon and "2m".
17. (R10.38) Type `year message`, `ui long-press` on the send button → "Disappearing message" → "Custom time" → set "months" and 12 → "Send". Message menu of `year message` → "Info". Check: the message shows "12mth"; its info shows "Disappears at" about 360 days after "Sent at".
18. (R10.29) Type `vanish 30`, `ui long-press` on the send button → "Disappearing message" → "30 seconds". Wait 40 s. Then switch to cibob → chat "citester"; wait 40 s. Check: on citester `vanish 30` shows the timer and "30s", then is gone after 40 s; on cibob it shows when the chat is opened (read), then is gone 30–40 s later.
19. (R10.39) Switch to citester → chat "cicarol" → chat info → "Contact preferences" → "Disappearing messages": "You allow" on, "Delete after" → "custom" → set 2 and "hours" → "Select" → "Save and notify contact"; close it. Then "ci team" → group info → "Group preferences" → turn "Disappearing messages" on → "Delete after" → "custom" → set 3 and "hours" → "Select" → "Save and notify group members"; close it. Check: "Delete after" shows "2 hours" for the contact and "3 hours" for the group; the chat "cicarol" shows the event "Disappearing messages: 2 hours" and "ci team" shows "Disappearing messages: 3 hours".
20. (R10.31) Chat "cicarol": send `default ttl` normally; type `custom ttl`, `ui long-press` on the send button → "Disappearing message" → "5 minutes". Check: `default ttl` shows the timer icon without a time text (it uses the chat's 2 hours); `custom ttl` shows the timer icon and "5m".
21. (R10.32) Edit `custom ttl` to `custom ttl edited` (within 5 minutes of sending it). Check: the text changes and the message keeps the timer icon and "5m", with an edited mark.
22. (R10.34) Message menu of `custom ttl edited` → "Reply", send `quote timed`. Check: `quote timed` shows a quote of `custom ttl edited` and the timer icon.
23. (R10.33) Message menu of `default ttl` → "Delete" → "Delete for me". Check: `default ttl` is gone.
24. (R10.35) With the field empty tap the lightning button; type `live timed`; wait 5 s; its message menu → "Info"; close it; tap the checkmark to finish; message menu → "Info" again. Check: while live, the info has no "Disappears at"; after finishing, it shows "Disappears at" about 2 hours after "Sent at".

**Message info.**

25. (R10.40) Chat "cibob": message menu of `live edited` (own, edited) → "Info"; the "History" tab; tap "Copy"; close. Message menu of `bob hi` (cibob's) → "Info"; close. Check: own: title "Sent message", "Sent at", and under "History" two versions (`live edited` marked "(current)", and `live hello world`); "Copy" works without an error. Other's: title "Received message", with "Sent at" and "Received at".
26. (R10.42) Message menu of `quote live` → "Info" → the "In reply to" tab. Check: it shows the quoted message `live edited`.
27. (R10.43) Message menu of the image with `live with image` → "Info". Check: it shows "File servers" with at least one server host name.
28. (R10.41) "ci team": send `status check`; wait 30 s; its message menu → "Info" → the "Delivery" tab. Check: the tab lists cibob and cicarol, each with a delivery status icon.

**Link previews (chat citester–cibob).**

29. (R11.1) Chat "cibob": type `https://example.com`; wait up to 10 s; if the alert "Enable link previews?" shows, tap "Enable"; wait up to 20 s for the preview above the field; send. Reopen the chat. Switch to cibob → chat "citester", reopen it. Check: before sending, the compose area shows a preview with the page title "Example Domain"; the sent message shows the preview on citester and on cibob, also after reopening.
30. (R11.2) Switch to citester → chat "cibob": tap the message field, then `ui do type "https://www.iana.org/about" -- click-text "Send Message"`, one chain, so it is sent before a preview appears. Check: the message is sent without a link preview. If a preview was attached anyway (it loaded before sending), mark SKIPPED: the timing cannot be controlled here.

**Disappearing message and restart (last).**

31. (R10.30) Chat "cibob": type `vanish bg`, `ui long-press` on the send button → "Disappearing message" → "1 minute". At once `ui key HOME` (the app goes to the background); wait 70 s; `ui key APP_SWITCH` and tap the SimpleX card in the recent apps (take a shot to find it; if recent apps don't show, `ui relaunch` and note it). Then type `vanish restart`, send it the same way with "1 minute", and at once `ui relaunch`; wait 70 s; open the chat "cibob". Check: after returning from the background `vanish bg` is gone; after the restart `vanish restart` is gone.


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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, S4, S5, R10.19, R10.20, R10.18, R10.27, R10.28, R10.21, R10.22, R10.24, R10.23, R10.37, R10.36, R10.38, R10.29, R10.39, R10.31, R10.32, R10.34, R10.33, R10.35, R10.40, R10.42, R10.43, R10.41, R11.1, R11.2, R10.30), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
