# Test: groups I part 2 (member info, direct chats with members, profile updates, inactive groups, auto-accept, invitations via a group) in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- The emulator's Pictures folder has `test-card.jpg` (a TV test card with colour bars and a large circle).
- All profiles live in this one app and connect to each other through the app's preset servers on the internet: deliveries take a few seconds; wait up to 60 s (`ui wait "<text>" 60`) for something another profile sent.

## How to do things in the app

- **Send a message:** `ui click-text Message` (the field's placeholder), `ui type "<text>"`, then `ui click-text "Send Message"`.
- **Group info:** tap the group's name in the chat's toolbar. `ui key BACK` closes it and other screens (member info, preferences, settings).
- **Member info:** in group info, tap the member's name in the member list (below the header "N members"); or, in the group chat, tap the member's profile picture left of their message (position from the screenshot). Member info has three round buttons near the top: "message", "call" and "video".
- **Switch profile:** tap your profile picture, the button without text at the left end of the chat list's toolbar (find it with `ui tree`); the picker lists your other profiles by name: tap the one you want. The picker also has "Settings".
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile" the name field below "Enter your name:" has the focus: type the name and tap "Create profile". `ui key BACK` until the chat list shows.
- **Connect profile A with profile B** (a one-time link, copied by the app itself):
  1. As A: "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link"; just below it are the link text, "…", and two buttons without text: tap the first of them (copy; find it with `ui tree`). `ui key BACK` until the chat list shows.
  2. Switch to B: "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert shows A's name with "Open new chat": tap it (if the alert is "Connect via one-time link?" instead, tap "Use current profile"). The new chat with A opens with a "Connect" bar: tap "Connect". `ui key BACK`.
  3. Switch to A. Wait up to 60 s until the chat list shows B's name.
- **Create a group and invite contacts:** "Start new chat" → "Create group"; the name field under "Enter group name:" has the focus: type the name and tap "Create group". The "Invite members" screen follows: tap each contact under "Select contacts" (it is then "Contact checked"), then "Invite to group"; or "Skip inviting members".
- **Group invitations:** the invited profile gets, in its chat with the inviting contact, a card with the group's name, "You are invited to group" and "Tap to join"; tapping "Tap to join" joins, and the card then says "You joined this group".
- **Group preferences:** group info → "Group preferences"; a feature's switch is at the right end of its row; then "Save and notify group members".
- **Developer tools:** profile picture → "Settings"; scroll to the bottom (`ui scroll 540 1600 down 5`) and tap the row showing the app's version number; on "App version" tap "Developer tools". It has "Chat console" and the switch "Show developer options". With that switch on, group info and member info end with a section "For console" with "Local name" and "Database ID".
- **Choose an image:** Android opens a picker that is not part of the app: find `test-card.jpg` (under Pictures, Images or Recent) and choose it, then confirm if the picker has a button for it ("Add", "Select", "Done").

## The test

The steps build on each other: run them in this order. Take a shot at each check, named after its step with `-` for the dot (`ui shot R44-13`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow"; Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) Add the profiles `cibob` and `cicarol`.
3. (S3) Connect citester with cibob, and citester with cicarol (citester is A both times). Check: citester's chat list shows "cibob" and "cicarol".
4. (S4) As citester, create the group `ci club` and invite cibob and cicarol (role "member"). Switch to cibob: "Tap to join" in the chat with citester; switch to cicarol: the same. Wait up to 60 s for each "You joined this group". Then, as cibob, open "ci club" and send `bob in club`; as cicarol, open "ci club" and send `carol in club`. Check: cicarol's "ci club" shows "bob in club".

**Members and direct chats.**

5. (R44.19) As cicarol, look at the chat list. Check: it has no chat "cibob" (only "citester" and "ci club"). Switch to cibob. Check: no chat "cicarol".
6. (R44.16) Switch to cicarol → "ci club". Tap cibob's profile picture left of "bob in club". Check: cibob's member info opens ("cibob", "Group" "ci club"). Tap its "message" button. Check: the alert "Can't message group member" with "Direct messages between members are prohibited in this group." Close it and `ui key BACK`.
7. (R44.17) Switch to citester → "ci club". Tap cibob's profile picture left of "bob in club" → "message". Check: the direct chat with cibob opens (its name in the toolbar, the earlier group invitation card in it). Open "ci club" again → group info → "cibob" → "message". Check: the direct chat with cibob opens again.
8. (R44.20) As citester: "ci club" → group info → "Group preferences" → turn on the switch of "Direct messages" → "Save and notify group members". `ui key BACK` until the chat shows. Switch to cicarol → "ci club" → tap cibob's profile picture → "message". Check: a chat "cibob" opens with "Send direct message to connect" above the message field. Type `hi bob` and tap "Send Message". Switch to cibob. Check: the chat list has "cicarol"; open it: the message "hi bob" and a bar with "Reject" and "Accept". Tap "Accept". Check: within 60 s the bar is gone and the chat can send: send `hi carol`. Switch to cicarol. Check: the chat "cibob" shows "hi carol".
9. (R44.21) Switch to cibob → "ci club". Check: an event "cicarol requested connection" followed by "Open". Tap "Open". Check: the direct chat with cicarol opens (with "hi bob" and "hi carol").
10. (R44.18) As citester → "ci club" → group info → "cibob" → "message". Check: the direct chat with cibob (a chat already in the chat list) opens. Switch to cibob → "ci club" → group info → "cicarol". Check: member info now offers "message", "call" and "video" for the new contact; tap "message". Check: the chat with cicarol from step 8 opens and is connected (send `still here`; it shows as sent). The case "a direct chat scrolled out of the chat list's view" cannot be made with this few chats: note it as SKIPPED.

**Group profile, removed and left members.**

11. (R44.14) Switch to citester → "ci club" → group info → "Edit group profile". Tap "Edit image" (the camera icon on the round group picture) → "From Gallery" → choose `test-card.jpg`. Tap the name field below "Enter group name:", delete its text (`ui key DEL` repeated, e.g. `ui key DEL DEL DEL DEL DEL DEL DEL`), type `ci room`. Tap the field below "Short description:" and type `club notes`. Tap "Save group profile". Check: the chat shows "group profile updated", and its name is "ci room" with the test card as picture. Switch to cibob. Check: the chat list shows "ci room" (not "ci club") with the test-card picture; the chat shows "updated group profile"; its group info shows "club notes". The editor shows a "Group full name:" field only for a group that already has a full name, and the app cannot set one: note the full-name part as SKIPPED.
12. (R44.13) Switch to cicarol → "ci room" → group info → "Leave group" → "Leave" in the alert "Leave group?". Check: the chat shows "you left". Switch to citester → "ci room". Check: the chat shows "cicarol" with "left". Tap cicarol's profile picture left of "carol in club". Check: member info has no "Remove member" (it offers "Delete member messages" instead). `ui key BACK`; group info → "cibob" → "Remove member" → "Remove" in the alert "Remove member?". Check: the chat shows "you removed cibob". Tap cibob's profile picture left of "bob in club". Check: no "Remove member" ("Delete member messages" instead).

**Auto-accept and invitations through a group.**

13. (R45.0) As citester: profile picture → "Settings" → "Your privacy". Under "Auto-accept", turn on the switch at the right end of "Group invitations". `ui key BACK` until the chat list shows. Switch to cibob: create the group `ci g1` and invite citester and cicarol (role "member"). Switch to citester. Check: within 60 s the chat list has "ci g1" without "You are invited to group", and the chat with cibob has the card for "ci g1" saying "You joined this group" (no "Tap to join"): citester joined automatically. Switch to cicarol. Check: its chat list row "ci g1" says "You are invited to group" (auto-accept is per profile and off for cicarol).
14. (S5) Switch to citester → "Settings" → "Your privacy" → turn the switch of "Group invitations" off again. Then open the developer tools and turn "Show developer options" on (it applies to all profiles). `ui key BACK` until the chat list shows.
15. (R46.0) Switch to cibob. "ci g1" → group info → "Group preferences" → turn on "Direct messages" → "Save and notify group members". Create the group `ci g2` and tap "Skip inviting members". Read the IDs: "ci g1" → group info → scroll to "For console" and note its "Database ID" (G1); in the same group info open "citester" and note the "Database ID" under "For console" (M, citester's member ID); "ci g2" → group info → "Database ID" (G2). Open the developer tools → "Chat console". Tap the message field at the bottom of the console, type `/_add #G2 #G1 M member` with the numbers you noted (for example `/_add #3 #2 4 member`), and tap "Send Message". Check: the console log shows your command and a response line after it whose name does not contain "error" (tap the response line to read its details if unsure). `ui key BACK` until the chat list shows. Switch to citester → "ci g1". Check: within 60 s a card shows "For you only", the group "ci g2", "You are invited to group" and "Tap to join". Tap "Tap to join". Check: the card says "You joined this group", and within 60 s the chat list has "ci g2", whose group info lists cibob.

**Inactive groups.**

16. (R44.15) Switch to cicarol. Check: in the chat list the row "ci room" has "Group inactive" (an icon over its picture, in the tree). Open "ci room". Check: the message field shows "you left" in place of "Message". Switch to cibob → "ci room". Check: the chat shows "removed you" and the message field shows "removed from group". Then cibob → "ci g2" → group info → "Delete group" → "Delete" in the alert "Delete group?". Switch to citester. Check: within 60 s the row "ci g2" has "Group inactive"; open it: the chat shows "deleted group" and the message field shows "group is deleted".

You have at most 600 turns, and the whole test fits in about 185 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- type cibob -- click-text "Create profile" -- shot cibob`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S5, R44.13 to R44.21, R45.0, R46.0), each with PASS, FAIL or SKIPPED (with the reason), its evidence (text and positions from the tree, screenshot names), and anything else unexpected. A check the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
