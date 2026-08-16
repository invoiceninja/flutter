import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/labeled_switch_group.dart';
import 'package:admin/ui/features/settings/view_models/user_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kUserDetailsNotificationsSearchKeys = <String>[
  'notifications',
  'all_events',
  'user_logged_in_notification',
  'task_assigned_notification',
  'disable_recurring_payment_notification',
  'enable_e_invoice_received_notification',
  'invoice_created',
  // Matches the row's label key — settings search renders a field key raw and
  // `invoice_sent` is ":count invoice sent".
  'invoice_sent_notification_label',
  'invoice_viewed',
  'invoice_late',
  'payment_success',
  'payment_failure',
  'payment_manual',
  'quote_created',
  'quote_sent',
  'quote_viewed',
  'quote_approved',
  'quote_expired',
  'quote_rejected',
  'credit_created',
  'credit_sent',
  'credit_viewed',
  'purchase_order_created',
  'purchase_order_sent',
  'purchase_order_viewed',
  'purchase_order_accepted',
  'inventory_threshold',
];

const String _kAllNotifications = 'all_notifications';
const String _kAllUserNotifications = 'all_user_notifications';

// Special first-section toggle codes. The server stores these as bare strings
// in `company_user.notifications.email` (matching React), NOT as settings-blob
// booleans. They're independent of the per-record master selector, so they're
// preserved across a master-mode switch.
const String _kTaskAssigned = 'task_assigned';
const String _kDisableRecurringPayment =
    'disable_recurring_payment_notification';
const String _kEnableEInvoiceReceived =
    'enable_e_invoice_received_notification';
const Set<String> _kSpecialCodes = {
  _kTaskAssigned,
  _kDisableRecurringPayment,
  _kEnableEInvoiceReceived,
};

enum _MasterMode { allRecords, ownedByUser, custom }

enum _EventMode { allRecords, ownedByUser, none }

class _EventDef {
  const _EventDef(this.code, this.labelKey);
  final String code;
  final String labelKey;
}

const List<_EventDef> _kEvents = <_EventDef>[
  _EventDef('invoice_created', 'invoice_created'),
  // Label key differs from the event id: `invoice_sent` is ":count invoice
  // sent", so the row uses the placeholder-free notification label.
  _EventDef('invoice_sent', 'invoice_sent_notification_label'),
  _EventDef('invoice_viewed', 'invoice_viewed'),
  _EventDef('invoice_late', 'invoice_late'),
  _EventDef('payment_success', 'payment_success'),
  _EventDef('payment_failure', 'payment_failure'),
  _EventDef('payment_manual', 'payment_manual'),
  _EventDef('quote_created', 'quote_created'),
  _EventDef('quote_sent', 'quote_sent'),
  _EventDef('quote_viewed', 'quote_viewed'),
  _EventDef('quote_approved', 'quote_approved'),
  _EventDef('quote_expired', 'quote_expired'),
  _EventDef('quote_rejected', 'quote_rejected'),
  _EventDef('credit_created', 'credit_created'),
  _EventDef('credit_sent', 'credit_sent'),
  _EventDef('credit_viewed', 'credit_viewed'),
  _EventDef('purchase_order_created', 'purchase_order_created'),
  _EventDef('purchase_order_sent', 'purchase_order_sent'),
  _EventDef('purchase_order_viewed', 'purchase_order_viewed'),
  _EventDef('purchase_order_accepted', 'purchase_order_accepted'),
  _EventDef('inventory_threshold', 'inventory_threshold'),
];

class UserDetailsNotificationsScreen extends StatelessWidget {
  const UserDetailsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserDetailsViewModel>();
    if (!vm.isLoaded || !vm.draftReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = vm.user;
    if (user == null) return const SizedBox.shrink();

    final email = user.notificationsEmail;
    final master = _masterFor(email);

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('notifications'),
          children: [
            LabeledSwitchGroup(
              items: [
                LabeledSwitchItem(
                  label: context.tr('user_logged_in_notification'),
                  value: user.userLoggedInNotification,
                  onChanged: vm.setUserLoggedInNotification,
                ),
                LabeledSwitchItem(
                  label: context.tr('task_assigned_notification'),
                  value: email.contains(_kTaskAssigned),
                  onChanged: (v) =>
                      vm.toggleNotificationCode(_kTaskAssigned, v),
                ),
                LabeledSwitchItem(
                  label: context.tr('disable_recurring_payment_notification'),
                  value: email.contains(_kDisableRecurringPayment),
                  onChanged: (v) =>
                      vm.toggleNotificationCode(_kDisableRecurringPayment, v),
                ),
                LabeledSwitchItem(
                  label: context.tr('enable_e_invoice_received_notification'),
                  value: email.contains(_kEnableEInvoiceReceived),
                  onChanged: (v) =>
                      vm.toggleNotificationCode(_kEnableEInvoiceReceived, v),
                ),
              ],
            ),
          ],
        ),
        FormSection(
          title: context.tr('notification_subscriptions'),
          spacing: 0,
          children: [
            _SubscriptionsTable(
              master: master,
              email: email,
              onMasterChanged: (m) => _onMasterChanged(vm, email, m),
              onEventChanged: (event, mode) =>
                  _onEventChanged(vm, email, event, mode),
            ),
          ],
        ),
      ],
    );
  }

  _MasterMode _masterFor(List<String> email) {
    if (email.contains(_kAllNotifications)) return _MasterMode.allRecords;
    if (email.contains(_kAllUserNotifications)) return _MasterMode.ownedByUser;
    return _MasterMode.custom;
  }

  void _onMasterChanged(
    UserDetailsViewModel vm,
    List<String> email,
    _MasterMode mode,
  ) {
    // The special toggle codes live in the same email list but are independent
    // of the per-record master selector — carry them across a master switch.
    final preserved = email.where(_kSpecialCodes.contains).toList();
    switch (mode) {
      case _MasterMode.allRecords:
        vm.setNotificationsEmail([_kAllNotifications, ...preserved]);
      case _MasterMode.ownedByUser:
        vm.setNotificationsEmail([_kAllUserNotifications, ...preserved]);
      case _MasterMode.custom:
        // Drop the master codes; keep any per-event subscriptions already
        // there (lets the user undo a master selection without losing the
        // previous custom shape).
        final keep = email
            .where(
              (code) =>
                  code != _kAllNotifications && code != _kAllUserNotifications,
            )
            .toList();
        vm.setNotificationsEmail(keep);
    }
  }

  void _onEventChanged(
    UserDetailsViewModel vm,
    List<String> email,
    String event,
    _EventMode mode,
  ) {
    final next = email
        .where((code) => code != '${event}_all' && code != '${event}_user')
        .toList();
    switch (mode) {
      case _EventMode.allRecords:
        next.add('${event}_all');
      case _EventMode.ownedByUser:
        next.add('${event}_user');
      case _EventMode.none:
        break;
    }
    vm.setNotificationsEmail(next);
  }
}

/// Two-column subscriptions table — Event | Email — matching the
/// admin-portal layout. The first row holds the master selector; when it's
/// set to All-records or Owned-by-user, the 21 per-event rows render as
/// read-only [_IconText] (icon + text) instead of a dropdown.
class _SubscriptionsTable extends StatelessWidget {
  const _SubscriptionsTable({
    required this.master,
    required this.email,
    required this.onMasterChanged,
    required this.onEventChanged,
  });

  final _MasterMode master;
  final List<String> email;
  final ValueChanged<_MasterMode> onMasterChanged;
  final void Function(String event, _EventMode mode) onEventChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final headerStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final disabledByMaster = master != _MasterMode.custom;
    // DataTable doesn't scroll horizontally — on a narrow phone a long
    // localized event label + the dropdown can overflow. Fill the width when
    // it fits (minWidth) and scroll when it doesn't.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 56,
            horizontalMargin: 0,
            columnSpacing: InSpacing.xl,
            dividerThickness: 0,
            columns: [
              const DataColumn(label: SizedBox.shrink()),
              DataColumn(label: Text(context.tr('email'), style: headerStyle)),
            ],
            rows: [
              DataRow(
                cells: [
                  DataCell(Text(context.tr('all_events'), style: headerStyle)),
                  DataCell(
                    _NotificationSelector<_MasterMode>(
                      value: master,
                      items: const [
                        _SelectorItem(
                          value: _MasterMode.allRecords,
                          labelKey: 'all_records',
                          icon: Icons.supervised_user_circle,
                        ),
                        _SelectorItem(
                          value: _MasterMode.ownedByUser,
                          labelKey: 'owned_by_user',
                          icon: Icons.account_circle,
                        ),
                        _SelectorItem(
                          value: _MasterMode.custom,
                          labelKey: 'custom',
                          icon: Icons.arrow_drop_down_circle,
                        ),
                      ],
                      onChanged: onMasterChanged,
                    ),
                  ),
                ],
              ),
              for (final event in _kEvents)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        context.tr(event.labelKey),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: disabledByMaster ? tokens.ink3 : tokens.ink,
                        ),
                      ),
                    ),
                    DataCell(_eventCell(context, event)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventCell(BuildContext context, _EventDef event) {
    // When the master selector locks the user into All-records / Owned-by-
    // user, the per-event rows in the old app become a static IconText
    // showing the inherited state. Mirror that here so the user can see at a
    // glance which mode they're in.
    if (master == _MasterMode.allRecords) {
      return _IconText(
        icon: Icons.supervised_user_circle,
        labelKey: 'all_records',
      );
    }
    if (master == _MasterMode.ownedByUser) {
      return _IconText(icon: Icons.account_circle, labelKey: 'owned_by_user');
    }
    final mode = _modeForEvent(email, event.code);
    return _NotificationSelector<_EventMode>(
      value: mode,
      items: const [
        _SelectorItem(
          value: _EventMode.allRecords,
          labelKey: 'all_records',
          icon: Icons.supervised_user_circle,
        ),
        _SelectorItem(
          value: _EventMode.ownedByUser,
          labelKey: 'owned_by_user',
          icon: Icons.account_circle,
        ),
        _SelectorItem(
          value: _EventMode.none,
          labelKey: 'none',
          icon: Icons.do_not_disturb_alt,
        ),
      ],
      onChanged: (mode) => onEventChanged(event.code, mode),
    );
  }

  _EventMode _modeForEvent(List<String> email, String event) {
    if (email.contains('${event}_all')) return _EventMode.allRecords;
    if (email.contains('${event}_user')) return _EventMode.ownedByUser;
    return _EventMode.none;
  }
}

class _SelectorItem<T> {
  const _SelectorItem({
    required this.value,
    required this.labelKey,
    required this.icon,
  });
  final T value;
  final String labelKey;
  final IconData icon;
}

class _NotificationSelector<T> extends StatelessWidget {
  const _NotificationSelector({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<_SelectorItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item.value,
            child: _IconText(icon: item.icon, labelKey: item.labelKey),
          ),
      ],
    );
  }
}

/// Small `Icon + Text` row used both as a non-interactive cell (when the
/// master selector locks the per-event rows) and as the body of each
/// dropdown menu item. Equivalent to admin-portal's `IconText` helper.
class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.labelKey});

  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: tokens.ink2),
        const SizedBox(width: InSpacing.sm),
        Text(context.tr(labelKey)),
      ],
    );
  }
}
