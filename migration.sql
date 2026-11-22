-- ============================================================================
-- FLIXORA MOVIE ID FINDER — COMPLETE SUPABASE MIGRATION & SYNCHRONIZATION SCRIPT
-- Project URL: https://comxecntwlntgvjbvkjs.supabase.co
-- Super Admin UID: 540e9d75-3e05-48c9-bb5c-5dac0db4c3f0 (dj4550797@gmail.com)
-- 
-- Safe & Idempotent: Can be run multiple times without data loss or duplicate errors.
-- Run this script in: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. REUSE & ENHANCE EXISTING TABLES
-- ----------------------------------------------------------------------------

-- A. movies table (Reuse existing table, safely add columns if needed)
CREATE TABLE IF NOT EXISTS public.movies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  title text NOT NULL,
  overview text DEFAULT '',
  poster_path text DEFAULT '',
  backdrop_path text DEFAULT '',
  release_date text DEFAULT '',
  rating numeric(3,1) DEFAULT 0,
  tmdb_id integer,
  media_type text DEFAULT 'movie'
);

-- Safely add any missing columns to existing movies table
DO $$ BEGIN
  ALTER TABLE public.movies ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'published';
  ALTER TABLE public.movies ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
  ALTER TABLE public.movies ADD COLUMN IF NOT EXISTS display_order integer NOT NULL DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- B. site_settings table (Reuse existing key-value table)
CREATE TABLE IF NOT EXISTS public.site_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- C. audit_logs table (Reuse existing table)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  action text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb
);

-- ----------------------------------------------------------------------------
-- 2. CREATE FLIXORA ADMIN & CONTENT SYNCHRONIZATION TABLES
-- ----------------------------------------------------------------------------

-- A. Hero Slides (Hero Trailer & Featured Carousel)
CREATE TABLE IF NOT EXISTS public.hero_slides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  title text NOT NULL,
  tagline text DEFAULT '',
  overview text DEFAULT '',
  backdrop_url text DEFAULT '',
  poster_url text DEFAULT '',
  trailer_yt_id text DEFAULT '',
  tmdb_id integer,
  media_type text DEFAULT 'movie',
  cta_text text DEFAULT 'Watch Trailer',
  cta_link text DEFAULT '#',
  badge text DEFAULT 'FEATURED',
  display_order integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'published',
  is_active boolean NOT NULL DEFAULT true
);

-- B. Content Overrides (Custom Posters, Titles, Synopses over TMDB Data)
CREATE TABLE IF NOT EXISTS public.content_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  tmdb_id integer NOT NULL,
  media_type text NOT NULL DEFAULT 'movie',
  custom_title text,
  custom_overview text,
  custom_poster_url text,
  custom_backdrop_url text,
  custom_badge text,
  custom_trailer_yt_id text,
  visibility text NOT NULL DEFAULT 'published',
  is_curated boolean NOT NULL DEFAULT true,
  curated_by uuid,
  notes text DEFAULT '',
  CONSTRAINT uq_content_overrides_item UNIQUE (tmdb_id, media_type)
);

-- C. Homepage Sections (Dynamic Section Ordering & Visual Formats)
CREATE TABLE IF NOT EXISTS public.homepage_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  subtitle text DEFAULT '',
  source_type text NOT NULL DEFAULT 'tmdb_movie',
  tmdb_endpoint text NOT NULL,
  card_shape text NOT NULL DEFAULT 'portrait',
  item_limit integer NOT NULL DEFAULT 12,
  display_order integer NOT NULL DEFAULT 0,
  is_enabled boolean NOT NULL DEFAULT true
);

-- D. Homepage Section Curated Items (Fixed Item Pinning in Rows)
CREATE TABLE IF NOT EXISTS public.homepage_section_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  section_id uuid REFERENCES public.homepage_sections(id) ON DELETE CASCADE,
  tmdb_id integer NOT NULL,
  media_type text NOT NULL DEFAULT 'movie',
  display_order integer NOT NULL DEFAULT 0,
  pinned boolean NOT NULL DEFAULT true,
  CONSTRAINT uq_section_items UNIQUE (section_id, tmdb_id, media_type)
);

-- E. Intro & Splash Animation Settings
CREATE TABLE IF NOT EXISTS public.intro_settings (
  id integer PRIMARY KEY DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now(),
  config jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- F. Website Presentation & Branding Settings
CREATE TABLE IF NOT EXISTS public.website_settings (
  id integer PRIMARY KEY DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now(),
  config jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- G. Sensitive Admin Configuration (SUPER ADMIN ONLY - NO PUBLIC ACCESS)
CREATE TABLE IF NOT EXISTS public.admin_settings (
  id integer PRIMARY KEY DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now(),
  config jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- H. Telemetry & Analytics Events
CREATE TABLE IF NOT EXISTS public.analytics_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  event_type text NOT NULL,
  media_id integer,
  media_type text,
  metadata jsonb DEFAULT '{}'::jsonb,
  client_id text
);

-- I. Super Admin Activity Audit Logs
CREATE TABLE IF NOT EXISTS public.admin_activity_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  admin_uid uuid NOT NULL,
  admin_email text,
  action text NOT NULL,
  target_entity text,
  target_id text,
  details jsonb DEFAULT '{}'::jsonb,
  ip_address text
);

-- ----------------------------------------------------------------------------
-- 3. ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ----------------------------------------------------------------------------
ALTER TABLE public.movies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hero_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homepage_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homepage_section_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intro_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_activity_logs ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY POLICIES (STRICT PUBLIC ALLOWLIST + SUPER ADMIN RBAC)
-- ----------------------------------------------------------------------------

-- PUBLIC ANONYMOUS ACCESS (Read-only, strictly restricted to published/public data)
DROP POLICY IF EXISTS "Public read movies" ON public.movies;
CREATE POLICY "Public read movies" ON public.movies FOR SELECT TO anon, authenticated 
USING (status = 'published');

DROP POLICY IF EXISTS "Public read site_settings" ON public.site_settings;
CREATE POLICY "Public read site_settings" ON public.site_settings FOR SELECT TO anon, authenticated 
USING (key IN ('site_title', 'site_tagline', 'maintenance_mode', 'announcement_enabled', 'announcement_text', 'announcement_type', 'contact_email', 'logo_url', 'brand_description', 'footer_text'));

DROP POLICY IF EXISTS "Public read published hero" ON public.hero_slides;
CREATE POLICY "Public read published hero" ON public.hero_slides FOR SELECT TO anon, authenticated 
USING (status = 'published' AND is_active = true);

DROP POLICY IF EXISTS "Public read published content" ON public.content_overrides;
CREATE POLICY "Public read published content" ON public.content_overrides FOR SELECT TO anon, authenticated 
USING (visibility = 'published');

DROP POLICY IF EXISTS "Public read enabled sections" ON public.homepage_sections;
CREATE POLICY "Public read enabled sections" ON public.homepage_sections FOR SELECT TO anon, authenticated 
USING (is_enabled = true);

DROP POLICY IF EXISTS "Public read section items" ON public.homepage_section_items;
CREATE POLICY "Public read section items" ON public.homepage_section_items FOR SELECT TO anon, authenticated 
USING (true);

DROP POLICY IF EXISTS "Public read intro settings" ON public.intro_settings;
CREATE POLICY "Public read intro settings" ON public.intro_settings FOR SELECT TO anon, authenticated 
USING (true);

DROP POLICY IF EXISTS "Public read site settings" ON public.website_settings;
CREATE POLICY "Public read site settings" ON public.website_settings FOR SELECT TO anon, authenticated 
USING (true);

-- Public Telemetry Logging (INSERT ONLY, validated event types)
DROP POLICY IF EXISTS "Public log validated events" ON public.analytics_events;
CREATE POLICY "Public log validated events" ON public.analytics_events FOR INSERT TO anon, authenticated 
WITH CHECK (event_type IN ('page_view','search','detail_open','hero_interact','trailer_play','trailer_error','nav_click','js_error','api_error','load_error'));

-- SUPER ADMIN PRIVILEGED ACCESS (Enforced by auth.uid() = 540e9d75-3e05-48c9-bb5c-5dac0db4c3f0)
DROP POLICY IF EXISTS "Admin all movies" ON public.movies;
CREATE POLICY "Admin all movies" ON public.movies FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all site_settings" ON public.site_settings;
CREATE POLICY "Admin all site_settings" ON public.site_settings FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all audit_logs" ON public.audit_logs;
CREATE POLICY "Admin all audit_logs" ON public.audit_logs FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all hero" ON public.hero_slides;
CREATE POLICY "Admin all hero" ON public.hero_slides FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all content" ON public.content_overrides;
CREATE POLICY "Admin all content" ON public.content_overrides FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all sections" ON public.homepage_sections;
CREATE POLICY "Admin all sections" ON public.homepage_sections FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all section items" ON public.homepage_section_items;
CREATE POLICY "Admin all section items" ON public.homepage_section_items FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all intro" ON public.intro_settings;
CREATE POLICY "Admin all intro" ON public.intro_settings FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all site settings" ON public.website_settings;
CREATE POLICY "Admin all site settings" ON public.website_settings FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all admin_settings" ON public.admin_settings;
CREATE POLICY "Admin all admin_settings" ON public.admin_settings FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin read analytics" ON public.analytics_events;
CREATE POLICY "Admin read analytics" ON public.analytics_events FOR SELECT TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin all logs" ON public.admin_activity_logs;
CREATE POLICY "Admin all logs" ON public.admin_activity_logs FOR ALL TO authenticated 
USING (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

-- ----------------------------------------------------------------------------
-- 5. STORAGE BUCKET CONFIGURATION & POLICIES
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) 
VALUES ('flixora-assets', 'flixora-assets', true) 
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public read flixora assets" ON storage.objects;
CREATE POLICY "Public read flixora assets" ON storage.objects FOR SELECT TO anon, authenticated 
USING (bucket_id = 'flixora-assets');

DROP POLICY IF EXISTS "Admin write flixora assets" ON storage.objects;
CREATE POLICY "Admin write flixora assets" ON storage.objects FOR ALL TO authenticated 
USING (bucket_id = 'flixora-assets' AND auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (bucket_id = 'flixora-assets' AND auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

-- Restrict private buckets (e.g. video storage) strictly to Super Admin
DROP POLICY IF EXISTS "Admin read private bucket" ON storage.objects;
CREATE POLICY "Admin read private bucket" ON storage.objects FOR SELECT TO authenticated 
USING (bucket_id = 'flixora-private' AND auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

DROP POLICY IF EXISTS "Admin write private bucket" ON storage.objects;
CREATE POLICY "Admin write private bucket" ON storage.objects FOR ALL TO authenticated 
USING (bucket_id = 'flixora-private' AND auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid) 
WITH CHECK (bucket_id = 'flixora-private' AND auth.uid() = '540e9d75-3e05-48c9-bb5c-5dac0db4c3f0'::uuid);

-- ----------------------------------------------------------------------------
-- 6. PRE-SEED EXISTING WEBSITE DATA (HOMEPAGE SECTIONS, SETTINGS, INTRO)
-- ----------------------------------------------------------------------------

-- Seed All 23 Existing Homepage Sections from index.html (HOME_R)
INSERT INTO public.homepage_sections (slug, title, source_type, tmdb_endpoint, card_shape, item_limit, display_order, is_enabled)
VALUES
  ('global_top_10_trending', 'Global Top 10 Trending', 'tmdb_all', '/trending/all/day', 'rank', 10, 1, true),
  ('recommended_for_you', 'Recommended For You', 'tmdb_movie', '/trending/movie/week', 'wide', 12, 2, true),
  ('indian_tv_shows', 'Indian TV Shows & Web Series', 'tmdb_tv', '/discover/tv?with_origin_country=IN&without_genres=16&sort_by=popularity.desc', 'wide', 12, 3, true),
  ('because_you_watched_cinema', 'Because You Watched Cinema', 'tmdb_movie', '/discover/movie?without_genres=16&sort_by=vote_average.desc&vote_count.gte=1200', 'slant', 12, 4, true),
  ('popular_blockbusters', 'Popular Blockbusters', 'tmdb_movie', '/discover/movie?without_genres=16&sort_by=popularity.desc', 'portrait', 12, 5, true),
  ('upcoming_releases', 'Upcoming Releases', 'tmdb_movie', '/movie/upcoming', 'leaf', 12, 6, true),
  ('now_playing_theatres', 'Now Playing Theatres', 'tmdb_movie', '/movie/now_playing', 'chamfer', 12, 7, true),
  ('popular_web_series', 'Popular Web Series', 'tmdb_tv', '/discover/tv?without_genres=16&without_original_language=ko&sort_by=popularity.desc', 'arch', 12, 8, true),
  ('top_rated_tv_series', 'Top Rated TV Series', 'tmdb_tv', '/discover/tv?without_genres=16&without_original_language=ko&sort_by=vote_average.desc&vote_count.gte=400', 'wide', 12, 9, true),
  ('top_rated_anime', 'Top Rated Anime', 'tmdb_anime', '/discover/tv?with_genres=16&with_original_language=ja&sort_by=vote_average.desc&vote_count.gte=300', 'chamfer', 12, 10, true),
  ('popular_anime_movies', 'Popular Anime Movies', 'tmdb_anime', '/discover/movie?with_genres=16&with_original_language=ja&sort_by=popularity.desc', 'slant', 12, 11, true),
  ('trending_kdramas', 'Trending K-Dramas', 'tmdb_kdrama', '/discover/tv?with_original_language=ko&sort_by=popularity.desc', 'wide', 12, 12, true),
  ('top_kdramas', 'Top K-Dramas', 'tmdb_kdrama', '/discover/tv?with_original_language=ko&sort_by=vote_average.desc&vote_count.gte=150', 'portrait', 12, 13, true),
  ('action_adventure', 'Action & Adventure', 'tmdb_movie', '/discover/movie?with_genres=28,12&without_genres=16', 'slant', 12, 14, true),
  ('scifi_mind_bending', 'Sci-Fi & Mind-Bending', 'tmdb_movie', '/discover/movie?with_genres=878&without_genres=16', 'chamfer', 12, 15, true),
  ('horror_supernatural', 'Horror & Supernatural', 'tmdb_movie', '/discover/movie?with_genres=27&without_genres=16', 'portrait', 12, 16, true),
  ('dark_thrillers', 'Dark Thrillers', 'tmdb_movie', '/discover/movie?with_genres=53&without_genres=16', 'arch', 12, 17, true),
  ('comedy_feel_good', 'Comedy & Feel-Good', 'tmdb_movie', '/discover/movie?with_genres=35&without_genres=16', 'leaf', 12, 18, true),
  ('crime_mystery', 'Crime & Mystery', 'tmdb_movie', '/discover/movie?with_genres=80,9648&without_genres=16', 'wide', 12, 19, true),
  ('romance_stories', 'Romance Stories', 'tmdb_movie', '/discover/movie?with_genres=10749&without_genres=16', 'slant', 12, 20, true),
  ('acclaimed_drama', 'Acclaimed Drama', 'tmdb_movie', '/discover/movie?with_genres=18&without_genres=16&sort_by=vote_average.desc&vote_count.gte=900', 'portrait', 12, 21, true),
  ('indian_cinema_hits', 'Indian Cinema Hits', 'tmdb_movie', '/discover/movie?with_origin_country=IN&without_genres=16', 'leaf', 12, 22, true),
  ('documentaries', 'Documentaries', 'tmdb_movie', '/discover/movie?with_genres=99', 'chamfer', 12, 23, true)
ON CONFLICT (slug) DO UPDATE SET
  title = EXCLUDED.title,
  source_type = EXCLUDED.source_type,
  tmdb_endpoint = EXCLUDED.tmdb_endpoint,
  card_shape = EXCLUDED.card_shape,
  item_limit = EXCLUDED.item_limit,
  display_order = EXCLUDED.display_order;

-- Seed Default Website Settings Matching index.html
INSERT INTO public.website_settings (id, config)
VALUES (
  1,
  jsonb_build_object(
    'site_title', 'Flixora — Movie ID Finder',
    'logo_url', 'https://i.ibb.co/8DW8gwrD/72d018c7c0e6909c13158fe402b62a9f2c2ddb8ae70b8a4fb0e2844e1ba4671c.png',
    'favicon_url', 'https://i.ibb.co/8DW8gwrD/72d018c7c0e6909c13158fe402b62a9f2c2ddb8ae70b8a4fb0e2844e1ba4671c.png',
    'fallback_image_url', '',
    'brand_description', 'High-performance cinema discovery and movie ID search engine with cinematic intro animations and video trailer immersion.',
    'footer_text', '© 2026 Flixora. Powered by Supabase & TMDB API.',
    'default_language', 'en',
    'maintenance_mode', false,
    'announcement_enabled', false,
    'announcement_text', '',
    'allow_indexing', true,
    'search', jsonb_build_object(
      'enabled', true,
      'placeholder', 'Search all movies, series, anime...',
      'limit', 24,
      'behavior', 'instant_debounced',
      'suggestions_enabled', true,
      'curated_terms', jsonb_build_array('Interstellar', 'Attack on Titan', 'Oppenheimer', 'Breaking Bad', 'Demon Slayer')
    )
  )
)
ON CONFLICT (id) DO NOTHING;

-- Seed Default Intro & Animation Settings Matching index.html
INSERT INTO public.intro_settings (id, config)
VALUES (
  1,
  jsonb_build_object(
    'enabled', true,
    'skip_button', true,
    'desktop_enabled', true,
    'mobile_enabled', true,
    'session_policy', 'every_visit',
    'reduced_motion', 'simplified',
    'emergency_timeout_ms', 12000,
    'stage1_enabled', true,
    'stage1_logo', 'https://i.ibb.co/wNkMGsms/IMG-80fb3083-ba3a-431a-88de-587a8ba7e963.jpg',
    'stage1_duration_ms', 1280,
    'stage1_text', true,
    'stage2_enabled', true,
    'stage2_logo', 'https://i.ibb.co/8DW8gwrD/72d018c7c0e6909c13158fe402b62a9f2c2ddb8ae70b8a4fb0e2844e1ba4671c.png',
    'stage2_duration_ms', 1800,
    'stage2_powered_by', true,
    'stage3_enabled', true,
    'stage3_logo', 'https://i.ibb.co/8DW8gwrD/72d018c7c0e6909c13158fe402b62a9f2c2ddb8ae70b8a4fb0e2844e1ba4671c.png',
    'stage3_status', 'Initializing Flixora',
    'stage3_bar', true,
    'stage4_enabled', true,
    'stage4_desktop_cursors', 6,
    'stage4_mobile_cursors', 4,
    'stage4_speed', 1.0,
    'stage4_fx', true
  )
)
ON CONFLICT (id) DO NOTHING;
