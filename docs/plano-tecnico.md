# Plano Técnico — App de Histórico e Avaliação de Filmes

## Contexto

O usuário quer construir um app mobile (Android/iOS) para casais/amigos/famílias registrarem filmes assistidos em grupo, com foco emocional/nostálgico ("Memórias") como diferencial frente a Letterboxd/IMDb. A especificação original cobre um escopo muito grande (grupos, TMDB, timeline, estatísticas, wishlist, ranking, notificações, gamificação, premium, integrações externas). O diretório do projeto está vazio — greenfield.

Decisões já alinhadas com o usuário:
- Plano deve definir um **MVP enxuto** + roadmap para o resto (não detalhar tudo de uma vez).
- Usuário está aberto a **simplificar a stack sugerida** (Flutter/FastAPI/Postgres/Redis/Firebase/AWS) se houver opção mais simples para começar.
- Depois do plano aprovado, o próximo passo nesta mesma conversa é **fazer o scaffolding do projeto**.

## Mudança de stack recomendada

Stack original exigia gerenciar 5 sistemas separados (FastAPI custom, PostgreSQL, Redis, Firebase Auth, AWS) para um app que é, na essência, CRUD + realtime + auth social + storage de imagens. Recomendo consolidar em **Supabase** para o MVP:

| Necessidade | Original | Recomendado (MVP) |
|---|---|---|
| Frontend | Flutter | Flutter (mantido) |
| Auth (Google/Apple/Email) | Firebase Auth | **Supabase Auth** (suporta os 3 nativamente) |
| Banco | PostgreSQL próprio | **Supabase Postgres** (é Postgres gerenciado) |
| Backend custom | FastAPI | **Supabase Edge Functions** (só onde precisa esconder a TMDB API key ou rodar lógica server-side) |
| Cache | Redis | Nenhum no MVP (Postgres + cache local no app resolvem; Redis entra depois se houver gargalo real) |
| Storage | S3/Supabase Storage | **Supabase Storage** (mantido) |
| Push | FCM | **FCM** (mantido — Supabase não faz push) |
| Hospedagem | AWS | Supabase Cloud (tudo incluso); sem servidor próprio para gerenciar |

Por quê: elimina 3 sistemas (FastAPI, Redis, AWS) sem perder nenhuma funcionalidade do MVP, reduz custo/complexidade operacional para um app inicial, e dá Row Level Security nativo — essencial já que "grupos privados" é requisito central (RLS garante isolamento de dados por grupo direto no banco). FastAPI/Redis/AWS voltam a ser reavaliados só se houver necessidade real de lógica pesada de backend ou escala que o Supabase não atenda.

## Escopo do MVP (Fase 1)

- Auth: Google, Apple, Email (Supabase Auth)
- Criar/entrar em grupos (convite por código/link), listar membros
- Cadastrar filme: busca TMDB → seleção → salva metadata localmente (evita rechamar API)
- Registrar sessão de filme assistido: onde assistiu, data, nº de vezes, nota (estrelas 1-5), comentário, emoji, "assistido com" (membros do grupo)
- Timeline/Histórico cronológico por grupo, agrupado por ano
- Página do filme: poster, sinopse, trailer, avaliações do grupo, comentários, quem assistiu, datas
- Perfil de usuário básico (nome, foto, total de filmes/horas)
- Perfil de grupo básico (nome, foto, nº membros, nº filmes)

## Fora do MVP (roadmap resumido)

**Fase 2** (curto prazo): estatísticas avançadas (gênero/diretor/ator favorito, streamer mais usado, etc.), wishlist "Quero assistir", ranking top 10, busca/filtros avançados, notificações push (novo filme/comentário/avaliação/membro).

**Fase 3** (diferencial/futuro): seção "Memórias" (aniversários de "assistiram há X anos"), gamificação/badges, recursos premium (backup, temas, export PDF/Excel, widgets, integração IMDb/Letterboxd).

## Modelo de dados (MVP)

Tabelas Postgres (via Supabase), RLS por `group_id`/membership:

- `profiles` (id = auth.uid(), name, avatar_url, created_at)
- `groups` (id, name, photo_url, created_by, created_at)
- `group_members` (group_id, user_id, role, joined_at)
- `movies` (id, tmdb_id unique, title, year, poster_url, backdrop_url, synopsis, runtime_minutes, genres text[], director, trailer_url, cached_at) — cache do TMDB para evitar rate limit e permitir joins
- `watch_entries` (id, group_id, movie_id, logged_by, watched_at date, watch_location enum, times_watched int, rating numeric(2,1), comment text, emojis text[], created_at)
- `watch_entry_participants` (watch_entry_id, user_id) — "assistido com"

## Integração TMDB

Duas Edge Functions (`tmdb-search`, `tmdb-movie-details`) fazem proxy para a TMDB API — mantém a API key no servidor (nunca no app) e permite cachear respostas. O Flutter app nunca chama a TMDB diretamente.

## Scaffolding inicial (próximo passo, após aprovação)

1. `flutter create` com estrutura feature-first: `lib/features/{auth,groups,movies,timeline,profile}`, `lib/core/{network,widgets,theme}`
2. Dependências: `supabase_flutter`, `google_sign_in`, `sign_in_with_apple`, `firebase_messaging` (só para push), roteamento (`go_router`)
3. Projeto Supabase local via CLI: `supabase/migrations/` com o schema acima + políticas RLS; `supabase/functions/` com as 2 Edge Functions de TMDB
4. Telas iniciais: Login → Lista/criação de grupo → Busca+registro de filme → Timeline

Observação: criar o projeto Supabase na nuvem (conta, chaves de produção) exige o usuário ter/criar uma conta no dashboard da Supabase — isso não pode ser feito por mim automaticamente. Vou deixar tudo pronto localmente (CLI + migrations) para rodar via `supabase start` (ambiente local) e o usuário conectar a um projeto cloud quando quiser publicar.

## Verificação

- `flutter analyze` e `flutter test` (widget tests básicos das telas iniciais) devem passar
- `supabase db reset` deve aplicar as migrations sem erro
- Rodar o app localmente (emulador Android/iOS) e validar fluxo: login → criar grupo → buscar filme na TMDB → registrar avaliação → ver na timeline
