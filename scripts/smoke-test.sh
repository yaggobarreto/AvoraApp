#!/bin/bash
# Exercises every Edge Function the way the Flutter client actually calls it.
#
# This exists because a security change once added a GET-only guard to the
# TMDB proxies, and the manual checks used curl with GET. The Supabase client
# invokes functions with POST, so every call from the app started failing with
# 405 while the checks kept passing. Testing the transport the client really
# uses is the point of this script.
#
# Usage: bash scripts/smoke-test.sh
set -u

ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
BASE="${SUPABASE_URL:-http://127.0.0.1:54321}"
EMAIL="${SMOKE_EMAIL:-smoke@avora.dev}"
PASSWORD="${SMOKE_PASSWORD:-Senha12345}"

pass=0
fail=0

check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ok    %-46s %s\n' "$label" "$actual"
    pass=$((pass + 1))
  else
    printf '  FALHA %-46s esperado %s, veio %s\n' "$label" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

echo "Preparando usuario de teste..."
curl -s -X POST "$BASE/auth/v1/signup" -H "apikey: $ANON" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"data\":{\"full_name\":\"Smoke\"}}" >/dev/null
# Email confirmation is on, and local mail never leaves Mailpit.
docker exec supabase_db_avora psql -U postgres -d postgres -tAc \
  "update auth.users set email_confirmed_at = now() where email = '$EMAIL' and email_confirmed_at is null;" >/dev/null 2>&1

TOKEN=$(curl -s "$BASE/auth/v1/token?grant_type=password" -H "apikey: $ANON" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | grep -o '"access_token":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Nao foi possivel autenticar. O Supabase esta rodando?"
  exit 1
fi

post() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/functions/v1/$1" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    ${2:+-d "$2"}
}

echo
echo "Edge Functions via POST (como o app chama):"
check "tmdb-search"          200 "$(post 'tmdb-search?query=matrix')"
check "tmdb-trending"        200 "$(post 'tmdb-trending')"
check "tmdb-discover"        200 "$(post 'tmdb-discover?media_type=movie&sort_by=top_rated')"
check "tmdb-discover+genres" 200 "$(post 'tmdb-discover?genres=28,35&media_type=movie')"
check "tmdb-movie-details"   200 "$(post 'tmdb-movie-details?tmdb_id=550&media_type=movie')"
check "tmdb-recommendations" 200 "$(post 'tmdb-recommendations?tmdb_id=550&media_type=movie')"
check "cache-movie"          200 "$(post 'cache-movie' '{"tmdb_id":550,"media_type":"movie"}')"

echo
echo "Validacao de entrada continua ativa:"
check "tmdb_id com path injection" 400 "$(post 'tmdb-movie-details?tmdb_id=550/reviews')"
check "genero nao numerico"        400 "$(post 'tmdb-discover?genres=28,DROP')"
check "generos demais"             400 "$(post 'tmdb-discover?genres=1,2,3,4,5,6,7,8,9,10,11')"

echo
echo "Autenticacao obrigatoria:"
check "sem token" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/functions/v1/tmdb-trending")"

echo
echo "RPCs usadas pela Home:"
rpc() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/rest/v1/rpc/$1" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" -d "$2"
}
check "get_global_top_movies"    200 "$(rpc get_global_top_movies '{"p_limit":10}')"
check "get_my_groups_with_stats" 200 "$(rpc get_my_groups_with_stats '{}')"

echo
if [ "$fail" -eq 0 ]; then
  echo "Tudo passou ($pass verificacoes)."
else
  echo "$fail falha(s) de $((pass + fail))."
  exit 1
fi
