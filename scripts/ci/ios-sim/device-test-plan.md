# Device test plan: custom chat lists (tags): create, add chats, filter, edit, delete

The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the table and build on each other: two local groups, "ci tag one" and "ci tag two", and one list, `work`, renamed to `work list` in R52.3 and deleted in R52.4.

## How to do things

- **The list row** (one-hand UI): just above the search field, near the bottom. With no list of your own it shows the preset filters ("Groups", "Notes") and "Add list"; once a list exists, "Add list" becomes a "+" button at the end of the row and the list shows by name.
- **Creating a group:** "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type the name, check the value in the tree (the keyboard may capitalize it: then fix it) → tap the "Create group" button (the list row, not the title; use `ui tap-xy` if ambiguous) → "Skip" if it shows → go back to the chat list with the navigation back button.
- **A chat row's list action:** swipe the chat's row from right to left (`ui swipe 360 <y> 120 <y>`, y from `ui find`): the "List" action appears at the right end (a full swipe runs it at once). It opens a sheet with your lists, each with a round selection mark.
- **Closing a sheet:** swipe it down, or tap outside it.

| ID | Do | Expect |
|----|----|--------|
| S1 | Create the group `ci tag one`, then the group `ci tag two`; go back to the chat list | The chat list shows "ci tag one", "ci tag two" and "Private notes"; the list row shows "Groups", "Notes" and "Add list" |
| R52.2 | Tap "Add list" → in the editor tap the field "List name..." (`ui tap-value "List name..."`), type `work` (check the value) → tap "Save list"; close the sheet if it stays. Then the list action on "ci tag one" → tap "work" in the sheet. Tap "work" in the list row; shot. Tap "work" again; shot | After saving, the list row shows "work" and a "+" in place of "Add list". After choosing "work" for "ci tag one", the sheet closes. With "work" selected the chat list shows "ci tag one" only (not "ci tag two", not "Private notes"); tapping "work" again shows all chats |
| R52.3 | Long-press "work" in the list row (`ui long-press` at its centre) → a sheet lists your lists: tap "work" in it → the editor shows `work` in the name field: tap the field at the right end of the text, `ui type " list"`, check the value is `work list` → tap "Save list"; close the sheets | The long press opens the sheet with the list "work" and "Create list"; the editor's "Save list" is enabled after the change; the list row then shows "work list", and selecting it still shows "ci tag one" only |
| R52.4 | Long-press "work list" in the list row → in the sheet swipe the row "work list" from right to left (`ui swipe 360 <y> 120 <y>`) → tap "Delete" → in the alert "Delete list?" tap "Delete"; close the sheet | The alert "Delete list?" says "All chats will be removed from the list work list, and the list deleted."; after "Delete" the list row no longer has "work list" and shows "Add list" again; "ci tag one" and "ci tag two" are still in the chat list |
