package org.jetbrains.compose.videoplayer

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asComposeImageBitmap
import org.jetbrains.skia.Bitmap
import org.jetbrains.skia.ColorAlphaType
import org.jetbrains.skia.ColorType
import org.jetbrains.skia.ImageInfo
import uk.co.caprica.vlcj.player.base.MediaPlayer
import uk.co.caprica.vlcj.player.embedded.videosurface.CallbackVideoSurface
import uk.co.caprica.vlcj.player.embedded.videosurface.VideoSurface
import uk.co.caprica.vlcj.player.embedded.videosurface.VideoSurfaceAdapters
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.BufferFormat
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.BufferFormatCallback
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.RenderCallback
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.format.RV32BufferFormat
import java.nio.ByteBuffer
import javax.swing.SwingUtilities

// https://github.com/JetBrains/compose-multiplatform/pull/3336/files
internal class SkiaBitmapVideoSurface : VideoSurface(VideoSurfaceAdapters.getVideoSurfaceAdapter()) {

  private val videoSurface = SkiaBitmapVideoSurface()

  // Every frame is decoded into one reused bitmap, and asComposeImageBitmap() hands out a view of it rather
  // than a copy. installPixels replaces that bitmap's pixel storage, so a thread reading the view while a
  // frame lands reads storage that is being freed - Skia's load_8888 then dereferences null. The lock makes
  // the write indivisible; snapshot() copies under it, so a reader ends up owning pixels nobody rewrites.
  private val frameLock = Any()
  private var imageInfo: ImageInfo? = null
  private var frameBytes: ByteArray? = null
  private var frameArrived = false
  private val skiaBitmap: Bitmap = Bitmap()
  private val composeBitmap = mutableStateOf<ImageBitmap?>(null)

  val bitmap: State<ImageBitmap?> = composeBitmap

  /**
   * The current frame as an image that keeps its pixels, for callers that outlive the next frame - taking a
   * still of a video, say. [bitmap] is the playing surface and its pixels are gone by the frame after next.
   */
  fun snapshot(): ImageBitmap? = synchronized(frameLock) {
    val info = imageInfo
    val bytes = frameBytes
    if (!frameArrived || info == null || bytes == null) return null
    Bitmap()
      .apply {
        installPixels(info, bytes.copyOf(), info.minRowBytes)
        setImmutable()
      }
      .asComposeImageBitmap()
  }

  override fun attach(mediaPlayer: MediaPlayer) {
    videoSurface.attach(mediaPlayer)
  }

  private inner class SkiaBitmapBufferFormatCallback : BufferFormatCallback {
    private var sourceWidth: Int = 0
    private var sourceHeight: Int = 0

    override fun getBufferFormat(sourceWidth: Int, sourceHeight: Int): BufferFormat {
      this.sourceWidth = sourceWidth
      this.sourceHeight = sourceHeight
      return RV32BufferFormat(sourceWidth, sourceHeight)
    }

    override fun allocatedBuffers(buffers: Array<ByteBuffer>) {
      synchronized(frameLock) {
        frameBytes = buffers[0].run { ByteArray(remaining()).also(::get) }
        imageInfo = ImageInfo(
          sourceWidth,
          sourceHeight,
          ColorType.BGRA_8888,
          ColorAlphaType.PREMUL,
        )
        frameArrived = false
      }
    }
  }

  private inner class SkiaBitmapRenderCallback : RenderCallback {
    override fun display(
      mediaPlayer: MediaPlayer,
      nativeBuffers: Array<ByteBuffer>,
      bufferFormat: BufferFormat,
    ) {
      SwingUtilities.invokeLater {
        synchronized(frameLock) {
          val info = imageInfo ?: return@invokeLater
          val bytes = frameBytes ?: return@invokeLater
          // VLC renegotiates the format when it cannot build the output it first asked for, and then displays
          // through a buffer of the new size against the info describing the old one. Skia reads the frame as
          // that info says, so the mismatch is read off the end of the array. Wait for the matching format.
          if (bufferFormat.width != info.width || bufferFormat.height != info.height) return@invokeLater
          val buffer = nativeBuffers[0]
          buffer.rewind()
          if (buffer.remaining() < bytes.size) return@invokeLater
          buffer.get(bytes)
          skiaBitmap.installPixels(info, bytes, info.minRowBytes)
          composeBitmap.value = skiaBitmap.asComposeImageBitmap()
          frameArrived = true
        }
      }
    }
  }

  private inner class SkiaBitmapVideoSurface : CallbackVideoSurface(
    SkiaBitmapBufferFormatCallback(),
    SkiaBitmapRenderCallback(),
    true,
    videoSurfaceAdapter,
  )
}
