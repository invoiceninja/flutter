package com.invoiceninja.admin.homewidgets

import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Decodes the golden snapshots the Dart builder writes
 * (`test/fixtures/home_widgets/`, `widget_snapshot_builder_test.dart`). A
 * schema change on the Dart side changes those files and fails this until the
 * Kotlin decoder follows — the contract test between the app and the widget.
 */
class WidgetSnapshotTest {
  private fun fixture(name: String): WidgetSnapshot {
    // Gradle runs unit tests from the module directory (android/app).
    val file = File("../../test/fixtures/home_widgets/$name")
    return WidgetSnapshot.parse(JSONObject(file.readText()))
  }

  @Test
  fun fullSnapshotDecodes() {
    val s = fixture("v1_full.json")
    assertEquals(1, s.version)
    assertFalse(s.tooNew)
    assertTrue(s.signedIn)
    assertEquals("u1", s.userId)
    assertEquals("co1", s.activeCompanyId)
    val company = s.company("")!!
    assertEquals("Acme Studio", company.name)
    assertTrue(company.canViewDashboard)

    val figures = company.figures!!
    assertNotNull(figures.fetchedAt)
    val outstanding = figures.outstanding!!
    assertEquals("$12,431.50", outstanding.amount.text)
    assertEquals(4, outstanding.unpaidCount)
    assertEquals(1, outstanding.pastDueCount)

    val month = figures.periods["this_month"]!!
    assertEquals("October", month.name)
    assertEquals("2026-10-31", month.endsOn)
    assertEquals(20, month.invoices!!.deltaPct)
    assertEquals(true, month.invoices!!.good)

    val attention = figures.attention!!
    assertEquals("2026-10-02", attention.pastDue.single().lateSince)
    assertEquals("2026-10-17", attention.dueSoon.single().dueOn)

    val timer = company.timers.single()
    assertEquals(1, company.runningCount)
    assertEquals("t1", timer.taskId)
    assertTrue(timer.canStop)
    assertTrue(timer.runningSince > 0)
    assertEquals("t2", company.recentTasks.single().taskId)
  }

  @Test
  fun signedOutStubDecodes() {
    val s = fixture("v1_signed_out.json")
    assertFalse(s.signedIn)
    assertTrue(s.companies.isEmpty())
    assertNull(s.company(""))
    // Strings ride along so "Sign in" is in the app's language.
    assertTrue(s.strings.containsKey("widget_sign_in"))
  }

  @Test
  fun aNewerSchemaAsksForAnUpdateInsteadOfGuessing() {
    val s = fixture("v99_future.json")
    assertTrue(s.tooNew)
  }

  @Test
  fun runningCountDefaultsToTheTimersCarried() {
    // An older snapshot has no runningCount: "+N running" counts the rows.
    val timer = """{"taskId":"t","runningSince":1}"""
    val older =
        WidgetSnapshot.parse(JSONObject("""{"companies":[{"timers":[$timer,$timer]}]}"""))
    assertEquals(2, older.companies.single().runningCount)
    // The snapshot carries at most three; the count is all of them.
    val capped =
        WidgetSnapshot.parse(
            JSONObject("""{"companies":[{"timers":[$timer,$timer,$timer],"runningCount":5}]}"""),
        )
    assertEquals(5, capped.companies.single().runningCount)
    // Never fewer than the rows carried.
    val short =
        WidgetSnapshot.parse(JSONObject("""{"companies":[{"timers":[$timer,$timer],"runningCount":1}]}"""))
    assertEquals(2, short.companies.single().runningCount)
  }

  @Test
  fun todayDecodesAndIsAbsentWithoutTimerRows() {
    val s =
        WidgetSnapshot.parse(
            JSONObject(
                """{"companies":[
                  {"id":"a","today":{"date":"2026-11-02","doneSeconds":5400}},
                  {"id":"b"},
                  {"id":"c","today":{"doneSeconds":60}},
                  {"id":"d","today":{"date":"2026-11-02","doneSeconds":-5}}]}""",
            ),
        )
    val today = s.company("a")!!.today!!
    assertEquals("2026-11-02", today.date)
    assertEquals(5400L, today.doneSeconds)
    // Sent only with the Timer widget's task rows.
    assertNull(s.company("b")!!.today)
    // No date: nothing to compare with today, so nothing to show.
    assertNull(s.company("c")!!.today)
    assertEquals(0L, s.company("d")!!.today!!.doneSeconds)
  }

  @Test
  fun pastDueShareIsOptionalAndClamped() {
    fun share(extra: String) =
        WidgetSnapshot.parse(
                JSONObject(
                    """{"companies":[{"id":"a","figures":{"outstanding":
                      {"amount":{"text":"$1"}$extra}}}]}""",
                ),
            )
            .company("a")!!
            .figures!!
            .outstanding!!
            .pastDueShare
    assertNull(share(""))
    assertEquals(0.25, share(""","pastDueShare":0.25""")!!, 0.0)
    assertEquals(1.0, share(""","pastDueShare":1.7""")!!, 0.0)
    assertNull(share(""","pastDueShare":"lots""""))
  }

  @Test
  fun garbageNeverThrows() {
    val s = WidgetSnapshot.parse(JSONObject("""{"companies":[{"figures":{"outstanding":7}}],"v":"x"}"""))
    assertFalse(s.signedIn)
    assertNull(s.companies.single().figures!!.outstanding)
  }
}
