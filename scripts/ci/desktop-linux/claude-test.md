# Test: contacts, 1-time links and the contact address in the SimpleX Chat desktop app (checklist batch B02-1)

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

Each case ID is `R<row>`, the row of the manual checklist it comes from (a letter after it marks a part of that row); `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database. Begin with `ui shot start` to see it. Never run `ui start` or `ui stop`, except in R2.27, which restarts the app exactly as it says.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. The toolbar is at the bottom of the left pane: the profile picture at about 27,730 and the pencil (New chat) at about 363,730. A profile without conversations shows no search field in the left pane and "Talk to someone" in the right pane; once it has a conversation, the left pane shows the search field "Search or paste SimpleX link" and the chats, "Private notes" among them.
- The test uses four profiles of this app: citester, cibob, cicarol and cidan. They talk through the app's preset servers on the internet: a connection takes a few seconds to a minute, so wait up to 60 s for it (`ui wait "<text>" 60`).
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.

## How to do things in the app

- **User menu:** click the profile picture (about 27,730). It shows your profile at the top, then "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", your other profiles by name (below a line), "Your chat profiles" and "Settings".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts). The new profile becomes the active one; press Escape until the left pane shows its chat list. If the alert "Make profile private!" shows, click "OK".
- **Switch profile:** user menu → click the other profile's name. The left pane then shows that profile's chats.
- **New chat:** the pencil opens "New chat": "Create 1-time link", "Paste link", "Create group", "Create public channel", "Archived contacts" (when there are archived contacts), the search field "Search or paste SimpleX link" at its top, and the list "Your contacts".
- **Copy a new 1-time link:** pencil → "Create 1-time link". The view shows "Share this 1-time invite link" with the link below it, and "Or show this code" with a QR code. Click the link text: the app copies it and shows "Copied to clipboard". Press Escape until the chat list shows (the link view and "New chat" close one at a time).
- **Connect by the copied link:** pencil → "Paste link" → "Tap to paste link". An alert names the other profile, with "Open new chat" and "Cancel": click "Open new chat". The chat opens with "Tap Connect to chat" and "Connect" at the bottom: click "Connect" (the one at the bottom of the right pane). Wait up to 60 s until the bottom shows the message field "Message" instead. (The chat already holds an item "Messages, files and calls are protected…", so a wait for the text "Message" passes at once: check in the screenshot that "Connect" is gone and the message field is at the bottom.)
- **Paste into a field:** click the field, then `ui key ctrl+v`.
- **Send a message:** click the message field at the bottom of the right pane ("Message"), `ui type "<text>"`, then `ui key Return`. Check it shows in the chat.
- **Chat info:** click the contact's name at the top of the right pane. Escape closes it.
- **Chat menu:** `ui right-click <x> <y>` on a chat's name in the left pane opens its menu ("Mark read" or "Mark unread", "Favorite" or "Unfavorite", "Clear", "Delete", …; for a contact request "Accept", "Reject").
- **Delete a contact (the dialogs):** "Delete contact" (or the menu's "Delete") shows the alert "Delete contact?" with "Only delete conversation", "Delete contact" and "Cancel". "Delete contact" then shows a second alert "Delete contact?" with "Contact will be deleted - this cannot be undone!", the switch "Keep conversation" (off), "Delete without notification", "Delete and notify contact" and "Cancel".

## The test

Run the parts in this order; each builds on the ones before.

**A. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".

**B. 1-time links and the first contact.**

1. (R2.2) As citester: pencil → "Create 1-time link". Check: the link and QR code show. Don't copy it; press Escape to go back. Check: the alert "Keep unused invitation?" says "You can view invitation link again in connection details." and has "Delete" and "Keep". Click "Delete". Press Escape until the chat list shows.
2. (R2.4) Pencil → "Create 1-time link", then click in the empty right pane (about 900,400). Check: the link view closes and the same alert shows. Click "Delete".
3. (R2.1) Copy a new 1-time link (How to). Check: "Share this 1-time invite link" with the link, "Or show this code" with the QR code, and "Copied to clipboard" after clicking the link.
4. (S2) Add the profile `cibob`.
5. (R2.8) As cibob, connect by the copied link. Check: the alert names "citester"; the chat "citester" opens with "Connect"; after it, the message field "Message" shows and the chat list lists "citester".
6. (R2.13) As cibob, send `hello from cibob`. Switch to citester.
7. (R2.14) Check: the chat list row "cibob" shows an unread count. Click it. Check: the chat shows `hello from cibob`, and the row's unread count is gone. Send `hi from citester`.
8. (R1.11) Switch to cibob, open "citester". Check: `hi from citester` is there: cibob, created in this session, receives without a restart of the app. This also completes R2.13 (sent and received both ways).
9. (R2.15) As cibob, send `second from cibob`. Switch to citester. Check: the row "cibob" shows an unread count. Right-click it → "Mark read". Check: the count is gone.
10. (R2.27) Right-click "cibob" → "Mark unread". Check: the row shows an unread mark. Restart the app: `ui stop`, then `ui start /home/runner/work/_temp/app/simplex`, then `ui wait "Search or paste SimpleX link" 120`. Check: citester's row "cibob" still shows the unread mark.
11. (R2.33) Right-click "cibob" → "Favorite". Check: a "Favorites" filter (a star) shows in the row of filters next to the search field. Click it. Check: the list shows only "cibob". Click it again to remove the filter. Right-click "cibob" → "Unfavorite". Check: the menu offered "Unfavorite" and the "Favorites" filter is gone.

**C. More contacts.**

1. (S3) Add the profile `cicarol`; as cicarol, copy a new 1-time link.
2. (R2.6) Switch to cibob, open "Private notes", paste the link into the message field (`ui key ctrl+v`) and press Return. Check: the note shows the link. Click the link in the note. Check: the alert names "cicarol" with "Open new chat"; open it, click "Connect" and wait until "Message" shows. (A link opened from outside the app can't be tested here: this checks a link clicked inside the app.)
3. (S4) Add the profile `cidan`; as cidan, copy a new 1-time link.
4. (R2.9a) Switch to cicarol. Click the chat list's search field and paste (only the link). Check: the alert names "cidan"; "Open new chat" → "Connect" → "Message" shows. Send `hi cidan`.
5. (S5) Switch to cidan; copy a new 1-time link.
6. (R2.9b) Switch to cibob. Click the search field, `ui type "hi "`, then paste (a link with text). Check: the alert names "cidan"; "Open new chat" → "Connect" → "Message" shows. Send `hello cidan`.
7. (S6) Switch to cicarol; copy a new 1-time link.
8. (R2.10) Switch to citester. Pencil, click the search field at the top of "New chat" and paste. Check: the alert names "cicarol"; "Open new chat" → "Connect" → "Message" shows.

**D. Clear and delete.**

1. (R2.23) Switch to cibob, open "citester", open chat info. Click "Clear chat". Check: the alert "Clear chat?" says "All messages will be deleted - this cannot be undone! The messages will be deleted ONLY for you."; click "Clear". Check: the chat's messages are gone.
2. (R2.24) Switch to cicarol, open "cibob" and send `to clear`. Right-click "cibob" in the chat list → "Clear" → "Clear" in "Clear chat?". Check: `to clear` is gone from the chat.
3. (R2.16) Switch to citester, open "cibob", open chat info. Click "Delete contact" → "Delete contact" in the first alert.
4. (R2.19) In the second alert leave "Keep conversation" off and click "Delete and notify contact". Check: "cibob" is gone from citester's chat list.
5. (R2.20) Switch to cibob, open "citester". Check: the chat shows the event "deleted contact", and the bottom of the chat says "contact deleted" (messages can't be sent).
6. (R2.18) Switch to citester. Pencil; in "Your contacts" right-click "cicarol" → "Delete" → "Delete contact" → "Delete without notification". Check: "cicarol" is gone from "Your contacts" and from the chat list (citester then has no conversations, so the left pane may be empty and the right pane may show "Talk to someone").
7. (R2.17) Switch to cidan. Right-click "cicarol" in the chat list → "Delete" → "Delete contact" → "Delete without notification". Check: "cicarol" is gone from cidan's chat list.
8. (R2.25) Switch to cicarol, open "cidan" and send `are you there`. Wait up to 60 s. Check: the message gets an error mark (a red cross by its time); click the message: the alert "Message delivery error" explains it (for example "Most likely this contact has deleted the connection with you."). Close it.
9. (R2.21) Switch to cibob, open "cicarol", open chat info → "Delete contact" → "Only delete conversation". Check: the alert "Conversation deleted!" says "You can send messages to cicarol from Archived contacts."; click "OK"; "cicarol" is gone from the chat list. Pencil → "Archived contacts" → click "cicarol". Check: the chat with cicarol opens. Send `back again`. Press Escape until the chat list shows. Check: "cicarol" is listed in the chat list again.
10. (R2.22) As cibob, open "cidan", open chat info → "Delete contact" → "Delete contact"; in the second alert turn "Keep conversation" on and click "Delete without notification". Check: the alert "Contact deleted!" says "You can still view conversation with cidan in the list of chats."; click "OK". Check: "cidan" is still in the chat list, and opening it shows `hello cidan`.

**E. The contact address (citester).**

1. (R17.1) Switch to citester. User menu → "Create SimpleX address" → "Create SimpleX address". Check: the view shows a QR code, "Share address" and "Address settings".
2. (R17.2) Scroll down, click "Delete address". Check: the alert "Delete address?" says "All your contacts will remain connected." and has "Delete"; click "Delete". Check: the view offers "Create SimpleX address" again.
3. (S7) Click "Create SimpleX address", then "Share address". Check: "Copied to clipboard". Press Escape until the chat list shows.
4. (R17.10) Switch to cidan. Pencil → "Paste link" → "Tap to paste link". Check: the alert names "citester" with "Open new chat"; click it. The chat shows "Tap Connect to send request", the field "Add message" and "Connect" at the bottom: click "Connect", then "Send request without message" in the alert "Send contact request?". Switch to citester. Check: the chat list shows "cidan" (a contact request). Click it: the chat shows "Accept contact request" and "Reject" and "Accept" at the bottom. Click "Reject". Check: the alert "Reject contact request" says "The sender will NOT be notified."; click "Reject". Check: "cidan" is gone from citester's chat list.
5. (S8) Switch to cidan. Right-click "citester" in the chat list → "Delete" → "Confirm" in "Confirm contact deletion?". Check: it is gone.
6. (R17.4) As cidan, send a request to citester again exactly as in R17.10. Switch to citester, click "cidan" in the chat list, then "Accept" (if the alert "Accept contact request" shows, click "Accept"). Check: the bottom now shows the message field "Message" (the pending contact was added and connects).
7. (R17.9) At once send `welcome cidan` as citester. Check: it shows as sent, without waiting for the connection. Switch to cidan, open "citester". Check: `welcome cidan` arrives within 60 s.
8. (R17.5) Switch to cicarol and send a request to citester (paste the address as in R17.10: "Open new chat" → "Connect" → "Send request without message"). Switch to citester. Right-click "cicarol" in the chat list → "Accept". Check: "cicarol" becomes a contact (its chat opens with "Message", or the row no longer shows the request).
9. (R17.6) Switch to cibob and send a request to citester the same way (cibob's old chat "citester" is a deleted contact; the new one may be named "citester" again or with a number). Switch to citester. Pencil; in "Your contacts" click "cibob". Check: its chat opens with "Accept"; click it. Check: "Message" shows; send `welcome cibob` and check it shows as sent (R17.9 from "New chat").

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click 363 730 -- click-text "Paste link" 10 -- click-text "Tap to paste link" 10 -- wait "Open new chat" 60 -- shot open-alert`
- `ui do click-text "Message" -- type "hello from cibob" -- key Return -- wait "hello from cibob" -- shot sent`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R2-8`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: S1, R2.2, R2.4, R2.1, S2, R2.8, R2.13, R2.14, R1.11, R2.15, R2.27, R2.33, S3, R2.6, S4, R2.9a, S5, R2.9b, S6, R2.10, R2.23, R2.24, R2.16, R2.19, R2.20, R2.18, R2.17, R2.25, R2.21, R2.22, R17.1, R17.2, S7, R17.10, S8, R17.4, R17.9, R17.5, R17.6; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
