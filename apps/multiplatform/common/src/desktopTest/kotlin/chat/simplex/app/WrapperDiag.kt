package chat.simplex.app

import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.material.LocalTextStyle
import androidx.compose.material.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.simplex.common.ui.theme.Inter
import chat.simplex.common.ui.theme.SimpleXTheme
import kotlin.test.Test

class WrapperDiag {
  private val sample = "You can connect to SimpleX Chat developers to ask any questions and to receive updates."

  private fun describe(label: String, r: TextLayoutResult) =
    "WDIAG $label height=${r.size.height} lines=${r.lineCount} " + (0 until r.lineCount).joinToString(" ") { "L$it=${r.getLineTop(it)},${r.getLineBottom(it)},${r.getLineBaseline(it)}" }

  @Test
  fun diag() {
    val out = StringBuilder()
    fun c(name: String, content: @Composable (onLayout: (TextLayoutResult) -> Unit) -> Unit): Pair<String, @Composable (onLayout: (TextLayoutResult) -> Unit) -> Unit> = name to content
    val cases = listOf(
      c("basic-raw") { cb -> BasicText(sample, Modifier.width(390.dp), TextStyle(fontFamily = Inter, fontSize = 16.sp, lineHeight = 22.sp, color = Color.Black), onTextLayout = cb) },
      c("material-raw") { cb -> SimpleXTheme { androidx.compose.material.Text(sample, Modifier.width(390.dp), lineHeight = 22.sp, onTextLayout = cb) } },
      c("material-style") { cb -> SimpleXTheme { val s = LocalTextStyle.current; out.append("WDIAG localStyle=$s\n"); androidx.compose.material.Text(sample, Modifier.width(390.dp), style = s.merge(lineHeight = 22.sp), onTextLayout = cb) } },
    )
    for ((name, content) in cases) {
      var result: TextLayoutResult? = null
      renderScene(width = 420, height = 200) { content { result = it } }
      out.append(describe(name, result!!)).append("\n")
    }
    val layout = try { Class.forName("chat.simplex.common.platform.Text_desktopKt").methods.firstOrNull { it.name == "layOutDesktopText" } } catch (e: ClassNotFoundException) { null }
    if (layout != null) {
      var result: TextLayoutResult? = null
      var transformed = ""
      renderScene(width = 420, height = 200) {
        SimpleXTheme {
          val style = LocalTextStyle.current.merge(lineHeight = 22.sp)
          val laidOut = layout.invoke(null, AnnotatedString(sample), style, androidx.compose.ui.platform.LocalDensity.current)
          val t = laidOut.javaClass.getMethod("getText").invoke(laidOut) as AnnotatedString
          val st = laidOut.javaClass.getMethod("getStyle").invoke(laidOut) as TextStyle
          transformed = "spans=${t.spanStyles.map { "${it.start}-${it.end}:${it.item.fontSize}" }} style.fontSize=${st.fontSize} lineHeight=${st.lineHeight} lhs=${st.lineHeightStyle}"
          androidx.compose.material.Text(t, Modifier.width(390.dp), style = st, onTextLayout = { result = it })
        }
      }
      out.append("WDIAG transformed $transformed\n").append(describe("material-transformed", result!!)).append("\n")
    }
    println(out)
  }
}
