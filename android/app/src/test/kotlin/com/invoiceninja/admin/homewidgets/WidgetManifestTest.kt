package com.invoiceninja.admin.homewidgets

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.w3c.dom.Element

/**
 * The widgets' two writers — the Stop receiver and the Start activity — are
 * safe only because nothing outside the app can reach them: not exported, no
 * intent filter (docs/home-screen-widgets.md § The only write is a queued
 * command). An exported one, or one given a filter, could be fired by any
 * app to stop or start a timer.
 */
class WidgetManifestTest {
  private val ns = "http://schemas.android.com/apk/res/android"

  private fun component(tag: String, name: String): Element? {
    // Gradle runs unit tests from the module directory (android/app).
    val doc =
        DocumentBuilderFactory.newInstance()
            .apply { isNamespaceAware = true }
            .newDocumentBuilder()
            .parse(File("src/main/AndroidManifest.xml"))
    val nodes = doc.getElementsByTagName(tag)
    return (0 until nodes.length)
        .map { nodes.item(it) as Element }
        .firstOrNull { it.getAttributeNS(ns, "name") == name }
  }

  private fun assertPrivate(tag: String, name: String) {
    val e = component(tag, name)
    assertNotNull("$name is not declared", e)
    assertEquals("$name must not be exported", "false", e!!.getAttributeNS(ns, "exported"))
    assertEquals("$name must have no intent filter", 0, e.getElementsByTagName("intent-filter").length)
  }

  @Test
  fun theStopReceiverIsPrivate() = assertPrivate("receiver", ".homewidgets.WidgetCommandReceiver")

  @Test
  fun theStartActivityIsPrivate() = assertPrivate("activity", ".homewidgets.WidgetStartActivity")
}
