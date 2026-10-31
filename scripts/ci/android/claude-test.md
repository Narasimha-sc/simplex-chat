# Test: incognito in groups, contact aliases, group links (part 2) in the SimpleX Chat Android app

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

- **Incognito is remembered app-wide:** the last profile choice (Incognito or not) becomes the default of every new 1-time link, every new chat opened from a link and the group creation screen. Before each such step, check which profile it shows and set the one the step asks for.
- **Profile of a new 1-time link:** under "Share profile" a row shows the profile that the link shares ("Incognito" or the profile name); tap it → "Select chat profile" → tap "Incognito" or your own profile (the screen closes). With Incognito the footer says "A new random profile will be shared.".
- **Profile of a chat opened from a link:** above its "Connect" or "Join group" button, the section "Your profile" shows the profile that will be used; tap it to list the choices ("Incognito" and the profiles) and tap one.
- **Group with incognito:** the create group screen has the switch "Incognito" below "Create group".
- **SimpleX address:** profile picker → "Create SimpleX address" → "Create SimpleX address". The address shows with "Share address": tap it → Android's share sheet → its copy button (see "System share sheet"). Later the profile picker shows "Your SimpleX address" instead.
- **Contact request, requester's side:** pasting an address shows an alert with "Open new chat"; the chat opens with an "Add message" field and a "Connect" button: tap "Connect"; if the alert "Send contact request?" shows, tap "Send request without message".
- **Contact request, address owner's side:** the request shows in the chat list under the requester's name. `ui long-press` on the row to get its menu ("Accept", "Reject"); or tap the row: the chat opens with "Reject" and "Accept" at the bottom.
- **Group link:** group info → "Create group link" → the link is created and shown with "Share link": tap it → Android's share sheet → its copy button (see "System share sheet"). Pasting a group link (as for a 1-time link) shows an alert with the group's name, "Open group" and "Cancel"; "Open group" opens the group's chat, not yet joined, with a "Join group" button at the bottom.
- **Pasting a link into the message field:** `ui long-press` on the message field and tap "Paste" in Android's text menu (read it with `ui text`).
- **A link inside a message** shows as "SimpleX group link" (or as a card with the group's name): tap it to get the same alert as when pasting.
- **Member info:** group info → tap the member's row.
- **Incognito marks:** an incognito chat shows a mask icon next to its name in the chat list and in the chat's top bar; its chat info has the section "Incognito" with "Your random profile" and the random name.
- **Chat console:** Settings → the app version row at the bottom of "Advanced settings" (it starts with "v") → "Developer tools" → "Chat console". Type a command into its field and send it; the answer shows above. Close it with `ui key BACK`.
- **Developer options:** the same "Developer tools" screen has the switch "Show developer options"; with it on, link screens show a "Full link" / "Short link" button above the QR code that switches the shared link's form.
- **Searching chats:** tap the search field "Search or paste SimpleX link" above the chat list and type; the list shows the matching chats. Clear the field before the next search.
- **The chat's top bar menu:** the "More" button at the right end of a chat's top bar (its description is "More") opens a menu.

## The test

The steps build on each other: run them in this order. Four profiles of this app take part, "citester", "cibob", "cicarol" and "cidan" (created in this order). citester is connected with cibob (cibob incognito), with cicarol (citester incognito) and with cidan (both with their own profiles), and owns the groups "ci team", "ci incog" (created incognito) and "ci links". A profile shared incognito shows to the other side under a random name. Connections go through the app's preset servers on the internet: after switching profile, wait up to 60 s for a connection or message from another profile.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before tapping it. The first screen has "Get started": tap it (if a What's new sheet covers it, close it first). Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profiles `cibob`, `cicarol` and `cidan`, in this order; switch to citester. Check: citester's profile menu lists the three profiles.
3. (S3) As citester: 1-time link with the profile "citester" → copy. Switch to cibob: paste → "Open new chat" → "Your profile" → "Incognito" → "Connect"; wait. Then, still as cibob, reset the remembered choice: "Start new chat" → "Create 1-time link" → profile "cibob"; close ("Delete" if asked). Check: citester's new chat has a random name (cibob incognito); cibob's chat "citester" shows the mask icon.
4. (S4) Switch to citester: 1-time link with the profile "Incognito" → copy. Switch to cicarol: paste → "Open new chat" → "Your profile" "cicarol" → "Connect"; wait. Switch to citester: reset the remembered choice ("Start new chat" → "Create 1-time link" → "citester"; close, "Delete" if asked). Check: citester's chat "cicarol" shows the mask icon; cicarol's new chat has a random name.
5. (S5) As citester: 1-time link with "citester" → copy. Switch to cidan: paste → "Open new chat" → "Your profile" "cidan" → "Connect"; wait. Check: citester has the chat "cidan"; cidan has "citester".

**Incognito in groups.**

6. (R55.24) Switch to citester. Create the group `ci team` ("Incognito" off), inviting cibob's random-named contact and cidan (role member). Switch to cibob → chat "citester": tap "Tap to join incognito"; open "ci team" → group info; then the chat "citester" → chat info. Switch to cidan: join "ci team". Switch to citester → "ci team" → group info. Check: cibob's "ci team" group info shows "Incognito" with "Your random profile" and the same random name as cibob's chat info for citester; citester's member list shows cibob under that random name (the same as citester's contact name for cibob).
7. (R55.25) As citester → "ci team" → group info → "Invite members" → tap the row "cicarol". Check: the alert "Can't invite contact!" says "You're trying to invite contact with whom you've shared an incognito profile to the group in which you're using your main profile"; tap "OK" and close.
8. (R55.27) Switch to cibob → "ci team": send `incog one`; its message menu → "Reply", send `incog self reply`. Switch to citester → "ci team": message menu of `incog one` → "Reply", send `owner reply`. Check: on cibob the quote above `incog self reply` names cibob's random name, not "cibob"; on citester cibob's messages show under the random name and the quote above `owner reply` names it too.
9. (R55.31) As citester: "Start new chat" → "Create group" → `ci incog`, turn "Incognito" on → "Create group". The group link screen opens: wait until it shows the link, then tap "Continue". In the chat, open the top bar menu ("More"). Check: the link is created by itself (QR code and "Share link"); the menu offers "Group link" and no "Invite members".
10. (R55.26) Close the menu → group info of "ci incog" → tap "Invite members". Check: the alert "Can't invite contacts!" says "You're using an incognito profile for this group - to prevent sharing your main profile inviting contacts is not allowed".
11. (R59.4) As citester: "ci incog" → group info → "Group link" → "Share link" (copy); close. Switch to cicarol: paste → "Open group" → "Your profile" "cicarol" → "Join group"; wait up to 120 s. Open "ci incog" → group info. Switch to citester: reset the remembered choice ("Start new chat" → "Create 1-time link" → "citester"; close, "Delete" if asked). Check: cicarol joins; cicarol's member list shows the host under a random name (citester is incognito in this group), not "citester".

**Contact aliases and search.**

12. (S6) Switch to cidan → "ci team": send `dan in group`. Check: it shows as sent.
13. (R55.28) Switch to citester → chat "cidan" → chat info → tap the field "Set contact name…", type `  Danny  ` (two spaces before and after), press Enter (`ui key ENTER`); close chat info and look at the chat list. Reopen chat info: tap the field, delete its text, type `Dan Two`, then close chat info without pressing Enter (`ui key ENTER`). Look at the chat list. Then reopen chat info and set `Danny` again with Enter (`ui key ENTER`). Check: after Enter (`ui key ENTER`), the chat list and the chat's top bar show "Danny" without the spaces, also after reopening; leaving without Enter (`ui key ENTER`) saved "Dan Two" too (the list shows it); finally the name is "Danny".
14. (R55.29) As citester: look at the chat list and the chat's top bar; open "ci team": cidan's message `dan in group`, and group info's member list → the member "Danny" → member info. Create the group `ci links` ("Incognito" off) and look at its invite screen's contact list, then tap "Skip inviting members". Check: everywhere cidan shows as "Danny": the chat list, the top bar, the sender of `dan in group`, the member list, member info and the invite list of "ci links".
15. (R55.30) Switch to cidan → chat console: send `/_profile 4 {"displayName":"cidan","fullName":"Daniel Fuller"}` (cidan is the 4th profile, so its id is 4; type it as one quoted argument: `ui type '/_profile 4 {"displayName":"cidan","fullName":"Daniel Fuller"}'`). Switch to citester; wait 30 s; search the chat list for `Dann`, then `cidan`, then `Fuller` (clear the field between). Check: the console answers without an error (a profile update for cidan); each search shows the chat "Danny": by the alias, by the display name and by the full name.

**Group links ("ci links").**

16. (R59.1) As citester → "ci links" → group info → "Create group link". Check: the link is created: QR code, "Share link" and "Delete link".
17. (R59.2) Tap "Delete link" → the alert "Delete link?" → "Delete"; close to group info. Then "Create group link" again → "Share link" (copy); close. Check: the alert says "All group members will remain connected."; after deleting, group info shows "Create group link" again; the new link is created.
18. (R59.9) Switch to cicarol: paste the link. Check: the alert names "ci links" with "Open group" and "Cancel": tap "Cancel"; cicarol's chat list has no "ci links". (Scanning needs a camera: not checked.)
19. (R59.3) As cicarol: paste the link again → "Open group" → "Your profile" "Incognito" → "Join group"; wait up to 120 s. Switch to cidan: paste the link → "Open group" → set "Your profile" to "cidan" → "Join group"; wait. Switch to citester → "ci links" → group info. Check: both join: the member list shows cidan (as "Danny") and a random name for cicarol; cicarol's "ci links" shows the mask icon.
20. (R59.7) As citester: look at the chat "ci links". Check: it shows "invited via your group link" for the members who joined by the link.
21. (R59.10) Look at citester's chat list; switch to cidan and look at its chat list. Check: citester has one chat for cidan ("Danny"), no second one; cidan has one chat "citester": the contact made through the group link was merged with the existing contact.
22. (R59.8) Switch to citester → developer options on. "ci links" → group info → "Group link" → tap "Full link" → "Share link" (copy). Switch to cibob: paste → the alert "Join group?" ("You will connect to all group members.") → "Use current profile"; at once take a shot of the chat list and tap the pending connection it shows. Check: the chat list shows a pending connection for the group; its screen has no "Set contact name…" field (a group link connection can't get an alias). If the connection completed before the tap, SKIPPED with that reason.
23. (R59.5) Wait up to 120 s for cibob to join "ci links". Switch to citester; look at the chat list; `ui relaunch` and look again. Check: on the joining side the pending connection was listed while connecting (R59.8's shot); citester's chat list gets no new contact for cibob's group link connection, also after the restart.
24. (R59.11) As citester → "ci links" → "Group link" → tap "Short link" → "Share link" (copy). Switch to cicarol → "ci links" → group info → "Leave group" → "Leave"; then "Delete group" → "Delete". Paste the link → "Open group" → "Join group"; wait up to 120 s. Check: after deleting, "ci links" is gone from cicarol's list (only the group was deleted, no contact); pasting the same link offers "Open group" again and joins "ci links" again.
25. (R59.6) Switch to citester → "ci links" → group info → "Group preferences" → turn "Direct messages" on → "Save and notify group members". Group info → the member "cibob" → member info → "message"; send `hello link contact`; close to the chat list. `ui relaunch`; look at the chat list. Check: a chat "cibob" appears in citester's chat list after the message and is still there after the restart.

You have at most 600 turns, and the whole test fits in about 320 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain; `ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Every `ui` command and every file edit is a turn. Take a shot at each check, named after its step with letters, digits, - and _ only (`ui shot R8-1` for R8.1). For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Before the first step, create it with a table `| ID | Result | Evidence | Screenshots |` holding one row for every ID of this test (S1, S2, S3, S4, S5, R55.24, R55.25, R55.27, R55.31, R55.26, R59.4, S6, R55.28, R55.29, R55.30, R59.1, R59.2, R59.9, R59.3, R59.7, R59.10, R59.8, R59.5, R59.11, R59.6), Result `todo`; fill a row in as soon as its step is done. Result is PASS, FAIL or SKIPPED: SKIPPED with the exact reason when the step needs something this runner or the app on this platform lacks (that is not a failure); FAIL when the app does not do what the check says. Evidence quotes what you saw (the text read, positions) and names the screenshots. Add a section `## Findings` for other app bugs you notice (steps, what you saw, what you expected, screenshots). Read `report.md` again after the conversation has been compacted, to see which steps are left. End your final message with one line: `CLAUDE-TEST: PASS` if no step failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the steps that failed.

## The ui helper
