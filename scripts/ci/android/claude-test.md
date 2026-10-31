# Test: contacts, 1-time links and the contact address in the SimpleX Chat Android app (checklist batch B02-1)

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

Each case ID is `R<row>`, the row of the manual checklist it comes from (a letter after it marks a part of that row); `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button; it closes one screen at a time.
- A profile without conversations shows the page "Talk to someone" in place of the chat list, without the search field; once it has a conversation, the list shows the search field "Search or paste SimpleX link" and the chats, "Private notes" among them, and the app's own cards as list items.
- The test uses four profiles of this app: citester, cibob, cicarol and cidan. They talk through the app's preset servers on the internet: a connection takes a few seconds to a minute, so wait up to 60 s for it (`ui wait "<text>" 60`).
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.

## How to do things in the app

- **User menu:** tap the profile image at the left end of the bottom toolbar (the "profile image placeholder" with the largest y). The menu lists the profiles by name at the top (tap another name to switch to it), then "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". The name field below "Enter your name:" has the focus: type the name and tap "Create profile" (the button, the lower of the two texts). The new profile becomes the active one; press BACK until its chat list shows. If the alert "Make profile private!" shows, tap "OK".
- **New chat:** "Start new chat" (the round button in the toolbar) opens "New chat": "Create 1-time link", "Paste link / Scan", "Create group", "Create public channel", "Archived contacts" (when there are archived contacts), the search field "Search or paste SimpleX link" and the list "Your contacts".
- **Copy a new 1-time link:** "Start new chat" → "Create 1-time link". The view shows "Share this 1-time invite link" with the link, and "Or show this code" with a QR code. Right of the link are two icon buttons without text (`ui tree`): the first copies the link, the second shares it. Tap the first. Then press BACK until the chat list shows (the link view and "New chat" close one at a time).
- **Copy the address:** in the address view tap "Share address": Android's share sheet opens; tap "Copy" in it (if the sheet has no "Copy", report it and skip the cases that need the copied address).
- **Paste into a field:** tap the field, then `ui key PASTE`. If the field stays empty, long-press it (`ui long-press <x> <y>`) and tap "Paste" in the menu that appears.
- **Connect by the copied link:** "Start new chat" → "Paste link / Scan" → "Tap to paste link" (the emulator has no camera: ignore the scanner part). An alert names the other profile, with "Open new chat" and "Cancel": tap "Open new chat". The chat opens with "Connect" at the bottom: tap it. Wait up to 60 s until the bottom shows the message field "Message" instead. (The chat already holds an item "Messages, files and calls are protected…", so a wait for the text "Message" passes at once: check in the screenshot that "Connect" is gone and the message field is at the bottom.)
- **Send a message:** tap the message field ("Message"), `ui type "<text>"`, then tap "Send Message" (the button at the right end of the field). Check it shows in the chat.
- **Chat info:** tap the contact's name at the top of the chat. `ui key BACK` closes it.
- **Delete a contact (the dialogs):** chat info → "Delete contact" shows the alert "Delete contact?" with "Only delete conversation", "Delete contact" and "Cancel". "Delete contact" then shows a second alert "Delete contact?" with "Contact will be deleted - this cannot be undone!", the switch "Keep conversation" (off), "Delete without notification", "Delete and notify contact" and "Cancel".

## The test

Run the parts in this order; each builds on the ones before.

**A. Setup.**

1. (S1) Onboarding. The first screen has "Get started": tap it. Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".

**B. 1-time links and the first contact.**

1. (R2.2) As citester: "Start new chat" → "Create 1-time link". Check: the link and QR code show. Don't copy it; `ui key BACK`. Check: the alert "Keep unused invitation?" says "You can view invitation link again in connection details." and has "Delete" and "Keep". Tap "Delete". Press BACK until the chat list shows.
2. (R2.1) Copy a new 1-time link (How to). Check: "Share this 1-time invite link" with the link and "Or show this code" with the QR code.
3. (S2) Add the profile `cibob`.
4. (R2.8) As cibob, connect by the copied link. Check: the alert names "citester"; the chat "citester" opens with "Connect"; after it, the message field "Message" shows.
5. (R2.13) As cibob, send `hello from cibob`. Switch to citester.
6. (R2.14) Check: the chat list row "cibob" shows an unread count. Tap it. Check: the chat shows `hello from cibob`. `ui key BACK`. Check: the row's unread count is gone. Open "cibob" again and send `hi from citester`.
7. (R1.11) Switch to cibob, open "citester". Check: `hi from citester` is there: cibob, created in this session, receives without a restart of the app. This also completes R2.13 (sent and received both ways).

**C. More contacts.**

1. (S3) Add the profile `cicarol`; as cicarol, copy a new 1-time link.
2. (R2.6) Switch to cibob, open "Private notes", paste the link into the message field and send it. Check: the note shows the link. Tap the link in the note. Check: the alert names "cicarol" with "Open new chat"; open it, tap "Connect" and wait until "Message" shows. (A link opened from outside the app can't be tested here: this checks a link tapped inside the app.)
3. (S4) Add the profile `cidan`; as cidan, copy a new 1-time link.
4. (R2.9a) Switch to cicarol. Tap the chat list's search field and paste (only the link). Check: the alert names "cidan"; "Open new chat" → "Connect" → "Message" shows. Send `hi cidan`.
5. (S5) Switch to cidan; copy a new 1-time link.
6. (R2.9b) Switch to cibob. Tap the search field, `ui type "hi "`, then paste (a link with text). Check: the alert names "cidan"; "Open new chat" → "Connect" → "Message" shows. Send `hello cidan`.
7. (S6) Switch to cicarol; copy a new 1-time link.
8. (R2.10) Switch to citester. "Start new chat", tap the search field of "New chat" and paste. Check: the alert names "cicarol"; "Open new chat" → "Connect" → "Message" shows.

**D. Clear and delete.**

1. (R2.23) Switch to cibob, open "citester", open chat info. Tap "Clear chat". Check: the alert "Clear chat?" says "All messages will be deleted - this cannot be undone! The messages will be deleted ONLY for you."; tap "Clear". Check: the chat's messages are gone.
2. (R2.16) Switch to citester, open "cibob", open chat info. Tap "Delete contact" → "Delete contact" in the first alert.
3. (R2.19) In the second alert leave "Keep conversation" off and tap "Delete and notify contact". Check: "cibob" is gone from citester's chat list.
4. (R2.20) Switch to cibob, open "citester". Check: the chat shows the event "deleted contact", and the bottom of the chat says "contact deleted" (messages can't be sent).
5. (R2.25) Switch to cidan, open "cicarol", open chat info → "Delete contact" → "Delete contact" → "Delete without notification". Check: "cicarol" is gone from cidan's chat list. Switch to cicarol, open "cidan" and send `are you there`. Wait up to 60 s. Check: the message gets an error mark (a red cross by its time); tap the message: the alert "Message delivery error" explains it (for example "Most likely this contact has deleted the connection with you."). Close it.
6. (R2.21) Switch to cibob, open "cicarol", open chat info → "Delete contact" → "Only delete conversation". Check: the alert "Conversation deleted!" says "You can send messages to cicarol from Archived contacts."; tap "OK"; "cicarol" is gone from the chat list. "Start new chat" → "Archived contacts" → tap "cicarol". Check: the chat with cicarol opens. Send `back again`. Press BACK until the chat list shows. Check: "cicarol" is listed in the chat list again.
7. (R2.22) As cibob, open "cidan", open chat info → "Delete contact" → "Delete contact"; in the second alert turn "Keep conversation" on and tap "Delete without notification". Check: the alert "Contact deleted!" says "You can still view conversation with cidan in the list of chats."; tap "OK". Check: "cidan" is still in the chat list, and opening it shows `hello cidan`.

**E. The contact address (citester).**

1. (R17.1) Switch to citester. User menu → "Create SimpleX address" → "Create SimpleX address" (citester still has cicarol, so the alert "Share address with SimpleX contacts?" shows: tap "Share"). Check: the view shows a QR code, "Share address" and "Address settings".
2. (R17.2) Scroll down, tap "Delete address". Check: the alert "Delete address?" says "All your contacts will remain connected." and has "Delete"; tap "Delete". Check: the view offers "Create SimpleX address" again.
3. (S7) Tap "Create SimpleX address" ("Share" in "Share address with SimpleX contacts?" if it shows), then copy the address (How to). Press BACK until the chat list shows.
4. (R17.10) Switch to cidan. "Start new chat" → "Paste link / Scan" → "Tap to paste link". Check: the alert names "citester" with "Open new chat"; tap it. The chat shows "Tap Connect to send request", the field "Add message" and "Connect": tap "Connect", then "Send request without message" in the alert "Send contact request?". Switch to citester. Check: the chat list shows "cidan" (a contact request). Tap it: the chat shows "Accept contact request" and "Reject" and "Accept" at the bottom. Tap "Reject". Check: the alert "Reject contact request" says "The sender will NOT be notified."; tap "Reject". Check: "cidan" is gone from citester's chat list.
5. (S8) Switch to cidan. Open "citester" (the request chat), open chat info → "Delete contact"; in "Confirm contact deletion?" tap "Confirm". Check: it is gone from cidan's chat list.
6. (R17.4) As cidan, send a request to citester again exactly as in R17.10. Switch to citester, tap "cidan" in the chat list, then "Accept" (if the alert "Accept contact request" shows, tap "Accept"). Check: the bottom now shows the message field "Message" (the pending contact was added and connects).
7. (R17.9) At once send `welcome cidan` as citester. Check: it shows as sent, without waiting for the connection. Switch to cidan, open "citester". Check: `welcome cidan` arrives within 60 s.
8. (R17.6) Switch to cibob and send a request to citester (paste the address as in R17.10: "Open new chat" → "Connect" → "Send request without message"; cibob's old chat "citester" is a deleted contact, the new one may be named "citester" again or with a number). Switch to citester. "Start new chat"; in "Your contacts" tap "cibob". Check: its chat opens with "Accept"; tap it. Check: "Message" shows; send `welcome cibob` and check it shows as sent (R17.9 from "New chat").

You have at most 600 turns, and the whole test fits in about 250 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click-text "Start new chat" -- click-text "Paste link / Scan" 10 -- click-text "Tap to paste link" 10 -- wait "Open new chat" 60 -- shot open-alert`
- `ui do click-text "Message" -- type "hello from cibob" -- click-text "Send Message" -- wait "hello from cibob" -- shot sent`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: S1, R2.2, R2.1, S2, R2.8, R2.13, R2.14, R1.11, S3, R2.6, S4, R2.9a, S5, R2.9b, S6, R2.10, R2.23, R2.16, R2.19, R2.20, R2.25, R2.21, R2.22, R17.1, R17.2, S7, R17.10, S8, R17.4, R17.9, R17.6; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
