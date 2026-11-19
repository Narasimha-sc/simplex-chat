package chat.simplex.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import org.jetbrains.skia.Font
import org.jetbrains.skia.FontHinting
import org.jetbrains.skia.FontMgr
import kotlin.test.Test

class DefaultFontDiag {
  @Test
  fun diag() {
    val out = StringBuilder()
    for (name in listOf("Noto Sans", "DejaVu Sans", "Arial", "Liberation Sans", "sans-serif")) {
      FontMgr.default.matchFamily(name).use { set ->
        val tf = if (set.count() > 0) set.matchStyle(org.jetbrains.skia.FontStyle.NORMAL) else null
        out.append("DIAG family=$name count=${set.count()} resolved=${tf?.familyName}\n")
        if (tf != null) for (px in listOf(9.8f, 11.2f, 12.25f, 14f, 16f)) {
          for (hinting in listOf(null, FontHinting.NONE, FontHinting.SLIGHT, FontHinting.NORMAL, FontHinting.FULL)) {
            Font(tf, px).use { f ->
              if (hinting != null) f.hinting = hinting
              val m = f.metrics
              out.append("DIAG   px=$px hinting=${hinting ?: "default(${f.hinting})"} ascent=${m.ascent} descent=${m.descent} leading=${m.leading}\n")
            }
          }
        }
      }
    }
    val placed = mutableMapOf<String, Placed>()
    for ((scale, lh) in listOf(0.7f to 14f, 0.7f to 13.5f, 0.8f to 14f, 0.875f to 14f, 1f to 14f, 1f to 16.5f)) {
      for (h in listOf(lh, lh * 0.96f, lh * 0.92f)) {
        var result: TextLayoutResult? = null
        renderScene(width = 300, height = 100) {
          CompositionLocalProvider(LocalDensity provides Density(scale, 1f)) {
            Box(Modifier.background(Color.White)) {
              BasicText(AnnotatedString("Hxg Hxg"), Modifier.record(placed, "t"), TextStyle(color = Color.Black, fontFamily = FontFamily.Default, fontSize = 14.sp, lineHeight = h.sp, lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Proportional, LineHeightStyle.Trim.None)), onTextLayout = { result = it })
            }
          }
        }
        val r = result!!
        out.append("DIAG layout scale=$scale lh=$h px=${14 * scale} linePx=${h * scale} height=${r.size.height} fb=${r.firstBaseline} top=${r.getLineTop(0)} bottom=${r.getLineBottom(0)}\n")
      }
    }
    println(out)
  }
}
