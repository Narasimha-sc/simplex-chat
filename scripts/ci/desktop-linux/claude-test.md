# Test: user, contact and group preferences (part 2) in the SimpleX Chat desktop app

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

- **Your preferences:** profile picker → "Chat preferences" → "Your preferences": one section per feature ("Disappearing messages" is a switch; "Delete for everyone", "Message reactions", "Voice messages", "Files and media", "Audio/video calls" are dropdowns with "always", "yes", "no"), then "Reset" and "Save and notify contacts". Each feature's footer describes the setting.
- **Contact preferences:** chat info → "Contact preferences": per feature a "You allow" dropdown ("default (…)", "always", "yes", "no") and the row "Contact allows"; a footer describes what is enabled; "Reset" and "Save and notify contact" at the bottom.
- **Group preferences:** group info → "Group preferences": per feature a switch for the owner (a value row for members), then "Reset" and "Save and notify group members"; the footer under each feature describes it. Leaving with unsaved changes asks "Save preferences?".
- **Preference events:** changing preferences adds events to the chat, such as "Voice messages: enabled for contact" or "offered Message reactions" (followed by "Accept" when you can enable it with a click).
- **Incognito 1-time link:** the pencil (about 363,730) → "Create 1-time link"; under "Share profile" click the row with your profile → "Select chat profile" → click "Incognito" (the screen closes): the footer says "A new random profile will be shared.". Copy the link as usual.

## The test

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; citester is connected with cibob normally and with cicarol incognito (citester shares a random profile with cicarol), and owns the group "ci team" with cibob as a member. Messages and profile updates go through the app's preset servers on the internet: after switching profile, wait up to 30 s for an update from another profile.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link. Switch to citester; create the group `ci team` (check that "Incognito" on the create screen is off), inviting cibob (role member); switch to cibob and join "ci team". Check: cibob has the chats "citester" and "ci team".
4. (R41.7) Open cibob's chat "citester" and scroll to its top. Check: the chat shows events for the chat features, created when the contact connected (for example "Message reactions: enabled"); note them all.
5. (S4) Switch to citester. Make an incognito 1-time link (see "Incognito 1-time link") and connect citester (A) with cicarol (B) by it. Then the pencil (about 363,730) → "Create 1-time link" again, set "Share profile" back to citester's own profile, and close it ("Keep" or "Delete" for the unused link are both fine). Check: cicarol has one new chat whose name is a random name (citester's incognito profile), not "citester"; citester's chat list shows a chat with "cicarol" marked with the incognito mask.

**Cases.**

6. (R41.2) As citester → chat "cibob" → chat info → "Contact preferences" → "Voice messages" → "You allow" "no"; click "Reset"; set "You allow" "no" again → "Save and notify contact"; close it. Switch to cibob → chat "citester" → chat info → "Contact preferences". Check: "Reset" puts "You allow" back to its previous value; after saving, citester's chat shows one new event about voice messages and no events for other features (record this under R41.7: only changed preferences); on cibob "Voice messages" shows "Contact allows" "no".
7. (R41.6) As cibob (in "Contact preferences" for citester): read the footer of "Voice messages"; set its "You allow" to "always" → "Save and notify contact"; read the footer again. Switch to citester → chat "cibob" → "Contact preferences": read the footers of "Voice messages" and "Message reactions". Check: cibob before: "Voice messages are prohibited in this chat." (citester allows "no"); cibob after: "Only your contact can send voice messages."; citester: "Only you can send voice messages." and "Both you and your contact can add message reactions.".
8. (R41.8) As citester → "Contact preferences" for cibob → "Message reactions" "You allow" "no" → "Save and notify contact". Switch to cibob → chat "citester" → "Contact preferences" → "Message reactions" "You allow" "no" → save; then set it to "always" → save. Switch to citester → chat "cibob": click "Accept" at the end of the event "offered Message reactions" (OCR reads "Accept" as its own word: click it). Check: citester's chat shows "offered Message reactions" with "Accept"; after the click, the chat shows an event that message reactions are enabled, and citester's "Contact preferences" show "Message reactions" "You allow" "yes".
9. (R41.10) Switch to cibob → chat "citester" → "Contact preferences" → "Message reactions" "You allow" "no" → save. Switch to citester → chat "cibob": open the message menu of any message. Check: the menu has no reaction emoji row (reactions are not allowed); the chat shows an event that message reactions are off for citester.
10. (R41.9) Switch to cibob → chat "citester" → "Contact preferences" → "Audio/video calls" "You allow" "no" → save. Switch to citester → chat "cibob" → chat info → click the "call" button once. Check: the alert "Calls prohibited!" says "Please ask your contact to enable calls." (no call starts).
11. (R41.1) As citester: profile picker → "Chat preferences" → "Files and media" → "no"; click "Reset"; set "no" again → "Save and notify contacts". Switch to cibob → chat "citester" → "Contact preferences". Check: "Reset" restores the previous value; after saving, cibob's "Files and media" shows "Contact allows" "no".
12. (R41.4) Switch to cicarol → open the chat with citester's incognito profile → chat info → "Contact preferences". Check: "Files and media" still shows "Contact allows" "always" (the default), not "no": the incognito contact was not updated by citester's profile preferences.
13. (R41.3) Switch to citester → "ci team" → group info → "Group preferences" → turn "Message reactions" off; click "Reset"; turn it off again → "Save and notify group members"; close it. Switch to cibob → "ci team". Check: "Reset" turns the switch back on; after saving, citester's chat shows "Message reactions: off" and cibob's "ci team" shows it too.
14. (R41.5) As cibob → "ci team" → group info → "Group preferences". Then switch to citester and open the same screen. Check: cibob sees values without switches, the footer "Only group owners can change group preferences." in group info, and member descriptions such as "Message reactions are prohibited."; citester sees switches with owner descriptions such as "Prohibit messages reactions." for the same feature.
15. (R41.11) As citester → "ci team" → "Group preferences" → turn "Files and media" off → "Save and notify group members". Switch to cibob → "ci team": click the paperclip button ("Attach") left of the message field. Check: the group shows "Files and media: off"; on cibob the paperclip is grey and nothing can be attached. Record whether the click shows the alert "Files and media prohibited!" ("Only group owners can enable files and media."); its absence is not a failure.

You have at most 600 turns, and the whole test fits in about 185 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, R41.7, S4, R41.2, R41.6, R41.8, R41.10, R41.9, R41.1, R41.4, R41.3, R41.5, R41.11), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
