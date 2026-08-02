// Discovers titles by genre and popularity — the cold-start source for the
// Home tab.
//
// "Top Filmes do Avora" is built from our own users' ratings, so on a fresh
// install it is empty, and recommendations are seeded from titles the user
// already rated, which on the first session is nothing. This backs both with
// TMDB data so the Home is never blank.
//
// Expects: GET /tmdb-discover?genres=28,35&media_type=movie&sort_by=popular
import {
  errorResponse,
  fetchTmdb,
  jsonResponse,
  parseMediaType,
  serveTmdb,
} from "../_shared/tmdb.ts";

const MAX_GENRES = 10;

/// Genre ids are interpolated into the TMDB query, so accept only digits and
/// cap how many can be passed.
function parseGenres(raw: string | null): string[] | null {
  if (raw === null || raw.trim() === "") return [];
  const parts = raw.split(",").map((part) => part.trim());
  if (parts.length > MAX_GENRES) return null;
  if (!parts.every((part) => /^\d{1,6}$/.test(part))) return null;
  return parts;
}

serveTmdb(async (req) => {
  const url = new URL(req.url);
  const mediaType = parseMediaType(url.searchParams.get("media_type"));
  const genres = parseGenres(url.searchParams.get("genres"));

  if (genres === null) {
    return errorResponse(req, "Invalid 'genres' parameter", 400);
  }

  // "top_rated" leans on TMDB's own vote average with a sane vote floor, so
  // an obscure title with three perfect scores can't top the list.
  const sortBy = url.searchParams.get("sort_by") === "top_rated"
    ? "vote_average.desc"
    : "popularity.desc";
  const voteFloor = sortBy === "vote_average.desc" ? "&vote_count.gte=500" : "";

  const genreFilter = genres.length > 0
    ? `&with_genres=${genres.join("|")}`
    : "";

  const data = await fetchTmdb(
    `/discover/${mediaType}?language=pt-BR&include_adult=false` +
      `&sort_by=${sortBy}${voteFloor}${genreFilter}`,
  ) as { results?: Record<string, unknown>[] };

  // /discover doesn't tag results with media_type the way /search/multi does.
  if (Array.isArray(data.results)) {
    data.results = data.results.map((item) => ({ ...item, media_type: mediaType }));
  }

  return jsonResponse(req, data);
});
