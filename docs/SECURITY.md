# Auditoria de Segurança — Avora

Auditoria completa do projeto (backend, frontend, banco, autenticação, APIs,
armazenamento e infraestrutura), com as correções já aplicadas.

Cada vulnerabilidade abaixo foi **confirmada na prática** contra a instância
local em execução (com contas reais de teste), não apenas por leitura de
código. As correções foram reverificadas do mesmo jeito.

---

## Resumo executivo

| # | Vulnerabilidade | Severidade | Status |
|---|---|---|---|
| 1 | Enumeração de perfis de todos os usuários | **Alta** | ✅ Corrigido |
| 2 | Envenenamento do cache compartilhado de filmes | **Alta** | ✅ Corrigido |
| 3 | Injeção de path nas Edge Functions (uso indevido da chave TMDB) | **Alta** | ✅ Corrigido |
| 4 | Upload de SVG/arquivo arbitrário em bucket público (XSS armazenado) | **Alta** | ✅ Corrigido |
| 5 | Sem verificação de email + política de senha fraca | **Média** | ✅ Corrigido |
| 6 | CORS liberado para qualquer origem (`*`) | **Média** | ✅ Corrigido |
| 7 | Vazamento de erros internos para a interface | **Média** | ✅ Corrigido |
| 8 | Ausência de headers de segurança HTTP | **Média** | ✅ Corrigido (app) / ⚠️ pendente no host |
| 9 | Sem validação de faixa/tamanho nos dados gravados | **Média** | ✅ Corrigido |
| 10 | Logout não invalidava a sessão em outros dispositivos | **Baixa** | ✅ Corrigido |
| 11 | Sem rate limiting por usuário | **Média** | ✅ Corrigido |
| 12 | `search_path` não fixado em funções `security definer` | **Média** | ✅ Corrigido |
| 13 | MFA não habilitado | **Baixa** | ⚠️ Preparado, não ativado |
| 14 | Sem proteção anti-bot (CAPTCHA) no cadastro | **Média** | ⚙️ Implementado, aguarda chaves |

**Bug funcional encontrado junto:** registrar um filme que outro usuário já
tinha cadastrado falhava com erro de RLS. A correção da vulnerabilidade #2
resolveu isso também.

---

## 1. Enumeração de perfis — **Alta**

**Risco.** Qualquer usuário cadastrado conseguia listar o nome e a foto de
**todos** os usuários do app. O Avora promete grupos privados; um diretório
completo de usuários quebra essa promessa e facilita engenharia social.

**Onde.** `supabase/migrations/20260727000000_initial_schema.sql` — política
`"profiles are readable by anyone authenticated" ... using (true)`.

**Confirmado com.** Uma conta sem nenhum grupo em comum listou todos os perfis:

```
GET /rest/v1/profiles?select=id,name
→ [{"name":"Yago"},{"name":"Lilian"},{"name":"Estranho"}]
```

**Correção.** `supabase/migrations/20260731060000_security_hardening.sql`
substitui a política por uma que exige que você seja o próprio perfil **ou**
compartilhe algum grupo, via a função `shares_group_with()` (`security
definer`, para poder consultar `group_members` sem recursão de RLS).

**Verificado.** O estranho agora só enxerga o próprio perfil; a Lilian, que
está no mesmo grupo do Yago, enxerga os dois.

---

## 2. Envenenamento do cache de filmes — **Alta**

**Risco.** A política de INSERT em `movies` era `with check (true)`: qualquer
usuário autenticado podia gravar linhas arbitrárias numa tabela que **todos**
leem — títulos falsos, sinopses maliciosas e URLs de imagem apontando para
qualquer servidor (o que também vaza o IP de quem visualiza).

**Onde.** Política `"authenticated users can cache movie metadata"` +
`lib/features/movies/data/watch_entries_repository.dart` (upsert direto).

**Confirmado com.**
```
POST /rest/v1/movies {"tmdb_id":999999,"title":"<script>alert(1)</script>"}
→ 201 Created
```

**Correção.** A escrita saiu do cliente. A nova Edge Function
`supabase/functions/cache-movie/index.ts` busca os dados **autoritativos** na
TMDB e grava com a service role; o cliente só informa `tmdb_id` e
`media_type`. INSERT/UPDATE/DELETE em `movies` foram revogados de
`authenticated`.

**Verificado.** A escrita direta agora retorna `permission denied`, e a
função de cache funciona e é idempotente (duas chamadas devolvem a mesma
linha) — o que também corrige o bug de recadastro.

> Observação: o Flutter renderiza texto com `Text()`, que não interpreta HTML,
> então isso não era XSS executável no app. O risco real era integridade dos
> dados e requisições a servidores de terceiros.

---

## 3. Injeção de path nas Edge Functions — **Alta**

**Risco.** O parâmetro `tmdb_id` era interpolado direto no caminho da URL da
TMDB sem validação, permitindo alcançar **qualquer endpoint da TMDB** usando
a nossa chave de API — incluindo consumir a cota até o bloqueio.

**Onde.** `tmdb-movie-details/index.ts` e `tmdb-recommendations/index.ts`:
`` `${TMDB_BASE_URL}/${mediaType}/${tmdbId}?...` ``

**Confirmado com.**
```
GET /functions/v1/tmdb-movie-details?tmdb_id=550/reviews
→ 200 com o conteúdo de /movie/550/reviews (endpoint não pretendido)
```

**Correção.** `supabase/functions/_shared/tmdb.ts` agora centraliza a
validação: `parseTmdbId()` aceita **apenas** dígitos (`/^\d{1,12}$/`) e
rejeita o resto, em vez de tentar sanitizar. A busca também passou a limitar
o tamanho da query (120 caracteres).

**Verificado.** `tmdb_id=550/reviews` → `400 Invalid 'tmdb_id' parameter`.

---

## 4. Upload de arquivo arbitrário em bucket público — **Alta**

**Risco.** A extensão vinha do nome do arquivo escolhido pelo usuário e era
usada para montar o `Content-Type`. Um `.svg` seria servido como imagem a
partir de um bucket **público** — e SVG aceita `<script>` embutido, o que dá
XSS armazenado no domínio do storage.

**Onde.** `profile_repository.dart` e `groups_repository.dart`:
`contentType: 'image/$extension'` com extensão não validada.

**Correção.** `lib/core/storage/image_upload.dart`:
- allowlist de extensões (`png`, `jpeg`, `jpg`, `webp`) — SVG explicitamente fora;
- verificação dos **magic bytes**, para que renomear `payload.html` para
  `.png` não passe;
- limite de 5 MB.

**Verificado.** 9 testes automatizados em `test/security_test.dart`.

---

## 5. Verificação de email e política de senha — **Média**

**Antes.** `enable_confirmations = false` (qualquer email, mesmo de terceiros,
criava conta ativa), `minimum_password_length = 6`, sem requisitos de
complexidade.

**Correção** (`supabase/config.toml`):
- `enable_confirmations = true` — confirmação de email obrigatória;
- `minimum_password_length = 8` e `password_requirements = "lower_upper_letters_digits"`;
- `secure_password_change = true` — exige reautenticação para trocar a senha;
- validação equivalente no cliente (`login_screen.dart`) para dar retorno imediato.

**Verificado.** `{"password":"123456"}` → `422 weak_password` no servidor.

> A validação do cliente **não** substitui a do servidor — ela existe só para
> a experiência de uso. A regra que vale é a do Supabase.

---

## 6. CORS liberado (`*`) — **Média**

**Risco.** `Access-Control-Allow-Origin: *` permitia que qualquer site
chamasse nossas funções pelo navegador de um usuário logado, gastando a cota
da TMDB.

**Correção.** `supabase/functions/_shared/cors.ts` passou a refletir apenas
origens de uma allowlist (`ALLOWED_ORIGINS`), com `Vary: Origin`.

> **Ação necessária em produção:** definir `ALLOWED_ORIGINS` com o domínio
> real. O padrão atual cobre só o desenvolvimento local.

---

## 7. Vazamento de erros internos — **Média**

**Risco.** Mensagens como `Erro: $e` e `Não deu certo: $error` iam direto
para a tela, podendo expor hostnames, detalhes do driver e stack traces.

**Correção.**
- `AuthRepository` traduz erros para mensagens seguras (`AuthFailure`) e
  registra o resto no log;
- login inválido e email inexistente devolvem **a mesma** mensagem, para não
  permitir descobrir quais contas existem;
- as Edge Functions nunca repassam o corpo de erro da TMDB;
- os `catch` nas telas de perfil/grupo agora usam `debugPrint` + mensagem genérica.

---

## 8. Headers de segurança HTTP — **Média**

**Correção aplicada** em `web/index.html`: Content-Security-Policy (com
`frame-ancestors 'none'`, `object-src 'none'`, `base-uri 'self'`),
`X-Content-Type-Options: nosniff` e `Referrer-Policy`.

> **Cuidado ao apertar essa CSP.** A primeira versão que escrevi travou o app
> na splash screen, sem erro visível. O Flutter Web em release baixa o
> **CanvasKit** de `https://www.gstatic.com/flutter-canvaskit/<engine>/` e a
> fonte **Roboto** de `https://fonts.gstatic.com`. Bloquear qualquer um dos
> dois impede o engine de inicializar — e como isso acontece antes do app
> rodar, não aparece exceção nenhuma no console, só a splash eterna.
>
> Por isso a CSP libera `www.gstatic.com` em `script-src`/`connect-src` e
> `fonts.gstatic.com` em `font-src`/`connect-src`.
>
> Para produção, o ideal é compilar com `flutter build web --no-web-resources-cdn`:
> o CanvasKit passa a ser servido da nossa própria origem e aí dá para
> remover `www.gstatic.com` da CSP, deixando-a mais fechada.

> **⚠️ Ação necessária em produção.** Alguns headers **só funcionam via HTTP**
> e precisam ser configurados em quem serve os arquivos (Nginx, Vercel,
> Firebase Hosting...):
> ```
> Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
> X-Frame-Options: DENY
> Permissions-Policy: geolocation=(), microphone=(), camera=()
> ```

---

## 9. Validação de dados no banco — **Média**

Não havia limite de tamanho nem de faixa. Um cliente modificado podia gravar
notas fora de 0–5 (distorcendo todos os rankings), datas no futuro
(corrompendo a timeline) e textos de megabytes que todo membro do grupo
depois baixaria.

**Correção.** `CHECK` constraints em `20260731060000_security_hardening.sql`:
nome de grupo (1–60), nome de perfil (1–80), comentário (≤2000), emojis (≤10),
nota (0–5), vezes assistido (1–1000) e `watched_at` não pode ser futuro.

**Verificado.** Nota 6, comentário de 5000 caracteres e nome de grupo de 500
caracteres são todos rejeitados; um registro válido continua funcionando.

---

## 10. Logout global — **Baixa**

`signOut()` encerrava só a sessão local. Agora usa `SignOutScope.global`,
invalidando os refresh tokens em todos os dispositivos — importante em caso
de aparelho perdido.

---

## 11. Rate limiting por usuário — **Média**

**Risco.** O Supabase limita os endpoints de autenticação por IP, mas nada
impedia um usuário **já autenticado** de criar conteúdo em loop: inundar a
timeline de um grupo, encher a watchlist, criar grupos em massa ou torrar a
cota da TMDB. RLS responde "você pode?", não "com que frequência?".

**Correção** (`supabase/migrations/20260731070000_rate_limiting.sql`).

Duas estratégias, escolhidas conforme o que existe para contar:

*Conteúdo* — triggers `BEFORE INSERT` contam as linhas recentes do próprio
usuário na mesma tabela. Não há tabela de contadores para manter em sincronia,
e apagar uma linha devolve a cota corretamente:

| Ação | Limite |
|---|---|
| Registrar filme/série | 60 / hora |
| Adicionar à watchlist | 100 / hora |
| Agendar sessão | 30 / hora |
| Criar grupo | 10 / hora |
| Entrar em grupo | 20 / hora |

O limite de entrada em grupos importa mais do que parece: o código de convite
tem só 8 caracteres hexadecimais, e tentativas ilimitadas tornariam viável
adivinhar um.

*Edge Functions* — não existe uma tabela natural de "chamadas", então essa
parte é explícita: `rate_limit_events` + a função `consume_rate_limit()`,
ambas acessíveis **apenas** pela service role (sem policy para
`authenticated`). Os quatro proxies da TMDB dividem um orçamento de 300/hora
(o que se protege é a cota da TMDB, não um endpoint específico) e o
`cache-movie` tem 120/hora por gravar uma linha a cada chamada.

O verificador **falha fechado**: se a consulta der erro, a chamada é negada.
Um rate limiter que para de limitar quando o banco oscila é o mesmo que não
ter nenhum.

Erros de limite usam o SQLSTATE próprio `AV429`, para o app distinguir
throttling de erro de permissão (`lib/core/network/app_errors.dart`).

**Verificado.** A 11ª criação de grupo é bloqueada com a mensagem correta; a
301ª chamada à TMDB devolve `429`; `rate_limit_events` é invisível para o
cliente (`permission denied`); e `consume_rate_limit` corta exatamente no
limite configurado.

---

## 12. `search_path` em funções `security definer` — **Média**

**Risco.** Nenhuma das funções `security definer` fixava `search_path`. Uma
role capaz de criar objetos em um schema anterior na busca poderia sombrear
as tabelas referenciadas e fazer a função rodar contra as tabelas dela — com
privilégios elevados.

**Correção.** Todas as funções passaram a declarar `set search_path`.
Verificado por consulta ao catálogo: **0** funções `security definer` sem
`proconfig`.

Aproveitando, `join_group_by_invite_code` foi reescrita: um convite inválido
levantava `'Invalid invite code'` com o P0001 genérico, indistinguível de
qualquer outro erro, então o app só conseguia mostrar uma falha genérica.
Agora usa o código `AV404` e uma mensagem em português.

---

## Itens verificados e já corretos

- **SQL Injection.** Não há concatenação de SQL em lugar nenhum. Todo acesso
  passa por PostgREST (parametrizado) ou funções plpgsql com parâmetros
  tipados. As funções `security definer` recebem argumentos tipados e não
  montam SQL dinâmico.
- **Autorização / IDOR.** RLS em todas as tabelas, ancorada em
  `is_group_member()`. Confirmado: um usuário de fora não lê `watch_entries`
  de um grupo alheio (`[]`, não erro).
- **Senhas.** Nunca tocadas pela aplicação — o Supabase Auth armazena com
  bcrypt. Não há hash caseiro nem senha em texto puro.
- **Segredos.** `.gitignore` cobre `.env`, `.env.*` e `supabase/.env*`.
  Confirmado que nenhum arquivo de segredo está versionado. A chave da TMDB
  vive apenas no servidor (Edge Functions) e nunca é enviada ao app.
- **Chave anon exposta no cliente.** Correto e esperado — é uma chave
  pública; a segurança real vem da RLS.
- **CSRF.** Não se aplica: a autenticação usa `Authorization: Bearer` (não
  cookies), então não há envio automático de credencial entre sites.
- **Sessão.** Persistida e renovada pelo `supabase_flutter`. Com os timeouts
  agora ativos (`timebox = 720h`, `inactivity_timeout = 336h`).
- **Consultas N+1.** Os contadores da lista de grupos foram feitos em uma
  única chamada (`get_my_groups_with_stats`) em vez de uma consulta por card.
- **Dependências.** `flutter pub outdated` não aponta pacotes com
  vulnerabilidade conhecida; nenhuma dependência sem uso.

---

## Pendências antes de publicar

Estas **não** foram implementadas e exigem decisão ou infraestrutura:

1. **CAPTCHA no cadastro (Média).** O código está **pronto dos dois lados** —
   falta apenas colar as chaves reais. Veja "Como ligar o CAPTCHA" abaixo.
2. **Headers no servidor (Média).** HSTS, X-Frame-Options e Permissions-Policy
   (ver item 8).
3. **`ALLOWED_ORIGINS` em produção (Média).** Ver item 6.
4. **MFA (Baixa).** `[auth.mfa.totp]` está pronto, com `enroll_enabled = false`.
   Ativar quando houver tela de gerenciamento.
5. **Google/Apple OAuth (Média).** O código está implementado, mas exige
   credenciais OAuth reais no painel do Supabase; no mobile precisa também de
   deep link registrado.
6. **Monitoramento e logs (Média).** Não há agregação de logs nem alertas.
   Nada sensível é logado hoje (sem senhas, tokens ou JWT), mas não há como
   detectar um ataque em andamento.
7. **Segurança mobile (Baixa).** Sem detecção de root/jailbreak nem
   ofuscação. Usar `flutter build --obfuscate --split-debug-info` no release.

---

## Como ligar o CAPTCHA

O widget (Cloudflare Turnstile) já está implementado e integrado à tela de
cadastro. Ele fica **inteiramente desligado** enquanto não houver site key, e
nesse estado o app funciona normalmente — foi assim que ficou entregue.

### As duas chaves

O Turnstile gera um par, e cada uma vai num lugar diferente:

| Chave | Onde vai | Segredo? |
|---|---|---|
| **Site key** | No app, via `--dart-define` | Não — ela aparece na página |
| **Secret key** | No Supabase, que valida o token | **Sim** — nunca no código |

Pegue as duas em `dash.cloudflare.com` → Turnstile → *Add site*. É gratuito e
não exige que o domínio esteja na Cloudflare.

### Passo a passo

1. **Secret key** — coloque em `supabase/.env` (já está no `.gitignore`):
   ```
   SUPABASE_AUTH_CAPTCHA_SECRET=0x4AAAAAAA...
   ```
2. Descomente o bloco `[auth.captcha]` em `supabase/config.toml` e reinicie
   (`supabase stop && supabase start`).
3. **Site key** — passe na compilação:
   ```
   flutter build web --dart-define=TURNSTILE_SITE_KEY=0x4AAAAAAA...
   ```

> **Ligue os dois juntos.** Só o servidor → todo cadastro é rejeitado
> (`captcha_failed`). Só o app → o widget aparece mas não protege nada.

### Testando sem conta no provedor

A Cloudflare publica chaves de teste que sempre passam. Usei-as para validar
o lado do servidor:

- site key: `1x00000000000000000000AA`
- secret:   `1x0000000000000000000000000000000AA`

Com elas, o cadastro **sem** token foi rejeitado com
`captcha protection: request disallowed (no captcha_token found)` e **com** o
token de teste foi aceito — ou seja, a validação server-side funciona.

> Depois do teste, revertí `config.toml` ao estado desabilitado. Não deixe o
> secret de teste em produção: ele aceita **qualquer** token.

### Comportamento fora da web

O Turnstile é um widget de navegador. No mobile, `turnstileSupported` é
`false` e o app não exibe nem exige o desafio — então **não ligue o CAPTCHA
no servidor enquanto houver build mobile em uso**, senão o cadastro pelo
celular passa a ser rejeitado. Cobrir mobile exige um desafio via webview,
que ainda não foi feito.

---

## Veredito

Todas as falhas exploráveis encontradas foram corrigidas e reverificadas
contra a instância em execução — incluindo as que expunham dados de usuários,
permitiam abusar da nossa chave da TMDB ou deixavam qualquer usuário
autenticado gerar carga ilimitada.

Para abrir cadastro público falta apenas **colar as chaves do CAPTCHA** — o
código dos dois lados está pronto e a validação server-side foi testada com
as chaves de teste da Cloudflare (ver "Como ligar o CAPTCHA").

Os itens 2 e 3 (headers no servidor e `ALLOWED_ORIGINS`) são configuração de
deploy e devem ser feitos no momento da publicação — não exigem mudança de
código.

Para uso fechado (só você e pessoas convidadas), o app já está em condição
segura de rodar hoje.
