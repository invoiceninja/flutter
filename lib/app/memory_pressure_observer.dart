import 'package:flutter/widgets.dart';

/// Hands the OS's low-memory signal to whatever can give memory back — today
/// [Services.releaseMemory], which drops the repositories' decoded records.
///
/// Registered by `InvoiceNinjaApp` beside the other lifecycle observers.
class MemoryPressureObserver with WidgetsBindingObserver {
  MemoryPressureObserver(this.onPressure);

  final VoidCallback onPressure;

  @override
  void didHaveMemoryPressure() => onPressure();
}
