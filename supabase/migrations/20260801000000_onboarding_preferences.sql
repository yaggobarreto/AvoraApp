-- Taste preferences collected during onboarding.
--
-- Without these, a brand-new user has nothing to recommend from: the Home's
-- recommendation rail is seeded from titles they already rated, which on the
-- first session is an empty set. Asking a couple of questions up front gives
-- the app something to work with immediately.

alter table profiles
  add column preferred_genres integer[] not null default '{}',
  add column content_preference text not null default 'both',
  add column onboarded_at timestamptz;

-- Genre ids come from TMDB and go straight into a discover query, so bound
-- both the count and the values rather than trusting the client.
alter table profiles add constraint profiles_preferred_genres_bounded
  check (array_length(preferred_genres, 1) is null or array_length(preferred_genres, 1) <= 10);

alter table profiles add constraint profiles_content_preference_valid
  check (content_preference in ('movie', 'tv', 'both'));
