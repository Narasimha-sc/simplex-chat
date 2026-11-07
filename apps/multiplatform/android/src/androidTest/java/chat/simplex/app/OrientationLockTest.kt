package chat.simplex.app

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.hardware.display.DisplayManager
import android.os.ParcelFileDescriptor
import android.view.Display
import android.view.Surface
import androidx.activity.compose.setContent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chat.simplex.common.platform.LockToCurrentOrientationUntilDispose
import chat.simplex.common.platform.mainActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OrientationLockTest {
  private val instrumentation = InstrumentationRegistry.getInstrumentation()

  @Test
  fun lockOnLandscapeDisplayKeepsActivity() {
    val sizes = shell("wm size")
    val (width, height) = Regex("""Physical size: (\d+)x(\d+)""").find(sizes)!!.destructured.toList().map { it.toInt() }
    val override = Regex("""Override size: (\d+x\d+)""").find(sizes)?.groupValues?.get(1)
    shell("wm size ${maxOf(width, height)}x${minOf(width, height)}")
    try {
      val intent = Intent(instrumentation.targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      val activity = instrumentation.startActivitySync(intent)
      val display = (activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
      assertEquals(Surface.ROTATION_0, display.rotation)
      assertEquals(Configuration.ORIENTATION_LANDSCAPE, activity.resources.configuration.orientation)
      instrumentation.runOnMainSync { (activity as MainActivity).setContent { LockToCurrentOrientationUntilDispose() } }
      Thread.sleep(3000)
      instrumentation.waitForIdleSync()
      assertSame(activity, mainActivity.get())
    } finally {
      mainActivity.get()?.finish()
      shell(if (override == null) "wm size reset" else "wm size $override")
    }
  }

  private fun shell(command: String): String =
    ParcelFileDescriptor.AutoCloseInputStream(instrumentation.uiAutomation.executeShellCommand(command)).bufferedReader().readText()
}
