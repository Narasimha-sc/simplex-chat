package chat.simplex.app

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Paragraph
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.createFontFamilyResolver
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import chat.simplex.common.ui.theme.Inter
import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.FontStyle
import kotlin.test.Test

class CjkWidthDiag {
  private val appLayout = try {
    Class.forName("chat.simplex.common.platform.Text_desktopKt").methods.firstOrNull { it.name == "layOutDesktopText" }
  } catch (e: ClassNotFoundException) {
    null
  }

  @Test
  fun cjkWidths() {
    val texts = listOf("東京は今日も晴れ", "東京は\n今日も", "Hxg 東京は ok")
    for (s in texts) {
      var i = 0
      while (i < s.length) {
        val cp = s.codePointAt(i)
        val t = FontMgr.default.matchFamilyStyleCharacter(null, FontStyle.NORMAL, null, cp)
        val tags = t?.tableTags?.toSet() ?: emptySet()
        println("CJKDIAG char ${String(Character.toChars(cp))} U+${cp.toString(16)} fallback=${t?.familyName} id=${t?.uniqueId} trak=${"trak" in tags} STAT=${"STAT" in tags}")
        i += Character.charCount(cp)
      }
    }
    val styles = listOf(
      "plain16" to TextStyle(fontFamily = Inter, fontSize = 16.sp),
      "center16-22" to TextStyle(fontFamily = Inter, fontSize = 16.sp, lineHeight = 22.sp, lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None)),
      "plain12" to TextStyle(fontFamily = Inter, fontSize = 12.sp),
    )
    for (density in listOf(Density(1f), Density(1.25f))) {
      for ((name, style) in styles) {
        for (s in texts) {
          val laidOut = appLayout?.let {
            if (it.parameterCount == 4) it.invoke(null, AnnotatedString(s), style, density, false) else it.invoke(null, AnnotatedString(s), style, density)
          }
          val text = laidOut?.let { it.javaClass.getMethod("getText").invoke(it) as AnnotatedString } ?: AnnotatedString(s)
          val laidStyle = laidOut?.let { it.javaClass.getMethod("getStyle").invoke(it) as TextStyle } ?: style
          val spans = text.spanStyles.joinToString(" ") { "[${it.start},${it.end} ls=${it.item.letterSpacing} fs=${it.item.fontSize} ff=${it.item.fontFamily} feat=${it.item.fontFeatureSettings}]" }
          val p = Paragraph(text.text, laidStyle, Constraints(maxWidth = 4000), density, createFontFamilyResolver(), spanStyles = text.spanStyles)
          println("CJKDIAG layout d=${density.density} $name \"${s.replace("\n", "\\n")}\" width=${p.maxIntrinsicWidth} height=${p.height} lh=${laidStyle.lineHeight} spans=$spans")
        }
      }
    }
  }
}
