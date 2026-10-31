# Test: onboarding and the first profile in the SimpleX Chat Android app (checklist batch B01)

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text, and marks disabled elements "disabled".

Each case ID is `R<row>`, the row of the manual checklist it comes from; `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button; it closes one screen at a time.
- While the profile has no conversations, the chat list shows the page "Talk to someone" in place of the list, without the search field. Once there is a conversation, the list shows the search field "Search or paste SimpleX link" and the app's own cards as list items.
- Never open, connect to or message "Ask SimpleX Team" or any other preset contact, group or channel: they reach real people. Only the profiles this test creates are used.

## How to do things in the app

- **User menu:** tap the profile image at the left end of the toolbar (with the toolbar at the bottom, the "profile image placeholder" with the largest y). The menu lists the profiles by name at the top, then "Create SimpleX address" (or "Your SimpleX address" once there is one), "Chat preferences", "Your chat profiles" and "Settings". Tapping the active profile's name opens "Your current profile"; tapping another name switches to that profile.
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". On "Create profile", the name field below "Enter your name:" has the focus: type the name and tap "Create profile" (the button, the lower of the two texts). The new profile becomes the active one; press BACK until the chat list shows. If "Your chat profiles" shows the alert "Make profile private!", tap "OK".
- **Settings:** user menu → "Settings". "Appearance", "Help & support" and "Notifications" are on it; scroll down (`ui scroll 540 1600 down`) to the app version row at the bottom (a version number such as 7.1…), tap it, then "Developer tools", which holds "Chat console" and "Reset all hints".
- **New chat:** "Start new chat" (the round button in the toolbar) opens "New chat" with "Create 1-time link", "Paste link / Scan", "Create group" and "Create public channel".
- **Create a group:** "Start new chat" → "Create group". The field under "Enter group name:" has the focus: type the name, tap "Create group", and wait for "Invite members". Press BACK until the chat list shows.

## The test

Run the parts in this order; each builds on the one before.

**A. Onboarding.** Each screen waits for the one before it; wait for a text before tapping it.

1. (R1.5) The first screen has "Get started": tap it. The next screen has the field "Enter profile name…" and the button "Create profile". Check with `ui tree`: "Create profile" is disabled while the field is empty. `ui type "   "` (three spaces). Check: "Create profile" is still disabled. Then `ui key DEL DEL DEL`.
2. (R1.4) Type `@citester`. Check: a red info icon shows at the right end of the field (a button without text in `ui tree`, right of the field; see the screenshot). Tap it. Check: the alert "Invalid name!" says "Correct name to citester?" and has "OK" and "Cancel". Tap "OK". Check: the field shows `citester`, the icon is gone and "Create profile" is enabled.
3. (R1.2) Tap "Create profile". Check: the screen "Your network" follows (the profile was created).
4. (R1.14) "Your network" shows "Setup routers", "Setup notifications" and "Continue". Tap "Setup routers". Check: the screen "Server operators" shows the operators as two cards with logos, each with a round check mark, and "OK". Take a shot, tap "OK".
5. (R1.15) Tap "Setup notifications". Check: "Private notifications" offers "Instant", "Periodic" and "When app is running". Tap "Periodic", then "OK". Tap "Continue". The app explains periodic notifications in an alert ("Periodic notifications", with "Disable notifications" and "Allow"): tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. (The mode is checked in F2.)
6. (R1.14, continued) The screen "Network commitments" shows "Privacy policy and conditions of use." and "Accept". Tap "Privacy policy and conditions of use.". Check: the conditions open (a long text). Take a shot, `ui key BACK`, then tap "Accept".
7. (R1.10) Wait up to 60 s for the chat list. Check: it shows "Talk to someone", and the toolbar shows the profile image and "Start new chat".

**B. The first page and its buttons (citester, no conversations).**

1. (R1.7) Check: "Talk to someone" shows two cards, "Let someone connect to you" and "Connect via link or QR code". Tap "Let someone connect to you". Check: the page "Create your link" shows "Invite someone privately" and "Create your public address", and "Back". Tap "Back". Check: "Talk to someone" shows again.
2. (R1.13) Tap "Connect via link or QR code". Check: a view with "Paste the link you received" and "Tap to paste link" opens (don't tap it; the emulator has no camera, so the scanner part may show an error or nothing). `ui key BACK`. Tap "Start new chat". Check: "New chat" shows "Create 1-time link", "Paste link / Scan", "Create group" and "Create public channel". `ui key BACK`.

**C. The address and 1-time link cards.**

1. (R1.19a) "Let someone connect to you" → "Create your public address". Check: the address is created at once: the view shows "Use this address in your social media profile, website, or email signature." and a QR code. `ui key BACK`. Check: the card now reads "Your public address".
   Then user menu → "Your SimpleX address" → scroll down → "Delete address". Check: the alert "Delete address?" with "Delete". Tap "Delete". Check: the view now offers "Create SimpleX address" and "SimpleX address or 1-time link?". Tap "SimpleX address or 1-time link?". Check: the view "Address or 1-time link?" opens with "Share address publicly" and "Share 1-time link with a friend". Press BACK until the page "Create your link" shows again (the pages don't return to "Talk to someone" by themselves; one BACK too many at the chat list closes the app: then `ui relaunch`).
   Then tap "Invite someone privately" there. Check: a 1-time link is created: the view shows "Send the link via any messenger - it's secure. Ask to paste into SimpleX." with a link and a QR code. `ui key BACK`. Check: the alert "Keep unused invitation?" with "Delete" and "Keep". Tap "Delete".
   (The checklist also names "create address from how to use it": the app's code shows no create button in that view; note it as not present, not as a failure.)
2. (R1.9) User menu → "Create SimpleX address". Check: the view "SimpleX address" offers "Create SimpleX address". Tap it. Check: the view now shows a QR code, "Share address" and "Address settings" (the address exists). Press BACK until the chat list shows.

**D. The chat list cards (citester, with a conversation).**

1. (S1) Create the group `ci notes` (How to: Create a group). Check: the chat list now shows "ci notes" and the search field "Search or paste SimpleX link".
2. (R1.18) Check: the list shows a card with "Bottom bar" and "Top bar". Tap "Top bar". Check: the search field moves to the top half of the screen (y under 1200). Tap "Bottom bar". Check: the search field is back in the bottom half. Then tap the small close mark at the right end of the card, right of "Top bar" (a clickable element without text; see the screenshot). Check: the alert "Reachable app toolbars" says "You can change it in Appearance settings."; tap "OK". Check: the card is gone.
3. (R1.19b) Check: the list shows a card with "New 1-time link" and "Paste link / Scan" and a "Close button". Tap "New 1-time link". Check: a 1-time link view opens; `ui key BACK`, and tap "Delete" in "Keep unused invitation?". Tap "Close button". Check: the card is gone. Then Settings → app version row → "Developer tools" → "Reset all hints". Press BACK until the chat list shows. Check: the "New 1-time link" / "Paste link / Scan" card shows again.

**E. Appearance.**

1. (R1.1) Settings → "Appearance". Open the "Color mode" menu (tap its value) and choose "Dark". Check: the app turns dark. `ui key BACK`, then Settings → "Help & support" → "About SimpleX Chat". Check, in the screenshot: the SimpleX logo at the top is drawn in light colours (its letters are white or light) on the dark background. Then set "Color mode" back to "System" and open "About SimpleX Chat" again. Check: the logo is drawn in its dark colours on a light background. (The emulator's system theme isn't switched: the check uses the app's own setting.)

**F. Settings and more profiles.**

1. (R1.3) Add the profile `ci spaces` (How to: Add a profile). Check: the field accepts the space (no red icon next to "Enter your name:"), "Create profile" creates it, and the user menu then shows the name `ci spaces` with its space.
2. (R1.15, continued) Switch to citester. Settings → "Notifications". Check: the row "Notification service" shows "Starts periodically" (the mode chosen in A5).
3. (R1.6) Settings → app version row → "Developer tools" → "Chat console". Tap the message field at the bottom of the console, `ui type '/_profile 1 {"displayName":"citester","fullName":"CI Full Name"}'`, and tap the send button at the right end of the field. Check: the console shows the command and a response `userProfileUpdated`, not an error. Run `ui relaunch` (it reloads the profile), then user menu → tap "citester". Check: "Your current profile" shows the field "Full name:" with `CI Full Name`, spaces included.

You have at most 600 turns, and the whole test fits in about 125 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- wait "Enter profile name" 30 -- shot R1-5-empty`
- `ui do click-text "Start new chat" -- click-text "Create group" 10 -- wait "Enter group name" -- type "ci notes" -- shot new-group`
- `ui do relaunch -- shot after-relaunch`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R1-4`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: R1.5, R1.4, R1.2, R1.14, R1.15, R1.10, R1.7, R1.13, R1.19a, R1.9, S1, R1.18, R1.19b, R1.1, R1.3, R1.6; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
