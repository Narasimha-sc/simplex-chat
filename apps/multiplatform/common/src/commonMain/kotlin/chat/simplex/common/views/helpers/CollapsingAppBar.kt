package chat.simplex.common.views.helpers

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.unit.IntSize
import chat.simplex.common.model.ChatController.appPrefs

val LocalAppBarHandler: ProvidableCompositionLocal<AppBarHandler?> = staticCompositionLocalOf { null }

@Composable
fun rememberAppBarHandler(key1: Any? = null, key2: Any? = null, keyboardCoversBar: Boolean = true, connection: () -> CollapsingAppBarNestedScrollConnection = ::CollapsingAppBarNestedScrollConnection): AppBarHandler {
  val graphicsLayer = rememberGraphicsLayer()
  val backgroundGraphicsLayer = rememberGraphicsLayer()
  return remember(key1, key2) { AppBarHandler(graphicsLayer, backgroundGraphicsLayer, keyboardCoversBar, connection = connection()) }
}

@Composable
fun adjustAppBarHandler(handler: AppBarHandler): AppBarHandler {
  val graphicsLayer = rememberGraphicsLayer()
  val backgroundGraphicsLayer = rememberGraphicsLayer()
  if (handler.graphicsLayer == null || handler.graphicsLayer?.isReleased == true || handler.backgroundGraphicsLayer?.isReleased == true) {
    handler.graphicsLayer = graphicsLayer
    handler.backgroundGraphicsLayer = backgroundGraphicsLayer
  }
  return handler
}

fun Modifier.copyViewToAppBar(blurRadius: Int, graphicsLayer: GraphicsLayer?): Modifier {
  return if (blurRadius > 0 && graphicsLayer != null) {
    this.drawWithContent {
      graphicsLayer.record {
        this@drawWithContent.drawContent()
      }
      drawLayer(graphicsLayer)
    }
  } else this
}

fun DrawScope.copyBackgroundToAppBar(graphicsLayerSize: MutableState<IntSize>?, backgroundGraphicsLayer: GraphicsLayer?, scope: DrawScope.() -> Unit) {
  val blurRadius = appPrefs.appearanceBarsBlurRadius.get()
  if (blurRadius > 0 && graphicsLayerSize != null && backgroundGraphicsLayer != null) {
    graphicsLayerSize.value = backgroundGraphicsLayer.size
    backgroundGraphicsLayer.record {
      scope()
    }
    drawLayer(backgroundGraphicsLayer)
  } else {
    scope()
  }
}

@Stable
class AppBarHandler(
  var graphicsLayer: GraphicsLayer?,
  var backgroundGraphicsLayer: GraphicsLayer?,
  val keyboardCoversBar: Boolean = true,
  listState: LazyListState = LazyListState(0, 0),
  scrollState: ScrollState = ScrollState(initial = 0),
  val connection: CollapsingAppBarNestedScrollConnection = CollapsingAppBarNestedScrollConnection()
) {
  val title = mutableStateOf("")
  var listState by mutableStateOf(listState, structuralEqualityPolicy())
    internal set

  var scrollState by mutableStateOf(scrollState, structuralEqualityPolicy())
    internal set

  val backgroundGraphicsLayerSize: MutableState<IntSize> = mutableStateOf(IntSize.Zero)

  // Bars that blur a copy of the scrolled content depend on this to know the copy moved. It is bumped from a collector
  // rather than while drawing: a write made during the draw phase invalidates the bars every frame and never settles.
  val contentVersion: MutableState<Int> = mutableStateOf(0)

  companion object {
    var appBarMaxHeightPx: Int = 0
  }
}

open class CollapsingAppBarNestedScrollConnection(): NestedScrollConnection {
  var scrollTrackingEnabled = true
  open var appBarOffset: Float by mutableFloatStateOf(0f)

  override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
    appBarOffset += available.y
    return Offset(0f, 0f)
  }

  override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
    appBarOffset -= available.y
    return Offset(x = 0f, 0f)
  }
}

class FixedAppBarNestedScrollConnection: CollapsingAppBarNestedScrollConnection() {
  override var appBarOffset: Float
    get() = 0f
    set(value) {}
}
