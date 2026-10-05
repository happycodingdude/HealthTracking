import 'package:shelf/shelf.dart';

import '../db/database.dart';
import '../http/json.dart';

/// `GET /healthz`: server sống và database trả lời (05 §6.8.2, §6.14).
Handler healthHandler(Database db) {
  return (request) async {
    final ok = await db.ping();
    return ok
        ? jsonResponse({'status': 'ok'})
        : jsonResponse({'status': 'database_unavailable'}, status: 503);
  };
}
