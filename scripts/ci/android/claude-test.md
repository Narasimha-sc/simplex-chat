# Test: groups I (creation, members, permissions, chat view) in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- The emulator's Pictures folder has `test-card.jpg` (a TV test card with colour bars and a large circle) and `simplex-logo.png`.
- All profiles live in this one app and connect to each other through the app's preset servers on the internet: deliveries take a few seconds; wait up to 60 s (`ui wait "<text>" 60`) for something another profile sent.

## How to do things in the app

- **Send a message:** tap the message field (its placeholder is "Message": `ui click-text Message`), `ui type "<text>"`, then `ui click-text "Send Message"`. Chain several: `ui do click-text Message -- type m1 -- click-text "Send Message" -- click-text Message -- type m2 -- click-text "Send Message"`.
- **Group info:** tap the group's name in the chat's toolbar. `ui key BACK` closes it and other screens (member info, preferences).
- **Member info:** in group info, tap the member's name in the member list (below the header "N members"); or, in the group chat, tap the member's profile picture left of their message (position from the screenshot).
- **Message menu:** `ui long-press <x> <y>` on the message's text opens its menu ("Reply", …).
- **Chat list row menu:** `ui long-press` on a chat's name in the chat list.
- **Switch profile:** tap your profile picture, the button without text at the left end of the chat list's toolbar (find it with `ui tree`); the picker lists your other profiles by name: tap the one you want. The chat list then shows that profile's chats.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile" the name field below "Enter your name:" has the focus: type the name and tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Connect profile A with profile B** (a one-time link, copied by the app itself):
  1. As A: "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link"; just below it are the link text, "…", and two buttons without text: tap the first of them (copy; find it with `ui tree`). `ui key BACK` until the chat list shows.
  2. Switch to B: "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert shows A's name with "Open new chat": tap it (if the alert is "Connect via one-time link?" instead, tap "Use current profile"). The new chat with A opens with a "Connect" bar: tap "Connect". `ui key BACK`.
  3. Switch to A. Wait up to 60 s until the chat list shows B's name. Then B's chat list shows A's name too.
- **Choose an image:** Android opens a picker that is not part of the app (the photo picker, or Files): find `test-card.jpg` (under Pictures, Images or Recent) and choose it, then confirm if the picker has a button for it ("Add", "Select", "Done").
- **Group invitations:** the invited profile gets, in its chat with the inviting contact, a card with the group's name and picture, "You are invited to group" and "Tap to join". Tapping "Tap to join" joins. Tapping the group's row in the chat list instead shows the alert "Join group?" with "Join" and "Delete".

## The test

The steps build on each other: run them in this order. Take a shot at each check, named after its step with `-` for the dot (`ui shot R44-1`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow"; Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) Add the profiles `cibob`, `cicarol` and `cidan`.
3. (S3) Connect citester with cibob, citester with cicarol, citester with cidan, and cibob with cidan (A is the first name of each pair). Check: citester's chat list shows "cibob", "cicarol" and "cidan"; cibob's shows "citester" and "cidan".

**Chat items and group creation.**

4. (R12.4) As citester, open the chat with cibob. Check: the events created when the contact connected show as one row of small feature icons, not as several text lines such as "Voice messages" or "Audio/video calls" (compare the text with the picture).
5. (R44.2) As citester: "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type `ci dup` and tap "Create group". On the next screen ("Invite members"), tap "Skip inviting members". `ui key BACK` until the chat list shows. Repeat: create a second group named `ci dup`, but on "Invite members" tap "cicarol" in the list under "Select contacts" (it is then checked: "Contact checked") and tap "Invite to group". Check: the chat list shows two rows named "ci dup".
6. (R44.1, R44.8 owner part) As citester: "Start new chat" → "Create group". Tap "Edit image" (the camera icon on the round group picture), then "From Gallery", and choose `test-card.jpg`. Check: the round picture shows the test card. Tap the name field below "Enter group name:", type `ci team`, tap "Create group". On "Invite members": tap the "New member role" row. Check: the list offers "observer", "member", "moderator", "admin" and "owner". Tap "admin". Tap "cibob" under "Select contacts", then "Invite to group". Check: the group "ci team" opens, with the test card as its picture in the toolbar.
7. (R44.7) Group info → "Invite members". Tap the search field right of the "Search" icon below "Select contacts" and type `car`. Check: the list shows "cicarol" and not "cidan". Tap "cicarol"; leave "New member role" at "member"; tap "Invite to group".
8. (R44.3) Open the chat with cibob. Check: the last item is a card with the group picture (the test card), "ci team" and "You sent group invitation". Switch to cibob. Check: the chat list has a row "ci team" with "You are invited to group"; in the chat with citester the card shows the group picture, "ci team", "You are invited to group" and "Tap to join".
9. (R44.4) As cibob, tap "Tap to join" on that card. Check: within 60 s the card says "You joined this group". Switch to cicarol: tap the row "ci team" in the chat list. Check: the alert "Join group?" with "Join" and "Delete"; tap "Join"; within 60 s "ci team" is a joined group. Then long-press the row "ci dup" (the invitation from step 5): check the menu has "Join" and "Delete"; tap "Delete", then "Delete" in the alert "Delete group?". Check: the row "ci dup" is gone from cicarol's chat list.
10. (R44.8 member and admin parts) As cicarol, open "ci team" → group info. Check: no "Invite members" (members may not add members). Switch to cibob → "ci team" → group info (cibob can invite only once connected: if "Invite members" is missing, wait 30 s and reopen group info). Check: "Invite members" is shown; tap it, tap the "New member role" row. Check: the list offers "observer", "member", "moderator" and "admin", and not "owner". Tap "observer", tap "cidan", "Invite to group".
11. (R44.6) Switch to cidan; tap "Tap to join" in the chat with cibob; wait up to 60 s until "ci team" is joined. Switch to citester → "ci team" → group info. Check: the member list shows cibob with "admin", cidan with "observer", and cicarol without a role text.
12. (R12.3) Switch to cidan → "ci team". Check: the events of the members who connected when cidan joined are one item naming both, such as "citester and cicarol connected" (any order), not one item per member. Group info lists citester, cibob and cicarol.

**Messages in the group.**

13. (S4) Switch to cibob → "ci team": send `b1`, `b2`, `b3` in a row. Switch to cicarol → "ci team": send `c1`, `c2`. Switch to cibob: send `b4`.
14. (R12.1, R12.2, R12.7) Switch to citester → "ci team". Check, in the picture: cibob's profile picture shows once for b1–b3 (not beside each message), and once for b4; the name "cibob" shows once above b1 and once above b4, "cicarol" once above c1; the event items ("connected", "invited …") have no name label above them; the time shows on the last message of each run of close messages (b3, c2, b4); b1, b2 and c1 show no time unless the minute changed right after them.
15. (R12.5) Tap cibob's profile picture left of b3. Check: cibob's member info opens (name "cibob", the group "ci team", role admin). `ui key BACK`.
16. (R12.11) As citester in "ci team": tap the message field, type `https://simplex.chat`; if the alert "Enable link previews?" shows, tap "Enable". Wait until the compose area shows the link preview, then tap "Send Message". Tap "Attach" → "Image", choose `test-card.jpg`, tap "Send Message". Tap the content-filter button: the button without text next to "More" in the chat's toolbar (`ui tree`). Check: the menu offers "Images" and "Links". Tap "Images". Check: the chat shows only the test-card image (no b1…c2 texts). Open the filter menu again → "Links". Check: only the simplex.chat link message shows.
17. (R12.12) Still filtered by "Links": tap the link message's bubble (outside the link text), then the small magnifier button beside it. Check: the chat shows all messages again around the link message (the image and b4 are visible near it), and the filter is cleared.

**Unread position, quotes beyond the loaded messages, dates (direct chat).**

18. (S5) As citester, open the chat with cibob and send `quote target`. Switch to cibob → chat with citester; send 105 messages `n001` … `n105`, chaining about 15 per `ui do` (`ui do click-text Message -- type n001 -- click-text "Send Message" -- click-text Message -- type n002 -- click-text "Send Message" ...`). Check the last one shows.
19. (R12.9) Switch to citester; the chat list row "cibob" shows unread messages. Open it. Check: the chat opens on the first unread message: "n001" is visible near the top and "n105" is not visible.
20. (R12.10) Scroll to the bottom (`ui scroll 540 1200 down 30`, repeat until "n105" shows). Scroll up until "quote target" shows (`ui scroll 540 1200 up 30`, repeat). Long-press "quote target" → "Reply"; type `reply to target`, tap "Send Message". `ui key BACK` to the chat list, then open "cibob" again. Check: the chat opens at its last message, "reply to target" (all read). Tap the quoted text "quote target" inside the reply. Check: the chat scrolls to the message "quote target" and it shows, with n001 below it.
21. (R12.8) Scroll a little (`ui scroll 540 1200 up 2`) and take a shot at once. Check: a date label of the form "<weekday>, <day> <month>" (for example "Fri, 30 Oct", today's date) floats at the top of the messages while scrolling, and a date separator with the same text is above the first message of the chat. Messages from different days cannot be made here: note this part as SKIPPED.

**Permissions, removal, leaving, deleting.**

22. (R44.11) Switch to cibob → "ci team" → group info. Check: no "Edit group profile" (cibob is an admin). Switch to citester → "ci team" → group info. Check: "Edit group profile" is shown; tap it; check the editor shows "Enter group name:" with "ci team"; `ui key BACK` (if asked to save, tap "Exit without saving").
23. (R44.10) Switch to cicarol → "ci team" → group info → "cibob". Check: no "Remove member" (members may not remove). Switch to cibob → group info → "citester". Check: no "Remove member" (an admin may not remove the owner). `ui key BACK`; open "cidan". Check: "Remove member" is shown; tap it, then "Remove" in the alert "Remove member?". Check: the chat shows "you removed cidan". Switch to citester → group info → "cicarol" → "Remove member" → "Remove". Check: the chat shows "you removed cicarol".
24. (R44.5) As citester in "ci team". Check: received events show, such as "invited cidan" under cibob's name, "connected" and "removed cidan"; and the sent event "you removed cicarol". Switch to cicarol → "ci team". Check: the received event "removed you".
25. (R44.9) Switch to cibob → "ci team" → group info. Check: "Leave group" is shown and "Delete group" is not (only owners delete a current group). Tap "Leave group", then "Leave" in the alert "Leave group?". Check: the chat shows "you left". Open group info again. Check: "Delete group" is now shown.
26. (R44.12) As cibob, in that group info. Check: "Leave group" is not shown any more. `ui key BACK` to the chat list, long-press the row "ci team". Check: the menu has no "Leave". Close the menu (`ui key BACK`). Then group info → "Delete group" → "Delete" in the alert "Delete group?". Check: "ci team" is gone from cibob's chat list. Switch to citester → "ci team" → group info. Check: "Delete group" is shown for the owner (do not tap it).

You have at most 600 turns, and the whole test fits in about 290 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S5, R12.1, R12.2, R12.3, R12.4, R12.5, R12.7, R12.8, R12.9, R12.10, R12.11, R12.12, R44.1 to R44.12), each with PASS, FAIL or SKIPPED (with the reason), its evidence (text and positions from the tree, screenshot names), and anything else unexpected. A check the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
