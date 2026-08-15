import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TursoClient {
  static String get _baseUrl {
    final rawUrl =
        dotenv.env['TURSO_DATABASE_URL'] ??
        (throw StateError('TURSO_DATABASE_URL tidak di-set di .env'));
    return '${rawUrl.replaceAll('libsql://', 'https://').replaceAll('turso://', 'https://')}/v2/pipeline';
  }

  static String get _authToken =>
      dotenv.env['TURSO_AUTH_TOKEN'] ??
      (throw StateError('TURSO_AUTH_TOKEN tidak di-set di .env'));

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? args,
  }) async {
    final body = _buildPayload(sql, args: args);
    final response = await _post(body);
    return _parseRows(response);
  }

  Future<void> execute(String sql, {List<dynamic>? args}) async {
    final body = _buildPayload(sql, args: args);
    await _post(body);
  }

  Future<void> batch(List<String> statements) async {
    final requests = <Map<String, dynamic>>[];
    for (final sql in statements) {
      requests.add({
        'type': 'execute',
        'stmt': {'sql': sql},
      });
    }
    requests.add({'type': 'close'});

    await _post({'requests': requests});
  }

  Map<String, dynamic> _buildPayload(String sql, {List<dynamic>? args}) {
    final stmt = <String, dynamic>{'sql': sql};

    if (args != null && args.isNotEmpty) {
      stmt['args'] = args.map((arg) => _encodeArg(arg)).toList();
    }

    return {
      'requests': [
        {'type': 'execute', 'stmt': stmt},
        {'type': 'close'},
      ],
    };
  }

  Map<String, dynamic> _encodeArg(dynamic value) {
    if (value == null) {
      return {'type': 'null', 'value': null};
    } else if (value is int) {
      return {'type': 'integer', 'value': value.toString()};
    } else if (value is double) {
      return {'type': 'float', 'value': value.toString()};
    } else if (value is String) {
      return {'type': 'text', 'value': value};
    } else {
      return {'type': 'text', 'value': value.toString()};
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $_authToken',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Turso HTTP ${response.statusCode}: ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _parseRows(Map<String, dynamic> response) {
    final results = response['results'] as List<dynamic>;
    if (results.isEmpty) return [];

    final first = results.first as Map<String, dynamic>;
    if (first['type'] != 'ok') return [];

    final executeResult =
        (first['response'] as Map<String, dynamic>)['result']
            as Map<String, dynamic>;

    final cols = (executeResult['cols'] as List<dynamic>)
        .map((col) => (col as Map<String, dynamic>)['name'] as String)
        .toList();

    final rows = (executeResult['rows'] as List<dynamic>).map((row) {
      final values = row as List<dynamic>;
      final map = <String, dynamic>{};
      for (var i = 0; i < cols.length; i++) {
        final cell = values[i] as Map<String, dynamic>;
        final type = cell['type'] as String?;
        final raw = cell['value'];
        map[cols[i]] = _coerceValue(raw, type);
      }
      return map;
    }).toList();

    return rows;
  }

  dynamic _coerceValue(dynamic raw, String? type) {
    if (raw == null) return null;
    if (raw is num) return raw;
    if (raw is String) {
      if (type == 'integer' || type == 'int') {
        return int.tryParse(raw) ?? raw;
      }
      if (type == 'float' || type == 'real' || type == 'double') {
        return double.tryParse(raw) ?? raw;
      }
    }
    return raw;
  }
}
