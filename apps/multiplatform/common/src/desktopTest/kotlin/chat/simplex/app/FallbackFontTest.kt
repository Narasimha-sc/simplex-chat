package chat.simplex.app

import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.paragraph.FontCollection
import org.jetbrains.skia.paragraph.ParagraphBuilder
import org.jetbrains.skia.paragraph.ParagraphStyle
import org.jetbrains.skia.paragraph.TextStyle
import org.junit.Assume.assumeTrue
import java.io.File
import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals

private const val SNOWMAN_BDF = """STARTFONT 2.1
FONT -misc-snowman-medium-r-normal--8-80-75-75-c-80-iso10646-1
SIZE 8 75 75
FONTBOUNDINGBOX 8 8 0 0
STARTPROPERTIES 5
FAMILY_NAME "Snowman"
FONT_ASCENT 8
FONT_DESCENT 0
CHARSET_REGISTRY "ISO10646"
CHARSET_ENCODING "1"
ENDPROPERTIES
CHARS 1
STARTCHAR snowman
ENCODING 9731
SWIDTH 1000 0
DWIDTH 8 0
BBX 8 8 0 0
BITMAP
3C
42
3C
42
81
81
42
3C
ENDCHAR
ENDFONT
"""

class FallbackFontTest {
  @Test
  fun textIsLaidOutWhenTheOnlyFallbackFontIsBitmap() = withTempDir { dir ->
    assumeTrue("fontconfig selects fallback fonts only on Linux", System.getProperty("os.name") == "Linux")
    Files.writeString(dir.resolve("snowman.bdf"), SNOWMAN_BDF)
    Files.writeString(dir.resolve("fonts.conf"), "<fontconfig><dir>$dir</dir><cachedir>$dir</cachedir></fontconfig>")
    val java = File(System.getProperty("java.home"), "bin/java").path
    val layout = ProcessBuilder(java, "-cp", System.getProperty("java.class.path"), "-XX:ErrorFile=$dir/hs_err.log", LayOutSnowman::class.java.name)
      .directory(dir.toFile())
      .redirectErrorStream(true)
      .apply { environment()["FONTCONFIG_FILE"] = dir.resolve("fonts.conf").toString() }
      .start()
    val output = layout.inputStream.bufferedReader().readText()
    assertEquals(0, layout.waitFor(), output)
  }
}

object LayOutSnowman {
  @JvmStatic
  fun main(args: Array<String>) {
    val fonts = FontCollection().setDefaultFontManager(FontMgr.default)
    ParagraphBuilder(ParagraphStyle(), fonts).pushStyle(TextStyle()).addText("☃").build().layout(100f)
  }
}
