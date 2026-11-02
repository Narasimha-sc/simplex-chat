# Directory bot: member screening

## Behavior

The bot accepts a member pending approval once: after a correct captcha, or at once when no captcha applies. With `review = all`, the member then moves to pending review. A moderator accepts the member after that.

`APIAcceptMember` (`src/Simplex/Chat/Library/Commands.hs`) accepts a member pending review.

## Mechanics

- Before handling `DEPendingMember` and `DEPendingMemberMsg` (`apps/simplex-directory-service/src/Directory/Service.hs`), the bot reads the member's status with `getMemberStatus` (`apps/simplex-directory-service/src/Directory/Store.hs`). The query selects `member_status` by user, group and member id.
- The bot handles the event when the status is pending approval. In every other case, including a failed read or a missing member, the bot drops the event.

## Test

`testStaleEventKeepsReview` (`tests/Bots/DirectoryTests.hs`):
- The captcha generator script blocks until a marker file is removed.
- A member without an image joins, adds an image, and sends two messages.
- The member stays pending review.

Condition: the bot receives both messages before the marker file is removed. The test waits 2 s.
