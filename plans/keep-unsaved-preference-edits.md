# Keep unsaved preference edits when a message arrives

## Problem

On Android and desktop, unsaved edits in Group preferences, Member admission and Contact preferences are discarded when any message or event of that chat arrives. Leaving the screen then shows no "Save preferences?" alert.

## Cause

Each screen keeps its edit state and the saved state in `rememberSaveable` keyed on the whole `GroupInfo` or `Contact`. `ChatsContext.addChatItem` replaces the chat's `chatInfo` with the event's object, whose `chatTs` and `updatedAt` differ, so the key changes and both states are re-initialised from the saved values.

## Fix

The states are keyed on the saved values they are initialised from:

- GroupPreferences.kt: `gInfo.fullGroupPreferences`
- MemberAdmission.kt: `gInfo.groupProfile.memberAdmission`
- ContactPreferences.kt: `ct.mergedPreferences` and `user`

A change of the saved preferences, by a save or by another member, still re-initialises the screen.

## Scope

- apps/multiplatform common code: Android and desktop.
- iOS keeps the edit state in the parent views and is not changed.
