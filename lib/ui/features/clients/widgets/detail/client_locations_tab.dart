import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/location.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/address_format.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_country_field.dart';

/// Client detail → Locations tab. Lists the client's read-embedded
/// `locations[]` and manages them through the standalone `/api/v1/locations`
/// resource (the `location*` outbox mutations). Mirrors React's Locations
/// tab + LocationModal. Each add/edit/delete enqueues immediately; the
/// dispatcher refreshes the parent client so this list (watched from Drift)
/// updates when the row drains.
class ClientLocationsTab extends StatelessWidget {
  const ClientLocationsTab({required this.client, super.key});

  final Client client;

  @override
  Widget build(BuildContext context) {
    // Locations are a separate `/api/v1/locations` resource keyed by
    // client_id; there's no id-remap for a foreign key inside a custom-
    // action payload, so a location can't be created against a not-yet-
    // synced (tmp_) client. Mirror React, which gates the tab until the
    // client is persisted ("Save to add locations").
    if (client.id.startsWith('tmp_')) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: context.tr('save_to_add_locations'),
      );
    }
    final locations = client.locations
        .where((l) => !l.isDeleted)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.all(InSpacing.md(context)),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(context.tr('add_location')),
              onPressed: () => _showLocationDialog(context, client, null),
            ),
          ),
        ),
        if (locations.isEmpty)
          EmptyState(
            icon: Icons.location_off_outlined,
            title: context.tr('no_locations'),
          )
        else
          for (final loc in locations)
            _LocationTile(client: client, location: loc),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.client, required this.location});

  final Client client;
  final Location location;

  String _addressLine(BuildContext context) {
    final swap = location.countryId.isEmpty
        ? false
        : (context
                  .read<Services>()
                  .statics
                  .country(location.countryId)
                  ?.swapPostalCode ??
              false);
    final cityLine = cityStateZip(
      city: location.city,
      state: location.state,
      postalCode: location.postalCode,
      swapPostalCode: swap,
    );
    return [
      location.address1,
      location.address2,
      cityLine,
    ].where((s) => s.isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final addressLine = _addressLine(context);
    return ListTile(
      leading: Icon(Icons.place_outlined, color: tokens.ink2),
      title: Text(
        location.name.isEmpty ? context.tr('location') : location.name,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addressLine.isNotEmpty)
            Text(addressLine, style: TextStyle(color: tokens.ink3)),
          if (location.isShippingLocation)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.tr('shipping_location'),
                style: TextStyle(
                  color: tokens.accentInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: tokens.overdue),
        tooltip: context.tr('delete_location'),
        onPressed: () => _confirmDelete(context, client, location),
      ),
      onTap: () => _showLocationDialog(context, client, location),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  Client client,
  Location location,
) async {
  final services = context.read<Services>();
  final companyId = services.auth.session.value?.currentCompanyId ?? '';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('delete_location')),
      content: Text(ctx.tr('are_you_sure')),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: ctx.tr('delete'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await runMutationWithNotify(
    context,
    () => services.clients.deleteLocation(
      companyId: companyId,
      clientId: client.id,
      locationId: location.id,
    ),
    successMsg: context.tr('deleted_location'),
  );
}

/// The dialog widget owns the controllers + the enqueue/notify call so its
/// own post-await `mounted` guards stay valid; this just presents it.
void _showLocationDialog(
  BuildContext context,
  Client client,
  Location? existing,
) {
  showDialog<bool>(
    context: context,
    builder: (ctx) => _LocationFormDialog(client: client, existing: existing),
  );
}

class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({required this.client, this.existing});

  final Client client;
  final Location? existing;

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address1;
  late final TextEditingController _address2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postalCode;
  late String _countryId;
  late bool _isShipping;
  // Custom values held in State (not controllers) so typed inputs — switch /
  // date / dropdown — can reflect a new selection on rebuild; `_build()` reads
  // these on save.
  late String _custom1;
  late String _custom2;
  late String _custom3;
  late String _custom4;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _address1 = TextEditingController(text: e?.address1 ?? '');
    _address2 = TextEditingController(text: e?.address2 ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _state = TextEditingController(text: e?.state ?? '');
    _postalCode = TextEditingController(text: e?.postalCode ?? '');
    _countryId = e?.countryId ?? '';
    _isShipping = e?.isShippingLocation ?? false;
    _custom1 = e?.customValue1 ?? '';
    _custom2 = e?.customValue2 ?? '';
    _custom3 = e?.customValue3 ?? '';
    _custom4 = e?.customValue4 ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  Location _build() {
    final e = widget.existing;
    return Location(
      id: e?.id ?? '',
      clientId: widget.client.id,
      name: _name.text.trim(),
      address1: _address1.text.trim(),
      address2: _address2.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      postalCode: _postalCode.text.trim(),
      countryId: _countryId,
      customValue1: _custom1,
      customValue2: _custom2,
      customValue3: _custom3,
      customValue4: _custom4,
      isShippingLocation: _isShipping,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isDeleted: false,
    );
  }

  Future<void> _save() async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final loc = _build();
    setState(() => _busy = true);
    final isEdit = widget.existing != null;
    await runMutationWithNotify(
      context,
      () => isEdit
          ? services.clients.updateLocation(
              companyId: companyId,
              clientId: widget.client.id,
              locationId: loc.id,
              body: loc.toApiJson(),
            )
          : services.clients.createLocation(
              companyId: companyId,
              clientId: widget.client.id,
              body: loc.toApiJson(),
            ),
      successMsg: context.tr(isEdit ? 'updated_location' : 'created_location'),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.tr(widget.existing == null ? 'add_location' : 'edit_location'),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // `words` is opted into per field, never defaulted: `state`
              // is bimodal ("California" / "CA") and auto-shifting only the
              // first letter turns the abbreviation into "Ca".
              _w(context, _name, 'name'),
              _w(context, _address1, 'address1'),
              _w(context, _address2, 'address2'),
              _w(context, _city, 'city'),
              _field(context, _state, 'state'),
              // Alphanumeric outside the US — uppercase, never numeric.
              _field(
                context,
                _postalCode,
                'postal_code',
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
              ),
              const SizedBox(height: 8),
              ClientEditCountryField(
                initial: _countryId,
                onChanged: (id) => _countryId = id,
              ),
              _LocationCustomFields(
                values: [_custom1, _custom2, _custom3, _custom4],
                onChanged: [
                  (v) => setState(() => _custom1 = v),
                  (v) => setState(() => _custom2 = v),
                  (v) => setState(() => _custom3 = v),
                  (v) => setState(() => _custom4 = v),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _isShipping,
                onChanged: (v) => setState(() => _isShipping = v),
                title: Text(context.tr('shipping_location')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('save'),
              enabled: !_busy,
              busy: _busy,
              // The form fields own focus; Enter submits via their onSubmitted.
              autofocus: false,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }

  /// [_field] with word capitalization — the proper-noun rows.
  Widget _w(BuildContext context, TextEditingController c, String labelKey) =>
      _field(
        context,
        c,
        labelKey,
        textCapitalization: TextCapitalization.words,
      );

  Widget _field(
    BuildContext context,
    TextEditingController c,
    String labelKey, {
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: c,
      // Single-line: Enter submits the form (matches the § Forms convention).
      textInputAction: TextInputAction.done,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: autocorrect,
      onSubmitted: (_) {
        if (!_busy) _save();
      },
      decoration: InputDecoration(
        labelText: context.tr(labelKey),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

/// Location custom fields (`location1..4`) — type-aware, gated by the company's
/// configured labels. Self-collapses (renders nothing) when none are set.
class _LocationCustomFields extends StatelessWidget {
  const _LocationCustomFields({required this.values, required this.onChanged});

  final List<String> values;
  final List<ValueChanged<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return EntityCustomFieldsSection(
      keyPrefix: 'location',
      companyStream: services.company.watchCompany(companyId),
      formatter: services.formatterIfReady(companyId),
      wrapInCard: false,
      values: values,
      onChanged: onChanged,
    );
  }
}
