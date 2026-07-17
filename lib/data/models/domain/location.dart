import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/location_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'location.freezed.dart';

/// Clean domain shape for a Client location (shipping / billing address).
///
/// Locations are **read-embedded** on [Client] (`client.locations[]`) but
/// **written via the standalone `/api/v1/locations` resource** (POST / PUT /
/// DELETE), not as part of the client save payload — see `LocationsApi` +
/// the `location*` outbox mutation kinds. Mirrors the [Contact] embed shape.
@freezed
abstract class Location with _$Location {
  const factory Location({
    required String id,
    required String clientId,
    required String name,
    required String address1,
    required String address2,
    required String city,
    required String state,
    required String postalCode,
    required String countryId,
    @Default('') String customValue1,
    @Default('') String customValue2,
    @Default('') String customValue3,
    @Default('') String customValue4,
    required bool isShippingLocation,
    required DateTime updatedAt,
    required bool isDeleted,
  }) = _Location;

  factory Location.fromApi(LocationApi a) => Location(
    id: a.id,
    clientId: a.clientId,
    name: a.name,
    address1: a.address1,
    address2: a.address2,
    city: a.city,
    state: a.state,
    postalCode: a.postalCode,
    countryId: a.countryId,
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    isShippingLocation: a.isShippingLocation,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    isDeleted: a.isDeleted,
  );
}

extension LocationCopy on Location {
  /// Body for `POST /api/v1/locations` (needs `client_id`) and
  /// `PUT /api/v1/locations/{id}`. Mirrors React's `LocationModal` payload.
  Map<String, dynamic> toApiJson() => {
    if (id.isNotEmpty) 'id': id,
    'client_id': clientId,
    'name': name,
    'address1': address1,
    'address2': address2,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    // Omit an empty country_id: the server's StoreLocationRequest rule is
    // `integer|exists:countries,id` with no nullable/sometimes, and Laravel's
    // ConvertEmptyStringsToNull turns '' → null, which 422s. Absent = skipped.
    if (countryId.isNotEmpty) 'country_id': countryId,
    'custom_value1': customValue1,
    'custom_value2': customValue2,
    'custom_value3': customValue3,
    'custom_value4': customValue4,
    'is_shipping_location': isShippingLocation,
  };
}
