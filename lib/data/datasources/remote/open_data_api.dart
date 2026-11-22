import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/ridership.dart';

class OpenDataException implements Exception {
  final String message;
  const OpenDataException(this.message);

  @override
  String toString() => message;
}

class OpenDataApi {
  static const String host = 'api.data.gov.my';
  static const String cataloguePath = '/data-catalogue/';
  static const String ridershipDatasetId = 'ridership_headline';
  static const Duration timeout = Duration(seconds: 12);

  final http.Client _client;

  OpenDataApi({http.Client? client}) : _client = client ?? http.Client();

  Uri ridershipUri({int limit = 400}) {
    return Uri.https(host, cataloguePath, {
      'id': ridershipDatasetId,
      'limit': '$limit',
      'sort': '-date',
    });
  }

  Future<List<RidershipRecord>> fetchRidership({int limit = 400}) async {
    try {
      final response =
          await _client.get(ridershipUri(limit: limit)).timeout(timeout);

      if (response.statusCode != 200) {
        throw OpenDataException(
          'The open data portal returned status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const OpenDataException(
          'Unexpected response shape from the open data portal.',
        );
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .where((row) => row['date'] != null)
          .map(RidershipRecord.fromJson)
          .toList();
    } on TimeoutException {
      throw const OpenDataException(
        'The open data portal did not respond in time.',
      );
    } on FormatException {
      throw const OpenDataException(
        'The open data response could not be parsed.',
      );
    } on http.ClientException catch (error) {
      throw OpenDataException('Network unavailable: ${error.message}');
    }
  }

  void dispose() => _client.close();
}
