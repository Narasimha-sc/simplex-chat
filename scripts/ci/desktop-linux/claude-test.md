# Test: onboarding and the first profile in the SimpleX Chat desktop app (checklist batch B01)

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

Each case ID is `R<row>`, the row of the manual checklist it comes from; `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. The toolbar is at the bottom of the left pane: the profile picture at about 27,730 and the pencil (New chat) at about 363,730. While the profile has no conversations, the right pane shows "Talk to someone" and the left pane shows no search field.
- Never open, connect to or message "Ask SimpleX Team" or any other preset contact, group or channel: they reach real people. Only the profiles this test creates are used.

## How to do things in the app

- **User menu:** click the profile picture (about 27,730). It shows your profile at the top, then "Create SimpleX address" (or "Your SimpleX address" once there is one), "Chat preferences", your other profiles by name (below a line), "Your chat profiles" and "Settings". Clicking your own name at the top opens "Your current profile".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows. If "Your chat profiles" shows the alert "Make profile private!", click "OK".
- **Switch profile:** user menu → click the other profile's name.
- **Settings:** user menu → "Settings". "Appearance" and "Help & support" are near the top; scroll the left pane down (`ui scroll 195 400 down`) to the app version row at the bottom (a version number such as 7.1…), click it, then "Developer tools", which holds "Chat console" and "Reset all hints". Escape closes one screen at a time.
- **New chat:** the pencil (about 363,730) opens "New chat" with "Create 1-time link", "Paste link", "Create group" and "Create public channel".
- **Create a group:** pencil → "Create group". Click the name field about 40 px below the text "Enter group name", type the name, and click "Create group" (the lower of the two). If "Skip inviting members" shows, click it.
- **Closing alerts:** an alert's buttons are text ("OK", "Cancel", "Delete", …): click the one the step names.

## The test

Run the parts in this order; each builds on the one before.

**A. Onboarding.** Each screen waits for the one before it; wait for a text before clicking it.

1. (R1.5) The first screen has "Create your profile": click it. The next screen has the field "Enter profile name…" and the button "Create profile". Without typing, click "Create profile". Check: the screen stays (the field "Enter profile name…" is still shown). Click the field, `ui type "   "` (three spaces), click "Create profile". Check: the screen stays. Then `ui key BackSpace BackSpace BackSpace`.
2. (R1.4) Type `@citester`. Check, in the screenshot: a red info icon shows at the right end of the field. Click it. Check: the alert "Invalid name!" says "Correct name to citester?" and has "OK" and "Cancel". Click "OK". Check: the field shows `citester` and the red icon is gone.
3. (R1.2) Click "Create profile". Check: the next screen offers "Use random passphrase" (the profile was created). Click "Use random passphrase", then "OK" in the alert that follows.
4. (R1.14) The screen "Your network" shows "Setup routers" and "Continue". Click "Setup routers". Check: the screen "Server operators" shows the operators as two cards with logos, each with a round check mark, and an "OK" button. Take a shot, click "OK". Click "Continue". Check: the screen "Network commitments" shows "Privacy policy and conditions of use." and "Accept". Click "Privacy policy and conditions of use.". Check: the conditions open (a long text). Take a shot, close them with Escape (or the back arrow at the top left), then click "Accept".
5. (R1.10) Wait up to 60 s for the chat list. Check: the right pane shows "Talk to someone"; the left pane shows the toolbar with the profile picture and the pencil.

**B. The first page and its buttons (citester, no conversations).**

1. (R1.7) Check: the right pane shows "Talk to someone" with two cards, "Let someone connect to you" and "Connect via link or QR code". Click "Let someone connect to you". Check: the page "Create your link" shows "Invite someone privately" and "Create your public address", and "Back". Click "Back". Check: "Talk to someone" shows again.
2. (R1.13) Click "Connect via link or QR code". Check: a view with "Paste the link you received" and "Tap to paste link" opens (don't click it). Press Escape. Click the pencil. Check: "New chat" shows "Create 1-time link", "Paste link", "Create group" and "Create public channel". Press Escape until "Talk to someone" shows with nothing else open.

**C. The address and 1-time link cards.**

1. (R1.19a) "Let someone connect to you" → "Create your public address". Check: the address is created at once: the view shows "Use this address in your social media profile, website, or email signature." and a QR code. Press Escape. Check: the card now reads "Your public address".
   Then user menu → "Your SimpleX address" → scroll down → "Delete address". Check: the alert "Delete address?" with "Delete". Click "Delete". Check: the view now offers "Create SimpleX address" and "SimpleX address or 1-time link?". Click "SimpleX address or 1-time link?". Check: the view "Address or 1-time link?" opens with "Share address publicly" and "Share 1-time link with a friend". Press Escape until no view is open in the left pane (Escape does nothing more once all are closed). The right pane still shows the page "Create your link" (the pages don't return to "Talk to someone" by themselves).
   Then click "Invite someone privately" there. Check: a 1-time link is created: the view shows "Send the link via any messenger - it's secure. Ask to paste into SimpleX." with a link and a QR code. Press Escape. Check: the alert "Keep unused invitation?" with "Delete" and "Keep". Click "Delete".
   (The checklist also names "create address from how to use it": the app's code shows no create button in that view; note it as not present, not as a failure.)
2. (R1.9) User menu → "Create SimpleX address". Check: the view "SimpleX address" offers "Create SimpleX address". Click it. Check: the view now shows a QR code, "Share address" and "Address settings" (the address exists). Press Escape until the chat list shows.

**D. The chat list cards (citester, with a conversation).**

1. (S1) Create the group `ci notes` (How to: Create a group). Press Escape until the left pane shows the chat list: it now has the search field "Search or paste SimpleX link" and lists "ci notes".
2. (R1.18) Check: the chat list shows a card with "Bottom bar" and "Top bar" (Bottom bar selected). Click "Top bar". Check: the search field moves to the top of the left pane (y under 200). Click "Bottom bar" (now near the top). Check: the search field is back at the bottom. Then click the small close mark at the right end of the card, right of "Top bar" (find it in the screenshot). Check: the alert "Reachable app toolbars" says "You can change it in Appearance settings."; click "OK". Check: the card is gone.
3. (R1.19b) Check: above the chats (the list is drawn from the bottom up, so the card is at its top) the list shows a card with "New 1-time link" and "Paste link" and a close button at its top right. Click "New 1-time link". Check: a 1-time link view opens; press Escape, and click "Delete" in "Keep unused invitation?". Click the card's close button. Check: the card is gone. Then Settings → app version row → "Developer tools" → "Reset all hints". Press Escape until the chat list shows. Check: the "New 1-time link" / "Paste link" card shows again.

**E. Appearance.**

1. (R1.1) Settings → "Appearance". Open the "Color mode" menu (click its value) and choose "Dark". Check: the app turns dark. Press Escape, then Settings → "Help & support" → "About SimpleX Chat". Check, in the screenshot: the SimpleX logo at the top is drawn in light colours (its letters are white or light) on the dark background. Take a shot. Then set "Color mode" back to "System" and open "About SimpleX Chat" again. Check: the logo is drawn in its dark colours on a light background. (The system theme of the display can't be switched here: the check uses the app's own setting.)

**F. More profiles.**

1. (R1.3) Add the profile `ci spaces` (How to: Add a profile). Check: the field accepts the space (no red icon next to "Enter your name:"), "Create profile" creates it, and the user menu then shows the name `ci spaces` with its space.
2. (R1.6) Switch to citester. Settings → app version row → "Developer tools" → "Chat console". Click the message field at the bottom of the console, `ui type '/_profile 1 {"displayName":"citester","fullName":"CI Full Name"}'`, and press Return. Check: the console shows the command and a response `userProfileUpdated`, not an error. Press Escape until the chat list shows. Switch to `ci spaces` and back to citester (this reloads the profile), then user menu → click "citester" at the top. Check: "Your current profile" shows the field "Full name:" with `CI Full Name`, spaces included. Press Escape.

You have at most 600 turns, and the whole test fits in about 120 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Create profile" -- shot R1-5-empty`
- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click 363 730 -- click-text "Create group" 10 -- wait "Enter group name" -- shot new-group`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: R1.5, R1.4, R1.2, R1.14, R1.10, R1.7, R1.13, R1.19a, R1.9, S1, R1.18, R1.19b, R1.1, R1.3, R1.6; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
