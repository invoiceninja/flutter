package com.invoiceninja.admin.homewidgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the Needs attention and Timer widgets choose to draw for a height —
 * the pure half of their capacity math. The heights are the measured dp of a
 * Roboto device at font scale 1 (BaseWidgetProvider.lineDp): a 13sp line 17.3,
 * 12sp 16, 14sp bold 18.6, 11sp 14.6, a 20sp clock 23.4, 26sp figure 30.5.
 */
class HomeWidgetsLayoutTest {
  private val attention =
      AttentionWidgetProvider.Heights(
          header = 18.6f,
          footer = 14.6f,
          row = 48f,
          section = 22f,
          block = 8 + 2 * 16f + 30.5f,
      )

  private fun attentionPlan(
      heightDp: Int,
      late: Int,
      soon: Int,
      nextDue: Boolean = false,
      padding: Float = 16f,
  ) =
      AttentionWidgetProvider.plan(
          attention,
          roomDp = heightDp - 2 * padding,
          tightDp = heightDp - 8f,
          lateCount = late,
          soonCount = soon,
          hasNextDue = nextDue,
          hasOutstanding = true,
      )

  @Test
  fun theSmallestAttentionWidgetStillShowsOneRow() {
    // 110dp: 78 of content at 16dp padding, and one row needs 81.2 — drawn
    // anyway, with the padding squeezed to fit.
    val plan = attentionPlan(110, late = 3, soon = 2)
    assertEquals(1, plan.late)
    assertEquals(0, plan.soon)
    assertFalse(plan.outstanding)
    assertTrue(plan.needDp <= 110 - 8)
  }

  @Test
  fun aDueSoonRowNeverSitsUnderPastDue() {
    // Room for exactly two rows and no section label: the second row is a
    // second past-due one or nothing — never a due-soon row under "Past due".
    val two = attentionPlan(32 + 33 + 2 * 48 + 10, late = 1, soon = 3)
    assertEquals(1, two.late)
    assertEquals(0, two.soon)
    assertFalse(two.soonSection)
    // Tall: the due-soon rows come under their own label.
    val tall = attentionPlan(360, late = 1, soon = 2)
    assertEquals(1, tall.late)
    assertEquals(2, tall.soon)
    assertTrue(tall.soonSection)
  }

  @Test
  fun leftoverRoomGetsTheOutstandingBlock() {
    val tall = attentionPlan(360, late = 1, soon = 0)
    assertTrue(tall.outstanding)
    assertTrue(tall.needDp <= 360 - 32)
    // Five rows fill a tall widget: no room left, no block.
    val full = attentionPlan(360, late = 5, soon = 0)
    assertEquals(5, full.late)
    assertFalse(full.outstanding)
  }

  @Test
  fun nothingPastDueShowsTheNextInvoiceWithItsLabelWhenItFits() {
    val roomy = attentionPlan(180, late = 0, soon = 0, nextDue = true)
    assertTrue(roomy.nextDue)
    assertTrue(roomy.nextDueSection)
    // 110dp: the row alone, under the check line.
    val small = attentionPlan(110, late = 0, soon = 0, nextDue = true)
    assertTrue(small.nextDue)
    assertFalse(small.nextDueSection)
  }

  private fun running(full: Float = 68.7f, compact: Float = 48.7f) =
      floatArrayOf(full, full, compact)

  @Test
  fun theTimerGoesCompactOnlyWhenOneFullRowCantFit() {
    // 60dp, one launcher row: 28 of content — the compact row, padding squeezed.
    val tiny = TimerWidgetProvider.plan(listOf(running()), 1, gap = 4f, moreDp = 20f, roomDp = 28f)
    assertEquals(listOf(TimerWidgetProvider.Fit.COMPACT), tiny.rows)
    assertTrue(tiny.needDp <= 60 - 8)
    val roomy = TimerWidgetProvider.plan(listOf(running()), 1, gap = 4f, moreDp = 20f, roomDp = 78f)
    assertEquals(listOf(TimerWidgetProvider.Fit.FULL), roomy.rows)
  }

  @Test
  fun plusNRunningCountsTimersTheSnapshotDidNotCarry() {
    // Three carried, five running, room for two: "+3 running".
    val plan =
        TimerWidgetProvider.plan(
            listOf(running(), running(), running()),
            runningCount = 5,
            gap = 4f,
            moreDp = 20f,
            roomDp = 170f,
        )
    assertEquals(2, plan.rows.size)
    assertTrue(plan.more)
    // One carried, one running: nothing more to say.
    val one = TimerWidgetProvider.plan(listOf(running()), 1, gap = 4f, moreDp = 20f, roomDp = 300f)
    assertFalse(one.more)
  }

  @Test
  fun aSecondRunningTimerIsCountedEvenAtTheDefaultSize() {
    // 110dp at 16dp padding: 78 of content. One full row (68.7) leaves no
    // room for "+1 running" (20), so the row drops its client line.
    val plan =
        TimerWidgetProvider.plan(listOf(running(), running()), 2, gap = 4f, moreDp = 20f, roomDp = 78f)
    assertEquals(listOf(TimerWidgetProvider.Fit.COMPACT), plan.rows)
    assertTrue(plan.more)
    assertTrue(plan.needDp <= 78f)
  }

  @Test
  fun aStoppedRowCutsItsStatusToOneLineBeforeGoingCompact() {
    val stopped = floatArrayOf(100.7f, 84.7f, 41.3f)
    val plan = TimerWidgetProvider.plan(listOf(stopped), 1, gap = 4f, moreDp = 20f, roomDp = 90f)
    assertEquals(listOf(TimerWidgetProvider.Fit.SHORT_STATUS), plan.rows)
  }
}
