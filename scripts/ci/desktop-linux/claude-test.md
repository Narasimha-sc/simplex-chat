# Test: link previews (part 2) in the SimpleX Chat desktop app

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

- **Link preview in the compose area:** about 1.5 s after a link is typed the app fetches its preview; the first time it asks with the alert "Enable link previews?" ("Disable" / "Enable"). While fetching, a spinner shows above the message field; then the preview (image, page title, link) with a cancel button (an x at its right; OCR can't read it: find it on the screenshot).

## The test

The steps build on each other: run them in this order. Two profiles of this app take part, "citester" and "cibob", connected by a 1-time link. Link previews are fetched from the internet. After switching profile, wait up to 30 s for a message from the other profile (`ui wait "<text>" 30`).

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profile `cibob`; switch back to citester. Connect citester (A) and cibob (B) by a 1-time link. Switch to citester and open the chat "cibob". Check: both chats show the encryption notice and a message field.
3. (R11.5) Type `https://example.com`; wait 3 s; when the alert "Enable link previews?" shows, click "Enable" and at once take two shots one after the other. Check: the alert offers "Disable" and "Enable"; one of the two shots shows a spinner above the message field before the preview appears. A missed spinner is not a failure (it is brief): PASS only if a shot shows it, otherwise SKIPPED with that reason.
4. (R11.4) Wait up to 20 s for the preview of example.com ("Example Domain"); click its cancel button; send the message. Check: the preview disappears from the compose area after the click; the sent message shows the link text without a preview card.
5. (R11.3) Type `https://example.com/` and wait up to 20 s for its preview; send. Switch to cibob → chat "citester" and look at the message. Switch to citester → chat "cibob": edit the message to `https://www.iana.org/about`, wait up to 20 s until the compose area shows the new preview, and send the edit. Switch to cibob; look at the message. Switch to citester: edit the message to `no link now` and send the edit. Switch to cibob; look at the message. Check: cibob first shows the message with the "Example Domain" preview; after the first edit, the preview on cibob changes to the iana.org page's preview; after the second edit, cibob shows `no link now` without a preview.

You have at most 600 turns, and the whole test fits in about 65 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, R11.5, R11.4, R11.3), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
