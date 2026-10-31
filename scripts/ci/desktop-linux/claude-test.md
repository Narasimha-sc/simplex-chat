# Test: member reports, moderation of reported messages and mentions in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730. The toolbar is at the bottom of the left pane.
- All profiles are in this one app; messages between them go through the app's preset servers on the internet, so a message or an event can take a few seconds to arrive: use `ui wait "<text>" 60` before judging that it did not.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`. Check the message then shows in the chat.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want. The chat list then shows that profile's chats.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Connect two profiles (a 1-time link):** as the inviting profile, the pencil → "Create 1-time link". Wait for "Share this 1-time invite link" and click the link text just below it: the toast "Copied to clipboard" shows. Press Escape until the chat list shows (if the alert "Keep unused invitation?" shows, click "Keep"). Switch to (or add) the other profile, then the pencil → "Paste link" → "Tap to paste link". An alert names the inviting profile with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. If an alert "Connect via one-time link?" shows instead, click "Use current profile". Switch back to the inviting profile and wait up to 60 s until its chat list shows the other profile's name, and the chat with it shows no "connecting".
- **Group info:** in the group's chat, click the group name at the top of the right pane. Press Escape to close panes and alerts and get back to the chat.
- **Message menu:** `ui right-click <x> <y>` on the message's text (centre from `ui find`) opens its menu.
- **Reporting** (only a member whose role is "member" can): right-click another member's message → "Report"; the alert "Report reason?" lists "Spam", "Inappropriate content", "Community guidelines violation", "Inappropriate profile" and "Another reason". After choosing, the compose area shows the reported message with a header such as "Report spam: only group moderators will see it.", and the field's placeholder is the reason. Type a comment if the case asks for one, then press Return. If the alert "Report sent to moderators" shows, click "OK".

## The test

The steps build on each other: run them in this order. Profiles: `citester` (owns the group), `cibob`, `cicarol`. Group: `ci reports`. Take a shot at each check, named after its ID with `-` for `.` (`ui shot R44-45`).

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Connect citester with a new profile `cibob`, then citester with a new profile `cicarol` (each time citester creates the link, then the new profile is added and pastes it). Check: citester's chat list shows "cibob" and "cicarol".
3. (S3) As citester: the pencil → "Create group". Click the field about 40 px below the text "Enter group name", type `ci reports`, and click "Create group". On the next pane ("Invite members"), click "cibob" and "cicarol" to select them (the role under "New member role" stays "member"), then click "Invite to group".
4. (S4) Switch to cibob, click "ci reports" in the chat list: the alert "Join group?" offers "Join": click it. Do the same as cicarol. Switch to citester, open "ci reports", and wait up to 60 s until the chat shows that both connected. Then as cibob in "ci reports" send `msg one`, `msg two`, `msg three`. Check: the three messages arrive in cicarol's and citester's chats.

**Reports.**

5. (R44.45) As cicarol in "ci reports": report "msg one" with "Spam" and the comment `spam comment`; report "msg two" with "Community guidelines violation" and no comment; report "msg three" with "Another reason": first check that with the field empty the report is not sent (Return does nothing, the send button stays disabled), then type `other comment` and send. Check each time the compose header before sending ("Report spam: only group moderators will see it.", "Report violation: only group moderators will see it.", "Report other: only group moderators will see it."). Then switch to citester → "ci reports". Check: the top of the chat shows "3 reports"; group info → "Member reports" lists three reports, with "Spam" and "spam comment", "Community guidelines violation", and "Another reason" and "other comment". Switch to cibob → "ci reports". Check: no report shows in cibob's chat, and cibob's group info has no "Member reports".
6. (R44.46) As citester in "ci reports" (the group chat, not the reports): right-click "msg one" → "Moderate" → "Delete" in the alert "Delete member message?". Check: in place of "msg one" the chat shows "moderated by citester". Group info → "Member reports". Check: the "Spam" report on "msg one" now shows "archived report" (or is gone from the list), and the count at the top of the chat is now "2 reports".
7. (R44.47) In "Member reports", right-click the report on "msg two" → "Archive report" → in the alert "Archive report?" click "For me". Then right-click the report on "msg three" → "Archive report" → "For all moderators". Check: both reports show "archived report" (or are gone from the list); the report count at the top of the group chat is gone; "msg two" and "msg three" still show in the group chat as normal messages.

**Mentions.**

8. (R44.48) Switch to cibob → "ci reports". Click the message field, type `@`. Check: a list of members shows above the field with "citester" and "cicarol". Type `cic`. Check: the list now shows only "cicarol". Click "cicarol". Check: the field shows "@cicarol". Type ` please look` and press Return. Check: the sent message shows "@cicarol please look".
9. (R44.49) Switch to cicarol (do not open the group yet). Check: the row "ci reports" in the chat list shows an "@" mark next to its unread count. Open "ci reports". Check on a shot: in the message "@cicarol please look", "@cicarol" is drawn in the link colour (blue), unlike the rest of the text.

You have at most 600 turns, and the whole test fits in about 105 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click-text "Message" -- type "msg one" -- key Return -- type "msg two" -- key Return -- type "msg three" -- key Return -- shot sent`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per step (S1 to S4, then each R case), each as PASS, FAIL or SKIPPED (with the reason) with its evidence (the text OCR read, screenshot names), and anything else unexpected. A step the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
