# Avora

App mobile para casais/amigos/famílias registrarem, em grupo, os filmes que assistiram — com timeline, avaliações e (futuramente) a seção "Memórias". Veja o plano técnico completo em `docs/plano-tecnico.md` (ou no histórico da conversa que gerou este projeto).

## Stack

- **App**: Flutter (`lib/`, estrutura feature-first em `lib/features/{auth,groups,movies,timeline,profile}`), pacote Dart `avora`, bundle id `com.avora.app`
- **Backend**: Supabase (Postgres + Auth + Storage + Edge Functions) — schema em `supabase/migrations/`, proxy do TMDB em `supabase/functions/`
- **Identidade visual**: logo/ícone/splash em `assets/branding/` (gerados a partir de `avora_icon.png` via `flutter_launcher_icons` e `flutter_native_splash` — veja a config no final do `pubspec.yaml`). Para regenerar após trocar a arte, rode `dart run flutter_launcher_icons` e `dart run flutter_native_splash:create`.

## Pré-requisitos já instalados nesta máquina

- Flutter SDK em `C:\src\flutter` (branch stable) — já no PATH do usuário
- Supabase CLI (via npm)

## Pendências para rodar o app de verdade

1. **Docker Desktop** — necessário para `supabase start` (roda Postgres/Auth/Storage local). Não foi instalado automaticamente.
2. **TMDB API Key** — crie uma conta gratuita em https://www.themoviedb.org/settings/api e, depois de rodar `supabase start`, configure com:
   ```bash
   supabase secrets set TMDB_API_KEY=sua_chave_aqui
   ```
3. **Android Studio / Android SDK** — necessário só para rodar em emulador/dispositivo Android. `flutter doctor` está reportando que falta. iOS exige um Mac com Xcode (não é possível neste Windows).
4. **Projeto Supabase na nuvem** (quando for publicar) — criar em https://supabase.com/dashboard e trocar as credenciais locais por `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## Rodando localmente

```bash
# 1. Subir o backend local (exige Docker rodando)
supabase start

# 2. Aplicar as migrations
supabase db reset

# 3. Rodar as Edge Functions localmente (outro terminal)
supabase functions serve --env-file supabase/.env.local

# 4. Rodar o app (web funciona sem Android SDK; ótimo para desenvolvimento rápido)
flutter run -d chrome
```

## Estado atual (scaffold)

- Login/cadastro por email (Supabase Auth) funcionando; Google/Apple ainda não configurados (precisam de OAuth client IDs no dashboard do Supabase)
- Criar grupo / entrar em grupo por código de convite
- Buscar filme via TMDB, registrar sessão assistida (onde, quando, quantas vezes, nota, comentário, emoji, com quem)
- Timeline por grupo, agrupada por ano
- Perfil básico com contagem de filmes

Fora do escopo desta primeira versão (ver plano técnico): estatísticas avançadas, wishlist, ranking, notificações, seção "Memórias", gamificação, recursos premium.
