import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves the bank-account name from the local Drift cache and renders
/// it as a `Text` (or a link when [link]). Falls back to the raw
/// `bankAccountId` while the watch is empty; on a cache miss it triggers
/// a lazy per-id hydrate (`BankAccountRepository.ensureLoaded`). Bank
/// accounts are bundled, so this is normally an instant cache hit — the
/// hydrate is the safety net for a stale / not-yet-bundled integration.
///
/// Drift dedupes identical watch queries (and the repo dedupes the
/// hydrate fetch), so N rows for the same account share one subscription
/// and one network call.
class BankAccountNameLabel extends StatefulWidget {
  const BankAccountNameLabel({
    super.key,
    required this.bankAccountId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String bankAccountId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// When true the resolved name renders as a hover-underlined link to
  /// the bank account's full-screen view. Off by default.
  final bool link;

  @override
  State<BankAccountNameLabel> createState() => _BankAccountNameLabelState();
}

class _BankAccountNameLabelState extends State<BankAccountNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(BankAccountNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bankAccountId != widget.bankAccountId) _ensure();
  }

  /// Lazily hydrate the referenced bank account into Drift if it isn't
  /// cached. No-op / deduped / negative-cached in the repo, so it's safe
  /// to fire unconditionally here.
  void _ensure() {
    final id = widget.bankAccountId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.bankAccounts.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.bankAccountId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, widget.bankAccountId);
    }
    return StreamBuilder<BankAccount?>(
      initialData: services.bankAccounts.peek(
        companyId: companyId,
        id: widget.bankAccountId,
      ),
      stream: services.bankAccounts.watch(
        companyId: companyId,
        id: widget.bankAccountId,
      ),
      builder: (context, snapshot) {
        final account = snapshot.data;
        final name = account == null || account.name.isEmpty
            ? widget.bankAccountId
            : account.name;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => linkOrText(
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(
            context,
            '/settings/bank_accounts',
            widget.bankAccountId,
          )
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}
