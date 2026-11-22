import 'dart:convert';
import 'dart:typed_data';

import '../models/vehicle_position.dart';

/// A minimal, dependency-free decoder for the GTFS-Realtime protobuf wire
/// format (https://gtfs.org/realtime/reference/).
///
/// Why hand-rolled instead of the `protobuf` package + generated `.pb.dart`
/// files: generating those needs `protoc`, an extra native toolchain
/// dependency that isn't guaranteed to be available wherever this project
/// gets built. The wire format itself is simple (tag = (field_number << 3)
/// | wire_type, varint / fixed32 / fixed64 / length-delimited), and we only
/// ever need to read a handful of fields out of a VehiclePosition, so a
/// ~150-line reader is more portable than a generated-code dependency. If
/// you'd rather use the official bindings, swap this file for the
/// generated gtfs-realtime.pb.dart - callers only depend on
/// [VehiclePosition] and [parseGtfsRealtimeFeed], not on anything below.
///
/// Field numbers were confirmed by hand-decoding a real sample from
/// https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb and
/// cross-checked against the public gtfs-realtime.proto schema.
class _Reader {
  final Uint8List data;
  int pos = 0;
  _Reader(this.data);

  bool get hasMore => pos < data.length;

  int readVarint() {
    int result = 0;
    int shift = 0;
    while (true) {
      final b = data[pos++];
      result |= (b & 0x7f) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return result;
  }

  /// Reads one (fieldNumber, wireType) tag + its payload, returning the
  /// payload as raw bytes for wireType 2 (length-delimited), or the decoded
  /// int/double otherwise. Caller inspects [wireType] to know how to read
  /// [intValue]/[doubleValue]/[bytesValue].
  _Field readField() {
    final tag = readVarint();
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    switch (wireType) {
      case 0: // varint
        return _Field(fieldNumber, wireType, intValue: readVarint());
      case 1: // 64-bit fixed (double / fixed64)
        final bytes = data.sublist(pos, pos + 8);
        pos += 8;
        return _Field(fieldNumber, wireType,
            doubleValue: ByteData.sublistView(bytes).getFloat64(0, Endian.little));
      case 2: // length-delimited (string / bytes / nested message)
        final len = readVarint();
        final bytes = data.sublist(pos, pos + len);
        pos += len;
        return _Field(fieldNumber, wireType, bytesValue: bytes);
      case 5: // 32-bit fixed (float / fixed32)
        final bytes = data.sublist(pos, pos + 4);
        pos += 4;
        return _Field(fieldNumber, wireType,
            doubleValue: ByteData.sublistView(bytes).getFloat32(0, Endian.little));
      default:
        throw FormatException('Unsupported protobuf wire type $wireType');
    }
  }
}

class _Field {
  final int fieldNumber;
  final int wireType;
  final int? intValue;
  final double? doubleValue;
  final Uint8List? bytesValue;
  _Field(this.fieldNumber, this.wireType,
      {this.intValue, this.doubleValue, this.bytesValue});

  String get asString => utf8.decode(bytesValue!);
}

class GtfsRealtimeFeed {
  final String version;
  final DateTime headerTimestamp;
  final List<VehiclePosition> vehicles;

  GtfsRealtimeFeed(this.version, this.headerTimestamp, this.vehicles);
}

/// Parses a full FeedMessage (FeedHeader + repeated FeedEntity) out of raw
/// protobuf bytes, as returned by
/// GET https://api.data.gov.my/gtfs-realtime/vehicle-position/{ktmb|prasarana?category=rapid-rail-kl}
GtfsRealtimeFeed parseGtfsRealtimeFeed(Uint8List bytes) {
  final reader = _Reader(bytes);
  String version = 'unknown';
  DateTime headerTs = DateTime.fromMillisecondsSinceEpoch(0);
  final vehicles = <VehiclePosition>[];

  while (reader.hasMore) {
    final f = reader.readField();
    if (f.fieldNumber == 1 && f.wireType == 2) {
      // FeedHeader
      final h = _Reader(f.bytesValue!);
      while (h.hasMore) {
        final hf = h.readField();
        if (hf.fieldNumber == 1) version = hf.asString;
        if (hf.fieldNumber == 3) {
          headerTs =
              DateTime.fromMillisecondsSinceEpoch((hf.intValue ?? 0) * 1000);
        }
      }
    } else if (f.fieldNumber == 2 && f.wireType == 2) {
      // FeedEntity
      final vp = _parseFeedEntityForVehicle(f.bytesValue!);
      if (vp != null) vehicles.add(vp);
    }
    // trip_update / alert entities and anything else are skipped: we only
    // consume vehicle-position feeds today (data.gov.my's own docs note
    // trip-update / service-alert feeds are still "in the pipeline").
  }
  return GtfsRealtimeFeed(version, headerTs, vehicles);
}

VehiclePosition? _parseFeedEntityForVehicle(Uint8List entityBytes) {
  final r = _Reader(entityBytes);
  Uint8List? vehicleMsg;
  while (r.hasMore) {
    final f = r.readField();
    if (f.fieldNumber == 4 && f.wireType == 2) {
      vehicleMsg = f.bytesValue;
    }
  }
  if (vehicleMsg == null) return null;
  return _parseVehiclePosition(vehicleMsg);
}

VehiclePosition _parseVehiclePosition(Uint8List bytes) {
  final r = _Reader(bytes);
  String tripId = '';
  double lat = 0, lon = 0, bearing = 0, speed = 0;
  int timestampSeconds = 0;
  String? vehicleId;
  String? vehicleLabel;

  while (r.hasMore) {
    final f = r.readField();
    switch (f.fieldNumber) {
      case 1: // TripDescriptor
        final tr = _Reader(f.bytesValue!);
        while (tr.hasMore) {
          final tf = tr.readField();
          if (tf.fieldNumber == 1) tripId = tf.asString;
        }
        break;
      case 2: // Position
        final pr = _Reader(f.bytesValue!);
        while (pr.hasMore) {
          final pf = pr.readField();
          switch (pf.fieldNumber) {
            case 1:
              lat = pf.doubleValue ?? 0;
              break;
            case 2:
              lon = pf.doubleValue ?? 0;
              break;
            case 3:
              bearing = pf.doubleValue ?? 0;
              break;
            case 5:
              speed = pf.doubleValue ?? 0;
              break;
          }
        }
        break;
      case 5: // timestamp
        timestampSeconds = f.intValue ?? 0;
        break;
      case 8: // VehicleDescriptor
        final vr = _Reader(f.bytesValue!);
        while (vr.hasMore) {
          final vf = vr.readField();
          if (vf.fieldNumber == 1) vehicleId = vf.asString;
          if (vf.fieldNumber == 2) vehicleLabel = vf.asString;
        }
        break;
    }
  }

  return VehiclePosition(
    tripId: tripId,
    latitude: lat,
    longitude: lon,
    bearing: bearing,
    speedKmh: speed,
    timestamp: timestampSeconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000)
        : DateTime.now(),
    vehicleId: vehicleId,
    vehicleLabel: vehicleLabel,
  );
}
