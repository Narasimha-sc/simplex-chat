# Test: notifications in the SimpleX Chat Android app (checklist batch B14)

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields, switches and buttons that have no text.

Each case ID is `R<row>`, the row of the manual checklist it comes from; `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button; `ui key HOME` leaves the app for the home screen; `ui relaunch` restarts the app and waits for its chat list.
- The app was installed with every permission granted, notifications included.
- The test uses four profiles of this app: citester, cibob, cicarol and cidan. Only one profile is active at a time; the app also receives for the others and notifies about them. They talk through the app's preset servers on the internet: wait up to 60 s for a connection or a message.
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.

## How to do things

- **The notification shade:** `ui scroll 540 5 up 1` swipes down from the top edge and opens it; `ui shot` then lists the notifications' texts. A SimpleX notification has the sender's name as its title and the message (or "Connected", "New contact request") as its text. If the app's notifications are grouped, expand the group (tap it, or swipe down on it with `ui scroll <x> <y> up 1`); a contact request's action "Accept" shows on the expanded notification. `ui key BACK` closes the shade.
- **User menu:** tap the profile image at the left end of the bottom toolbar (the "profile image placeholder" with the largest y). The menu lists the profiles by name at the top (tap another name to switch to it), then "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". The name field below "Enter your name:" has the focus: type the name and tap "Create profile" (the button, the lower of the two texts). The new profile becomes the active one; press BACK until its chat list shows. If the alert "Make profile private!" shows, tap "OK".
- **Copy a new 1-time link:** "Start new chat" → "Create 1-time link". Right of the link under "Share this 1-time invite link" are two icon buttons without text (`ui tree`): the first copies the link; tap it. Then press BACK until the chat list shows (the link view and "New chat" close one at a time).
- **Copy the address:** "Share address" opens Android's share sheet: tap "Copy" in it.
- **Connect by a copied 1-time link:** "Start new chat" → "Paste link / Scan" → "Tap to paste link" → "Open new chat" in the alert → "Connect" at the bottom of the chat; wait up to 60 s until the message field "Message" shows. (The chat already holds an item "Messages, files and calls are protected…", so a wait for the text "Message" passes at once: check in the screenshot that "Connect" is gone and the message field is at the bottom.)
- **Send a request by the copied address:** "Start new chat" → "Paste link / Scan" → "Tap to paste link" → "Open new chat" → "Connect" → "Send request without message" in the alert "Send contact request?".
- **Send a message:** tap the message field ("Message"), `ui type "<text>"`, then tap "Send Message".
- **Settings:** user menu → "Settings": "Notifications" (with the row "Notification service": "Runs when app is open", "Starts periodically" or "Always on") and "Chat data" → "Database passphrase" (with the switch "Save passphrase in Keystore").

## The test

Run the parts in this order; each builds on the ones before.

**A. Setup.**

1. (S1) Onboarding. The first screen has "Get started": tap it. Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) As citester copy a new 1-time link. Add the profile `cibob`; as cibob connect by the link and send `hello citester`. Switch to citester, open "cibob", check `hello citester` is there, and press BACK to the chat list.

**B. Messages.**

1. (R18.1) Switch to cibob, open "citester" and send `ping 1`. Wait 10 s, then open the shade. Check: a notification titled "cibob" with the text `ping 1` (a message in a chat of the inactive profile citester). Take a shot.
2. (R18.2) Tap that notification. Check: the app switches to citester and opens its chat with cibob, showing `ping 1`. Send `pong 1` from it. Check: it shows as sent; switch to cibob and check `pong 1` arrived.
3. (R57.12) Switch to citester. Settings → "Chat data" → "Database passphrase". Check: "Save passphrase in Keystore" is on (the default). Press BACK until the chat list shows. Switch to cibob and send `ping 2` to citester. Open the shade. Check: the notification shows the decrypted text `ping 2` (not a placeholder such as "new message"). Close the shade.

**C. Connections and requests.**

1. (R18.4) Switch to citester; copy a new 1-time link. Add the profile `cicarol`; as cicarol connect by the link. Wait up to 60 s, then open the shade. Check: a notification titled "cicarol" with the text "Connected" (for citester). Close the shade.
2. (R18.5) Switch to citester. User menu → "Create SimpleX address" → "Create SimpleX address" (if "Share address with SimpleX contacts?" shows, tap "Share"); copy the address; press BACK until the chat list shows. Add the profile `cidan`; as cidan send a request by the copied address. Wait 10 s, then open the shade. Check: a notification titled "cidan" with the text "New contact request".
3. (R55.12) Expand that notification. Check: its only action is "Accept" (the notification offers no incognito accept; this row's "incognito" part is not offered by the notification).
4. (R18.6) Tap "Accept" on the notification. Check: the app switches to citester and cidan becomes a contact: citester's chat list shows "cidan" without the request; open it and send `welcome cidan`. Open citester's chat info of cidan. Check: it has no "Your random profile" (R55.12: the request was accepted with citester's own profile, not incognito). Switch to cidan and check `welcome cidan` arrives within 60 s.

**D. The chat service.**

1. (R18.7) Switch to citester. Settings → "Notifications". Check: "Notification service" shows "Always on" (chosen in onboarding). Open the shade. Check: a notification "SimpleX Chat service" with "Receiving messages…". Close the shade. Tap "Notification service" and choose "Runs when app is open" (answer any alert with "OK"). `ui key HOME`, open the shade. Check: "SimpleX Chat service" is gone. Close the shade, `ui relaunch`. Settings → "Notifications" → "Notification service" → "Always on" (if an alert asks to allow background use, tap "Allow", and "Allow" in Android's dialog). `ui key HOME`, open the shade. Check: "SimpleX Chat service" with "Receiving messages…" is there while the app is closed. Close the shade, `ui relaunch`.
2. (R18.8) Switch to cibob, open "citester", send `ping 3`, and at once `ui key HOME`. Wait 15 s, open the shade. Check: a notification titled "cibob" with `ping 3` (delivered with the service running and the app in the background). Close the shade, `ui relaunch`. (A sender outside this app can't be used here: the message is sent by another profile of the same app.)

**E. A hidden profile (last: it hides citester).**

1. (R64.3) As cibob: user menu → "Your chat profiles". Long-press the row "citester" (`ui long-press <x> <y>` on its name) → "Hide". On "Hide profile", tap the field "Password to show", tap the eye icon at its right end (so the field shows the text) and type `cipass1`; do the same in "Confirm password". If `ui type` still reports that the field doesn't show the text, the field masks it: don't type again, check the screenshot instead. Then tap "Save profile password". Check: citester is no longer listed. Press BACK until cibob's chat list shows, open "citester" and send `ping hidden`. Wait 20 s, open the shade. Check: no notification with `ping hidden` (compare R18.1, where the same kind of message to the visible profile was notified). Close the shade.

You have at most 600 turns, and the whole test fits in about 170 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do scroll 540 5 up 1 -- shot shade`
- `ui do click-text "Message" -- type "ping 1" -- click-text "Send Message" -- wait "ping 1" -- shot sent`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R18-1`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: S1, S2, R18.1, R18.2, R57.12, R18.4, R18.5, R55.12, R18.6, R18.7, R18.8, R64.3; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
