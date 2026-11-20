package chat.simplex.app

import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.*
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import chat.simplex.common.ui.theme.Inter
import org.jetbrains.skia.Font
import org.jetbrains.skia.FontMgr
import kotlin.test.Test

class TinyDefaultDiag {
  @Test
  fun diag() {
    val out = StringBuilder()
    val skiko = org.jetbrains.skiko.Version.skiko
    val inter = FontMgr.default.makeFromFile("src/commonMain/moko-resources/fonts/Inter-Regular.ttf")!!
    for (px in listOf(0.3f, 0.43f, 0.5f, 0.7f, 1f, 1.3f, 1.6f, 2f, 2.5f, 3f, 4f, 6f)) {
      val m = Font(inter, px).use { it.metrics }
      out.append("TDIAG skiko=$skiko metrics px=$px ascent=${m.ascent} descent=${m.descent} leading=${m.leading}\n")
    }
    val pns = LineHeightStyle(LineHeightStyle.Alignment.Proportional, LineHeightStyle.Trim.None)
    for ((fontPx, linePx) in listOf(12.8f to 18f, 13.44f to 18f, 16f to 22f, 20f to 28f, 9.6f to 13f)) {
      val defaults = listOf(0f) + listOf(0.43f, 0.6f, 0.8f, 1f, 1.25f, 1.5f, 2f, 2.5f, 3f, 4f, 6f, 8f)
      for (dpx in defaults) {
        var result: TextLayoutResult? = null
        renderScene(width = 300, height = 100) {
          CompositionLocalProvider(LocalDensity provides Density(1f)) {
            val real = TextStyle(fontFamily = Inter, fontSize = fontPx.sp, lineHeight = linePx.sp, lineHeightStyle = pns, color = Color.Black)
            if (dpx == 0f) {
              BasicText(AnnotatedString("Hxg Hxg"), style = real, onTextLayout = { result = it })
            } else {
              BasicText(buildAnnotatedString { withStyle(real.toSpanStyle()) { append("Hxg Hxg") } }, style = real.copy(fontSize = dpx.sp), onTextLayout = { result = it })
            }
          }
        }
        val r = result!!
        out.append("TDIAG skiko=$skiko layout font=$fontPx line=$linePx default=$dpx height=${r.size.height} fb=${r.firstBaseline} top=${r.getLineTop(0)} bottom=${r.getLineBottom(0)}\n")
      }
    }
    println(out)
  }
}
