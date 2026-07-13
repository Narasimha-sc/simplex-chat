package chat.simplex.common.platform

import com.sun.jna.*

// Windows-only: shows a startup error the jpackage launcher otherwise hides behind "Failed to launch
// JVM" (#4146); on Linux/Mac the error rethrown by the caller reaches stderr. Uses a native message
// box, not Swing, because broken AWT initialization can be the cause; Ctrl+C copies the box's text.
fun showStartupError(e: Throwable) {
  if (!desktopPlatform.isWindows()) return
  try {
    NativeLibrary.getInstance("user32").getFunction("MessageBoxW").invokeInt(arrayOf(
      Pointer.NULL,
      WString(
        "SimpleX could not start. Press Ctrl+C to copy this message and report it " +
          "to https://github.com/simplex-chat/simplex-chat/issues\n\n" +
          e.stackTraceToString().take(3500) // MessageBoxW has no scrollbar - keep the box on screen
      ),
      WString("SimpleX failed to start"),
      0x2010 // MB_OK | MB_ICONERROR | MB_TASKMODAL
    ))
  } catch (_: Throwable) {
    // nothing useful to do: the caller rethrows the original error, which reaches stderr
  }
}
