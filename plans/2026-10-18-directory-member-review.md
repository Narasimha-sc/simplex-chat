# Directory bot: members pending approval

## Problem

In a group with member admission `review = all`, a member joining via the directory bot's group link could be accepted without a moderator's accept.

## Cause

The bot handles events from one queue, sequentially. Each event contains the member as of the time of receipt (`pending m` in `apps/simplex-directory-service/src/Directory/Events.hs`).

`APIAcceptMember` (`src/Simplex/Chat/Library/Commands.hs`) depends on the member's current status:
- pending approval, `review = all`: the member becomes pending review.
- pending review: the member is accepted.

Two queued events of one member can both state pending approval. The bot sends `APIAcceptMember` for each, and the second accept applies to a member already pending review.

Captcha generation runs in the event handler thread, and events queue while it runs.

## Fix

Before handling `DEPendingMember` and `DEPendingMemberMsg`, the bot reads the member's status (`getMemberStatus` in `apps/simplex-directory-service/src/Directory/Store.hs`: one column, selected by primary key). The bot handles the event when the status is pending approval (`stillPendingApproval` in `apps/simplex-directory-service/src/Directory/Service.hs`).

The core accepts a member pending approval only from the host (`src/Simplex/Chat/Library/Commands.hs`). The bot is the host and handles events sequentially.

## Test

`testStaleEventKeepsReview` (`tests/Bots/DirectoryTests.hs`):
- The captcha generator script blocks until a marker file is removed.
- A member without an image joins, adds an image, and sends two messages.
- The member stays pending review.

The test requires that the bot receives both messages while the generator is blocked.
