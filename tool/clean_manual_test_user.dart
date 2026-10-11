// Deletes cloud data owned by one Budgly manual-test user.
//
// Usage:
//   dart run tool/clean_manual_test_user.dart [uid-or-email]
//   dart run tool/clean_manual_test_user.dart [uid-or-email] --apply
//
// Supabase URL/key are loaded from assets/.env. An administrative Supabase key
// can override SUPABASE_KEY through SUPABASE_SERVICE_ROLE_KEY. Firebase project
// ID comes from FIREBASE_PROJECT_ID or --project=<id>.

import 'dart:convert';
import 'dart:io';

const _usage = '''
Usage: dart run tool/clean_manual_test_user.dart [uid-or-email] [--apply] [--project=<firebase-project-id>]

Default mode is preview. Add --apply to enable deletion; the script will then
require typing DELETE, the resolved UID, and the Firebase project ID.

Environment:
  FIREBASE_PROJECT_ID          Firebase/Google Cloud project ID (optional; inferred from Android config)
  SUPABASE_SERVICE_ROLE_KEY    Optional admin key override (never pass as an argument)

Prerequisite: `gcloud auth application-default login` with permission to read
and delete Firebase Auth users and administer Firestore.
''';

class _Args {
  _Args(List<String> values) {
    for (final value in values) {
      if (value == '--apply') {
        apply = true;
      } else if (value.startsWith('--project=')) {
        project = value.substring('--project='.length).trim();
      } else if (value == '--help' || value == '-h') {
        help = true;
      } else if (value.startsWith('--')) {
        throw FormatException('Option inconnue: $value');
      } else if (target == null) {
        target = value.trim();
      } else {
        throw const FormatException('Un seul UID ou email est accepté.');
      }
    }
  }
  String? target;
  String? project;
  bool apply = false;
  bool help = false;
}

class _Api {
  final HttpClient _client = HttpClient();

  Future<dynamic> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    Set<int> allowed = const {200},
  }) async {
    final request = await _client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    if (!allowed.contains(response.statusCode)) {
      throw HttpException(
        '$method $uri a échoué (${response.statusCode}): $text',
      );
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  void close() => _client.close(force: true);
}

class _Firestore {
  _Firestore(this.api, this.project, this.token);
  final _Api api;
  final String project;
  final String token;
  String get root => 'projects/$project/databases/(default)/documents';
  Map<String, String> get headers => {'Authorization': 'Bearer $token'};
  int documentsFound = 0;

  Future<List<String>> collectionIds(String parent) async {
    final result = await api.request(
      'POST',
      Uri.https('firestore.googleapis.com', '/v1/$parent:listCollectionIds'),
      headers: headers,
      body: {'pageSize': 1000},
      allowed: {200, 404},
    ) as Map<String, dynamic>;
    return (result['collectionIds'] as List<dynamic>? ?? []).cast<String>();
  }

  Future<List<Map<String, dynamic>>> list(String collection) async {
    final docs = <Map<String, dynamic>>[];
    String? token;
    do {
      final query = <String, String>{'pageSize': '1000', 'pageToken': ?token};
      final result = await api.request(
        'GET',
        Uri.https('firestore.googleapis.com', '/v1/$collection', query),
        headers: headers,
      ) as Map<String, dynamic>;
      docs.addAll(
        (result['documents'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>(),
      );
      token = result['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    return docs;
  }

  Future<void> removeTree(String documentName, {required bool delete}) async {
    for (final id in await collectionIds(documentName)) {
      final collection = '$documentName/$id';
      final children = await list(collection);
      documentsFound += children.length;
      for (final child in children) {
        await removeTree(child['name'] as String, delete: delete);
      }
    }
    if (delete) {
      await api.request(
        'DELETE',
        Uri.https('firestore.googleapis.com', '/v1/$documentName'),
        headers: headers,
        allowed: {200, 204},
      );
    }
  }

  Future<void> removeUser(String uid, {required bool delete}) async {
    final userDoc = '$root/users/$uid';
    // The user document may not exist while its subcollections still do.
    for (final id in await collectionIds(userDoc)) {
      final collection = '$userDoc/$id';
      final children = await list(collection);
      documentsFound += children.length;
      for (final child in children) {
        await removeTree(child['name'] as String, delete: delete);
      }
    }
    if (delete) {
      await api.request(
        'DELETE',
        Uri.https('firestore.googleapis.com', '/v1/$userDoc'),
        headers: headers,
        allowed: {200, 204, 404},
      );
    }
  }
}

class _Supabase {
  _Supabase(this.api, this.url, this.key);
  final _Api api;
  final String url;
  final String key;
  Map<String, String> get headers => {
    'apikey': key,
    'Authorization': 'Bearer $key',
  };
  Uri endpoint(String path, [Map<String, String>? query]) =>
      Uri.parse('$url$path').replace(queryParameters: query);

  Future<List<Map<String, dynamic>>> select(String table, String query) async =>
      (await api.request(
        'GET',
        endpoint('/rest/v1/$table', {'select': '*', ..._parseQuery(query)}),
        headers: headers,
      ) as List<dynamic>).cast<Map<String, dynamic>>();

  Map<String, String> _parseQuery(String query) {
    final i = query.indexOf('=');
    return {query.substring(0, i): query.substring(i + 1)};
  }

  Future<int> delete(String table, String query, {required bool apply}) async {
    final rows = await select(table, query);
    if (apply && rows.isNotEmpty) {
      await api.request(
        'DELETE',
        endpoint('/rest/v1/$table', _parseQuery(query)),
        headers: {...headers, 'Prefer': 'return=minimal'},
        allowed: {200, 204},
      );
    }
    return rows.length;
  }

  Future<List<String>> storageObjects(String bucket, String prefix) async {
    final found = <String>[];
    Future<void> walk(String folder) async {
      var offset = 0;
      while (true) {
        final result = await api.request(
          'POST',
          endpoint('/storage/v1/object/list/$bucket'),
          headers: headers,
          body: {
            'prefix': folder,
            'limit': 1000,
            'offset': offset,
            'sortBy': {'column': 'name', 'order': 'asc'},
          },
        ) as List<dynamic>;
        for (final raw in result.cast<Map<String, dynamic>>()) {
          final name = raw['name'] as String?;
          if (name == null || name.isEmpty) continue;
          final path = '$folder/$name';
          if (raw['id'] == null && raw['metadata'] == null) {
            await walk(path);
          } else {
            found.add(path);
          }
        }
        if (result.length < 1000) break;
        offset += result.length;
      }
    }

    await walk(prefix);
    return found;
  }

  Future<void> deleteStorage(List<String> paths) async {
    for (var i = 0; i < paths.length; i += 100) {
      final end = (i + 100 < paths.length) ? i + 100 : paths.length;
      await api.request(
        'DELETE',
        endpoint('/storage/v1/object/accounts-pictures'),
        headers: headers,
        body: {'prefixes': paths.sublist(i, end)},
        allowed: {200, 201},
      );
    }
  }
}

Future<String> _accessToken() async {
  final result = await Process.run('gcloud', [
    'auth',
    'application-default',
    'print-access-token',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Impossible de lire les identifiants Google ADC via gcloud. Lancez `gcloud auth application-default login`.',
    );
  }
  final token = (result.stdout as String).trim();
  if (token.isEmpty) throw StateError('gcloud n’a pas renvoyé de jeton.');
  return token;
}

Future<Map<String, String>> _readEnvFile() async {
  final file = File('assets/.env');
  if (!await file.exists()) {
    throw StateError(
      'Fichier assets/.env introuvable depuis le dossier courant.',
    );
  }
  final values = <String, String>{};
  for (final rawLine in await file.readAsLines()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf('=');
    if (separator < 1) continue;
    final name = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[name] = value;
  }
  return values;
}

String? _jwtRole(String key) {
  final parts = key.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(normalized)),
    ) as Map<String, dynamic>;
    return payload['role'] as String?;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

Future<String?> _firebaseProjectFromAndroidConfig() async {
  final file = File('android/app/google-services.json');
  if (!await file.exists()) return null;
  final config = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  return (config['project_info'] as Map<String, dynamic>?)?['project_id']
      as String?;
}

Future<void> main(List<String> arguments) async {
  final args = _Args(arguments);
  if (args.help) {
    stdout.write(_usage);
    return;
  }
  var target = args.target;
  if (target == null) {
    stdout.write('UID Firebase ou email du compte de test : ');
    target = stdin.readLineSync()?.trim();
  }
  if (target == null || target.isEmpty) {
    throw const FormatException('UID ou email requis.');
  }
  final project =
      args.project ??
      Platform.environment['FIREBASE_PROJECT_ID'] ??
      await _firebaseProjectFromAndroidConfig();
  if (project == null || project.isEmpty) {
    throw StateError('Variables requises manquantes. Consultez --help.');
  }
  final dotenv = await _readEnvFile();
  final supabaseUrl =
      Platform.environment['SUPABASE_URL'] ?? dotenv['SUPABASE_URL'];
  final supabaseKey =
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      dotenv['SUPABASE_SERVICE_ROLE_KEY'] ??
      dotenv['SUPABASE_KEY'];
  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseKey == null ||
      supabaseKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL et SUPABASE_KEY sont absents de assets/.env.',
    );
  }
  if (supabaseKey.startsWith('sb_publishable_') ||
      _jwtRole(supabaseKey) == 'anon') {
    throw StateError(
      'La clé SUPABASE_KEY de assets/.env est une clé client publishable/anon. Elle ne permet pas d’effacer les données d’un autre utilisateur sous RLS. Fournis une clé admin via SUPABASE_SERVICE_ROLE_KEY dans l’environnement du terminal.',
    );
  }
  final api = _Api();
  try {
    final token = await _accessToken();
    final identityEndpoint = Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/projects/$project/accounts:lookup',
    );
    final lookup = await api.request(
      'POST',
      identityEndpoint,
      headers: {'Authorization': 'Bearer $token'},
      body: target.contains('@')
          ? {
              'email': [target],
            }
          : {
              'localId': [target],
            },
    ) as Map<String, dynamic>;
    final users = (lookup['users'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (users.length != 1) {
      throw StateError('Compte Firebase introuvable ou ambigu.');
    }
    final uid = users.single['localId'] as String;
    final supabase = _Supabase(
      api,
      supabaseUrl.replaceFirst(RegExp(r'/$'), ''),
      supabaseKey,
    );
    final firestore = _Firestore(api, project, token);

    final profileCount = await supabase.delete(
      'user_profiles',
      'user_id=eq.$uid',
      apply: false,
    );
    final accounts = await supabase.select('accounts', 'user_id=eq.$uid');
    final accountIds = accounts.map((a) => a['id'] as String).toList();
    var categories = 0;
    for (final id in accountIds) {
      categories += await supabase.delete(
        'categories',
        'account_id=eq.$id',
        apply: false,
      );
    }
    final objects = await supabase.storageObjects('accounts-pictures', uid);
    await firestore.removeUser(uid, delete: false);

    stdout.writeln('Projet Firebase : $project');
    stdout.writeln(
      'Compte cible : ${users.single['email'] ?? '(sans email)'} (UID $uid)',
    );
    stdout.writeln(
      'Supabase : $profileCount profil(s), ${accounts.length} compte(s), $categories catégorie(s)',
    );
    stdout.writeln(
      'Firestore : ${firestore.documentsFound} document(s) sous users/$uid',
    );
    stdout.writeln('Storage accounts-pictures : ${objects.length} fichier(s)');
    stdout.writeln('Firebase Auth : 1 utilisateur');
    if (!args.apply) {
      stdout.writeln(
        '\nAperçu uniquement. Relancez avec --apply pour supprimer après confirmation.',
      );
      return;
    }
    final confirmation = 'DELETE $uid FROM $project';
    stdout.write('\nPour confirmer, tapez exactement "$confirmation" : ');
    if (stdin.readLineSync()?.trim() != confirmation) {
      throw StateError('Confirmation incorrecte; aucune suppression exécutée.');
    }

    if (objects.isNotEmpty) await supabase.deleteStorage(objects);
    for (final id in accountIds) {
      await supabase.delete('categories', 'account_id=eq.$id', apply: true);
    }
    await supabase.delete('accounts', 'user_id=eq.$uid', apply: true);
    await supabase.delete('user_profiles', 'user_id=eq.$uid', apply: true);
    await firestore.removeUser(uid, delete: true);
    await api.request(
      'POST',
      identityEndpoint.replace(path: '/v1/projects/$project/accounts:delete'),
      headers: {'Authorization': 'Bearer $token'},
      body: {'localId': uid},
    );
    stdout.writeln('Nettoyage terminé.');
  } finally {
    api.close();
  }
}
