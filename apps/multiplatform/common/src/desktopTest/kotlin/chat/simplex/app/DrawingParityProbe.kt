package chat.simplex.app

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import org.jetbrains.skia.Bitmap
import org.jetbrains.skia.ColorAlphaType
import org.jetbrains.skia.ColorType
import org.jetbrains.skia.EncodedImageFormat
import org.jetbrains.skia.Image
import org.jetbrains.skia.ImageInfo
import java.io.*
import java.util.zip.Deflater
import java.util.zip.DeflaterOutputStream
import java.util.zip.InflaterInputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.test.Test

class DrawingParityProbe {
  private val probeDir = System.getenv("PROBE_DIR")
  private val label = System.getenv("PROBE_LABEL")
  private val cell = 64

  private val photo: ImageBitmap by lazy {
    val w = 97
    val h = 71
    val bmp = ImageBitmap(w, h)
    val canvas = Canvas(bmp)
    val paint = Paint()
    for (y in 0 until h) for (x in 0 until w) {
      paint.color = Color(((x * 37 + y * 11) % 256) / 255f, ((x * 5 + y * 23) % 256) / 255f, (((x xor y) * 13) % 256) / 255f)
      canvas.drawRect(x.toFloat(), y.toFloat(), x + 1f, y + 1f, paint)
    }
    bmp
  }

  private fun c(name: String, content: @Composable () -> Unit): Pair<String, @Composable () -> Unit> = name to content

  private val cells: List<Pair<String, @Composable () -> Unit>> = listOf(
    c("shadow-1") { Box(Modifier.padding(8.dp).size(40.dp).shadow(1.dp, RoundedCornerShape(8.dp)).background(Color.White)) },
    c("shadow-2") { Box(Modifier.padding(8.dp).size(40.dp).shadow(2.dp, RoundedCornerShape(8.dp)).background(Color.White)) },
    c("shadow-4") { Box(Modifier.padding(8.dp).size(40.dp).shadow(4.dp, RoundedCornerShape(8.dp)).background(Color.White)) },
    c("shadow-8") { Box(Modifier.padding(8.dp).size(40.dp).shadow(8.dp, CircleShape).background(Color.White)) },
    c("blur-4") { Box(Modifier.padding(4.dp).size(48.dp).blur(4.dp).background(Brush.linearGradient(listOf(Color.Red, Color.Blue)))) },
    c("blur-12") { Box(Modifier.padding(4.dp).size(48.dp).blur(12.dp).background(Brush.linearGradient(listOf(Color.Green, Color.Magenta)))) },
    c("image-crop") { Image(photo, null, Modifier.size(48.dp).clip(CircleShape), contentScale = ContentScale.Crop) },
    c("image-fit-low") { Image(photo, null, Modifier.size(56.dp), contentScale = ContentScale.Fit, filterQuality = FilterQuality.Low) },
    c("image-fit-medium") { Image(photo, null, Modifier.size(56.dp), contentScale = ContentScale.Fit, filterQuality = FilterQuality.Medium) },
    c("image-fit-high") { Image(photo, null, Modifier.size(56.dp), contentScale = ContentScale.Fit, filterQuality = FilterQuality.High) },
    c("radial") { Box(Modifier.size(56.dp).background(Brush.radialGradient(listOf(Color.Yellow, Color.Blue)))) },
    c("border") { Box(Modifier.padding(4.dp).size(48.dp).border(1.dp, Color.Black, RoundedCornerShape(12.dp))) },
    c("border-half") { Box(Modifier.padding(4.dp).size(48.dp).border(0.5.dp, Color.DarkGray, RoundedCornerShape(18.dp))) },
    c("clip-round") { Box(Modifier.padding(4.dp).size(48.dp).clip(RoundedCornerShape(10.dp)).background(Color(0xFF2C7BE5))) },
    c("alpha") { Box(Modifier.padding(4.dp).size(48.dp).background(Color.Black.copy(alpha = 0.35f), RoundedCornerShape(6.dp))) },
    c("canvas") {
      Canvas(Modifier.size(56.dp)) {
        drawArc(Color(0xFF0088FF), -90f, 250f, false, Offset(4f, 4f), Size(size.width - 8f, size.height - 8f), style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
        val p = Path().apply { moveTo(4f, size.height - 4f); quadraticBezierTo(size.width / 2, 0f, size.width - 4f, size.height - 4f); close() }
        drawPath(p, Color(0x8800AA44))
        drawCircle(Color.Black, 2.5f, Offset(size.width / 2, size.height / 2))
        drawLine(Color.Black, Offset(0f, 0f), Offset(size.width, size.height * 0.3f), strokeWidth = 1f)
      }
    },
  )

  private val scales = listOf(1f, 1.1f, 1.25f, 1.3f, 1.5f, 1.75f, 2f, 2.25f, 2.5f, 3f, 0.7f, 0.9f)

  @Test
  fun drawingParity() {
    if (probeDir == null || label == null) return
    val baseDir = File(probeDir, "base/drawing").apply { mkdirs() }
    val reportDir = File(probeDir, "fix/report").apply { mkdirs() }
    val diffDir = File(reportDir, "diff-drawing").apply { mkdirs() }
    val rows = if (label == "fix") PrintWriter(File(reportDir, "drawing-rows.tsv").bufferedWriter()) else null
    rows?.println("scale\tcell\tdiffPx\tmaxDiff")
    for (scale in scales) {
      val side = (cell * scale).toInt() + 4
      val width = side * cells.size
      val image = renderScene(width = width, height = side) {
        Row(Modifier.fillMaxSize().background(Color(0xFFF2F2F2))) {
          CompositionLocalProvider(LocalDensity provides Density(scale, 1f)) {
            for ((_, content) in cells) Box(Modifier.requiredSize((side / scale).dp), contentAlignment = androidx.compose.ui.Alignment.Center) { content() }
          }
        }
      }
      val bmp = Bitmap.makeFromImage(image)
      val bytes = bmp.readPixels()!!
      val rb = bmp.rowBytes
      val file = File(baseDir, "scale-$scale.bin")
      if (label == "base") {
        DataOutputStream(DeflaterOutputStream(FileOutputStream(file), Deflater(1))).use { it.writeInt(rb); it.writeInt(bmp.height); it.write(bytes) }
        continue
      }
      val base = DataInputStream(InflaterInputStream(FileInputStream(file))).use { inp -> val r = inp.readInt(); val h = inp.readInt(); ByteArray(r * h).also { inp.readFully(it) } to r }
      cells.forEachIndexed { i, (name, _) ->
        var n = 0
        var mx = 0
        for (y in 0 until bmp.height) for (x in i * side until (i + 1) * side) {
          val a = y * rb + x * 4
          var d = 0
          for (c in 0 until 4) d = max(d, abs((bytes[a + c].toInt() and 255) - (base.first[a + c].toInt() and 255)))
          if (d > 2) n++
          mx = max(mx, d)
        }
        rows!!.println("$scale\t$name\t$n\t$mx")
        if (mx > 2) {
          val out = ByteArray(side * 2 * 4 * side * 4)
          for (y in 0 until side * 2) for (x in 0 until side * 2) for (half in 0 until 2) {
            val src = if (half == 0) base.first else bytes
            val s = (y / 2) * rb + (i * side + x / 2) * 4
            val o = (y * side * 4 + half * side * 2 + x) * 4
            for (c in 0 until 4) out[o + c] = src[s + c]
          }
          val img = Image.makeRaster(ImageInfo(side * 4, side * 2, ColorType.N32, ColorAlphaType.PREMUL), out, side * 4 * 4)
          File(diffDir, "$name-$scale.png").writeBytes(img.encodeToData(EncodedImageFormat.PNG)!!.bytes)
        }
      }
    }
    rows?.close()
  }
}
