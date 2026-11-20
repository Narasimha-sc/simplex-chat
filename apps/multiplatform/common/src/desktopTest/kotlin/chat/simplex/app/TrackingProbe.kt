package chat.simplex.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.simplex.common.ui.theme.Inter
import org.jetbrains.skia.Bitmap
import org.jetbrains.skia.Font
import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.FontStyle
import org.jetbrains.skia.Typeface
import org.jetbrains.skia.paragraph.FontCollection
import org.jetbrains.skia.paragraph.ParagraphBuilder
import org.jetbrains.skia.paragraph.ParagraphStyle
import org.jetbrains.skia.paragraph.TypefaceFontProvider
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.test.Test

class TrackingProbe {
  private val probeDir = System.getenv("PROBE_DIR")
  private val label = System.getenv("PROBE_LABEL")

  private fun trackingPx(tf: Typeface, cp: Int, px: Float): Float {
    val provider = TypefaceFontProvider().apply { registerTypeface(tf, "trackprobe") }
    val fc = FontCollection().apply { setAssetFontManager(provider); setDefaultFontManager(FontMgr.default) }
    val ts = org.jetbrains.skia.paragraph.TextStyle().setFontSize(px).setFontFamilies(arrayOf("trackprobe"))
    val ps = ParagraphStyle().apply { textStyle = ts }
    val s = String(Character.toChars(cp)).repeat(4)
    val p = ParagraphBuilder(ps, fc).apply { pushStyle(ts); addText(s) }.build().apply { layout(10000f) }
    val adv = Font(tf, px).use { f -> f.getWidths(shortArrayOf(tf.getUTF32Glyph(cp)))[0] }
    return p.maxIntrinsicWidth / 4 - adv
  }

  private fun hasTrak(tf: Typeface?) = tf != null && tf.tableTags.contains("trak")

  @Composable
  private fun tracked(s: String, style: TextStyle, scale: Float): AnnotatedString {
    val px = style.fontSize.value * scale
    return buildAnnotatedString {
      append(s)
      if (style.fontFamily == FontFamily.Default) {
        val tf = FontMgr.default.matchFamilyStyle(".AppleSystemUIFont", FontStyle.NORMAL)
        if (hasTrak(tf)) addStyle(SpanStyle(letterSpacing = (-trackingPx(tf!!, 'H'.code, px) / scale).sp), 0, s.length)
        return@buildAnnotatedString
      }
      var i = 0
      while (i < s.length) {
        val cp = s.codePointAt(i)
        val n = Character.charCount(cp)
        val tf = FontMgr.default.matchFamilyStyleCharacter(null, FontStyle.NORMAL, null, cp)
        if (cp > 0x2E80 && hasTrak(tf)) addStyle(SpanStyle(letterSpacing = (-trackingPx(tf!!, cp, px) / scale).sp), i, i + n)
        i += n
      }
    }
  }

  @Test
  fun trackingParity() {
    if (probeDir == null || label == null || !System.getProperty("os.name").lowercase().contains("mac")) return
    val dir = File(probeDir, "base/track").apply { mkdirs() }
    val report = File(probeDir, "fix/report").apply { mkdirs() }
    val lines = StringBuilder()
    val samples = listOf(
      "cjk" to TextStyle(fontFamily = Inter, color = Color.Black),
      "default" to TextStyle(fontFamily = FontFamily.Default, color = Color.Black),
    )
    val texts = mapOf("cjk" to "東京は今日も晴れ Hxg 你好世界", "default" to "Hello world, settings 12:45")
    for (scale in listOf(1f, 1.25f, 1.5f, 2f)) for (size in listOf(12f, 14f, 16f, 18f)) {
      val widths = mutableListOf<Float>()
      val image = renderScene(width = 900, height = 200) {
        CompositionLocalProvider(LocalDensity provides Density(scale, 1f)) {
          Column(Modifier.background(Color.White)) {
            for ((name, st) in samples) {
              val style = st.copy(fontSize = size.sp)
              val s = texts.getValue(name)
              val text = if (label == "fix") tracked(s, style, scale) else AnnotatedString(s)
              BasicText(text, Modifier.padding(2.dp), style, onTextLayout = { widths += it.getLineRight(0) })
            }
          }
        }
      }
      val px = Bitmap.makeFromImage(image).readPixels()!!
      val file = File(dir, "track-$scale-$size.bin")
      val wfile = File(dir, "track-$scale-$size.txt")
      if (label == "base") { file.writeBytes(px); wfile.writeText(widths.joinToString(",")); continue }
      val base = file.readBytes()
      var n = 0
      var mx = 0
      for (i in px.indices) { val dd = abs((px[i].toInt() and 255) - (base[i].toInt() and 255)); if (dd > 2) n++; mx = max(mx, dd) }
      lines.append("TRACK scale=$scale size=$size widthsBase=${wfile.readText()} widthsFix=${widths.joinToString(",")} diffBytes=$n max=$mx\n")
    }
    println(lines)
    File(report, "track.txt").writeText(lines.toString())
  }
}
