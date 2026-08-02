// Caches a title's TMDB metadata into the `movies` table.
//
// The client used to upsert into `movies` directly, which meant any
// authenticated user could write arbitrary rows into a table everyone reads
// (cache poisoning), and re-caching a title someone else had already saved
// failed RLS because there was no UPDATE policy. Doing the write here, from
// authoritative TMDB data under the service role, closes both.
//
// Expects: POST /cache-movie  { "tmdb_id": 157336, "media_type": "movie" }
import { corsHeadersFor } from "../_shared/cors.ts";
import { adminClient, userIdFrom, withinRateLimit } from "../_shared/rate_limit.ts";
import { fetchTmdb, parseMediaType, parseTmdbId } from "../_shared/tmdb.ts";

const IMAGE_BASE = "https://image.tmdb.org/t/p";

function json(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeadersFor(req), "Content-Type": "application/json" },
  });
}

type TmdbPayload = Record<string, any>;

function toMovieRow(data: TmdbPayload, mediaType: "movie" | "tv") {
  const isTv = mediaType === "tv";
  const date = (isTv ? data.first_air_date : data.release_date) as string | null;

  let director: string | null = null;
  if (isTv) {
    const creators = (data.created_by ?? []) as TmdbPayload[];
    director = creators.length > 0
      ? creators.map((c) => c.name).join(", ")
      : null;
  } else {
    const crew = (data.credits?.crew ?? []) as TmdbPayload[];
    director = crew.find((member) => member.job === "Director")?.name ?? null;
  }

  const videos = (data.videos?.results ?? []) as TmdbPayload[];
  const trailerKey = videos.find(
    (video) => video.type === "Trailer" && video.site === "YouTube",
  )?.key;

  const runtime = isTv
    ? (data.episode_run_time ?? [])[0] ?? null
    : data.runtime ?? null;

  return {
    tmdb_id: data.id,
    media_type: mediaType,
    title: (isTv ? data.name : data.title) ?? "Sem título",
    year: date ? Number(date.slice(0, 4)) || null : null,
    poster_url: data.poster_path ? `${IMAGE_BASE}/w500${data.poster_path}` : null,
    backdrop_url: data.backdrop_path
      ? `${IMAGE_BASE}/w780${data.backdrop_path}`
      : null,
    synopsis: data.overview || null,
    runtime_minutes: runtime,
    genres: ((data.genres ?? []) as TmdbPayload[]).map((g) => g.name),
    director,
    trailer_url: trailerKey ? `https://www.youtube.com/watch?v=${trailerKey}` : null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(req) });
  }
  if (req.method !== "POST") {
    return json(req, { error: "Method not allowed" }, 405);
  }

  // The platform already rejects requests without a valid JWT, but the row is
  // only written on behalf of a real user, so confirm one is present.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json(req, { error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json().catch(() => null);
    if (body === null || typeof body !== "object") {
      return json(req, { error: "Invalid JSON body" }, 400);
    }

    const tmdbId = parseTmdbId(String((body as TmdbPayload).tmdb_id ?? ""));
    const mediaType = parseMediaType((body as TmdbPayload).media_type ?? null);
    if (tmdbId === null) {
      return json(req, { error: "Invalid 'tmdb_id'" }, 400);
    }

    const userId = await userIdFrom(authHeader);
    if (userId === null) {
      return json(req, { error: "Unauthorized" }, 401);
    }

    const admin = adminClient();
    // Tighter than the read-only proxies: this one writes a row every call.
    const allowed = await withinRateLimit(admin, userId, "cache-movie", 120, 3600);
    if (!allowed) {
      return json(req, { error: "Too many requests. Slow down." }, 429);
    }

    const details = await fetchTmdb(
      `/${mediaType}/${tmdbId}?language=pt-BR&append_to_response=credits,videos`,
    ) as TmdbPayload;

    const { data, error } = await admin
      .from("movies")
      .upsert(toMovieRow(details, mediaType), { onConflict: "tmdb_id,media_type" })
      .select()
      .single();

    if (error) {
      console.error("Failed to cache movie:", error);
      return json(req, { error: "Could not cache title" }, 500);
    }

    return json(req, data);
  } catch (error) {
    console.error("Unhandled cache-movie error:", error);
    return json(req, { error: "Something went wrong" }, 502);
  }
});
