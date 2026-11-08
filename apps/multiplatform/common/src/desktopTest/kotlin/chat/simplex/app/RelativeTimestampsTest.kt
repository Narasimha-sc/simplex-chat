package chat.simplex.app

import chat.simplex.common.model.*
import chat.simplex.common.model.ChatController.appPrefs
import kotlinx.datetime.Instant
import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.hours
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Duration.Companion.seconds

class RelativeTimestampsTest {
  private val now = Instant.parse("2026-11-07T12:00:00Z")

  private fun inUsLocale(test: () -> Unit) {
    val locale = Locale.getDefault()
    try {
      Locale.setDefault(Locale.US)
      test()
    } finally {
      Locale.setDefault(locale)
    }
  }

  @Test
  fun agesOfPastAndFutureTimes() = inUsLocale {
    assertEquals("just now", getRelativeTimestampText(now + 59.seconds, now))
    assertEquals("just now", getRelativeTimestampText(now + 5.minutes, now))
    assertEquals("1m ago", getRelativeTimestampText(now - 1.seconds, now))
    assertEquals("1m ago", getRelativeTimestampText(now - 1.minutes, now))
    assertEquals("59m ago", getRelativeTimestampText(now - 59.minutes, now))
    assertEquals("2h5m ago", getRelativeTimestampText(now - 2.hours - 5.minutes, now))
    assertEquals("23h59m ago", getRelativeTimestampText(now - 1.days + 1.minutes, now))
    assertEquals("1d ago", getRelativeTimestampText(now - 1.days, now))
    assertEquals("364d ago", getRelativeTimestampText(now - 364.days, now))
    assertEquals("1y100d ago", getRelativeTimestampText(now - 465.days, now))
  }

  @Test
  fun enabledToggleShowsAges() = inUsLocale {
    val enabled = appPrefs.relativeTimestamps.get()
    val shownNow = relativeTimestampsNow.value
    try {
      appPrefs.relativeTimestamps.set(true)
      relativeTimestampsNow.value = now
      val meta = CIMeta.getSample(1, now - 23.hours - 59.minutes, "")
      assertEquals("23h59m ago", meta.timestampText)
      assertEquals("2h5m ago", chatTimestampText(now - 2.hours - 5.minutes))
    } finally {
      appPrefs.relativeTimestamps.set(enabled)
      relativeTimestampsNow.value = shownNow
    }
  }
}
