# Test: member reports, moderation of reported messages and mentions in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- All profiles are in this one app; messages between them go through the app's preset servers on the internet, so a message or an event can take a few seconds to arrive: use `ui wait "<text>" 60` before judging that it did not.

## How to do things in the app

- **Send a message:** tap the message field (placeholder "Message"), `ui type "<text>"`, then tap "Send Message". Check the message then shows in the chat.
- **The profile button** is your profile picture at the left end of the toolbar at the bottom of the chat list: in `ui text` it is the "profile image placeholder" element at about the same y as "Start new chat".
- **Switch profile:** tap the profile button; the menu lists your other profiles by name: tap the one you want. The chat list then shows that profile's chats.
- **Add a profile:** profile button → "Your chat profiles" → "Add profile". On "Create profile", tap the field just below "Enter your name:", type the name, tap "Create profile" (the lower one; the upper one is the title). The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Connect two profiles (a 1-time link):** as the inviting profile, "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link": right of the link text below it are two icons without labels; tap the first (the copy icon; `ui tree` lists it as an unlabeled clickable element at the same y as the link, left of the share icon). Do not tap the link text: it opens Android's share sheet (if it does, `ui key BACK`). `ui key BACK` until the chat list shows (if the alert "Keep unused invitation?" shows, tap "Keep"). Switch to (or add) the other profile, then "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the inviting profile with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. If an alert "Connect via one-time link?" shows instead, tap "Use current profile". Switch back to the inviting profile and wait up to 60 s until its chat list shows the other profile's name, and the chat with it shows no "connecting".
- **Group info:** in the group's chat, tap the group name at the top. `ui key BACK` closes it.
- **Message menu:** `ui long-press <x> <y>` on the message's text (centre from `ui find`) opens its menu.
- **Reporting** (only a member whose role is "member" can): long-press another member's message → "Report"; the alert "Report reason?" lists "Spam", "Inappropriate content", "Community guidelines violation", "Inappropriate profile" and "Another reason". After choosing, the compose area shows the reported message with a header such as "Report spam: only group moderators will see it.", and the field's placeholder is the reason. Type a comment if the case asks for one, then tap "Send Message". If the alert "Report sent to moderators" shows, tap "OK".

## The test

The steps build on each other: run them in this order. Profiles: `citester` (owns the group), `cibob`, `cicarol`. Group: `ci reports`. Take a shot at each check, named after its ID with `-` for `.` (`ui shot R44-45`).

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow"; Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) Connect citester with a new profile `cibob`, then citester with a new profile `cicarol` (each time citester creates the link, then the new profile is added and pastes it). Check: citester's chat list shows "cibob" and "cicarol".
3. (S3) As citester: "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type `ci reports` and tap "Create group". On "Invite members", tap "cibob" and "cicarol" to select them (the role under "New member role" stays "member"), then tap "Invite to group".
4. (S4) Switch to cibob, tap "ci reports" in the chat list: the alert "Join group?" offers "Join": tap it. Do the same as cicarol. Switch to citester, open "ci reports", and wait up to 60 s until the chat shows that both connected. Then as cibob in "ci reports" send `msg one`, `msg two`, `msg three`. Check: the three messages arrive in cicarol's and citester's chats.

**Reports.**

5. (R44.45) As cicarol in "ci reports": report "msg one" with "Spam" and the comment `spam comment`; report "msg two" with "Community guidelines violation" and no comment; report "msg three" with "Another reason": first check that with the field empty "Send Message" is disabled (`ui tree` shows its state; tapping it sends nothing), then type `other comment` and send. Check each time the compose header before sending ("Report spam: only group moderators will see it.", "Report violation: only group moderators will see it.", "Report other: only group moderators will see it."). Then switch to citester → "ci reports". Check: the top of the chat shows "3 reports"; group info → "Member reports" lists three reports, with "Spam" and "spam comment", "Community guidelines violation", and "Another reason" and "other comment". Switch to cibob → "ci reports". Check: no report shows in cibob's chat, and cibob's group info has no "Member reports".
6. (R44.46) As citester in "ci reports" (the group chat, not the reports): long-press "msg one" → "Moderate" → "Delete" in the alert "Delete member message?". Check: in place of "msg one" the chat shows "moderated by citester". Group info → "Member reports". Check: the "Spam" report on "msg one" now shows "archived report" (or is gone from the list), and the count at the top of the chat is now "2 reports".
7. (R44.47) In "Member reports", long-press the report on "msg two" → "Archive report" → in the alert "Archive report?" tap "For me". Then long-press the report on "msg three" → "Archive report" → "For all moderators". Check: both reports show "archived report" (or are gone from the list); the report count at the top of the group chat is gone; "msg two" and "msg three" still show in the group chat as normal messages.

**Mentions.**

8. (R44.48) Switch to cibob → "ci reports". Tap the message field, type `@`. Check: a list of members shows above the field with "citester" and "cicarol". Type `cic`. Check: the list now shows only "cicarol". Tap "cicarol". Check: the field shows "@cicarol". Type ` please look` and tap "Send Message". Check: the sent message shows "@cicarol please look".
9. (R44.49) Switch to cicarol (do not open the group yet). Check: the row "ci reports" in the chat list shows an "@" mark next to its unread count (`ui text` lists it as "Notifications" in that row). Open "ci reports". Check on a shot: in the message "@cicarol please look", "@cicarol" is drawn in the link colour (blue), unlike the rest of the text.

You have at most 600 turns, and the whole test fits in about 105 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click-text "Message" -- type "msg one" -- click-text "Send Message" -- type "msg two" -- click-text "Send Message" -- shot sent`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped.

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per step (S1 to S4, then each R case), each as PASS, FAIL or SKIPPED (with the reason) with its evidence (the text on screen, screenshot names), and anything else unexpected. A step the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
