# Test: replies, reactions, editing and deletion (part 1) in the SimpleX Chat Android app

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

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" that cibob and cicarol join. Messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`). When a step says "reopen the chat", do it as described under "Reopen a chat".

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before tapping it. The first screen has "Get started": tap it (if a What's new sheet covers it, close it first). Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link. Check: both chats show the encryption notice and a message field.
4. (S4) As cibob, in the chat "citester": send `bob one`, then `*bold* and _italic_`. Check: the second shows "bold" in bold and "italic" in italics, without `*` and `_`.

**Replies and reactions in the direct chat.**

5. (R8.1) Switch to citester → chat "cibob": open the message menu of `bob one` → "Reply", send `reply one`; reopen the chat. Check: `reply one` shows a quote of `bob one` above its text, also after reopening. (cibob's side is checked in R8.2.)
6. (R8.6) As citester: message menu of the message "bold and italic" → "Reply", send `markdown reply`. Check: the quote above `markdown reply` shows "bold" in bold and "italic" in italics, without `*` and `_` (judge from the screenshot). (cibob's side is checked in R8.2.)
7. (R8.2) As citester: send `own one`; its message menu → "Reply", send `quote own`; reopen the chat. Then switch to cibob → chat "citester" and reopen it. Check: on citester `quote own` quotes `own one`, also after reopening. On cibob after reopening: `reply one` quotes `bob one`, `markdown reply` quotes the formatted message, `quote own` quotes `own one`. Record the cibob results of R8.1 and R8.6 in their rows.
8. (R8.7) As cibob: message menu of `own one` (citester's) → 👍 (the first emoji of the menu's top row); message menu of `bob one` (cibob's own) → 👍. Then tap the 👍 reaction under `bob one`. Check: after adding, a 👍 reaction shows under each of the two messages; after tapping the one under `bob one`, it is gone there and stays under `own one`.
9. (R8.8) Switch to citester → chat "cibob": tap the 👍 reaction under `own one` (cibob's reaction). Check: before, 👍 has no count; after, the count "2" shows next to it.

**Editing in the direct chat.**

10. (R10.3) Switch to cibob → chat "citester": message menu of `quote own` → "Delete" → "Delete for me". Switch to citester → chat "cibob": edit `quote own` to `quote own edited`. Switch to cibob → chat "citester". Check: `quote own` disappears from cibob after the deletion; after citester's edit, `quote own edited` arrives on cibob as a new message at the bottom of the chat.
11. (R10.4) Switch to citester → chat "cibob": send `plain words`, then edit it to `now *bold*`. Check: citester shows "now bold" with "bold" in bold and an edited mark (a pencil icon next to the time, judged from the screenshot). (cibob's side is checked in R10.5.)
12. (R10.5) As citester: send `steady text`; message menu → "Edit" and, without changing the text, send it. Then switch to cibob → chat "citester". Check: no error alert; `steady text` has no edited mark on citester nor on cibob; on cibob `now bold` shows "bold" in bold with an edited mark (record this under R10.4).

**The group "ci team".**

13. (S5) Switch to citester. Connect citester (A) and cicarol (B) by a 1-time link. Check: cicarol's chat "citester" shows the encryption notice and a message field.
14. (S6) Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member); in its chat send `owner note`. Switch to cibob and join "ci team"; switch to cicarol and join "ci team". Check: cibob and cicarol each have "ci team" with an enabled message field and `owner note` in it (the group sends recent history to new members).
15. (S7) As cicarol in "ci team": message menu of `owner note` → 👍; send `carol note`. Switch to cibob → "ci team": message menu of `owner note` → 👍; send `group hello`. Check: the 👍 under `owner note` shows the count "2" on cibob.
16. (R8.4) Switch to cicarol → "ci team": message menu of `carol note` (her own) → "Reply", send `carol self quote`; reopen the chat. Check: `carol self quote` quotes `carol note`, also after reopening. (citester's and cibob's sides are checked in R8.3.)
17. (R8.3) Switch to citester → "ci team": message menu of `group hello` (cibob's) → "Reply", send `reply in group`; reopen the chat. Switch to cicarol → "ci team" and reopen it. Switch to cibob → "ci team" and reopen it. Check: on all three profiles after reopening, `reply in group` quotes `group hello`, and `carol self quote` quotes `carol note` (record the latter under R8.4 too).
18. (R8.9) Switch to citester → "ci team": `ui long-press` on the 👍 reaction under `owner note`; then tap "cibob" in the menu that opens. Check: the menu lists the members who reacted, cibob and cicarol; tapping cibob opens cibob's member info (name cibob, role member). Close it (`ui key BACK`).
19. (R10.1) As citester: in "ci team" edit `owner note` to `owner note edited`; in the chat "cibob" edit `own one` to `own one edited`. Switch to cibob: open "ci team", then the chat "citester". Check: on cibob "ci team" shows `owner note edited` and the chat "citester" shows `own one edited`, each with the edited mark (pencil icon next to the time).
20. (R10.6) As cibob: in the chat "citester" delete `bob one` (cibob's own) and `steady text` (received) with "Delete for me"; in "ci team" delete `group hello` (own) and `carol note` (cicarol's) with "Delete for me". Switch to citester: open the chat "cibob" and "ci team". Check: on cibob the four messages are gone; on citester `bob one` is still in the chat "cibob", and `group hello` and `carol note` are still in "ci team".
21. (R10.7) As citester: in the chat "cibob" send `bye direct`, then delete it: "Delete" → "For everyone"; in "ci team" send `bye group` and delete it the same way. Switch to cibob: open the chat "citester", then the deleted message's menu → "Reveal"; open "ci team" and do the same. Check: on citester each deleted message shows "marked deleted"; on cibob each shows "marked deleted" in place of its text, and after "Reveal" its text (`bye direct`, `bye group`) shows again.
22. (R10.8) As cibob in the chat "citester": message menu of `bye direct` (deleted by citester) → "Delete" → "Delete for me". Check: the message is gone from cibob's chat.

**Moderation in "ci team".**

23. (R10.9) As cibob in "ci team": send `spam one`. Switch to citester → "ci team": message menu of `spam one` → "Moderate". Check: the alert "Delete member message?" says "The message will be marked as moderated for all members."; click "Delete"; `spam one` then shows "moderated by citester" in place of its text.
24. (R10.10) Switch to cicarol → "ci team". Check: `spam one` shows "moderated by citester" in place of its text.
25. (R10.11) As cicarol: message menu of the moderated `spam one` → "Reveal". Switch to citester → "ci team" → group info → "Group preferences" → turn "Delete for everyone" on → "Save and notify group members"; close the preferences. Switch to cibob → "ci team": send `spam two`. Switch to citester: message menu of `spam two` → "Moderate" → "Delete". Switch to cicarol → "ci team": open the message menu of `spam two`. Check: with the preference off, "Reveal" shows `spam one`'s text; after it is on, the "Moderate" alert says "The message will be deleted for all members."; on cicarol `spam two` shows "moderated by citester" and its menu has no "Reveal".
26. (R10.12) As cicarol: message menu of `spam two` → "Delete" → "Delete for me". Check: the moderated message is gone from cicarol's chat.

You have at most 600 turns, and the whole test fits in about 310 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, S4, R8.1, R8.6, R8.2, R8.7, R8.8, R10.3, R10.4, R10.5, S5, S6, S7, R8.4, R8.3, R8.9, R10.1, R10.6, R10.7, R10.8, R10.9, R10.10, R10.11, R10.12), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
