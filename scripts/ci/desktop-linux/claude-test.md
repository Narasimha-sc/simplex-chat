# Test: groups I (creation, members, permissions, chat view) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730. The toolbar is at the bottom of the left pane.
- The folder `images` in your working directory has `test-card.jpg` (a TV test card with colour bars and a large circle) and `simplex-logo.png`. Use their absolute paths (your working directory followed by `/images/...`) in file dialogs.
- All profiles live in this one app and connect to each other through the app's preset servers on the internet: deliveries take a few seconds; wait up to 60 s (`ui wait "<text>" 60`) for something another profile sent.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`. The field keeps the focus after sending, so several messages can be chained: `ui do type m1 -- key Return -- type m2 -- key Return`.
- **Group info:** click the group's name at the top of the right pane. Press Escape to close it and other panes (member info, preferences) and get back to the chat.
- **Member info:** in group info, click the member's name in the member list (below the header "N members"); or, in the group chat, click the member's profile picture left of their message.
- **Message menu:** `ui right-click <x> <y>` on the message's text opens its menu ("Reply", …).
- **Chat list row menu:** `ui right-click` on a chat's name in the chat list.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want. The chat list then shows that profile's chats.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Connect profile A with profile B** (a one-time link, copied by the app itself):
  1. As A: the pencil (about 363,730) → "Create 1-time link". Wait for "Share this 1-time invite link"; click the link text just below it (it starts with "https"). Check the toast "Copied to clipboard". Press Escape until the chat list shows.
  2. Switch to B: the pencil → "Paste link" → "Tap to paste link". An alert shows A's name with "Open new chat": click it (if the alert is "Connect via one-time link?" instead, click "Use current profile"). The new chat with A opens with a "Connect" bar at the bottom: click "Connect".
  3. Switch to A. Wait up to 60 s until the chat list shows B's name. Then B's chat list shows A's name too.
- **Choose an image in a file dialog:** click its "File Name" field, type the absolute path of the image, and press Return.
- **Group invitations:** the invited profile gets, in its chat with the inviting contact, a card with the group's name and picture, "You are invited to group" and "Tap to join". Clicking "Tap to join" joins. Clicking the group's row in the chat list instead shows the alert "Join group?" with "Join" and "Delete".

## The test

The steps build on each other: run them in this order. Take a shot at each check, named after its step with `-` for the dot (`ui shot R44-1`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profiles `cibob`, `cicarol` and `cidan`.
3. (S3) Connect citester with cibob, citester with cicarol, citester with cidan, and cibob with cidan (A is the first name of each pair). Check: citester's chat list shows "cibob", "cicarol" and "cidan"; cibob's shows "citester" and "cidan".

**Chat items and group creation.**

4. (R12.4) As citester, open the chat with cibob. Check: the events created when the contact connected show as one row of small feature icons, not as several text lines such as "Voice messages" or "Audio/video calls" (OCR reads no feature name there; compare with the picture).
5. (R44.2) As citester: the pencil → "Create group". Click the name field about 40 px below the text "Enter group name:", type `ci dup`, click "Create group". On the next screen ("Invite members"), click "Skip inviting members". Press Escape until the chat list shows. Repeat: create a second group named `ci dup`, but on "Invite members" click "cicarol" in the list under "Select contacts" (a check mark appears) and click "Invite to group". Check: the chat list shows two rows named "ci dup".
6. (R44.1, R44.8 owner part) As citester: the pencil → "Create group". Click the camera icon at the lower right of the round group picture, then "From Gallery"; choose `images/test-card.jpg` in the file dialog. Check: the round picture shows the test card. Type `ci team` in the name field below "Enter group name:", click "Create group". On "Invite members": click the "New member role" row. Check: the list offers "observer", "member", "moderator", "admin" and "owner" (owners invite in all roles). Click "admin". Click "cibob" under "Select contacts", then "Invite to group". Check: the group "ci team" opens, with the test card as its picture at the top.
7. (R44.7) Group info → "Invite members". Click the search field right of the magnifier icon below "Select contacts" and type `car`. Check: the list shows "cicarol" and not "cidan". Click "cicarol"; leave "New member role" at "member"; click "Invite to group".
8. (R44.3) Open the chat with cibob. Check: the last item is a card with the group picture (the test card), "ci team" and "You sent group invitation". Switch to cibob. Check: the chat list has a row "ci team" with "You are invited to group"; in the chat with citester the card shows the group picture, "ci team", "You are invited to group" and "Tap to join".
9. (R44.4) As cibob, click "Tap to join" on that card. Check: within 60 s the card says "You joined this group" and the chat "ci team" opens or its row no longer says "You are invited to group". Switch to cicarol: click the row "ci team" in the chat list. Check: the alert "Join group?" with "Join" and "Delete"; click "Join"; within 60 s "ci team" is a joined group. Then right-click the row "ci dup" (the invitation from step 5): check the menu has "Join" and "Delete"; click "Delete", then "Delete" in the alert "Delete group?". Check: the row "ci dup" is gone from cicarol's chat list.
10. (R44.8 member and admin parts) As cicarol, open "ci team" → group info. Check: the member section has no "Invite members" (members may not add members). Switch to cibob → "ci team" → group info (cibob can invite only once connected: if its own row says "connecting" and "Invite members" is missing, wait 30 s and reopen group info). Check: "Invite members" is shown; click it, click the "New member role" row. Check: the list offers "observer", "member", "moderator" and "admin", and not "owner". Click "observer", click "cidan", "Invite to group".
11. (R44.6) Switch to cidan; click "Tap to join" in the chat with cibob; wait up to 60 s until "ci team" is joined. Switch to citester → "ci team" → group info. Check: the member list shows cibob with "admin", cidan with "observer", and cicarol without a role text (member is not shown).
12. (R12.3) Switch to cidan → "ci team". Check: the events of the members who connected when cidan joined are one item naming both, such as "citester and cicarol connected" (any order), not one item per member. Group info lists citester, cibob and cicarol.

**Messages in the group.**

13. (S4) Switch to cibob → "ci team": send `b1`, `b2`, `b3` in a row. Switch to cicarol → "ci team": send `c1`, `c2`. Switch to cibob: send `b4`.
14. (R12.1, R12.2, R12.7) Switch to citester → "ci team". Check, in the picture: cibob's profile picture shows once for b1–b3 (not beside each message), and once for b4; the name "cibob" shows once above b1 and once above b4, "cicarol" once above c1; the event items ("connected", "invited …") have no name label above them; the time shows on the last message of each run of close messages (b3, c2, b4); b1, b2 and c1 show no time unless the minute changed right after them.
15. (R12.5) Click cibob's profile picture left of b3. Check: cibob's member info opens (name "cibob", the group "ci team", role admin). Press Escape.
16. (R12.11) As citester in "ci team": click the message field, type `https://simplex.chat`; if the alert "Enable link previews?" shows, click "Enable". Wait until the compose area shows the link preview, then press Return. Click the paperclip at the left end of the message field → "Image", choose `images/test-card.jpg`, press Return. Click the content-filter button: the picture-stack icon at the right end of the chat's top bar, left of the three-dot menu. Check: the menu offers "Images" and "Links". Click "Images". Check: the chat shows only the test-card image (no b1…c2 texts). Open the filter menu again → "Links". Check: only the simplex.chat link message shows.
17. (R12.12) Still filtered by "Links": click the small magnifier button beside the link message. Check: the chat shows all messages again around the link message (the image and b4 are visible near it), and the filter is cleared.

**Unread position, quotes beyond the loaded messages, dates (direct chat).**

18. (S5) As citester, open the chat with cibob and send `quote target`. Switch to cibob → chat with citester; send 105 messages `n001` … `n105`, chaining about 20 per `ui do` (`ui do type n001 -- key Return -- type n002 -- key Return ...`). Check the last one shows.
19. (R12.9) Switch to citester; the chat list row "cibob" shows unread messages. Open it. Check: the chat opens on the first unread message: "n001" is visible near the top and "n105" is not visible.
20. (R12.10) Scroll to the bottom (`ui scroll 900 450 down 60`, repeat until "n105" shows). Scroll up until "quote target" shows (`ui scroll 900 450 up 60`, repeat). Right-click "quote target" → "Reply"; type `reply to target`, press Return. Click another chat in the chat list, then "cibob" again. Check: the chat opens at its last message, "reply to target" (all read). Click the quoted text "quote target" inside the reply. Check: the chat scrolls to the message "quote target" and it shows (highlighted briefly), with n001 below it.
21. (R12.8) Scroll up and down by a few wheel clicks (`ui scroll 900 450 up 5`) and take a shot at once. Check: a date label of the form "<weekday>, <day> <month>" (for example "Fri, 30 Oct", today's date) floats at the top of the messages while scrolling, and a date separator with the same text is above the first message of the chat. Messages from different days cannot be made here: note this part as SKIPPED.

**Permissions, removal, leaving, deleting.**

22. (R44.11) Switch to cibob → "ci team" → group info. Check: there is no "Edit group profile" (cibob is an admin). Switch to citester → "ci team" → group info. Check: "Edit group profile" is shown; click it; check the editor shows "Enter group name:" with "ci team"; press Escape (if asked to save, click "Exit without saving").
23. (R44.10) Switch to cicarol → "ci team" → group info → "cibob". Check: no "Remove member" (members may not remove). Switch to cibob → group info → "citester". Check: no "Remove member" (an admin may not remove the owner). Press Escape; open "cidan". Check: "Remove member" is shown; click it, then "Remove" in the alert "Remove member?". Check: the chat shows "you removed cidan". Switch to citester → group info → "cicarol" → "Remove member" → "Remove". Check: the chat shows "you removed cicarol".
24. (R44.5) As citester in "ci team". Check: received events show, such as "cibob invited cidan" (or "invited cidan" under cibob's name), "connected" and "removed cidan"; and the sent event "you removed cicarol". Switch to cicarol → "ci team". Check: the received event "removed you".
25. (R44.9) Switch to cibob → "ci team" → group info. Check: "Leave group" is shown and "Delete group" is not (only owners delete a current group). Click "Leave group", then "Leave" in the alert "Leave group?". Check: the chat shows "you left". Open group info again. Check: "Delete group" is now shown.
26. (R44.12) As cibob, in that group info. Check: "Leave group" is not shown any more. Press Escape, right-click the row "ci team" in the chat list. Check: the menu has no "Leave". Close the menu (Escape). Then group info → "Delete group" → "Delete" in the alert "Delete group?". Check: "ci team" is gone from cibob's chat list. Switch to citester → "ci team" → group info. Check: "Delete group" is shown for the owner (do not click it).

You have at most 600 turns, and the whole test fits in about 290 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click 27 730 -- click-text cibob 10 -- click-text citester 20 -- shot bob-chat`
- `ui do type b1 -- key Return -- type b2 -- key Return -- type b3 -- key Return -- wait b3 -- shot sent`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S5, R12.1, R12.2, R12.3, R12.4, R12.5, R12.7, R12.8, R12.9, R12.10, R12.11, R12.12, R44.1 to R44.12), each with PASS, FAIL or SKIPPED (with the reason), its evidence (the text OCR read, screenshot names), and anything else unexpected. A check the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
