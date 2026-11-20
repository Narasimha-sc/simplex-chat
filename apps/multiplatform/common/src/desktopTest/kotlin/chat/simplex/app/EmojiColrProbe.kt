package chat.simplex.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
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
import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.FontStyle
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.test.Test

class EmojiColrProbe {
  private val probeDir = System.getenv("PROBE_DIR")
  private val label = System.getenv("PROBE_LABEL")

  private fun colrV0Font(): ByteArray? {
    val tf = FontMgr.default.matchFamilyStyle("Segoe UI Emoji", FontStyle.NORMAL) ?: return null
    val tags = tf.tableTags.sorted()
    val tables = tags.map { tag ->
      val data = tf.getTableData(tag)!!.bytes
      if (tag == "COLR") { data[0] = 0; data[1] = 0 }
      tag to data
    }
    val out = ByteArrayOutputStream()
    val d = DataOutputStream(out)
    val n = tables.size
    var pow = 1
    var log = 0
    while (pow * 2 <= n) { pow *= 2; log++ }
    d.writeInt(0x00010000); d.writeShort(n); d.writeShort(pow * 16); d.writeShort(log); d.writeShort(n * 16 - pow * 16)
    var offset = 12 + n * 16
    for ((tag, data) in tables) {
      var sum = 0L
      val padded = data.copyOf((data.size + 3) / 4 * 4)
      for (i in padded.indices step 4) sum = (sum + (((padded[i].toLong() and 255) shl 24) or ((padded[i + 1].toLong() and 255) shl 16) or ((padded[i + 2].toLong() and 255) shl 8) or (padded[i + 3].toLong() and 255))) and 0xffffffffL
      d.write(tag.toByteArray(Charsets.US_ASCII)); d.writeInt(sum.toInt()); d.writeInt(offset); d.writeInt(data.size)
      offset += padded.size
    }
    for ((_, data) in tables) { d.write(data); repeat((4 - data.size % 4) % 4) { d.write(0) } }
    return out.toByteArray()
  }

  private val samples = listOf("Hxg 😀🎉 ok", "💻 desktop", "🚀❤️👍🏽", "👨‍👩‍👧 🇺🇸")

  private fun emojiRanges(s: String): List<IntRange> {
    val out = mutableListOf<IntRange>()
    var i = 0
    var start = -1
    while (i < s.length) {
      val cp = s.codePointAt(i)
      val n = Character.charCount(cp)
      val emoji = cp >= 0x2600 && cp != 0x20 && (cp >= 0x1F000 || cp in 0x2600..0x27BF || cp == 0x200D || cp in 0xFE00..0xFE0F)
      if (emoji && start < 0) start = i
      if (!emoji && start >= 0) { out += start until i; start = -1 }
      i += n
    }
    if (start >= 0) out += start until s.length
    return out
  }

  @Test
  fun emojiParity() {
    if (probeDir == null || label == null || !System.getProperty("os.name").lowercase().contains("win")) return
    val bytes = colrV0Font()
    val flat = bytes?.let { FontFamily(androidx.compose.ui.text.platform.Font("SegoeUIEmojiColrV0", it)) }
    val dir = File(probeDir, "base/emoji").apply { mkdirs() }
    val report = File(probeDir, "fix/report").apply { mkdirs() }
    val lines = StringBuilder()
    for (scale in listOf(1f, 1.25f, 1.5f, 2f)) for (size in listOf(14f, 16f, 22f)) {
      val image = renderScene(width = 600, height = 400) {
        CompositionLocalProvider(LocalDensity provides Density(scale, 1f)) {
          Column(Modifier.background(Color.White)) {
            for (s in samples) {
              val text = if (label == "fix" && flat != null) buildAnnotatedString { append(s); for (r in emojiRanges(s)) addStyle(SpanStyle(fontFamily = flat), r.first, r.last + 1) } else AnnotatedString(s)
              BasicText(text, Modifier.padding(2.dp), TextStyle(fontFamily = Inter, fontSize = size.sp, color = Color.Black))
            }
          }
        }
      }
      val px = Bitmap.makeFromImage(image).readPixels()!!
      val file = File(dir, "emoji-$scale-$size.bin")
      if (label == "base") { file.writeBytes(px); continue }
      val base = file.readBytes()
      var n = 0
      var mx = 0
      for (i in px.indices) { val dd = abs((px[i].toInt() and 255) - (base[i].toInt() and 255)); if (dd > 2) n++; mx = max(mx, dd) }
      lines.append("EMOJI scale=$scale size=$size flatFont=${bytes?.size} diffBytes=$n max=$mx\n")
      File(report, "emoji-$scale-$size.png").writeBytes(org.jetbrains.skia.Image.makeFromBitmap(Bitmap.makeFromImage(image)).encodeToData(org.jetbrains.skia.EncodedImageFormat.PNG)!!.bytes)
      val baseBmp = Bitmap().apply { allocPixels(Bitmap.makeFromImage(image).imageInfo); installPixels(base) }
      File(report, "emoji-base-$scale-$size.png").writeBytes(org.jetbrains.skia.Image.makeFromBitmap(baseBmp).encodeToData(org.jetbrains.skia.EncodedImageFormat.PNG)!!.bytes)
    }
    println(lines)
    File(report, "emoji.txt").writeText(lines.toString())
  }
}
