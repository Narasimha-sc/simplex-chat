package chat.simplex.app

import androidx.compose.foundation.text.BasicText
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.*
import androidx.compose.ui.unit.sp
import chat.simplex.common.ui.theme.Inter
import org.jetbrains.skia.Font
import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.FontStyle
import kotlin.test.Test

class FallbackFontDiag {
  @Test
  fun diag() {
    val out = StringBuilder()
    val skiko = org.jetbrains.skiko.Version.skiko
    for (ch in listOf(0x6771, 0x4eac, 0x3042, 0xc548, 0x0645, 0x0e2a, 0x1F600, 0x1F680, 0x1F4BB)) {
      val tf = FontMgr.default.matchFamilyStyleCharacter(null, FontStyle.NORMAL, arrayOf("en"), ch)
      val tags = tf?.tableTags?.joinToString(",") ?: ""
      val colr = tf?.getTableData("COLR")?.bytes
      val colrVersion = if (colr != null && colr.size >= 2) ((colr[0].toInt() and 255) shl 8) or (colr[1].toInt() and 255) else -1
      val glyph = tf?.getUTF32Glyph(ch)
      val advance = if (tf != null && glyph != null) Font(tf, 16f).use { f -> f.getWidths(shortArrayOf(glyph.toShort()))[0] } else Float.NaN
      out.append("FDIAG skiko=$skiko char=${Integer.toHexString(ch)} family=${tf?.familyName} glyph=$glyph advance16=$advance colr=$colrVersion tables=$tags\n")
    }
    for (text in listOf("東京は", "مرحبا", "😀🚀")) {
      var result: TextLayoutResult? = null
      renderScene(width = 400, height = 80) {
        BasicText(AnnotatedString(text), style = TextStyle(fontFamily = Inter, fontSize = 16.sp, color = Color.Black), onTextLayout = { result = it })
      }
      val r = result!!
      out.append("FDIAG skiko=$skiko layout text=$text width=${r.getLineRight(0)} boxes=${(0 until text.length).joinToString(";") { r.getBoundingBox(it).let { b -> "${b.left},${b.right}" } }}\n")
    }
    println(out)
  }
}
