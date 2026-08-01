import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SQLSTATE raised by the database rate-limit triggers. Matches the
/// `raise_rate_limited()` helper in the rate limiting migration.
const _rateLimitedSqlState = 'AV429';

/// SQLSTATE raised by `join_group_by_invite_code` for an unknown code.
const _notFoundSqlState = 'AV404';

/// Turns a backend failure into something safe to show the user.
///
/// Raw error text can carry hostnames, table names and driver internals, so
/// anything not explicitly recognized becomes a generic message and the
/// detail goes to the log instead.
String friendlyErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == _rateLimitedSqlState || error.code == _notFoundSqlState) {
      // These messages come from our own functions and are written to be
      // read by the user ("Limite de X atingido...", "Convite inválido...").
      return error.message;
    }
    if (error.code == '23505') {
      return 'Isso já foi adicionado.';
    }
    if (error.code == '23514') {
      return 'Alguns dados estão fora do permitido. Revise e tente de novo.';
    }
    if (error.code == '42501') {
      return 'Você não tem permissão para isso.';
    }
  }

  if (error is FunctionException) {
    if (error.status == 429) {
      return 'Muitas requisições. Aguarde um pouco e tente de novo.';
    }
    if (error.status == 401) {
      return 'Sua sessão expirou. Entre novamente.';
    }
  }

  debugPrint('Unhandled backend error: $error');
  return 'Algo deu errado. Tente novamente.';
}
