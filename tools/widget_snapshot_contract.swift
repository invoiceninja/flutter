// The Swift half of the home-screen widgets' app/widget contract test
// (docs/home-screen-widgets.md): decodes the golden snapshots the Dart builder
// writes (test/fixtures/home_widgets/, widget_snapshot_builder_test.dart) with
// the extension's own decoder, and fails on any drift. Android's twin is
// WidgetSnapshotTest.kt.
//
//   tools/widget_snapshot_contract.sh
//
// A plain executable rather than an XCTest target: the decoder is pure
// Foundation, and this runs anywhere `swiftc` does, in CI without a simulator.

import Foundation

var failures = 0

func check(_ ok: Bool, _ what: String, line: Int = #line) {
  if !ok {
    failures += 1
    print("FAIL (line \(line)): \(what)")
  }
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "test/fixtures/home_widgets"

func fixture(_ name: String) -> WidgetSnapshot? {
  guard let data = FileManager.default.contents(atPath: "\(dir)/\(name)") else {
    print("FAIL: missing fixture \(dir)/\(name)")
    failures += 1
    return nil
  }
  return WidgetSnapshot.parse(data)
}

if let s = fixture("v1_full.json") {
  check(s.v == 1 && !s.tooNew, "version 1, not too new")
  check(s.signedIn, "signed in")
  check(s.userId == "u1", "userId")
  check(s.activeCompanyId == "co1", "activeCompanyId")
  let c = s.company("")
  check(c?.name == "Acme Studio", "current company resolves")
  check(c?.canViewDashboard == true, "canViewDashboard")
  let f = c?.figures
  check(f?.fetchedAt != nil, "figures.fetchedAt")
  check(f?.outstanding?.amount.text == "$12,431.50", "outstanding text")
  check(f?.outstanding?.unpaidCount == 4, "unpaidCount")
  check(f?.outstanding?.pastDueCount == 1, "pastDueCount")
  let month = f?.periods["this_month"]
  check(month?.name == "October", "period name")
  check(month?.endsOn == "2026-10-31", "period endsOn")
  check(month?.invoices?.deltaPct == 20, "invoices trend")
  check(month?.invoices?.good == true, "invoices good")
  check(f?.attention?.pastDue.first?.lateSince == "2026-10-02", "pastDue lateSince")
  check(f?.attention?.dueSoon.first?.dueOn == "2026-10-17", "dueSoon dueOn")
  check(c?.timers.first?.taskId == "t1", "timer task")
  check(c?.timers.first?.canStop == true, "timer canStop")
  check(c?.runningCount == 1, "running count")
  check(c?.today?.date == "2026-10-14", "today date")
  check(c?.figures?.outstanding?.pastDueShare == 0.01, "past-due share")
  check(c?.recentTasks.first?.taskId == "t2", "recent task")
}

if let s = fixture("v1_signed_out.json") {
  check(!s.signedIn, "signed out")
  check(s.companies.isEmpty, "no companies")
  check(s.strings["widget_sign_in"] != nil, "strings ride along")
}

if let s = fixture("v99_future.json") {
  check(s.tooNew, "a newer schema asks for an update")
}

let garbage = #"{"companies":[{"figures":{"outstanding":7}}],"v":"x"}"#.data(using: .utf8)!
let g = WidgetSnapshot.parse(garbage)
check(g != nil && g?.signedIn == false, "garbage decodes without crashing")
check(g?.companies.first?.figures?.outstanding == nil, "a mistyped field is just absent")

check(WidgetText.fill(":count of :countdown", ["count": "3", "countdown": "10"]) == "3 of 10",
  "placeholders fill longest first")

if failures > 0 {
  print("\(failures) widget snapshot contract check(s) failed")
  exit(1)
}
print("Widget snapshot contract: OK")
