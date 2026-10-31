# Test: live and disappearing messages, message info, link previews (part 1) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons or emoji; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop` (except in R10.30, as it says). Begin with `ui shot start` to see it.
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

- **Live message from an empty field:** while the message field is empty, a lightning button shows right of the microphone at the right end of the field (OCR can't read icons: find it on the screenshot); click it. The first time, the alert "Live message!" asks to confirm with "Send". Then type: the message is sent at once and updated about every 3 s while you type; the send button turns into a checkmark; click it to finish the live message.
- **Send button menu:** with text (or an attachment) in the compose area, `ui right-click` on the send button at the right end of the field opens its menu: "Send live message" and "Disappearing message". "Disappearing message" opens a menu headed "Send disappearing message" with "30 seconds", "1 minute", "5 minutes" and "Custom time"; "Custom time" opens the dialog "Delete after" with a "Send" button below two dropdowns for the number and the unit (seconds, minutes, hours, days, weeks, months); click each and pick the value.
- **Timer mark:** a disappearing message shows a timer icon next to its time; when its time differs from the chat's timer it also shows the time in short form ("30s", "5m", "2h", "12mth").
- **Message info:** message menu → "Info" opens the message's details titled "Sent message" or "Received message", with "Sent at" / "Received at", "Disappears at" for a disappearing message, "File servers" for a file, "Share" and "Copy", and tabs at the bottom such as "History", "In reply to" and "Delivery". Close it with Escape.
- **Attaching the test card:** click the paperclip (about 415,730, left of the message field) → "Image"; in the file dialog click its "File Name" field, type the absolute path of `images/test-card.jpg` in your working directory and press Return. The compose area then shows the image above the field (a TV test card: colour bars, "1080" at the top).
- **Waiting a fixed time:** `ui wait "<a text that never shows>" <secs>` returns after <secs> seconds; its "not on screen" result is expected there.

## The test

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" that both join. The chat citester–cibob has no chat-level timer; the chat citester–cicarol gets one in R10.39. Messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link; then, as cibob in the chat "citester", send `bob hi`. Check: citester's chat "cibob" shows `bob hi`.
4. (S4) Switch to citester. Connect citester (A) and cicarol (B) by a 1-time link. Check: cicarol's chat "citester" shows the encryption notice and a message field.
5. (S5) Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member). Switch to cibob and join "ci team"; switch to cicarol and join "ci team". Check: cibob and cicarol each have "ci team" with an enabled message field.

**Live messages (chat citester–cibob).**

6. (R10.19) Switch to citester → chat "cibob". With the message field empty, click the lightning button. Check: the alert "Live message!" says "Send a live message - it will update for the recipient(s) as you type it" and offers "Send"; click "Send".
7. (R10.20) Continue the live message: type `live hello`; wait 5 s; take two shots a second apart. Then open the live message's menu and look at its items; close the menu. Check: the live message shows the header "LIVE" and animated dots after its text (the typing indicator); its menu has no "Edit", no "Delete" and no "Reply" (record this under R10.22, R10.23 and R10.24 too). The recipient's side cannot be watched while citester types (one app): that part is not checked.
8. (R10.18) Continue: type ` world`; wait 5 s; click the send button (a checkmark) to finish. Check: the message shows `live hello world` without the "LIVE" header. (The recipient is checked in R10.21.)
9. (R10.27) Type `typed then live` (do not send), `ui right-click` on the send button → "Send live message". Type ` more`, wait 5 s, click the checkmark. Check: no alert this time; while live the message shows "LIVE"; finished, it reads `typed then live more`.
10. (R10.28) Attach the test card; `ui right-click` on the send button → "Send live message"; type `live with image`; wait 5 s; click the checkmark. Check: the menu offers "Send live message" with an image attached; the chat then shows the image with the text `live with image`.
11. (R10.21) Switch to cibob → chat "citester". Check: cibob shows `live hello world`, `typed then live more` and the image with `live with image` (record these under R10.18, R10.27 and R10.28), each without "LIVE" and without an edited mark (pencil icon); citester's copies had no edited mark either.
12. (R10.22) Switch to citester → chat "cibob": edit `live hello world` to `live edited`. Check: after the live message was finished, "Edit" is in its menu and the edit works: `live edited` shows with an edited mark. (While live, "Edit" was absent: R10.20.)
13. (R10.24) Message menu of `live edited` → "Reply", send `quote live`. Check: `quote live` shows a quote of `live edited`. (While live, "Reply" was absent.)
14. (R10.23) Message menu of `typed then live more` → "Delete" → "Delete for me". Check: the message is gone. (While live, "Delete" was absent.)

**Disappearing messages.**

15. (R10.37) As citester: chat "cibob" → chat info → "Contact preferences": look at "Disappearing messages"; close it. Type `custom check`, `ui right-click` on the send button. Check: "You allow" is on and "Delete after" is "off" (no chat timer), messages sent normally (`bob hi`, `quote live`) have no timer icon, and the send button's menu still offers "Disappearing message".
16. (R10.36) Continue: "Disappearing message" → "Custom time" → set 2 and "minutes" → "Send". Check: `custom check` shows the timer icon and "2m".
17. (R10.38) Type `year message`, `ui right-click` on the send button → "Disappearing message" → "Custom time" → set "months" and 12 → "Send". Message menu of `year message` → "Info". Check: the message shows "12mth"; its info shows "Disappears at" about 360 days after "Sent at".
18. (R10.29) Type `vanish 30`, `ui right-click` on the send button → "Disappearing message" → "30 seconds". Wait 40 s. Then switch to cibob → chat "citester"; wait 40 s. Check: on citester `vanish 30` shows the timer and "30s", then is gone after 40 s; on cibob it shows when the chat is opened (read), then is gone 30–40 s later.
19. (R10.39) Switch to citester → chat "cicarol" → chat info → "Contact preferences" → "Disappearing messages": "You allow" on, "Delete after" → "custom" → set 2 and "hours" → "Select" → "Save and notify contact"; close it. Then "ci team" → group info → "Group preferences" → turn "Disappearing messages" on → "Delete after" → "custom" → set 3 and "hours" → "Select" → "Save and notify group members"; close it. Check: "Delete after" shows "2 hours" for the contact and "3 hours" for the group; the chat "cicarol" shows the event "Disappearing messages: 2 hours" and "ci team" shows "Disappearing messages: 3 hours".
20. (R10.31) Chat "cicarol": send `default ttl` normally; type `custom ttl`, `ui right-click` on the send button → "Disappearing message" → "5 minutes". Check: `default ttl` shows the timer icon without a time text (it uses the chat's 2 hours); `custom ttl` shows the timer icon and "5m".
21. (R10.32) Edit `custom ttl` to `custom ttl edited` (within 5 minutes of sending it). Check: the text changes and the message keeps the timer icon and "5m", with an edited mark.
22. (R10.34) Message menu of `custom ttl edited` → "Reply", send `quote timed`. Check: `quote timed` shows a quote of `custom ttl edited` and the timer icon.
23. (R10.33) Message menu of `default ttl` → "Delete" → "Delete for me". Check: `default ttl` is gone.
24. (R10.35) With the field empty click the lightning button; type `live timed`; wait 5 s; its message menu → "Info"; close it; click the checkmark to finish; message menu → "Info" again. Check: while live, the info has no "Disappears at"; after finishing, it shows "Disappears at" about 2 hours after "Sent at".

**Message info.**

25. (R10.40) Chat "cibob": message menu of `live edited` (own, edited) → "Info"; the "History" tab; click "Copy"; close. Message menu of `bob hi` (cibob's) → "Info"; close. Check: own: title "Sent message", "Sent at", and under "History" two versions (`live edited` marked "(current)", and `live hello world`); "Copy" works without an error. Other's: title "Received message", with "Sent at" and "Received at".
26. (R10.42) Message menu of `quote live` → "Info" → the "In reply to" tab. Check: it shows the quoted message `live edited`.
27. (R10.43) Message menu of the image with `live with image` → "Info". Check: it shows "File servers" with at least one server host name.
28. (R10.41) "ci team": send `status check`; wait 30 s; its message menu → "Info" → the "Delivery" tab. Check: the tab lists cibob and cicarol, each with a delivery status icon.

**Link previews (chat citester–cibob).**

29. (R11.1) Chat "cibob": type `https://example.com`; wait up to 10 s; if the alert "Enable link previews?" shows, click "Enable"; wait up to 20 s for the preview above the field; send. Reopen the chat. Switch to cibob → chat "citester", reopen it. Check: before sending, the compose area shows a preview with the page title "Example Domain"; the sent message shows the preview on citester and on cibob, also after reopening.
30. (R11.2) Switch to citester → chat "cibob": `ui do click-text "Message" -- type "https://www.iana.org/about" -- key Return`, one chain, so it is sent before a preview appears. Check: the message is sent without a link preview. If a preview was attached anyway (it loaded before sending), mark SKIPPED: the timing cannot be controlled here.

**Disappearing message and restart (last).**

31. (R10.30) Chat "cibob": type `vanish after restart`, `ui right-click` on the send button → "Disappearing message" → "1 minute". At once restart the app. This is the only step where `ui stop` and `ui start` are allowed: `ui stop`, then `ui start <app dir>`, where <app dir> is the folder `app/simplex` next to your working directory, written out in full (your working directory is `<temp>/claude-test`, so the app is `<temp>/app/simplex`, for example `/home/runner/work/_temp/app/simplex`; the helper refuses `$` and `~`). `ui start` waits for the app's window; the app keeps its data and opens with the last active profile. If `ui start` fails, record its output, mark the step SKIPPED and end the test. Wait 70 s; open the chat "cibob". Check: after the restart the message is gone once its minute has passed. (Returning from background cannot be tested on desktop.)


You have at most 600 turns, and the whole test fits in about 330 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, S4, S5, R10.19, R10.20, R10.18, R10.27, R10.28, R10.21, R10.22, R10.24, R10.23, R10.37, R10.36, R10.38, R10.29, R10.39, R10.31, R10.32, R10.34, R10.33, R10.35, R10.40, R10.42, R10.43, R10.41, R11.1, R11.2, R10.30), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
