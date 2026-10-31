# Test: user, contact and group preferences (part 2) in the SimpleX Chat Android app

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

- **Your preferences:** profile picker → "Chat preferences" → "Your preferences": one section per feature ("Disappearing messages" is a switch; "Delete for everyone", "Message reactions", "Voice messages", "Files and media", "Audio/video calls" are dropdowns with "always", "yes", "no"), then "Reset" and "Save and notify contacts". Each feature's footer describes the setting.
- **Contact preferences:** chat info → "Contact preferences": per feature a "You allow" dropdown ("default (…)", "always", "yes", "no") and the row "Contact allows"; a footer describes what is enabled; "Reset" and "Save and notify contact" at the bottom.
- **Group preferences:** group info → "Group preferences": per feature a switch for the owner (a value row for members), then "Reset" and "Save and notify group members"; the footer under each feature describes it. Leaving with unsaved changes asks "Save preferences?".
- **Preference events:** changing preferences adds events to the chat, such as "Voice messages: enabled for contact" or "offered Message reactions" (followed by "Accept" when you can enable it with a tap).
- **Incognito 1-time link:** "Start new chat" → "Create 1-time link"; under "Share profile" tap the row with your profile → "Select chat profile" → tap "Incognito" (the screen closes): the footer says "A new random profile will be shared.". Copy the link as usual.

## The test

The steps build on each other: run them in this order. Three profiles of this app take part: "citester", "cibob" and "cicarol"; citester is connected with cibob normally and with cicarol incognito (citester shares a random profile with cicarol), and owns the group "ci team" with cibob as a member. Messages and profile updates go through the app's preset servers on the internet: after switching profile, wait up to 30 s for an update from another profile.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before tapping it. The first screen has "Get started": tap it (if a What's new sheet covers it, close it first). Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profile `cibob`, then the profile `cicarol`; switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) Connect citester (A) and cibob (B) by a 1-time link. Switch to citester; create the group `ci team` (check that "Incognito" on the create screen is off), inviting cibob (role member); switch to cibob and join "ci team". Check: cibob has the chats "citester" and "ci team".
4. (R41.7) Open cibob's chat "citester" and scroll to its top. Check: the chat shows events for the chat features, created when the contact connected (for example "Message reactions: enabled"); note them all.
5. (S4) Switch to citester. Make an incognito 1-time link (see "Incognito 1-time link") and connect citester (A) with cicarol (B) by it. Then "Start new chat" → "Create 1-time link" again, set "Share profile" back to citester's own profile, and close it ("Keep" or "Delete" for the unused link are both fine). Check: cicarol has one new chat whose name is a random name (citester's incognito profile), not "citester"; citester's chat list shows a chat with "cicarol" marked with the incognito mask.

**Cases.**

6. (R41.2) As citester → chat "cibob" → chat info → "Contact preferences" → "Voice messages" → "You allow" "no"; tap "Reset"; set "You allow" "no" again → "Save and notify contact"; close it. Switch to cibob → chat "citester" → chat info → "Contact preferences". Check: "Reset" puts "You allow" back to its previous value; after saving, citester's chat shows one new event about voice messages and no events for other features (record this under R41.7: only changed preferences); on cibob "Voice messages" shows "Contact allows" "no".
7. (R41.6) As cibob (in "Contact preferences" for citester): read the footer of "Voice messages"; set its "You allow" to "always" → "Save and notify contact"; read the footer again. Switch to citester → chat "cibob" → "Contact preferences": read the footers of "Voice messages" and "Message reactions". Check: cibob before: "Voice messages are prohibited in this chat." (citester allows "no"); cibob after: "Only your contact can send voice messages."; citester: "Only you can send voice messages." and "Both you and your contact can add message reactions.".
8. (R41.8) As citester → "Contact preferences" for cibob → "Message reactions" "You allow" "no" → "Save and notify contact". Switch to cibob → chat "citester" → "Contact preferences" → "Message reactions" "You allow" "no" → save; then set it to "always" → save. Switch to citester → chat "cibob": tap "Accept" at the end of the event "offered Message reactions" (the event is one element in `ui text`: tap at the right end of its text, where "Accept" is drawn, judged from the screenshot). Check: citester's chat shows "offered Message reactions" with "Accept"; after the tap, the chat shows an event that message reactions are enabled, and citester's "Contact preferences" show "Message reactions" "You allow" "yes".
9. (R41.10) Switch to cibob → chat "citester" → "Contact preferences" → "Message reactions" "You allow" "no" → save. Switch to citester → chat "cibob": open the message menu of any message. Check: the menu has no reaction emoji row (reactions are not allowed); the chat shows an event that message reactions are off for citester.
10. (R41.9) Switch to cibob → chat "citester" → "Contact preferences" → "Audio/video calls" "You allow" "no" → save. Switch to citester → chat "cibob" → chat info → tap the "call" button once. Check: the alert "Calls prohibited!" says "Please ask your contact to enable calls." (no call starts).
11. (R41.1) As citester: profile picker → "Chat preferences" → "Files and media" → "no"; tap "Reset"; set "no" again → "Save and notify contacts". Switch to cibob → chat "citester" → "Contact preferences". Check: "Reset" restores the previous value; after saving, cibob's "Files and media" shows "Contact allows" "no".
12. (R41.4) Switch to cicarol → open the chat with citester's incognito profile → chat info → "Contact preferences". Check: "Files and media" still shows "Contact allows" "always" (the default), not "no": the incognito contact was not updated by citester's profile preferences.
13. (R41.3) Switch to citester → "ci team" → group info → "Group preferences" → turn "Message reactions" off; tap "Reset"; turn it off again → "Save and notify group members"; close it. Switch to cibob → "ci team". Check: "Reset" turns the switch back on; after saving, citester's chat shows "Message reactions: off" and cibob's "ci team" shows it too.
14. (R41.5) As cibob → "ci team" → group info → "Group preferences". Then switch to citester and open the same screen. Check: cibob sees values without switches, the footer "Only group owners can change group preferences." in group info, and member descriptions such as "Message reactions are prohibited."; citester sees switches with owner descriptions such as "Prohibit messages reactions." for the same feature.
15. (R41.11) As citester → "ci team" → "Group preferences" → turn "Files and media" off → "Save and notify group members". Switch to cibob → "ci team": tap the paperclip button ("Attach") left of the message field. Check: the group shows "Files and media: off"; on cibob the paperclip is grey and nothing can be attached. Record whether the tap shows the alert "Files and media prohibited!" ("Only group owners can enable files and media."); its absence is not a failure.

You have at most 600 turns, and the whole test fits in about 195 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, R41.7, S4, R41.2, R41.6, R41.8, R41.10, R41.9, R41.1, R41.4, R41.3, R41.5, R41.11), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
