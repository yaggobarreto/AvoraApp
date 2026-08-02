-- Adds series (TV show) support alongside movies. TMDB uses separate ID
-- spaces for movies and TV shows, so a bare tmdb_id isn't unique on its own
-- once both media types share this table — the unique constraint needs to
-- be on (tmdb_id, media_type) instead.

alter table movies
  add column media_type text not null default 'movie'
    check (media_type in ('movie', 'tv'));

alter table movies drop constraint movies_tmdb_id_key;
alter table movies add constraint movies_tmdb_id_media_type_key unique (tmdb_id, media_type);
