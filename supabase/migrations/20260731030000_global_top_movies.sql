-- "Top Filmes do Avora" on the Home tab is global — every user's ratings
-- count, not just your own groups. This intentionally bypasses the
-- group-membership RLS on watch_entries (via security definer) but only
-- ever returns aggregates (title, count, average, weighted score) — never
-- group_id, user identity, or comments, so individual reviews stay private
-- even though the aggregate score is public across the whole app.

create function get_global_top_movies(p_limit int default 10)
returns table (
  movie_id uuid,
  tmdb_id integer,
  title text,
  poster_url text,
  backdrop_url text,
  media_type text,
  entry_count bigint,
  avg_rating numeric,
  weighted_score numeric
)
language plpgsql
security definer
stable
as $$
declare
  v_global_avg numeric;
  v_min_votes constant int := 3;
begin
  select coalesce(avg(rating), 3.5) into v_global_avg
  from watch_entries
  where rating is not null;

  return query
  with per_movie as (
    select
      we.movie_id as pm_movie_id,
      count(*) as pm_entry_count,
      avg(we.rating) as pm_avg_rating,
      sum(we.rating * exp(-extract(epoch from (now() - we.watched_at::timestamptz)) / 86400.0 / 365.0))
        / nullif(sum(exp(-extract(epoch from (now() - we.watched_at::timestamptz)) / 86400.0 / 365.0)), 0)
        as pm_recency_weighted_avg
    from watch_entries we
    where we.rating is not null
    group by we.movie_id
  )
  select
    m.id,
    m.tmdb_id,
    m.title,
    m.poster_url,
    m.backdrop_url,
    m.media_type,
    pm.pm_entry_count,
    round(pm.pm_avg_rating, 2),
    round(
      (pm.pm_entry_count::numeric / (pm.pm_entry_count + v_min_votes))
        * coalesce(pm.pm_recency_weighted_avg, pm.pm_avg_rating)
      + (v_min_votes::numeric / (pm.pm_entry_count + v_min_votes)) * v_global_avg,
      2
    ) as weighted_score
  from per_movie pm
  join movies m on m.id = pm.pm_movie_id
  order by weighted_score desc
  limit p_limit;
end;
$$;

grant execute on function get_global_top_movies(int) to authenticated;
