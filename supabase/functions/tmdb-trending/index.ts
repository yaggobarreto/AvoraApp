// Proxies TMDB's weekly trending (movies + TV) for the Home tab's
// "Lançamentos" rail. Expects: GET /tmdb-trending
import { fetchTmdb, jsonResponse, serveTmdb } from "../_shared/tmdb.ts";

serveTmdb(async (req) => {
  const data = await fetchTmdb("/trending/all/week?language=pt-BR") as {
    results?: { media_type?: string }[];
  };

  if (Array.isArray(data.results)) {
    data.results = data.results.filter(
      (item) => item.media_type === "movie" || item.media_type === "tv",
    );
  }

  return jsonResponse(req, data);
});
