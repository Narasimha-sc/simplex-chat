package chat.simplex.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.layoutId
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import chat.simplex.common.model.CIDirection
import chat.simplex.common.model.ChatController.appPrefs
import chat.simplex.common.model.ChatItem
import chat.simplex.common.views.chat.item.*
import chat.simplex.common.views.helpers.NavigationButtonBack
import org.jetbrains.skia.Bitmap
import kotlin.math.absoluteValue
import kotlin.test.Test
import kotlin.test.assertEquals

class RtlLayoutTest {
  private val placed = mutableMapOf<String, Placed>()

  private fun Bitmap.ink(x: Int, y: Int): Float = 1 - Color(getColor(x, y)).luminance()

  private fun tailSide(dir: CIDirection): String {
    val roundness = appPrefs.chatItemRoundness.get()
    val tail = appPrefs.chatItemTail.get()
    try {
      appPrefs.chatItemRoundness.set(0.75f)
      appPrefs.chatItemTail.set(true)
      val image = Bitmap.makeFromImage(renderScene(LayoutDirection.Rtl) {
        Box(Modifier.background(Color.White)) {
          Box(Modifier.size(100.dp, 60.dp).record(placed, "bubble").clipChatItem(ChatItem.getSampleData(dir = dir), tailVisible = true).background(Color.Black))
        }
      })
      val bubble = placed.getValue("bubble")
      val y = bubble.y + bubble.height - 2
      val left = image.ink(bubble.x + 4, y) > 0.5f
      val right = image.ink(bubble.x + bubble.width - 5, y) > 0.5f
      return if (left && !right) "left" else if (right && !left) "right" else "none"
    } finally {
      appPrefs.chatItemRoundness.set(roundness)
      appPrefs.chatItemTail.set(tail)
    }
  }

  @Test
  fun bubbleTailOnAvatarSideRightToLeft() {
    assertEquals("right", tailSide(CIDirection.DirectRcv()))
    assertEquals("left", tailSide(CIDirection.DirectSnd()))
  }

  @Test
  fun appBarSlotsMirroredRightToLeft() {
    renderScene(LayoutDirection.Rtl) {
      CenteredRowLayout(Modifier.size(300.dp, 50.dp).record(placed, "bar")) {
        Box(Modifier.size(20.dp).record(placed, "navigation"))
        Box(Modifier.size(100.dp, 20.dp))
        Box(Modifier.size(30.dp, 20.dp).record(placed, "buttons"))
      }
    }
    val bar = placed.getValue("bar")
    assertEquals(Placed(280, 15, 20, 20), placed.getValue("navigation").relativeTo(bar))
    assertEquals(Placed(0, 15, 30, 20), placed.getValue("buttons").relativeTo(bar))
  }

  @Test
  fun backArrowMirroredRightToLeft() {
    fun backButton(direction: LayoutDirection): Pair<Bitmap, Placed> {
      val image = renderScene(direction) {
        Box(Modifier.background(Color.White).record(placed, "button")) {
          NavigationButtonBack(onButtonClicked = {}, tintColor = Color.Black)
        }
      }
      return Bitmap.makeFromImage(image) to placed.getValue("button")
    }
    val (ltr, l) = backButton(LayoutDirection.Ltr)
    val (rtl, r) = backButton(LayoutDirection.Rtl)
    val differing = (0 until r.width).sumOf { i ->
      (0 until r.height).count { j -> (rtl.ink(r.x + i, r.y + j) - ltr.ink(l.x + l.width - 1 - i, l.y + j)).absoluteValue > 0.5f }
    }
    assertEquals(0, differing)
  }

  @Test
  fun memberNameRowFromBubbleStartRightToLeft() {
    renderScene(LayoutDirection.Rtl) {
      Box(Modifier.width(300.dp)) {
        DependentLayout(Modifier.record(placed, "layout"), CHAT_BUBBLE_LAYOUT_ID) {
          Box(Modifier.width(150.dp).height(20.dp).record(placed, "name"))
          Box(Modifier.layoutId(CHAT_BUBBLE_LAYOUT_ID).size(100.dp, 40.dp).record(placed, "bubble"))
        }
      }
    }
    val layout = placed.getValue("layout")
    assertEquals(Placed(-50, 0, 150, 20), placed.getValue("name").relativeTo(layout))
    assertEquals(Placed(0, 20, 100, 40), placed.getValue("bubble").relativeTo(layout))
  }

  @Test
  fun shortCaptionAtStartEdgeRightToLeft() {
    renderScene(LayoutDirection.Rtl) {
      Box(Modifier.width(300.dp)) {
        PriorityLayout(Modifier.record(placed, "layout"), CHAT_IMAGE_LAYOUT_ID) {
          Box(Modifier.layoutId(CHAT_IMAGE_LAYOUT_ID).size(200.dp, 100.dp).record(placed, "media"))
          Box(Modifier.size(80.dp, 40.dp).record(placed, "caption"))
        }
      }
    }
    val layout = placed.getValue("layout")
    assertEquals(Placed(0, 0, 200, 100), placed.getValue("media").relativeTo(layout))
    assertEquals(Placed(120, 100, 80, 40), placed.getValue("caption").relativeTo(layout))
  }
}
