import AppIntents
import SwiftUI
import WidgetKit

// Control Center / lock-screen / Action-button controls (iOS 18). Each opens
// a link in the app through the deep-link pipeline; none writes anything.

#if os(iOS)
  @available(iOS 18.0, *)
  struct OpenAppLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open in Invoice Ninja"
    static var isDiscoverable = false

    @Parameter(title: "Route") var route: String

    init() {}
    init(route: String) { self.route = route }

    func perform() async throws -> some IntentResult & OpensIntent {
      let url = URL(string: "invoiceninja://app\(route)") ?? URL(string: "invoiceninja://app/dashboard")!
      return .result(opensIntent: OpenURLIntent(url))
    }
  }

  @available(iOS 18.0, *)
  struct NewInvoiceControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
      StaticControlConfiguration(kind: "com.invoiceninja.admin.control.newInvoice") {
        ControlWidgetButton(action: OpenAppLinkIntent(route: "/invoices/new")) {
          Label("New Invoice", systemImage: "doc.badge.plus")
        }
      }
      .displayName("New Invoice")
      .description("Opens a new invoice.")
    }
  }

  @available(iOS 18.0, *)
  struct NewTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
      StaticControlConfiguration(kind: "com.invoiceninja.admin.control.newTask") {
        ControlWidgetButton(action: OpenAppLinkIntent(route: "/tasks/new")) {
          Label("New Task", systemImage: "timer")
        }
      }
      .displayName("New Task")
      .description("Opens a new task, ready to start its timer.")
    }
  }
#endif
