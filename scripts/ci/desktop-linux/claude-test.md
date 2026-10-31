# Test: groups I part 2 (member info, direct chats with members, profile updates, inactive groups, auto-accept, invitations via a group) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730. The toolbar is at the bottom of the left pane.
- The folder `images` in your working directory has `test-card.jpg` (a TV test card with colour bars and a large circle). Use its absolute path (your working directory followed by `/images/test-card.jpg`) in file dialogs.
- All profiles live in this one app and connect to each other through the app's preset servers on the internet: deliveries take a few seconds; wait up to 60 s (`ui wait "<text>" 60`) for something another profile sent.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`.
- **Group info:** click the group's name at the top of the right pane. Press Escape to close it and other panes (member info, preferences, settings) and get back.
- **Member info:** in group info, click the member's name in the member list (below the header "N members"); or, in the group chat, click the member's profile picture left of their message. Member info has three round buttons near the top: "message", "call" and "video".
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want. The same menu has "Settings".
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Connect profile A with profile B** (a one-time link, copied by the app itself):
  1. As A: the pencil (about 363,730) → "Create 1-time link". Wait for "Share this 1-time invite link"; click the link text just below it (it starts with "https"). Check the toast "Copied to clipboard". Press Escape until the chat list shows.
  2. Switch to B: the pencil → "Paste link" → "Tap to paste link". An alert shows A's name with "Open new chat": click it (if the alert is "Connect via one-time link?" instead, click "Use current profile"). The new chat with A opens with a "Connect" bar at the bottom: click "Connect".
  3. Switch to A. Wait up to 60 s until the chat list shows B's name.
- **Create a group and invite contacts:** the pencil → "Create group"; click the name field about 40 px below "Enter group name:", type the name, click "Create group". The "Invite members" screen follows: click each contact under "Select contacts" (a check mark appears), then "Invite to group"; or "Skip inviting members".
- **Group invitations:** the invited profile gets, in its chat with the inviting contact, a card with the group's name, "You are invited to group" and "Tap to join"; clicking "Tap to join" joins, and the card then says "You joined this group".
- **Group preferences:** group info → "Group preferences"; a feature's switch is at the right end of its row; then "Save and notify group members".
- **Developer tools:** profile picture → "Settings"; scroll the settings to the bottom (`ui scroll 200 450 down 10`) and click the row showing the app's version number; on "App version" click "Developer tools". It has "Chat console" and the switch "Show developer options". With that switch on, group info and member info end with a section "For console" with "Local name" and "Database ID".

## The test

The steps build on each other: run them in this order. Take a shot at each check, named after its step with `-` for the dot (`ui shot R44-13`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profiles `cibob` and `cicarol`.
3. (S3) Connect citester with cibob, and citester with cicarol (citester is A both times). Check: citester's chat list shows "cibob" and "cicarol".
4. (S4) As citester, create the group `ci club` and invite cibob and cicarol (role "member"). Switch to cibob: "Tap to join" in the chat with citester; switch to cicarol: the same. Wait up to 60 s for each "You joined this group". Then, as cibob, open "ci club" and send `bob in club`; as cicarol, open "ci club" and send `carol in club`. Check: cicarol's "ci club" shows "bob in club".

**Members and direct chats.**

5. (R44.19) As cicarol, look at the chat list. Check: it has no chat "cibob" (only "citester" and "ci club"). Switch to cibob. Check: no chat "cicarol". (Members met only through the group get no contact.)
6. (R44.16) Switch to cicarol → "ci club". Click cibob's profile picture left of "bob in club". Check: cibob's member info opens ("cibob", "Group" "ci club"). Click its "message" button. Check: the alert "Can't message group member" with "Direct messages between members are prohibited in this group." Close it and press Escape.
7. (R44.17) Switch to citester → "ci club". Click cibob's profile picture left of "bob in club" → "message". Check: the direct chat with cibob opens (its name at the top, the earlier group invitation card in it). Open "ci club" again → group info → "cibob" → "message". Check: the direct chat with cibob opens again.
8. (R44.20) As citester: "ci club" → group info → "Group preferences" → turn on the switch of "Direct messages" → "Save and notify group members". Press Escape until the chat shows. Switch to cicarol → "ci club" → click cibob's profile picture → "message". Check: a chat "cibob" opens with "Send direct message to connect" above the message field. Type `hi bob`, press Return. Switch to cibob. Check: the chat list has "cicarol"; open it: the message "hi bob" and a bar with "Reject" and "Accept". Click "Accept". Check: within 60 s the bar is gone and the chat can send: send `hi carol`. Switch to cicarol. Check: the chat "cibob" shows "hi carol".
9. (R44.21) Switch to cibob → "ci club". Check: an event "cicarol requested connection" followed by "Open". Click "Open". Check: the direct chat with cicarol opens (with "hi bob" and "hi carol").
10. (R44.18) As citester → "ci club" → group info → "cibob" → "message". Check: the direct chat with cibob (a chat already in the chat list) opens. Switch to cibob → "ci club" → group info → "cicarol". Check: member info now offers "message", "call" and "video" for the new contact; click "message". Check: the chat with cicarol from step 8 opens and is connected (send `still here`; it shows as sent). The case "a direct chat scrolled out of the chat list's view" cannot be made with this few chats: note it as SKIPPED.

**Group profile, removed and left members.**

11. (R44.14) Switch to citester → "ci club" → group info → "Edit group profile". Click the camera icon at the lower right of the round group picture → "From Gallery" → choose `images/test-card.jpg`. Click the name field below "Enter group name:", `ui key ctrl+a`, type `ci room`. Click the field below "Short description:" and type `club notes`. Click "Save group profile". Check: the chat shows "group profile updated", and its name at the top is "ci room" with the test card as picture. Switch to cibob. Check: the chat list shows "ci room" (not "ci club") with the test-card picture; the chat shows "updated group profile"; its group info shows "club notes". The editor shows a "Group full name:" field only for a group that already has a full name, and the app cannot set one: note the full-name part as SKIPPED.
12. (R44.13) Switch to cicarol → "ci room" → group info → "Leave group" → "Leave" in the alert "Leave group?". Check: the chat shows "you left". Switch to citester → "ci room". Check: the chat shows "cicarol" with "left". Click cicarol's profile picture left of "carol in club". Check: member info has no "Remove member" (it offers "Delete member messages" instead). Press Escape; group info → "cibob" → "Remove member" → "Remove" in the alert "Remove member?". Check: the chat shows "you removed cibob". Click cibob's profile picture left of "bob in club". Check: no "Remove member" ("Delete member messages" instead).

**Auto-accept and invitations through a group.**

13. (R45.0) As citester: profile picture → "Settings" → "Your privacy". Under "Auto-accept", turn on the switch at the right end of "Group invitations". Press Escape until the chat list shows. Switch to cibob: create the group `ci g1` and invite citester and cicarol (role "member"). Switch to citester. Check: within 60 s the chat list has "ci g1" without "You are invited to group", and the chat with cibob has the card for "ci g1" saying "You joined this group" (no "Tap to join"): citester joined automatically. Switch to cicarol. Check: its chat list row "ci g1" says "You are invited to group" (auto-accept is per profile and off for cicarol).
14. (S5) Switch to citester → "Settings" → "Your privacy" → turn the switch of "Group invitations" off again. Then open the developer tools and turn "Show developer options" on (it applies to all profiles). Press Escape until the chat list shows.
15. (R46.0) Switch to cibob. "ci g1" → group info → "Group preferences" → turn on "Direct messages" → "Save and notify group members". Create the group `ci g2` and click "Skip inviting members". Read the IDs: "ci g1" → group info → scroll to "For console" and note its "Database ID" (G1); in the same group info open "citester" and note the "Database ID" under "For console" (M, citester's member ID); "ci g2" → group info → "Database ID" (G2). Open the developer tools → "Chat console". Click the message field at the bottom of the console, type `/_add #G2 #G1 M member` with the numbers you noted (for example `/_add #3 #2 4 member`), and press Return. Check: the console log shows your command and a response line after it whose name does not contain "error" (click the response line to read its details if unsure). Press Escape until the chat list shows. Switch to citester → "ci g1". Check: within 60 s a card shows "For you only", the group "ci g2", "You are invited to group" and "Tap to join". Click "Tap to join". Check: the card says "You joined this group", and within 60 s the chat list has "ci g2", whose group info lists cibob.

**Inactive groups.**

16. (R44.15) Switch to cicarol → "ci room". Check: the message field shows "you left" in place of "Message", and you cannot send. Switch to cibob → "ci room". Check: the chat shows "removed you" and the message field shows "removed from group". Then cibob → "ci g2" → group info → "Delete group" → "Delete" in the alert "Delete group?". Switch to citester → "ci g2". Check: within 60 s the chat shows "deleted group" and the message field shows "group is deleted". In each of these chat lists the group's picture has a small grey cross mark (the inactive mark; compare with the picture).

You have at most 600 turns, and the whole test fits in about 185 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click 27 730 -- click-text cicarol 10 -- click-text "ci club" 20 -- shot carol-club`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S5, R44.13 to R44.21, R45.0, R46.0), each with PASS, FAIL or SKIPPED (with the reason), its evidence (the text OCR read, screenshot names), and anything else unexpected. A check the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
