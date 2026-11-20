package chat.simplex.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.currentComposer
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import chat.simplex.common.ui.theme.EmojiFont
import chat.simplex.common.ui.theme.Inter
import org.jetbrains.skia.Bitmap
import org.jetbrains.skia.ColorAlphaType
import org.jetbrains.skia.ColorType
import org.jetbrains.skia.EncodedImageFormat
import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.Typeface
import org.jetbrains.skia.Image
import org.jetbrains.skia.ImageInfo
import java.io.*
import java.util.zip.Deflater
import java.util.zip.DeflaterOutputStream
import java.util.zip.InflaterInputStream
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.test.Test
import kotlin.test.assertNotNull

private class Spec(
  val group: String,
  val template: String,
  val content: String,
  val scale: Float,
  val text: AnnotatedString,
  val style: TextStyle,
  val bubbleRound: Boolean = false,
  val lineHeightScale: Float = 1f,
  val compensate: Boolean = true,
  val width: Float? = null,
  val maxLines: Int = Int.MAX_VALUE,
  val overflow: TextOverflow = TextOverflow.Clip,
) {
  val fontPx: Float get() = (style.fontSize.takeOrElse { 14.sp }).value * scale
  val pad: Int get() = ceil(fontPx * 0.7f).toInt() + 3
}

private class Measured(val box: Placed, val text: Placed, val geometry: String, val boxes: List<Rect>, val linePx: Float)

class DisplayParityProbe {
  private val probeDir = System.getenv("PROBE_DIR")
  private val label = System.getenv("PROBE_LABEL")
  private val sceneWidth = 1400
  private val rowsPerScene = 40

  private val compensation = try {
    Class.forName("chat.simplex.common.platform.ResourcesKt").methods.firstOrNull { it.name == "withDesktopLineHeight" }
  } catch (e: ClassNotFoundException) {
    null
  }

  @Composable
  private fun compensated(style: TextStyle): TextStyle =
    compensation?.invoke(null, style, currentComposer, 0) as TextStyle? ?: style

  private val scales: List<Float> = run {
    val os = listOf(1f, 1.25f, 1.5f, 1.75f, 2f)
    val zoom = (0..10).map { 1f + it / 10f }
    val font = (0..8).map { 0.7f + it / 10f }
    os.flatMap { d -> zoom.flatMap { z -> font.map { f -> ((d * z * f) * 10000).roundToInt() / 10000f } } }.distinct().sorted()
  }

  private val inter = TextStyle(fontFamily = Inter, color = Color.Black)
  private val proportionalNone = LineHeightStyle(LineHeightStyle.Alignment.Proportional, LineHeightStyle.Trim.None)
  private val chatRatio = 22f / 16f
  private val interLineHeight = 3408f / 2816f
  private val contrastFactors = listOf(1f, 0.95f, 0.9f, 0.88f, 0.86f, 0.8485f)

  private val geometryContents: List<Pair<String, AnnotatedString>> = listOf(
    "latin" to AnnotatedString("Hxg Hxg"),
    "two-lines" to AnnotatedString("Hxg\nHxg"),
    "emoji" to AnnotatedString("Hxg 😀🎉 ok"),
    "cjk" to AnnotatedString("Hxg 東京は ok"),
    "arabic" to AnnotatedString("Hxg مرحبا ok"),
    "event-span" to buildAnnotatedString { withStyle(SpanStyle(fontSize = 12.sp, fontWeight = FontWeight.Light)) { append("Hxg updated  12:45") } },
    "cjk-only" to AnnotatedString("東京は今日も晴れ"),
    "arabic-only" to AnnotatedString("مرحبا بالعالم"),
    "emoji-only" to AnnotatedString("😀🎉❤️"),
    "thai-only" to AnnotatedString("สวัสดีครับ"),
    "cjk-two-lines" to AnnotatedString("東京は\n今日も"),
    "blank-line" to AnnotatedString("Hxg\n\nHxg"),
    "leading-newline" to AnnotatedString("\nHxg"),
  )

  private val longText = "The quick brown fox jumps over the lazy dog and keeps running far away from home"

  private fun featureContents(): List<Triple<String, AnnotatedString, (Spec) -> Spec>> = listOf(
    Triple("wrap", AnnotatedString(longText), { s -> s.copyWith(width = 220f) }),
    Triple("ellipsis-2", AnnotatedString(longText), { s -> s.copyWith(width = 160f, maxLines = 2, overflow = TextOverflow.Ellipsis) }),
    Triple("ellipsis-1", AnnotatedString(longText), { s -> s.copyWith(width = 160f, maxLines = 1, overflow = TextOverflow.Ellipsis) }),
    Triple("spans", buildAnnotatedString {
      append("Plain ")
      withStyle(SpanStyle(textDecoration = TextDecoration.Underline)) { append("link") }
      append(" ")
      withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) { append("struck") }
      append(" ")
      withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append("italic") }
      append(" ")
      withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("bold") }
      append(" ")
      withStyle(SpanStyle(fontFamily = FontFamily.Monospace, letterSpacing = (-1).sp)) { append("code()") }
      append(" ")
      withStyle(SpanStyle(fontSize = 12.sp, fontWeight = FontWeight.Light)) { append("12:45") }
    }, { s -> s }),
    Triple("center", AnnotatedString(longText), { s -> s.copyWith(width = 220f, align = TextAlign.Center) }),
    Triple("rtl", AnnotatedString("مرحبا بالعالم hello שלום"), { s -> s.copyWith(width = 220f) }),
    Triple("empty", AnnotatedString(""), { s -> s }),
    Triple("trailing-newline", AnnotatedString("Hxg\n"), { s -> s }),
  )

  private fun Spec.copyWith(width: Float? = this.width, maxLines: Int = this.maxLines, overflow: TextOverflow = this.overflow, align: TextAlign? = null) =
    Spec(group, template, content, scale, text, if (align != null) style.copy(textAlign = align) else style, bubbleRound, lineHeightScale, compensate, width, maxLines, overflow)

  private class Template(val name: String, val style: TextStyle, val bubbleRound: Boolean = false, val lineHeightScale: Float = 1f, val compensate: Boolean = true, val features: Boolean = false)

  private fun siteTemplates(): List<Template> {
    val t = mutableListOf<Template>()
    fun chat(name: String, size: Float, base: TextStyle = inter, ratioSize: Float = size, compensate: Boolean = true, features: Boolean = false, factors: List<Float> = contrastFactors) {
      for (f in factors) {
        val lh = (ratioSize * chatRatio * f).sp
        t += Template("$name-bubble-f$f", base.copy(fontSize = size.sp, lineHeight = lh, lineHeightStyle = proportionalNone), bubbleRound = true, compensate = compensate, features = features && f == 1f)
        t += Template("$name-terminal-f$f", base.copy(fontSize = size.sp, lineHeight = lh, lineHeightStyle = proportionalNone), compensate = compensate, features = features && f == 1f)
      }
    }
    chat("message-16", 16f, features = true)
    chat("quote-15", 15f)
    chat("quote-sender-13.5", 13.5f)
    chat("time-12", 12f)
    chat("event-16-on-12", 16f, ratioSize = 12f)
    chat("event-plain-16-on-12", 16f, ratioSize = 12f)
    chat("event-uncompensated-16-on-12", 16f, ratioSize = 12f, compensate = false)
    chat("event-plain-12", 12f)
    chat("event-default-14-on-12", 14f, base = TextStyle(color = Color.Black, fontFamily = FontFamily.Default), ratioSize = 12f)
    chat("code-mono-14", 14f, base = inter.copy(fontFamily = FontFamily.Monospace), factors = listOf(1f))
    for ((level, scale) in listOf(1 to 1.5625f, 2 to 1.25f)) {
      t += Template("heading$level-bubble", inter.copy(fontSize = (16f * scale).sp, fontWeight = FontWeight.Bold, lineHeight = 22.sp, lineHeightStyle = proportionalNone), bubbleRound = true, lineHeightScale = scale)
      t += Template("heading$level-terminal", inter.copy(fontSize = (16f * scale).sp, fontWeight = FontWeight.Bold, lineHeight = (22f * scale).sp, lineHeightStyle = proportionalNone))
    }
    for ((level, scale) in listOf(1 to 1.5f, 2 to 1.3f, 3 to 1.15f)) {
      t += Template("heading$level-plain", inter.copy(fontSize = (16f * scale).sp, fontWeight = FontWeight.Bold, lineHeight = (22f * scale).sp))
    }
    t += Template("code-mono-plain", inter.copy(fontFamily = FontFamily.Monospace, fontSize = 14.sp, lineHeight = 19.8.sp))
    t += Template("invitation-16-inter", inter.copy(fontSize = 16.sp, lineHeight = (16f * interLineHeight).sp, lineHeightStyle = proportionalNone), bubbleRound = true)
    t += Template("invitation-13-18", inter.copy(fontSize = 13.sp, lineHeight = 18.sp, lineHeightStyle = proportionalNone), bubbleRound = true)
    t += Template("file-14-inter", inter.copy(fontSize = 14.sp, lineHeight = (14f * interLineHeight).sp, lineHeightStyle = proportionalNone), bubbleRound = true)
    t += Template("deleted-16-22", inter.copy(fontSize = 16.sp, lineHeight = 22.sp, lineHeightStyle = proportionalNone), bubbleRound = true)
    for ((size, lh, weight) in listOf(
      Triple(16f, 22f, FontWeight.Normal), Triple(14f, 21f, FontWeight.Normal), Triple(14f, 18f, FontWeight.Normal), Triple(13f, 18f, FontWeight.Normal),
      Triple(14f, 20f, FontWeight.Normal), Triple(15f, 24f, FontWeight.Normal), Triple(14f, 22f, FontWeight.Normal), Triple(16f, 24f, FontWeight.Normal),
      Triple(17.5f, 20f, FontWeight.Normal), Triple(18.5f, 25f, FontWeight.Medium), Triple(33.5f, 42f, FontWeight.Bold), Triple(24f, 22f, FontWeight.Normal),
    )) {
      t += Template("plain-$size-$lh-$weight", inter.copy(fontSize = size.sp, lineHeight = lh.sp, fontWeight = weight), features = size == 16f && lh == 22f || size == 14f && lh == 21f)
    }
    return t
  }

  private val unspecifiedSizes = listOf(6f, 10f, 11.5f, 12f, 12.5f, 13f, 13.5f, 14f, 15f, 16f, 17.5f, 18f, 18.4f, 18.5f, 20f, 20.8f, 22f, 24f, 25f, 26f, 30f, 33.5f, 36f, 48f, 50f)

  private fun geometrySpecs(): List<Spec> {
    val out = mutableListOf<Spec>()
    val templates = siteTemplates()
    for (scale in scales) {
      for (t in templates) {
        for ((name, text) in geometryContents) {
          out += Spec("site", t.name, name, scale, text, t.style, t.bubbleRound, t.lineHeightScale, t.compensate)
        }
        if (t.features) for ((name, text, f) in featureContents()) {
          out += f(Spec("site", t.name, name, scale, text, t.style, t.bubbleRound, t.lineHeightScale, t.compensate))
        }
      }
      for (size in unspecifiedSizes) {
        for ((name, text) in geometryContents) {
          out += Spec("unspecified", "inter-$size", name, scale, text, inter.copy(fontSize = size.sp))
        }
        if (size == 14f || size == 16f) for ((name, text, f) in featureContents()) {
          out += f(Spec("unspecified", "inter-$size", name, scale, text, inter.copy(fontSize = size.sp)))
        }
      }
      for (size in listOf(14f, 16f, 18f)) for ((name, text) in geometryContents) {
        out += Spec("unspecified", "default-$size", name, scale, text, TextStyle(color = Color.Black, fontSize = size.sp))
      }
      for (size in listOf(12f, 14f, 16f)) for ((name, text) in geometryContents) {
        out += Spec("unspecified", "mono-$size", name, scale, text, TextStyle(color = Color.Black, fontFamily = FontFamily.Monospace, fontSize = size.sp))
      }
      for (size in listOf(16f, 36f, 48f)) {
        out += Spec("unspecified", "emoji-font-$size", "emoji", scale, AnnotatedString("😀🎉❤️👍"), TextStyle(color = Color.Black, fontFamily = EmojiFont, fontSize = size.sp))
      }
    }
    return out
  }

  private val latin = (0x21..0x7e).map { it.toChar() }.joinToString("") +
    " ÄÖÜäöüßéèêëàâçñœ " +
    "АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЩЭЮЯ " +
    "абвгдежзиклмнопрстуфхцчшщэюя " +
    "–—‘’“”…•€£"
  private val ascii = (0x21..0x7e).map { it.toChar() }.joinToString("")
  private val scripts = "東京は今日も晴れです 你好世界 안녕하세요 مرحبا שלום नमस्ते สวัสดี ☃✓⌘"
  private val emojis = "😀😂❤️👍🎉🔥✅⭐🙏😢🇺🇸👨‍👩‍👧"

  private fun rasterSpecs(): List<Spec> {
    val out = mutableListOf<Spec>()
    val interSizes = listOf(12f, 13f, 13.5f, 14f, 15f, 16f, 17.5f, 18f, 18.5f, 20f, 24f, 25f, 33.5f)
    val faces = listOf(
      "inter-regular" to inter, "inter-italic" to inter.copy(fontStyle = FontStyle.Italic), "inter-medium" to inter.copy(fontWeight = FontWeight.Medium),
      "inter-semibold" to inter.copy(fontWeight = FontWeight.SemiBold), "inter-bold" to inter.copy(fontWeight = FontWeight.Bold), "inter-light" to inter.copy(fontWeight = FontWeight.Light),
    )
    fun add(face: String, style: TextStyle, sizes: List<Float>, text: String) {
      val seen = HashSet<Int>()
      for (size in sizes) for (scale in scales) {
        if (seen.add((size * scale * 1000).roundToInt())) {
          out += Spec("raster", face, "size-$size", scale, AnnotatedString(text), style.copy(fontSize = size.sp), width = 1200f / scale)
        }
      }
    }
    for ((face, style) in faces) add(face, style, interSizes, latin)
    add("mono", TextStyle(color = Color.Black, fontFamily = FontFamily.Monospace), listOf(12f, 14f, 16f), ascii)
    add("default", TextStyle(color = Color.Black), listOf(14f, 16f, 18f), latin)
    add("scripts-in-inter", inter, listOf(12f, 14f, 16f), scripts)
    add("emoji-in-inter", inter, listOf(12f, 16f), emojis)
    add("emoji-font", TextStyle(color = Color.Black, fontFamily = EmojiFont), listOf(16f, 36f, 48f), emojis)
    return out
  }

  @Composable
  private fun SpecText(spec: Spec, into: MutableMap<String, Placed>, key: String, layouts: MutableMap<String, Pair<TextLayoutResult, Float>>) {
    CompositionLocalProvider(LocalDensity provides Density(spec.scale, 1f)) {
      var style = spec.style
      if (spec.bubbleRound && style.lineHeight.isSp) {
        style = style.copy(lineHeight = with(LocalDensity.current) { style.lineHeight.toPx().roundToInt().toSp() })
      }
      if (spec.lineHeightScale != 1f) style = style.copy(lineHeight = style.lineHeight * spec.lineHeightScale)
      var text = spec.text
      if (spec.compensate && label == "fix") {
        val (t, s) = desktopParagraph(text, style)
        text = t
        style = s
      } else if (spec.compensate) {
        style = compensated(style)
      }
      val linePx = if (style.lineHeight.isSp) with(LocalDensity.current) { style.lineHeight.toPx() } else 0f
      val m = if (spec.width != null) Modifier.width(spec.width.dp) else Modifier
      BasicText(
        text, m.record(into, key), style,
        onTextLayout = { layouts[key] = it to linePx },
        overflow = spec.overflow, maxLines = spec.maxLines
      )
    }
  }

  private val interTypeface by lazy { FontMgr.default.makeFromFile("src/commonMain/moko-resources/fonts/Inter-Regular.ttf") }
  private val osName = System.getProperty("os.name").lowercase()

  private fun firstInstalled(linux: List<String>, windows: List<String>, mac: List<String>): Typeface? =
    (if (osName.contains("linux")) linux else if (osName.contains("win")) windows else mac).firstNotNullOfOrNull { n ->
      FontMgr.default.matchFamily(n).use { s -> if (s.count() > 0) s.matchStyle(org.jetbrains.skia.FontStyle.NORMAL) else null }
    }

  private val monoTypeface by lazy { firstInstalled(listOf("Noto Sans Mono", "DejaVu Sans Mono", "Consolas"), listOf("Consolas"), listOf(".AppleSystemUIFontMonospaced", "Menlo", "Courier")) }
  private val sansTypeface by lazy { firstInstalled(listOf("Noto Sans", "DejaVu Sans", "Arial"), listOf("Segoe UI", "Arial"), listOf(".AppleSystemUIFont", "Helvetica Neue", "Helvetica")) }

  private fun typefaceOf(family: FontFamily?): Typeface? = when (family) {
    null, Inter -> interTypeface
    FontFamily.Monospace -> monoTypeface
    FontFamily.Default, FontFamily.SansSerif -> sansTypeface
    else -> null
  }

  @Composable
  private fun desktopParagraph(text: AnnotatedString, style: TextStyle): Pair<AnnotatedString, TextStyle> {
    val s = text.text
    if (s.isEmpty() || s.startsWith("\n") || s.endsWith("\n") || s.contains("\n\n")) return text to compensated(style)
    val density = LocalDensity.current
    val fontPx = with(density) { style.fontSize.takeOrElse { 14.sp }.toPx() }
    val trimBoth = (style.lineHeightStyle ?: LineHeightStyle.Default).trim == LineHeightStyle.Trim.Both
    val tinyPx = if (style.lineHeight.isSpecified) {
      val linePx = with(density) { style.lineHeight.toPx() }
      val typeface = typefaceOf(style.fontFamily)
      if (typeface == null || (linePx <= fontPx && !trimBoth)) return text to compensated(style)
      val unit = org.jetbrains.skia.Font(typeface, 100f).use { it.metrics }.let { (it.descent - it.ascent + it.leading) / 100f }
      0.52f / unit
    } else 0.2f
    val wrapped = buildAnnotatedString { withStyle(style.toSpanStyle()) { append(text) } }
    return wrapped to style.copy(fontSize = with(density) { tinyPx.toSp() })
  }

  private fun f(v: Float) = if (v.isNaN()) "nan" else ((v * 100).roundToInt() / 100f).toString()

  private fun geometry(r: TextLayoutResult): String = buildString {
    append("size=${r.size.width}x${r.size.height} lc=${r.lineCount} fb=${f(r.firstBaseline)} lb=${f(r.lastBaseline)}")
    for (i in 0 until r.lineCount) {
      append(" L$i=${f(r.getLineTop(i))},${f(r.getLineBottom(i))},${f(r.getLineBaseline(i))},${f(r.getLineLeft(i))},${f(r.getLineRight(i))},${r.getLineEnd(i)},${r.isLineEllipsized(i)}")
    }
    val c = r.getCursorRect(r.layoutInput.text.length)
    append(" cur=${f(c.left)},${f(c.top)},${f(c.bottom)}")
  }

  private class Pixels(val width: Int, val height: Int, val rowBytes: Int, val bytes: ByteArray) {
    fun lum(x: Int, y: Int): Int {
      val i = y * rowBytes + x * 4
      return ((bytes[i].toInt() and 255) + (bytes[i + 1].toInt() and 255) + (bytes[i + 2].toInt() and 255)) / 3
    }
    fun maxDiff(o: Pixels, x: Int, y: Int, ox: Int, oy: Int): Int {
      if (x < 0 || y < 0 || x >= width || y >= height) return if (ox in 0 until o.width && oy in 0 until o.height && o.lum(ox, oy) < 250) 255 else 0
      if (ox < 0 || oy < 0 || ox >= o.width || oy >= o.height) return if (lum(x, y) < 250) 255 else 0
      val i = y * rowBytes + x * 4
      val j = oy * o.rowBytes + ox * 4
      var d = 0
      for (c in 0 until 4) d = max(d, abs((bytes[i + c].toInt() and 255) - (o.bytes[j + c].toInt() and 255)))
      return d
    }
  }

  private fun render(specs: List<Spec>): Pair<Pixels, List<Measured>> {
    var height = specs.sumOf { s -> s.pad * 2 + estimateHeight(s) } + 16
    while (true) {
      val placed = mutableMapOf<String, Placed>()
      val layouts = mutableMapOf<String, Pair<TextLayoutResult, Float>>()
      val image = renderScene(width = sceneWidth, height = height) {
        Column(Modifier.fillMaxSize().background(Color.White)) {
          specs.forEachIndexed { i, s ->
            Box(Modifier.record(placed, "b$i").padding(horizontal = s.pad.dp, vertical = s.pad.dp)) {
              SpecText(s, placed, "t$i", layouts)
            }
          }
        }
      }
      val bottom = specs.indices.maxOf { i -> placed.getValue("b$i").let { it.y + it.height } }
      if (bottom > height) {
        height = bottom + 16
        continue
      }
      val bmp = Bitmap.makeFromImage(image)
      val pixels = Pixels(bmp.width, bmp.height, bmp.rowBytes, bmp.readPixels()!!)
      val measured = specs.indices.map { i ->
        val (layout, linePx) = layouts.getValue("t$i")
        val boxes = if (label == "fix") (0 until layout.layoutInput.text.length).map { layout.getBoundingBox(it) } else emptyList()
        Measured(placed.getValue("b$i"), placed.getValue("t$i"), geometry(layout), boxes, linePx)
      }
      return pixels to measured
    }
  }

  private fun estimateHeight(s: Spec): Int {
    val lh = if (s.style.lineHeight.isSp) s.style.lineHeight.value * s.scale * s.lineHeightScale else 0f
    val line = max(lh, s.fontPx * 1.6f)
    val lines = when {
      s.width != null -> ceil(s.text.length * s.fontPx * 0.75f / (s.width * s.scale)).toInt() + 1
      else -> s.text.count { it == '\n' } + 1
    }
    return ceil(line * min(lines, 12)).toInt() + 4
  }

  private fun writeBase(dir: File, n: Int, pixels: Pixels, measured: List<Measured>) {
    DataOutputStream(BufferedOutputStream(DeflaterOutputStream(FileOutputStream(File(dir, "scene-$n.bin")), Deflater(1), 1 shl 16))).use { out ->
      out.writeInt(pixels.width); out.writeInt(pixels.height); out.writeInt(pixels.rowBytes)
      out.write(pixels.bytes)
      out.writeInt(measured.size)
      for (m in measured) {
        for (p in listOf(m.box, m.text)) { out.writeInt(p.x); out.writeInt(p.y); out.writeInt(p.width); out.writeInt(p.height) }
        out.writeFloat(m.linePx)
        out.writeUTF(m.geometry)
      }
    }
  }

  private fun readBase(dir: File, n: Int): Pair<Pixels, List<Measured>> =
    DataInputStream(BufferedInputStream(InflaterInputStream(FileInputStream(File(dir, "scene-$n.bin")), java.util.zip.Inflater(), 1 shl 16))).use { inp ->
      val w = inp.readInt(); val h = inp.readInt(); val rb = inp.readInt()
      val bytes = ByteArray(rb * h).also { inp.readFully(it) }
      val count = inp.readInt()
      val measured = (0 until count).map {
        val ps = (0 until 2).map { Placed(inp.readInt(), inp.readInt(), inp.readInt(), inp.readInt()) }
        val linePx = inp.readFloat()
        Measured(ps[0], ps[1], inp.readUTF(), emptyList(), linePx)
      }
      Pixels(w, h, rb, bytes) to measured
    }

  private fun inkRows(p: Pixels, box: Placed): List<Int> =
    (0 until box.height).filter { dy -> val y = box.y + dy; y < p.height && (box.x until min(p.width, box.x + box.width)).any { x -> p.lum(x, y) < 128 } }

  private fun crop(p: Pixels, box: Placed, w: Int, h: Int, scale: Int): ByteArray {
    val out = ByteArray(w * scale * h * scale * 4)
    for (y in 0 until h * scale) for (x in 0 until w * scale) {
      val sx = box.x + x / scale; val sy = box.y + y / scale
      val o = (y * w * scale + x) * 4
      if (sx < p.width && sy < p.height) {
        val i = sy * p.rowBytes + sx * 4
        for (c in 0 until 4) out[o + c] = p.bytes[i + c]
      } else {
        for (c in 0 until 4) out[o + c] = -1
      }
    }
    return out
  }

  private fun writeDiffImage(file: File, base: Pixels, fix: Pixels, b: Placed, x: Placed) {
    val w = min(max(b.width, x.width), 700)
    val h = min(max(b.height, x.height), 400)
    val scale = if (w * 3 <= 700) 3 else 1
    val sw = w * scale; val sh = h * scale
    val total = ByteArray(sw * 3 * sh * 4)
    val left = crop(base, b, w, h, scale)
    val mid = crop(fix, x, w, h, scale)
    for (y in 0 until sh) for (xx in 0 until sw) {
      val o = (y * sw + xx) * 4
      val bi = (y * sw * 3 + xx) * 4
      val mi = (y * sw * 3 + sw + xx) * 4
      val di = (y * sw * 3 + 2 * sw + xx) * 4
      for (c in 0 until 4) { total[bi + c] = left[o + c]; total[mi + c] = mid[o + c] }
      var d = 0
      for (c in 0 until 3) d = max(d, abs((left[o + c].toInt() and 255) - (mid[o + c].toInt() and 255)))
      val lb = ((left[o].toInt() and 255) + (left[o + 1].toInt() and 255) + (left[o + 2].toInt() and 255)) / 3
      val gray = (255 - (255 - lb) / 4).toByte()
      if (d > 2) { total[di] = 0; total[di + 1] = 0; total[di + 2] = -1; total[di + 3] = -1 } else { total[di] = gray; total[di + 1] = gray; total[di + 2] = gray; total[di + 3] = -1 }
    }
    val info = ImageInfo(sw * 3, sh, ColorType.N32, ColorAlphaType.PREMUL)
    val image = Image.makeRaster(info, total, sw * 3 * 4)
    file.writeBytes(image.encodeToData(EncodedImageFormat.PNG)!!.bytes)
  }

  private fun run(kind: String, specs: List<Spec>) {
    if (probeDir == null || label == null) return
    if (label == "fix") assertNotNull(compensation, "withDesktopLineHeight not found in the fix half")
    val baseDir = File(probeDir, "base/$kind").apply { mkdirs() }
    val reportDir = File(probeDir, "fix/report").apply { mkdirs() }
    val diffDir = File(reportDir, "diff-$kind").apply { mkdirs() }
    val rows = if (label == "fix") PrintWriter(File(reportDir, "$kind-rows.tsv").bufferedWriter()) else null
    rows?.println("group\ttemplate\tcontent\tscale\tfontPx\tlinePxBase\tlinePxFix\tclass\tdiffPx\tmaxDiff\tinkBase\tinkFix\tchars\tgeometryBase\tgeometryFix")
    val counts = sortedMapOf<String, IntArray>()
    val examples = HashMap<String, Int>()
    var images = 0
    val started = System.currentTimeMillis()
    val chunks = mutableListOf<MutableList<Spec>>()
    var chunkHeight = 0
    for (s in specs) {
      val h = s.pad * 2 + estimateHeight(s)
      if (chunks.isEmpty() || chunks.last().size >= rowsPerScene || chunkHeight + h > 5000) {
        chunks += mutableListOf<Spec>()
        chunkHeight = 0
      }
      chunks.last() += s
      chunkHeight += h
    }
    chunks.forEachIndexed { n, chunk ->
      val (pixels, measured) = render(chunk)
      if (label == "base") {
        writeBase(baseDir, n, pixels, measured)
      } else {
        val (bp, bm) = readBase(baseDir, n)
        chunk.forEachIndexed { i, s ->
          val b = bm[i]; val x = measured[i]
          val w = max(b.box.width, x.box.width); val h = max(b.box.height, x.box.height)
          var diffPx = 0; var maxDiff = 0
          val chars = sortedSetOf<String>()
          val offX = x.text.x - x.box.x; val offY = x.text.y - x.box.y
          for (dy in 0 until h) for (dx in 0 until w) {
            val d = bp.maxDiff(pixels, b.box.x + dx, b.box.y + dy, x.box.x + dx, x.box.y + dy)
            if (d > 2) {
              diffPx++; maxDiff = max(maxDiff, d)
              val tx = (dx - offX).toFloat(); val ty = (dy - offY).toFloat()
              val hit = x.boxes.indexOfFirst { r -> tx >= r.left - 1 && tx <= r.right + 1 && ty >= r.top - 2 && ty <= r.bottom + 2 }
              if (hit >= 0) chars += s.text.text.substring(hit, hit + 1)
            } else if (d > 0) maxDiff = max(maxDiff, d)
          }
          val inkB = inkRows(bp, b.box); val inkF = inkRows(pixels, x.box)
          val cls = when {
            b.geometry != x.geometry || b.box.width != x.box.width || b.box.height != x.box.height -> "layout"
            inkB != inkF -> "ink-rows"
            diffPx > 0 -> "pixels"
            maxDiff > 0 -> "faint"
            else -> "same"
          }
          val key = "${s.group}\t${s.template}\t${s.content}\t$cls"
          counts.getOrPut(key) { IntArray(1) }[0]++
          if (cls != "same") {
            rows!!.println("${s.group}\t${s.template}\t${s.content}\t${s.scale}\t${f(s.fontPx)}\t${f(b.linePx)}\t${f(x.linePx)}\t$cls\t$diffPx\t$maxDiff\t${inkB.joinToString(",")}\t${inkF.joinToString(",")}\t${chars.joinToString("")}\t${b.geometry}\t${x.geometry}")
            val e = examples.merge(key, 1, Int::plus)!!
            if (e <= 2 && images < 2500) {
              images++
              writeDiffImage(File(diffDir, "${s.group}_${s.template}_${s.content}_${cls}_${s.scale}.png".replace('/', '-')), bp, pixels, b.box, x.box)
            }
          }
        }
      }
    }
    rows?.close()
    if (label == "fix") {
      PrintWriter(File(reportDir, "$kind-summary.tsv").bufferedWriter()).use { out ->
        out.println("group\ttemplate\tcontent\tclass\trows")
        counts.forEach { (k, v) -> out.println("$k\t${v[0]}") }
      }
    }
    println("PROBE $kind label=$label specs=${specs.size} ms=${System.currentTimeMillis() - started} skiko=${org.jetbrains.skiko.Version.skiko}")
  }

  @Test
  fun geometryParity() = run("geometry", geometrySpecs())

  @Test
  fun rasterParity() = run("raster", rasterSpecs())
}
