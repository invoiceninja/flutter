package com.invoiceninja.admin.homewidgets

import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Test

class HomeWidgetsTextTest {
  @Test
  fun fillReplacesLongestPlaceholderFirst() {
    // As `Localization.lookup`: `:count` must not eat the start of `:countdown`.
    assertEquals(
        "3 of 10",
        HomeWidgets.fill(":count of :countdown", mapOf("count" to "3", "countdown" to "10")),
    )
  }

  @Test
  fun dayNumbersMatchTheCalendar() {
    assertEquals(0L, HomeWidgets.epochDay(1970, 1, 1))
    assertEquals(20_757L, HomeWidgets.epochDay(2026, 10, 31))
    assertEquals(11_016L, HomeWidgets.epochDay(2000, 2, 29))
    assertEquals(
        1L,
        HomeWidgets.parseDate("2026-11-01")!! - HomeWidgets.parseDate("2026-10-31")!!,
    )
    assertEquals(null, HomeWidgets.parseDate("31/10/2026"))
  }

  @Test
  fun aPeriodEndsAfterItsLastDay() {
    assertEquals(true, HomeWidgets.periodEnded("2000-01-31"))
    assertEquals(false, HomeWidgets.periodEnded("2999-01-31"))
    assertEquals(false, HomeWidgets.periodEnded("not a date"))
  }

  @Test
  fun aStoppedTimerReadsHoursMinutesSeconds() {
    assertEquals("0:00:00", HomeWidgets.elapsedText(0, Locale.US))
    assertEquals("0:05:09", HomeWidgets.elapsedText(309, Locale.US))
    assertEquals("1:02:05", HomeWidgets.elapsedText(3725, Locale.US))
    assertEquals("27:00:00", HomeWidgets.elapsedText(27 * 3600, Locale.US))
    // A stop stamped before the start (a clock change) is never negative.
    assertEquals("0:00:00", HomeWidgets.elapsedText(-90, Locale.US))
  }

  @Test
  fun todayReadsHoursAndMinutes() {
    assertEquals("0:00", HomeWidgets.hoursMinutes(59, Locale.US))
    assertEquals("3:05", HomeWidgets.hoursMinutes(3 * 3600 + 5 * 60 + 30, Locale.US))
    assertEquals("0:00", HomeWidgets.hoursMinutes(-1, Locale.US))
  }

  @Test
  fun aSliverPastDueStillShowsOnTheBar() {
    assertEquals(0, SnapshotWidgetProvider.barProgress(0.0))
    assertEquals(1, SnapshotWidgetProvider.barProgress(0.0001))
    assertEquals(250, SnapshotWidgetProvider.barProgress(0.25))
    assertEquals(1000, SnapshotWidgetProvider.barProgress(3.0))
  }

  @Test
  fun aStartCommandIsWhatTheAppReads() {
    // `HomeWidgetCommand.fromJson` (Dart): a Stop's shape, kind "start", and
    // no runningSince — nothing is running yet.
    val json = WidgetStore.startCommand("id-1", "u1", "co1", "t2", 1_791_977_400_000)
    assertEquals(setOf("v", "id", "kind", "userId", "companyId", "taskId", "at"), json.keys().asSequence().toSet())
    assertEquals(1, json.getInt("v"))
    assertEquals("start", json.getString("kind"))
    assertEquals("u1", json.getString("userId"))
    assertEquals("co1", json.getString("companyId"))
    assertEquals("t2", json.getString("taskId"))
    assertEquals(1_791_977_400_000, json.getLong("at"))
  }
}
