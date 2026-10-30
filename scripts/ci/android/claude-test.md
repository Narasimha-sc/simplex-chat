# Test: replies, reactions, editing and deletion (part 2): roles, irreversible deletion, deleting several messages in the SimpleX Chat Android app

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

## The test

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" where cibob is an admin and cicarol a member. Messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

Selecting messages: message menu → "Select"; a selection mark shows next to each message, the title reads "Selected 1", and a toolbar of three icon buttons without text replaces the message field: delete (a trash can, at the left), moderate (a flag, in the middle; shown only to moderators and above) and forward (at the right). Tap other messages to add them to the selection. Deleting asks "Delete <n> messages?"; moderating asks "Delete <n> messages of members?".

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before tapping it. The first screen has "Get started": tap it (if a What's new sheet covers it, close it first). Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link; switch to citester and connect citester (A) and cicarol (B) the same way. Check: cibob and cicarol each have a chat "citester" with the encryption notice and a message field.
4. (S4) Switch to citester. Create the group `ci team`: on the invite screen set "New member role" to "admin", select cibob and tap "Invite to group". In the group: group info → "Invite members" → set "New member role" to "member", select cicarol → "Invite to group". Send `owner msg` in the group. Switch to cibob and join "ci team"; switch to cicarol and join "ci team". Check: cibob and cicarol each have "ci team" with an enabled message field and `owner msg` in it; citester's group info lists cibob with the role admin and cicarol with member.
5. (S5) As cicarol in "ci team": send `member msg`. Switch to cibob → "ci team": send `admin msg`. Check: both show as sent.

**Cases.**

6. (R10.13) As cibob (admin) in "ci team": open the message menu of `owner msg` (citester is the owner) and close it; open the message menu of `member msg` (cicarol is a member) and close it without choosing. Check: the menu of `owner msg` has no "Moderate"; the menu of `member msg` has "Moderate".
7. (R10.14) Switch to citester → chat "cibob" → chat info → "Contact preferences" → in the section "Delete for everyone" set "You allow" to "yes" → "Save and notify contact". Switch to cibob → chat "citester" → the same: "You allow" "yes" → "Save and notify contact". Switch to citester → chat "cibob": send `vanish direct`, message menu → "Delete". Check: the alert "Delete message?" says "Message will be deleted - this cannot be undone!"; tap "For everyone". Switch to cibob → chat "citester". Check: `vanish direct` is gone from both chats, with no "marked deleted" item left on cibob.
8. (S6) As cibob in the chat "citester": send `bob 1`. Switch to citester → chat "cibob": send `own 1`, `own 2`, `own 3`. Check: all show in citester's chat.
9. (R10.16) As citester in the chat "cibob": message menu of `bob 1` → "Select"; tap `own 1` to add it; tap the delete button. Check: the alert "Delete 2 messages?" offers only "Delete for me" (a received message is selected).
10. (R10.15) Continue: tap "Delete for me". Then select `own 2` and `own 3` (message menu of `own 2` → "Select", tap `own 3`), tap the delete button and choose "For everyone". Switch to cibob → chat "citester". Then switch to citester → "ci team": select `member msg` and `admin msg` (message menu → "Select", tap the other), tap the moderate button → "Delete" in the alert "Delete 2 messages of members?". Switch to cicarol → "ci team". Check: local: `bob 1` and `own 1` are gone from citester and still on cibob; for recipient: the alert for `own 2` and `own 3` offers "For everyone", and afterwards both are gone on citester and on cibob; moderation: on citester and on cicarol `member msg` and `admin msg` show "moderated by citester".
11. (R10.17) As cicarol in "ci team": send `member msg 2`. Switch to citester → "ci team": send `owner msg 2`; select `owner msg 2` (own) and `member msg 2` (message menu → "Select", tap the other); tap the moderate button → "Delete". Switch to cicarol → "ci team". Check: the moderate button is enabled with an own message in the selection; the alert says "Delete 2 messages of members?"; afterwards both messages show as deleted on citester and on cicarol ("moderated by citester" or "marked deleted" in place of their text).

You have at most 600 turns, and the whole test fits in about 170 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, S4, S5, R10.13, R10.14, S6, R10.16, R10.15, R10.17), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
