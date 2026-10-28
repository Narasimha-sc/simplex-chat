# Missing "left" line in the main chat when a pending member leaves

## Problem

When a member who is pending approval or review leaves the group, the "member left" line does not appear in the group's main chat and the chat preview does not show it. The item is in a support chat of a member who has left, which the UI does not list.

## Cause

`xGrpLeave` calls `updateMemberRecordDeleted`, which deletes the member's support chat and sets the status to `GSMemLeft` in the database. It returns only the updated `GroupInfo`, so `xGrpLeave` passes the old member value to `mkGroupChatScope`. That value still has a pending status, so the scope is the member's support chat, which was just deleted. The item is saved with that scope and shows in no view.

## Fix

`updateMemberRecordDeleted` also returns the updated member (support chat removed, new status). `xGrpLeave` passes it to `mkGroupChatScope`, so the item is created in the group scope, as for any non-pending member. The left-member event now uses the updated member (support chat removed, status left) in all cases; the explicit status override is dropped, since the updated member already has the status. The only other caller, member removal in `xGrpMemDel`, keeps only the `GroupInfo`.

## Alternatives considered

- Re-read the member from the database after the update: one more query for a value the function already holds.
- Make `mkGroupChatScope` read the status itself: about 20 callers would change, and most have no stale-status problem.
- Do not create the item for pending members: a product decision, and it would change what the receiving admins and moderators see compared with a leave by a member who is not pending. Members who are not moderators never receive the leave of a pending member: a leave in pending review is forwarded to moderators only, a leave in pending approval is not forwarded at all.

## Tests

`testGLinkPendingApprovalMemberLeaves`: a member pending approval leaves; the admin's last main chat item is "left". On master that item is in the support scope, so the main chat's last item is an earlier one and the test fails.

`testScopedSupportForwardLeave` also checks that alice, bob and dan each have "left (signed)" as the last main chat item after a pending review member leaves.

## Open questions

- UX inconsistency: the "member connected" and pending-review items are created in the support chat, which is deleted on leave.
  - On leave, admins now see "X left" in the main chat although the join never appeared there (same as non-pending leaves).
  - On rejection, the rejecting admin sees no line (the item is created in the support scope, then deleted with it) and other moderators see "removed" in the main chat.
  - Repeated join and leave moves the group to the top of the chat list each time.
