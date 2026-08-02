// Proxies TMDB movie/TV details + credits + videos + watch providers in one
// call. Used both to populate the `movies` cache table when a title is first
// selected, and to render the full detail page (streaming availability goes
// stale, so that page always calls this fresh instead of relying on the cache).
// Expects: GET /tmdb-movie-details?tmdb_id=157336&media_type=movie
import {
  errorResponse,
  fetchTmdb,
  jsonResponse,
  parseMediaType,
  parseTmdbId,
  serveTmdb,
} from "../_shared/tmdb.ts";

serveTmdb(async (req) => {
  const url = new URL(req.url);
  const tmdbId = parseTmdbId(url.searchParams.get("tmdb_id"));
  const mediaType = parseMediaType(url.searchParams.get("media_type"));

  if (tmdbId === null) {
    return errorResponse(req, "Invalid 'tmdb_id' parameter", 400);
  }

  const data = await fetchTmdb(
    `/${mediaType}/${tmdbId}?language=pt-BR` +
      `&append_to_response=credits,videos,watch/providers`,
  ) as Record<string, unknown>;

  return jsonResponse(req, { ...data, media_type: mediaType });
});
