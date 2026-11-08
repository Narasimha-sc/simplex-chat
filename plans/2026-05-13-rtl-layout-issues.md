# Right-to-left layout: bubble tails, toolbars, framed rows and directional icons

## Problem

On Android and desktop, with a right-to-left language (Arabic, Persian, Hebrew), issue #5448:

- message bubble tails are on the wrong side: a received bubble is drawn over the sender's avatar, and the tail of a sent bubble is on the inner edge;
- in centred toolbars, the navigation button (back, close or profile picture) is kept on the left and the action buttons on the right (chat, chat list, New chat sheet, settings pages with the one-hand UI, selection mode);
- back and forward arrows, chevrons, the sent-via-proxy arrow and the signal-strength waves are drawn in their left-to-right direction;
- a short caption under an image, file or voice message is placed at the end edge;
- the group member name and role row above a short received message is aligned with the far edge and may be partly outside the pane;
- the supporter banner picture is kept at the right edge, over the start of the banner text; the room reserved for the picture is on the left.

## Cause

Each of these is drawn with left/right coordinates instead of start/end ones:

- In `chatItemShape` (`ChatItemView.kt`), the tail is mirrored by `sent` alone, and the `LayoutDirection` passed by `GenericShape` is ignored; the padding reserved for the tail (`FramedItemView.kt`, `ChatView.kt`) and `chatItemOffset` depend on the layout direction.
- In `CenteredRowLayout` (`FramedItemView.kt`), used by every centred `DefaultAppBar`, the navigation and buttons slots are placed with `place`.
- The rows of `PriorityLayout` are placed with `place` when `limitToPriorityWidth` is set (classic items and captionless media), those of `DependentLayout` in all cases; the picture of `SupportSimpleXBanner` is placed with `place` at the right edge.
- The directional vector icons are drawn as in their SVG files, in both directions.

## Fix

- In `chatItemShape`, the tail is mirrored when `sent != (layoutDirection == LayoutDirection.Rtl)`.
- The navigation and buttons slots of `CenteredRowLayout`, the rows of `PriorityLayout` and `DependentLayout`, and the banner picture are placed with `placeRelative`.
- Under right-to-left, `Painter.mirrorIfRtl()` (`Modifiers.kt`) returns a painter with the original drawn at horizontal scale -1; under left-to-right, the original painter is returned. The function is applied to `ic_arrow_back_ios_new` (`NavigationButtonBack`, onboarding cards' Back, the desktop full-screen video Back, What's new previous version, bot commands menu), `ic_arrow_forward_ios` (share profile, What's new next version), `ic_chevron_right` (bot commands submenu, the "Don't enable" button of `SetDeliveryReceiptsView`), `ic_arrow_forward` (sent via proxy in the message meta and in Info → Delivery, "Show message status" in `AdvancedNetworkSettings`, the go-to-forwarded-message button `GoToItemInnerButton`, whose `icon` parameter is now a `Painter`) and the four `ic_radiowaves_up_forward_*` icons (`SubscriptionStatusIcon`).
- In Info → Delivery, the status icon is mirrored when it is `ic_chevron_right_2` (forwarded), the only directional icon among the results of `GroupSndStatus.statusIcon()`.

## Scope

Android and desktop (common code; the full-screen video Back button is desktop only). iOS is unchanged.

Unchanged: reply, forward and open-link icons, backspace, login and logout icons, play icons, `ic_search`, delivery ticks, the send button, Markdown tables, the selection mode offset, the voice message progress bar, and the restart that desktop needs to apply a new layout direction.
