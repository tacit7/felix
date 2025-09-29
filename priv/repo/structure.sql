--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2 (Postgres.app)
-- Dumped by pg_dump version 16.2 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: update_places_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_places_location() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(CAST(NEW.longitude AS double precision), CAST(NEW.latitude AS double precision)), 4326);
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aircraft; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aircraft (
    id integer NOT NULL,
    icao24 character varying(6) NOT NULL,
    registration character varying(255),
    manufacturericao character varying(255),
    manufacturername character varying(255),
    model character varying(255),
    typecode character varying(255),
    serialnumber character varying(255),
    owner character varying(255),
    operator character varying(255),
    operator_callsign character varying(255),
    operator_icao character varying(255),
    operator_iata character varying(255),
    first_flight_date date,
    category_description character varying(255),
    engines integer,
    engine_type character varying(255),
    last_seen timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: airports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.airports (
    id integer NOT NULL,
    icao character varying(4) NOT NULL,
    iata character varying(3),
    name character varying(255) NOT NULL,
    city character varying(255) NOT NULL,
    country character varying(255) NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    altitude integer,
    timezone character varying(255),
    dst character varying(255),
    tz_database character varying(255),
    type character varying(255),
    source character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: blog_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blog_posts (
    id uuid NOT NULL,
    title character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    content text NOT NULL,
    excerpt text,
    featured_image character varying(255),
    author character varying(255) DEFAULT 'RouteWise Team'::character varying,
    published boolean DEFAULT false,
    published_at timestamp(0) without time zone,
    meta_description character varying(255),
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: cached_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cached_places (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    place_type integer NOT NULL,
    country_code character varying(2),
    admin1_code character varying(255),
    lat double precision,
    lon double precision,
    popularity_score integer DEFAULT 0,
    search_count integer DEFAULT 0,
    source character varying(255) DEFAULT 'manual'::character varying,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: default_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.default_images (
    id bigint NOT NULL,
    category character varying(255) NOT NULL,
    image_url text NOT NULL,
    fallback_url text,
    description text,
    source character varying(255) DEFAULT 'unsplash'::character varying,
    is_active boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: default_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.default_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: default_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.default_images_id_seq OWNED BY public.default_images.id;


--
-- Name: flight_tracks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flight_tracks (
    id integer NOT NULL,
    flight_id bigint NOT NULL,
    icao24 character varying(6) NOT NULL,
    "time" timestamp(0) without time zone NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    altitude double precision,
    true_track double precision,
    on_ground boolean DEFAULT false,
    source character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: flights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flights (
    id integer NOT NULL,
    icao24 character varying(6) NOT NULL,
    callsign character varying(255),
    origin_country character varying(255) NOT NULL,
    first_seen timestamp(0) without time zone,
    last_seen timestamp(0) without time zone,
    departure_airport character varying(255),
    arrival_airport character varying(255),
    departure_time timestamp(0) without time zone,
    arrival_time timestamp(0) without time zone,
    flight_status character varying(255),
    aircraft_id bigint,
    latitude double precision,
    longitude double precision,
    altitude double precision,
    geo_altitude double precision,
    velocity double precision,
    true_track double precision,
    vertical_rate double precision,
    on_ground boolean DEFAULT false,
    squawk character varying(255),
    position_source integer,
    last_position_update timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: google_api_usage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_api_usage (
    id bigint NOT NULL,
    usage_date date NOT NULL,
    endpoint_type character varying(255) NOT NULL,
    call_count integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: google_api_usage_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.google_api_usage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: google_api_usage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.google_api_usage_id_seq OWNED BY public.google_api_usage.id;


--
-- Name: hero_carousel_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hero_carousel_images (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    subtitle character varying(255),
    description text,
    image_url text NOT NULL,
    image_alt_text character varying(500),
    mobile_image_url text,
    tablet_image_url text,
    webp_image_url text,
    mobile_webp_image_url text,
    cta_text character varying(100),
    cta_url character varying(500),
    cta_type character varying(50) DEFAULT 'internal'::character varying,
    background_color character varying(20),
    text_color character varying(20) DEFAULT 'white'::character varying,
    overlay_opacity numeric(3,2) DEFAULT 0.4,
    text_position character varying(20) DEFAULT 'center'::character varying,
    text_alignment character varying(20) DEFAULT 'center'::character varying,
    animation_type character varying(50) DEFAULT 'fade'::character varying,
    display_duration integer DEFAULT 5000,
    transition_duration integer DEFAULT 1000,
    priority_order integer NOT NULL,
    is_active boolean DEFAULT true,
    is_featured boolean DEFAULT false,
    start_date date,
    end_date date,
    target_audience character varying(100),
    device_targeting character varying(255)[] DEFAULT ARRAY['desktop'::character varying, 'tablet'::character varying, 'mobile'::character varying],
    geographic_targeting character varying(255)[] DEFAULT ARRAY[]::character varying[],
    seasonal_targeting character varying(255)[] DEFAULT ARRAY[]::character varying[],
    click_count integer DEFAULT 0,
    impression_count integer DEFAULT 0,
    conversion_count integer DEFAULT 0,
    last_shown timestamp(0) without time zone,
    photographer_credit character varying(255),
    location_featured character varying(255),
    image_tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    accessibility_compliant boolean DEFAULT true,
    loading_priority character varying(20) DEFAULT 'high'::character varying,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    approved_by_user_id bigint,
    approval_status character varying(20) DEFAULT 'pending'::character varying,
    approval_date timestamp(0) without time zone,
    scheduled_publish_date timestamp(0) without time zone,
    content_version integer DEFAULT 1,
    seo_title character varying(255),
    seo_description character varying(500),
    meta_keywords character varying(255)[] DEFAULT ARRAY[]::character varying[],
    canonical_url character varying(500),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT animation_type_check CHECK (((animation_type)::text = ANY ((ARRAY['fade'::character varying, 'slide-left'::character varying, 'slide-right'::character varying, 'slide-up'::character varying, 'slide-down'::character varying, 'zoom'::character varying, 'none'::character varying])::text[]))),
    CONSTRAINT approval_status_check CHECK (((approval_status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'draft'::character varying])::text[]))),
    CONSTRAINT cta_type_check CHECK (((cta_type)::text = ANY ((ARRAY['internal'::character varying, 'external'::character varying, 'modal'::character varying, 'none'::character varying])::text[]))),
    CONSTRAINT date_range_check CHECK (((start_date IS NULL) OR (end_date IS NULL) OR (start_date <= end_date))),
    CONSTRAINT duration_check CHECK (((display_duration >= 1000) AND (transition_duration >= 0))),
    CONSTRAINT loading_priority_check CHECK (((loading_priority)::text = ANY ((ARRAY['high'::character varying, 'low'::character varying, 'auto'::character varying])::text[]))),
    CONSTRAINT overlay_opacity_check CHECK (((overlay_opacity >= 0.0) AND (overlay_opacity <= 1.0))),
    CONSTRAINT text_alignment_check CHECK (((text_alignment)::text = ANY ((ARRAY['left'::character varying, 'center'::character varying, 'right'::character varying, 'justify'::character varying])::text[]))),
    CONSTRAINT text_position_check CHECK (((text_position)::text = ANY ((ARRAY['top'::character varying, 'center'::character varying, 'bottom'::character varying, 'left'::character varying, 'right'::character varying, 'top-left'::character varying, 'top-right'::character varying, 'bottom-left'::character varying, 'bottom-right'::character varying])::text[])))
);


--
-- Name: hero_carousel_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hero_carousel_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hero_carousel_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hero_carousel_images_id_seq OWNED BY public.hero_carousel_images.id;


--
-- Name: hero_carousel_performance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hero_carousel_performance (
    id bigint NOT NULL,
    image_id bigint NOT NULL,
    date date NOT NULL,
    impressions integer DEFAULT 0,
    clicks integer DEFAULT 0,
    conversions integer DEFAULT 0,
    bounce_rate numeric(5,4),
    avg_time_on_page integer,
    device_type character varying(20),
    traffic_source character varying(50),
    geographic_location character varying(100),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: hero_carousel_performance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hero_carousel_performance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hero_carousel_performance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hero_carousel_performance_id_seq OWNED BY public.hero_carousel_performance.id;


--
-- Name: hero_carousel_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hero_carousel_schedules (
    id bigint NOT NULL,
    image_id bigint NOT NULL,
    day_of_week integer,
    start_time time(0) without time zone,
    end_time time(0) without time zone,
    timezone character varying(50) DEFAULT 'UTC'::character varying,
    is_active boolean DEFAULT true,
    weight integer DEFAULT 1,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6))),
    CONSTRAINT time_range_check CHECK (((start_time IS NULL) OR (end_time IS NULL) OR (start_time < end_time))),
    CONSTRAINT weight_check CHECK ((weight > 0))
);


--
-- Name: hero_carousel_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hero_carousel_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hero_carousel_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hero_carousel_schedules_id_seq OWNED BY public.hero_carousel_schedules.id;


--
-- Name: hidden_gem_experiences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_gem_experiences (
    id bigint NOT NULL,
    hidden_gem_id bigint NOT NULL,
    visitor_name character varying(255),
    visit_date date,
    experience_text text,
    rating integer,
    visit_duration character varying(50),
    visit_season character varying(20),
    travel_party_size integer,
    travel_party_type character varying(50),
    helpful_tips text,
    would_return boolean,
    is_approved boolean DEFAULT false,
    is_featured boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: hidden_gem_experiences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_gem_experiences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_gem_experiences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_gem_experiences_id_seq OWNED BY public.hidden_gem_experiences.id;


--
-- Name: hidden_gem_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_gem_photos (
    id bigint NOT NULL,
    hidden_gem_id bigint NOT NULL,
    url text NOT NULL,
    caption character varying(500),
    photographer_credit character varying(255),
    is_primary boolean DEFAULT false,
    display_order integer DEFAULT 0,
    photo_type character varying(50) DEFAULT 'general'::character varying,
    season character varying(20),
    time_of_day character varying(20),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: hidden_gem_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_gem_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_gem_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_gem_photos_id_seq OWNED BY public.hidden_gem_photos.id;


--
-- Name: hidden_gem_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_gem_tags (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    display_name character varying(100) NOT NULL,
    color character varying(20),
    icon character varying(50),
    is_active boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: hidden_gem_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_gem_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_gem_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_gem_tags_id_seq OWNED BY public.hidden_gem_tags.id;


--
-- Name: hidden_gems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_gems (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    subtitle character varying(255),
    description text,
    image_url text,
    location character varying(255),
    city character varying(100),
    state character varying(50),
    country character varying(50) DEFAULT 'USA'::character varying,
    latitude numeric(10,6),
    longitude numeric(10,6),
    category character varying(50),
    subcategory character varying(50),
    difficulty_level character varying(20),
    best_time_to_visit character varying(100),
    estimated_duration character varying(50),
    accessibility_level character varying(20),
    crowd_level character varying(20),
    cost_estimate character varying(100),
    insider_tip text,
    how_to_get_there text,
    parking_info text,
    facilities_available character varying(255)[] DEFAULT ARRAY[]::character varying[],
    seasonal_notes text,
    photography_tips text,
    nearby_attractions character varying(255)[] DEFAULT ARRAY[]::character varying[],
    local_guides_available boolean DEFAULT false,
    requires_permits boolean DEFAULT false,
    permit_info text,
    safety_notes text,
    weather_dependency character varying(50),
    is_featured boolean DEFAULT false,
    is_active boolean DEFAULT true,
    visibility_score integer DEFAULT 50,
    uniqueness_score integer DEFAULT 50,
    difficulty_score integer DEFAULT 50,
    overall_rating numeric(3,2),
    total_votes integer DEFAULT 0,
    featured_order integer,
    discovery_date date,
    last_verified date,
    google_place_id character varying(255),
    google_rating numeric(3,2),
    google_reviews_count integer,
    google_phone character varying(50),
    google_website character varying(500),
    google_opening_hours jsonb,
    google_price_level integer,
    google_types character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT accessibility_level_check CHECK (((accessibility_level)::text = ANY ((ARRAY['High'::character varying, 'Medium'::character varying, 'Low'::character varying, 'None'::character varying])::text[]))),
    CONSTRAINT crowd_level_check CHECK (((crowd_level)::text = ANY ((ARRAY['Very Low'::character varying, 'Low'::character varying, 'Moderate'::character varying, 'High'::character varying, 'Very High'::character varying])::text[]))),
    CONSTRAINT difficulty_level_check CHECK (((difficulty_level)::text = ANY ((ARRAY['Easy'::character varying, 'Moderate'::character varying, 'Challenging'::character varying, 'Expert'::character varying])::text[]))),
    CONSTRAINT score_range_check CHECK ((((visibility_score >= 0) AND (visibility_score <= 100)) AND ((uniqueness_score >= 0) AND (uniqueness_score <= 100)) AND ((difficulty_score >= 0) AND (difficulty_score <= 100)))),
    CONSTRAINT weather_dependency_check CHECK (((weather_dependency)::text = ANY ((ARRAY['Low'::character varying, 'Medium'::character varying, 'High'::character varying, 'Critical'::character varying])::text[])))
);


--
-- Name: hidden_gems_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_gems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_gems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_gems_id_seq OWNED BY public.hidden_gems.id;


--
-- Name: hidden_gems_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_gems_tags (
    id bigint NOT NULL,
    hidden_gem_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: hidden_gems_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_gems_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_gems_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_gems_tags_id_seq OWNED BY public.hidden_gems_tags.id;


--
-- Name: interest_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interest_categories (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    display_name character varying(255) NOT NULL,
    description text,
    icon_name character varying(255),
    is_active boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: interest_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interest_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interest_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interest_categories_id_seq OWNED BY public.interest_categories.id;


--
-- Name: live_aircraft_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.live_aircraft_states (
    id integer NOT NULL,
    icao24 character varying(6) NOT NULL,
    callsign character varying(255),
    origin_country character varying(255) NOT NULL,
    time_position timestamp(0) without time zone,
    last_contact timestamp(0) without time zone NOT NULL,
    latitude double precision,
    longitude double precision,
    baro_altitude double precision,
    on_ground boolean DEFAULT false,
    velocity double precision,
    true_track double precision,
    vertical_rate double precision,
    geo_altitude double precision,
    squawk character varying(255),
    spi boolean,
    position_source integer,
    data_source character varying(255) DEFAULT 'opensky'::character varying,
    last_updated timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id uuid NOT NULL,
    location_iq_place_id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    display_name character varying(255) NOT NULL,
    latitude numeric(10,8) NOT NULL,
    longitude numeric(11,8) NOT NULL,
    city_type character varying(255),
    state character varying(255),
    country character varying(255) NOT NULL,
    country_code character varying(255) NOT NULL,
    search_count integer DEFAULT 0,
    last_searched_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    normalized_name character varying(255),
    bbox_north numeric(10,7),
    bbox_south numeric(10,7),
    bbox_east numeric(10,7),
    bbox_west numeric(10,7),
    search_radius_meters integer,
    bounds_source character varying(255) DEFAULT 'osm'::character varying,
    bounds_updated_at timestamp(0) without time zone,
    location_type character varying(255) DEFAULT 'city'::character varying NOT NULL
);


--
-- Name: places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.places (
    id bigint NOT NULL,
    google_place_id character varying(255) NOT NULL,
    name character varying(255),
    formatted_address character varying(255),
    latitude numeric(10,6),
    longitude numeric(10,6),
    categories character varying(255)[] DEFAULT ARRAY[]::character varying[],
    rating numeric(3,2),
    price_level integer,
    phone_number character varying(255),
    website character varying(255),
    opening_hours jsonb,
    photos jsonb[] DEFAULT ARRAY[]::jsonb[],
    reviews_count integer DEFAULT 0,
    google_data jsonb DEFAULT '{}'::jsonb,
    cached_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    location public.geometry(Point,4326),
    location_iq_place_id character varying(255),
    location_iq_data jsonb,
    description text,
    wiki_image character varying(255),
    tripadvisor_url character varying(255),
    tips text[],
    hidden_gem boolean DEFAULT false,
    hidden_gem_reason text,
    overrated boolean DEFAULT false,
    overrated_reason text,
    tripadvisor_rating numeric(3,2),
    tripadvisor_review_count integer,
    entry_fee text,
    best_time_to_visit text,
    accessibility text,
    duration_suggested text,
    related_places text[],
    local_name text,
    wikidata_id text,
    popularity_score integer DEFAULT 0,
    last_updated timestamp without time zone,
    curated boolean DEFAULT false NOT NULL,
    image_data jsonb,
    cached_image_original character varying(255),
    cached_image_thumb character varying(255),
    cached_image_medium character varying(255),
    cached_image_large character varying(255),
    cached_image_xlarge character varying(255),
    images_cached_at timestamp(0) without time zone,
    image_processing_status character varying(255),
    image_processing_error text,
    default_image_id bigint
);


--
-- Name: places_nearby; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.places_nearby (
    id bigint NOT NULL,
    place_id bigint NOT NULL,
    nearby_place_name character varying(255) NOT NULL,
    recommendation_reason text NOT NULL,
    description text,
    latitude numeric(10,6),
    longitude numeric(10,6),
    distance_km numeric(8,2),
    travel_time_minutes integer,
    transportation_method character varying(255),
    place_type character varying(255),
    country_code character varying(2),
    state_province character varying(255),
    popularity_score integer DEFAULT 0,
    recommendation_category character varying(255),
    best_season character varying(255),
    difficulty_level character varying(255),
    estimated_visit_duration character varying(255),
    google_place_id character varying(255),
    location_iq_place_id character varying(255),
    wikipedia_url character varying(255),
    official_website character varying(255),
    tips character varying(255)[] DEFAULT ARRAY[]::character varying[],
    image_url character varying(255),
    image_attribution character varying(255),
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    source character varying(255) DEFAULT 'manual'::character varying,
    verified boolean DEFAULT false,
    last_verified_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: places_nearby_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.places_nearby_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: places_nearby_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.places_nearby_id_seq OWNED BY public.places_nearby.id;


--
-- Name: places_new_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.places_new_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: places_new_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.places_new_id_seq OWNED BY public.places.id;


--
-- Name: pois; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pois (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    category character varying(255) NOT NULL,
    rating numeric(2,1) NOT NULL,
    review_count integer NOT NULL,
    time_from_start character varying(255) NOT NULL,
    image_url character varying(255) NOT NULL,
    place_id character varying(255),
    address character varying(255),
    price_level integer,
    is_open boolean,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    tips text[] DEFAULT ARRAY[]::text[],
    best_time_to_visit text,
    duration_suggested text,
    accessibility text,
    entry_fee text
);


--
-- Name: pois_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pois_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pois_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pois_id_seq OWNED BY public.pois.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: seasonal_travel_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasonal_travel_categories (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    display_name character varying(100) NOT NULL,
    description text,
    icon character varying(50),
    color character varying(20),
    is_active boolean DEFAULT true,
    display_order integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: seasonal_travel_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seasonal_travel_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasonal_travel_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seasonal_travel_categories_id_seq OWNED BY public.seasonal_travel_categories.id;


--
-- Name: seasonal_travel_highlights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasonal_travel_highlights (
    id bigint NOT NULL,
    travel_idea_id bigint NOT NULL,
    highlight character varying(255) NOT NULL,
    icon character varying(50),
    order_index integer DEFAULT 0
);


--
-- Name: seasonal_travel_highlights_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seasonal_travel_highlights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasonal_travel_highlights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seasonal_travel_highlights_id_seq OWNED BY public.seasonal_travel_highlights.id;


--
-- Name: seasonal_travel_ideas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasonal_travel_ideas (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    title character varying(255) NOT NULL,
    subtitle character varying(255),
    description text,
    image_url text,
    destination character varying(255),
    best_months character varying(100),
    duration character varying(50),
    difficulty character varying(20),
    estimated_cost character varying(100),
    temperature_range character varying(50),
    featured_activities character varying(255)[] DEFAULT ARRAY[]::character varying[],
    travel_tips character varying(255)[] DEFAULT ARRAY[]::character varying[],
    is_featured boolean DEFAULT false,
    is_active boolean DEFAULT true,
    priority integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT seasonal_difficulty_check CHECK (((difficulty)::text = ANY ((ARRAY['Easy'::character varying, 'Moderate'::character varying, 'Challenging'::character varying])::text[])))
);


--
-- Name: seasonal_travel_ideas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seasonal_travel_ideas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasonal_travel_ideas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seasonal_travel_ideas_id_seq OWNED BY public.seasonal_travel_ideas.id;


--
-- Name: seasonal_weather_info; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasonal_weather_info (
    id bigint NOT NULL,
    travel_idea_id bigint NOT NULL,
    month character varying(20) NOT NULL,
    avg_high_temp integer,
    avg_low_temp integer,
    precipitation character varying(50),
    weather_description character varying(255)
);


--
-- Name: seasonal_weather_info_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seasonal_weather_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasonal_weather_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seasonal_weather_info_id_seq OWNED BY public.seasonal_weather_info.id;


--
-- Name: suggested_trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suggested_trips (
    id bigint NOT NULL,
    slug character varying(100) NOT NULL,
    title character varying(255) NOT NULL,
    summary text,
    description text,
    duration character varying(50),
    difficulty character varying(20),
    best_time character varying(100),
    estimated_cost character varying(100),
    hero_image text,
    tips character varying(255)[] DEFAULT ARRAY[]::character varying[],
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    is_active boolean DEFAULT true,
    featured_order integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT difficulty_check CHECK (((difficulty)::text = ANY ((ARRAY['Easy'::character varying, 'Moderate'::character varying, 'Challenging'::character varying])::text[])))
);


--
-- Name: suggested_trips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.suggested_trips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: suggested_trips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.suggested_trips_id_seq OWNED BY public.suggested_trips.id;


--
-- Name: trip_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_activities (
    id uuid NOT NULL,
    trip_id bigint NOT NULL,
    user_id bigint,
    action character varying(255) NOT NULL,
    description text,
    changes_data jsonb DEFAULT '{}'::jsonb,
    ip_address character varying(255),
    user_agent character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: trip_collaborators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_collaborators (
    id uuid NOT NULL,
    trip_id bigint NOT NULL,
    user_id bigint NOT NULL,
    permission_level character varying(255) DEFAULT 'viewer'::character varying NOT NULL,
    invited_by_id bigint,
    invited_at timestamp(0) without time zone NOT NULL,
    accepted_at timestamp(0) without time zone,
    last_activity_at timestamp(0) without time zone,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: trip_itinerary; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_itinerary (
    id bigint NOT NULL,
    trip_id bigint NOT NULL,
    day integer NOT NULL,
    title character varying(255) NOT NULL,
    location character varying(255),
    activities character varying(255)[] DEFAULT ARRAY[]::character varying[],
    highlights character varying(255)[] DEFAULT ARRAY[]::character varying[],
    estimated_time character varying(50),
    driving_time character varying(50),
    order_index integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT day_positive CHECK ((day > 0))
);


--
-- Name: trip_itinerary_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_itinerary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_itinerary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_itinerary_id_seq OWNED BY public.trip_itinerary.id;


--
-- Name: trip_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_places (
    id bigint NOT NULL,
    trip_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    image text,
    latitude numeric(10,8),
    longitude numeric(11,8),
    activities character varying(255)[] DEFAULT ARRAY[]::character varying[],
    best_time_to_visit character varying(100),
    order_index integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: trip_places_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_places_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_places_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_places_id_seq OWNED BY public.trip_places.id;


--
-- Name: trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trips (
    id bigint NOT NULL,
    user_id bigint,
    title character varying(255) NOT NULL,
    start_city character varying(255),
    end_city character varying(255),
    checkpoints jsonb DEFAULT '{}'::jsonb,
    route_data jsonb,
    pois_data jsonb DEFAULT '{}'::jsonb,
    is_public boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    trip_type character varying(255) DEFAULT 'road-trip'::character varying,
    start_date date,
    end_date date,
    start_location jsonb,
    end_location jsonb,
    days jsonb DEFAULT '{"days": []}'::jsonb,
    total_distance_km numeric(10,2),
    estimated_cost numeric(10,2),
    difficulty_level character varying(255) DEFAULT 'moderate'::character varying,
    trip_tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    weather_requirements jsonb,
    packing_list character varying(255)[] DEFAULT ARRAY[]::character varying[],
    status character varying(255) DEFAULT 'planning'::character varying,
    last_modified_by_user_at timestamp(0) without time zone,
    is_shareable boolean DEFAULT false,
    share_token character varying(64),
    share_expires_at timestamp(0) without time zone,
    share_permissions jsonb DEFAULT '{}'::jsonb,
    allow_public_edit boolean DEFAULT false,
    require_approval_for_edits boolean DEFAULT true,
    max_collaborators integer DEFAULT 10
);


--
-- Name: trips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trips_id_seq OWNED BY public.trips.id;


--
-- Name: user_interests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_interests (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    category_id bigint NOT NULL,
    is_enabled boolean DEFAULT true,
    priority integer DEFAULT 1,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_interests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_interests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_interests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_interests_id_seq OWNED BY public.user_interests.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username character varying(255) NOT NULL,
    password_hash character varying(255),
    email character varying(255),
    google_id character varying(255),
    full_name character varying(255),
    avatar character varying(255),
    provider character varying(255) DEFAULT 'local'::character varying,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users_new_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_new_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_new_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_new_id_seq OWNED BY public.users.id;


--
-- Name: weekly_featured_trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.weekly_featured_trips (
    id bigint NOT NULL,
    slug character varying(100) NOT NULL,
    title character varying(255) NOT NULL,
    subtitle character varying(255),
    description text,
    image_url text,
    duration character varying(50),
    difficulty character varying(20),
    best_time character varying(100),
    total_miles character varying(50),
    estimated_cost character varying(100),
    trending_metric character varying(100),
    is_active boolean DEFAULT true,
    week_priority integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT difficulty_check CHECK (((difficulty)::text = ANY ((ARRAY['Easy'::character varying, 'Moderate'::character varying, 'Challenging'::character varying])::text[])))
);


--
-- Name: weekly_featured_trips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.weekly_featured_trips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: weekly_featured_trips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.weekly_featured_trips_id_seq OWNED BY public.weekly_featured_trips.id;


--
-- Name: weekly_trip_highlights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.weekly_trip_highlights (
    id bigint NOT NULL,
    trip_id bigint NOT NULL,
    highlight character varying(255) NOT NULL,
    order_index integer DEFAULT 0
);


--
-- Name: weekly_trip_highlights_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.weekly_trip_highlights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: weekly_trip_highlights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.weekly_trip_highlights_id_seq OWNED BY public.weekly_trip_highlights.id;


--
-- Name: weekly_trip_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.weekly_trip_stats (
    id bigint NOT NULL,
    trip_id bigint NOT NULL,
    stat_type character varying(50) NOT NULL,
    stat_value character varying(100) NOT NULL,
    icon character varying(50)
);


--
-- Name: weekly_trip_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.weekly_trip_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: weekly_trip_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.weekly_trip_stats_id_seq OWNED BY public.weekly_trip_stats.id;


--
-- Name: default_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_images ALTER COLUMN id SET DEFAULT nextval('public.default_images_id_seq'::regclass);


--
-- Name: google_api_usage id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_api_usage ALTER COLUMN id SET DEFAULT nextval('public.google_api_usage_id_seq'::regclass);


--
-- Name: hero_carousel_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_images ALTER COLUMN id SET DEFAULT nextval('public.hero_carousel_images_id_seq'::regclass);


--
-- Name: hero_carousel_performance id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_performance ALTER COLUMN id SET DEFAULT nextval('public.hero_carousel_performance_id_seq'::regclass);


--
-- Name: hero_carousel_schedules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_schedules ALTER COLUMN id SET DEFAULT nextval('public.hero_carousel_schedules_id_seq'::regclass);


--
-- Name: hidden_gem_experiences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_experiences ALTER COLUMN id SET DEFAULT nextval('public.hidden_gem_experiences_id_seq'::regclass);


--
-- Name: hidden_gem_photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_photos ALTER COLUMN id SET DEFAULT nextval('public.hidden_gem_photos_id_seq'::regclass);


--
-- Name: hidden_gem_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_tags ALTER COLUMN id SET DEFAULT nextval('public.hidden_gem_tags_id_seq'::regclass);


--
-- Name: hidden_gems id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gems ALTER COLUMN id SET DEFAULT nextval('public.hidden_gems_id_seq'::regclass);


--
-- Name: hidden_gems_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gems_tags ALTER COLUMN id SET DEFAULT nextval('public.hidden_gems_tags_id_seq'::regclass);


--
-- Name: interest_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_categories ALTER COLUMN id SET DEFAULT nextval('public.interest_categories_id_seq'::regclass);


--
-- Name: places id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places ALTER COLUMN id SET DEFAULT nextval('public.places_new_id_seq'::regclass);


--
-- Name: places_nearby id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places_nearby ALTER COLUMN id SET DEFAULT nextval('public.places_nearby_id_seq'::regclass);


--
-- Name: pois id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pois ALTER COLUMN id SET DEFAULT nextval('public.pois_id_seq'::regclass);


--
-- Name: seasonal_travel_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_categories ALTER COLUMN id SET DEFAULT nextval('public.seasonal_travel_categories_id_seq'::regclass);


--
-- Name: seasonal_travel_highlights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_highlights ALTER COLUMN id SET DEFAULT nextval('public.seasonal_travel_highlights_id_seq'::regclass);


--
-- Name: seasonal_travel_ideas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_ideas ALTER COLUMN id SET DEFAULT nextval('public.seasonal_travel_ideas_id_seq'::regclass);


--
-- Name: seasonal_weather_info id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_weather_info ALTER COLUMN id SET DEFAULT nextval('public.seasonal_weather_info_id_seq'::regclass);


--
-- Name: suggested_trips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggested_trips ALTER COLUMN id SET DEFAULT nextval('public.suggested_trips_id_seq'::regclass);


--
-- Name: trip_itinerary id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_itinerary ALTER COLUMN id SET DEFAULT nextval('public.trip_itinerary_id_seq'::regclass);


--
-- Name: trip_places id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_places ALTER COLUMN id SET DEFAULT nextval('public.trip_places_id_seq'::regclass);


--
-- Name: trips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trips ALTER COLUMN id SET DEFAULT nextval('public.trips_id_seq'::regclass);


--
-- Name: user_interests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interests ALTER COLUMN id SET DEFAULT nextval('public.user_interests_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_new_id_seq'::regclass);


--
-- Name: weekly_featured_trips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_featured_trips ALTER COLUMN id SET DEFAULT nextval('public.weekly_featured_trips_id_seq'::regclass);


--
-- Name: weekly_trip_highlights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_trip_highlights ALTER COLUMN id SET DEFAULT nextval('public.weekly_trip_highlights_id_seq'::regclass);


--
-- Name: weekly_trip_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_trip_stats ALTER COLUMN id SET DEFAULT nextval('public.weekly_trip_stats_id_seq'::regclass);


--
-- Name: aircraft aircraft_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aircraft
    ADD CONSTRAINT aircraft_pkey PRIMARY KEY (id);


--
-- Name: airports airports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.airports
    ADD CONSTRAINT airports_pkey PRIMARY KEY (id);


--
-- Name: blog_posts blog_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT blog_posts_pkey PRIMARY KEY (id);


--
-- Name: cached_places cached_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cached_places
    ADD CONSTRAINT cached_places_pkey PRIMARY KEY (id);


--
-- Name: locations cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: default_images default_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_images
    ADD CONSTRAINT default_images_pkey PRIMARY KEY (id);


--
-- Name: flight_tracks flight_tracks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_tracks
    ADD CONSTRAINT flight_tracks_pkey PRIMARY KEY (id);


--
-- Name: flights flights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flights
    ADD CONSTRAINT flights_pkey PRIMARY KEY (id);


--
-- Name: google_api_usage google_api_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_api_usage
    ADD CONSTRAINT google_api_usage_pkey PRIMARY KEY (id);


--
-- Name: hero_carousel_images hero_carousel_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_images
    ADD CONSTRAINT hero_carousel_images_pkey PRIMARY KEY (id);


--
-- Name: hero_carousel_performance hero_carousel_performance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_performance
    ADD CONSTRAINT hero_carousel_performance_pkey PRIMARY KEY (id);


--
-- Name: hero_carousel_schedules hero_carousel_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_schedules
    ADD CONSTRAINT hero_carousel_schedules_pkey PRIMARY KEY (id);


--
-- Name: hidden_gem_experiences hidden_gem_experiences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_experiences
    ADD CONSTRAINT hidden_gem_experiences_pkey PRIMARY KEY (id);


--
-- Name: hidden_gem_photos hidden_gem_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_photos
    ADD CONSTRAINT hidden_gem_photos_pkey PRIMARY KEY (id);


--
-- Name: hidden_gem_tags hidden_gem_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_tags
    ADD CONSTRAINT hidden_gem_tags_pkey PRIMARY KEY (id);


--
-- Name: hidden_gems hidden_gems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gems
    ADD CONSTRAINT hidden_gems_pkey PRIMARY KEY (id);


--
-- Name: hidden_gems_tags hidden_gems_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gems_tags
    ADD CONSTRAINT hidden_gems_tags_pkey PRIMARY KEY (id);


--
-- Name: interest_categories interest_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_categories
    ADD CONSTRAINT interest_categories_pkey PRIMARY KEY (id);


--
-- Name: live_aircraft_states live_aircraft_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.live_aircraft_states
    ADD CONSTRAINT live_aircraft_states_pkey PRIMARY KEY (id);


--
-- Name: places_nearby places_nearby_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places_nearby
    ADD CONSTRAINT places_nearby_pkey PRIMARY KEY (id);


--
-- Name: places places_new_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_new_pkey PRIMARY KEY (id);


--
-- Name: pois pois_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pois
    ADD CONSTRAINT pois_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: seasonal_travel_categories seasonal_travel_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_categories
    ADD CONSTRAINT seasonal_travel_categories_pkey PRIMARY KEY (id);


--
-- Name: seasonal_travel_highlights seasonal_travel_highlights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_highlights
    ADD CONSTRAINT seasonal_travel_highlights_pkey PRIMARY KEY (id);


--
-- Name: seasonal_travel_ideas seasonal_travel_ideas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_ideas
    ADD CONSTRAINT seasonal_travel_ideas_pkey PRIMARY KEY (id);


--
-- Name: seasonal_weather_info seasonal_weather_info_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_weather_info
    ADD CONSTRAINT seasonal_weather_info_pkey PRIMARY KEY (id);


--
-- Name: suggested_trips suggested_trips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suggested_trips
    ADD CONSTRAINT suggested_trips_pkey PRIMARY KEY (id);


--
-- Name: trip_activities trip_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_activities
    ADD CONSTRAINT trip_activities_pkey PRIMARY KEY (id);


--
-- Name: trip_collaborators trip_collaborators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_collaborators
    ADD CONSTRAINT trip_collaborators_pkey PRIMARY KEY (id);


--
-- Name: trip_itinerary trip_itinerary_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_itinerary
    ADD CONSTRAINT trip_itinerary_pkey PRIMARY KEY (id);


--
-- Name: trip_places trip_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_places
    ADD CONSTRAINT trip_places_pkey PRIMARY KEY (id);


--
-- Name: trips trips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (id);


--
-- Name: user_interests user_interests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interests
    ADD CONSTRAINT user_interests_pkey PRIMARY KEY (id);


--
-- Name: users users_new_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_new_pkey PRIMARY KEY (id);


--
-- Name: weekly_featured_trips weekly_featured_trips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_featured_trips
    ADD CONSTRAINT weekly_featured_trips_pkey PRIMARY KEY (id);


--
-- Name: weekly_trip_highlights weekly_trip_highlights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_trip_highlights
    ADD CONSTRAINT weekly_trip_highlights_pkey PRIMARY KEY (id);


--
-- Name: weekly_trip_stats weekly_trip_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_trip_stats
    ADD CONSTRAINT weekly_trip_stats_pkey PRIMARY KEY (id);


--
-- Name: aircraft_icao24_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX aircraft_icao24_index ON public.aircraft USING btree (icao24);


--
-- Name: aircraft_last_seen_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aircraft_last_seen_index ON public.aircraft USING btree (last_seen);


--
-- Name: aircraft_model_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aircraft_model_index ON public.aircraft USING btree (model);


--
-- Name: aircraft_operator_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aircraft_operator_index ON public.aircraft USING btree (operator);


--
-- Name: aircraft_registration_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aircraft_registration_index ON public.aircraft USING btree (registration);


--
-- Name: airports_city_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX airports_city_index ON public.airports USING btree (city);


--
-- Name: airports_country_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX airports_country_index ON public.airports USING btree (country);


--
-- Name: airports_iata_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX airports_iata_index ON public.airports USING btree (iata);


--
-- Name: airports_icao_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX airports_icao_index ON public.airports USING btree (icao);


--
-- Name: airports_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX airports_latitude_longitude_index ON public.airports USING btree (latitude, longitude);


--
-- Name: blog_posts_published_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX blog_posts_published_at_index ON public.blog_posts USING btree (published_at);


--
-- Name: blog_posts_published_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX blog_posts_published_index ON public.blog_posts USING btree (published);


--
-- Name: blog_posts_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX blog_posts_slug_index ON public.blog_posts USING btree (slug);


--
-- Name: blog_posts_tags_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX blog_posts_tags_index ON public.blog_posts USING gin (tags);


--
-- Name: cached_places_country_code_place_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cached_places_country_code_place_type_index ON public.cached_places USING btree (country_code, place_type);


--
-- Name: cached_places_name_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cached_places_name_gin_idx ON public.cached_places USING gin (name public.gin_trgm_ops);


--
-- Name: cached_places_name_prefix_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cached_places_name_prefix_idx ON public.cached_places USING btree (name text_pattern_ops);


--
-- Name: cached_places_place_type_popularity_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cached_places_place_type_popularity_score_index ON public.cached_places USING btree (place_type, popularity_score);


--
-- Name: cached_places_search_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cached_places_search_count_index ON public.cached_places USING btree (search_count);


--
-- Name: cities_country_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_country_code_index ON public.locations USING btree (country_code);


--
-- Name: cities_last_searched_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_last_searched_at_index ON public.locations USING btree (last_searched_at);


--
-- Name: cities_location_iq_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cities_location_iq_place_id_index ON public.locations USING btree (location_iq_place_id);


--
-- Name: cities_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_name_index ON public.locations USING btree (name);


--
-- Name: cities_normalized_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_normalized_name_index ON public.locations USING btree (normalized_name);


--
-- Name: cities_search_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_search_count_index ON public.locations USING btree (search_count);


--
-- Name: default_images_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX default_images_category_index ON public.default_images USING btree (category);


--
-- Name: default_images_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX default_images_is_active_index ON public.default_images USING btree (is_active);


--
-- Name: default_images_source_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX default_images_source_index ON public.default_images USING btree (source);


--
-- Name: flight_tracks_flight_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flight_tracks_flight_id_index ON public.flight_tracks USING btree (flight_id);


--
-- Name: flight_tracks_icao24_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flight_tracks_icao24_index ON public.flight_tracks USING btree (icao24);


--
-- Name: flight_tracks_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flight_tracks_latitude_longitude_index ON public.flight_tracks USING btree (latitude, longitude);


--
-- Name: flight_tracks_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flight_tracks_time_index ON public.flight_tracks USING btree ("time");


--
-- Name: flights_arrival_airport_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_arrival_airport_index ON public.flights USING btree (arrival_airport);


--
-- Name: flights_callsign_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_callsign_index ON public.flights USING btree (callsign);


--
-- Name: flights_departure_airport_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_departure_airport_index ON public.flights USING btree (departure_airport);


--
-- Name: flights_first_seen_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_first_seen_index ON public.flights USING btree (first_seen);


--
-- Name: flights_flight_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_flight_status_index ON public.flights USING btree (flight_status);


--
-- Name: flights_icao24_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_icao24_index ON public.flights USING btree (icao24);


--
-- Name: flights_last_position_update_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_last_position_update_index ON public.flights USING btree (last_position_update);


--
-- Name: flights_last_seen_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_last_seen_index ON public.flights USING btree (last_seen);


--
-- Name: flights_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flights_latitude_longitude_index ON public.flights USING btree (latitude, longitude);


--
-- Name: google_api_usage_endpoint_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX google_api_usage_endpoint_type_index ON public.google_api_usage USING btree (endpoint_type);


--
-- Name: google_api_usage_usage_date_endpoint_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX google_api_usage_usage_date_endpoint_type_index ON public.google_api_usage USING btree (usage_date, endpoint_type);


--
-- Name: google_api_usage_usage_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX google_api_usage_usage_date_index ON public.google_api_usage USING btree (usage_date);


--
-- Name: hero_carousel_images_approval_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_approval_status_index ON public.hero_carousel_images USING btree (approval_status);


--
-- Name: hero_carousel_images_click_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_click_count_index ON public.hero_carousel_images USING btree (click_count);


--
-- Name: hero_carousel_images_created_by_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_created_by_user_id_index ON public.hero_carousel_images USING btree (created_by_user_id);


--
-- Name: hero_carousel_images_impression_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_impression_count_index ON public.hero_carousel_images USING btree (impression_count);


--
-- Name: hero_carousel_images_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_is_active_index ON public.hero_carousel_images USING btree (is_active);


--
-- Name: hero_carousel_images_is_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_is_featured_index ON public.hero_carousel_images USING btree (is_featured);


--
-- Name: hero_carousel_images_priority_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_priority_order_index ON public.hero_carousel_images USING btree (priority_order);


--
-- Name: hero_carousel_images_scheduled_publish_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_scheduled_publish_date_index ON public.hero_carousel_images USING btree (scheduled_publish_date);


--
-- Name: hero_carousel_images_start_date_end_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_start_date_end_date_index ON public.hero_carousel_images USING btree (start_date, end_date);


--
-- Name: hero_carousel_images_target_audience_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_images_target_audience_index ON public.hero_carousel_images USING btree (target_audience);


--
-- Name: hero_carousel_performance_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_performance_date_index ON public.hero_carousel_performance USING btree (date);


--
-- Name: hero_carousel_performance_device_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_performance_device_type_index ON public.hero_carousel_performance USING btree (device_type);


--
-- Name: hero_carousel_performance_image_id_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_performance_image_id_date_index ON public.hero_carousel_performance USING btree (image_id, date);


--
-- Name: hero_carousel_schedules_day_of_week_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_schedules_day_of_week_index ON public.hero_carousel_schedules USING btree (day_of_week);


--
-- Name: hero_carousel_schedules_image_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_schedules_image_id_index ON public.hero_carousel_schedules USING btree (image_id);


--
-- Name: hero_carousel_schedules_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hero_carousel_schedules_is_active_index ON public.hero_carousel_schedules USING btree (is_active);


--
-- Name: hero_perf_unique_tracking_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX hero_perf_unique_tracking_idx ON public.hero_carousel_performance USING btree (image_id, date, device_type, traffic_source);


--
-- Name: hidden_gem_experiences_hidden_gem_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_experiences_hidden_gem_id_index ON public.hidden_gem_experiences USING btree (hidden_gem_id);


--
-- Name: hidden_gem_experiences_is_approved_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_experiences_is_approved_index ON public.hidden_gem_experiences USING btree (is_approved);


--
-- Name: hidden_gem_experiences_is_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_experiences_is_featured_index ON public.hidden_gem_experiences USING btree (is_featured);


--
-- Name: hidden_gem_experiences_rating_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_experiences_rating_index ON public.hidden_gem_experiences USING btree (rating);


--
-- Name: hidden_gem_experiences_visit_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_experiences_visit_date_index ON public.hidden_gem_experiences USING btree (visit_date);


--
-- Name: hidden_gem_photos_display_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_photos_display_order_index ON public.hidden_gem_photos USING btree (display_order);


--
-- Name: hidden_gem_photos_hidden_gem_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_photos_hidden_gem_id_index ON public.hidden_gem_photos USING btree (hidden_gem_id);


--
-- Name: hidden_gem_photos_is_primary_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_photos_is_primary_index ON public.hidden_gem_photos USING btree (is_primary);


--
-- Name: hidden_gem_photos_photo_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_photos_photo_type_index ON public.hidden_gem_photos USING btree (photo_type);


--
-- Name: hidden_gem_tags_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gem_tags_is_active_index ON public.hidden_gem_tags USING btree (is_active);


--
-- Name: hidden_gem_tags_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX hidden_gem_tags_name_index ON public.hidden_gem_tags USING btree (name);


--
-- Name: hidden_gems_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_category_index ON public.hidden_gems USING btree (category);


--
-- Name: hidden_gems_city_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_city_state_index ON public.hidden_gems USING btree (city, state);


--
-- Name: hidden_gems_featured_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_featured_order_index ON public.hidden_gems USING btree (featured_order);


--
-- Name: hidden_gems_google_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX hidden_gems_google_place_id_index ON public.hidden_gems USING btree (google_place_id) WHERE (google_place_id IS NOT NULL);


--
-- Name: hidden_gems_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_is_active_index ON public.hidden_gems USING btree (is_active);


--
-- Name: hidden_gems_is_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_is_featured_index ON public.hidden_gems USING btree (is_featured);


--
-- Name: hidden_gems_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_latitude_longitude_index ON public.hidden_gems USING btree (latitude, longitude);


--
-- Name: hidden_gems_overall_rating_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_overall_rating_index ON public.hidden_gems USING btree (overall_rating);


--
-- Name: hidden_gems_subcategory_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_subcategory_index ON public.hidden_gems USING btree (subcategory);


--
-- Name: hidden_gems_tags_hidden_gem_id_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX hidden_gems_tags_hidden_gem_id_tag_id_index ON public.hidden_gems_tags USING btree (hidden_gem_id, tag_id);


--
-- Name: hidden_gems_tags_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_tags_tag_id_index ON public.hidden_gems_tags USING btree (tag_id);


--
-- Name: hidden_gems_uniqueness_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_uniqueness_score_index ON public.hidden_gems USING btree (uniqueness_score);


--
-- Name: hidden_gems_visibility_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hidden_gems_visibility_score_index ON public.hidden_gems USING btree (visibility_score);


--
-- Name: interest_categories_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX interest_categories_name_index ON public.interest_categories USING btree (name);


--
-- Name: live_aircraft_states_callsign_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_aircraft_states_callsign_index ON public.live_aircraft_states USING btree (callsign);


--
-- Name: live_aircraft_states_icao24_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX live_aircraft_states_icao24_index ON public.live_aircraft_states USING btree (icao24);


--
-- Name: live_aircraft_states_last_contact_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_aircraft_states_last_contact_index ON public.live_aircraft_states USING btree (last_contact);


--
-- Name: live_aircraft_states_last_updated_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_aircraft_states_last_updated_index ON public.live_aircraft_states USING btree (last_updated);


--
-- Name: live_aircraft_states_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_aircraft_states_latitude_longitude_index ON public.live_aircraft_states USING btree (latitude, longitude);


--
-- Name: live_aircraft_states_on_ground_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_aircraft_states_on_ground_index ON public.live_aircraft_states USING btree (on_ground);


--
-- Name: live_aircraft_states_origin_country_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX live_aircraft_states_origin_country_index ON public.live_aircraft_states USING btree (origin_country);


--
-- Name: locations_location_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_location_type_index ON public.locations USING btree (location_type);


--
-- Name: places_curated_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_curated_index ON public.places USING btree (curated);


--
-- Name: places_default_image_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_default_image_id_index ON public.places USING btree (default_image_id);


--
-- Name: places_image_processing_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_image_processing_status_index ON public.places USING btree (image_processing_status);


--
-- Name: places_images_cached_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_images_cached_at_index ON public.places USING btree (images_cached_at);


--
-- Name: places_location_gist_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_location_gist_idx ON public.places USING gist (location);


--
-- Name: places_location_iq_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_location_iq_place_id_index ON public.places USING btree (location_iq_place_id);


--
-- Name: places_nearby_distance_km_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_distance_km_index ON public.places_nearby USING btree (distance_km);


--
-- Name: places_nearby_google_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_google_place_id_index ON public.places_nearby USING btree (google_place_id);


--
-- Name: places_nearby_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_latitude_longitude_index ON public.places_nearby USING btree (latitude, longitude);


--
-- Name: places_nearby_location_iq_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_location_iq_place_id_index ON public.places_nearby USING btree (location_iq_place_id);


--
-- Name: places_nearby_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_place_id_index ON public.places_nearby USING btree (place_id);


--
-- Name: places_nearby_place_id_is_active_sort_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_place_id_is_active_sort_order_index ON public.places_nearby USING btree (place_id, is_active, sort_order);


--
-- Name: places_nearby_place_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_place_type_index ON public.places_nearby USING btree (place_type);


--
-- Name: places_nearby_popularity_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_popularity_score_index ON public.places_nearby USING btree (popularity_score);


--
-- Name: places_nearby_recommendation_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_nearby_recommendation_category_index ON public.places_nearby USING btree (recommendation_category);


--
-- Name: places_new_cached_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_new_cached_at_index ON public.places USING btree (cached_at);


--
-- Name: places_new_google_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX places_new_google_place_id_index ON public.places USING btree (google_place_id);


--
-- Name: places_new_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_new_latitude_longitude_index ON public.places USING btree (latitude, longitude);


--
-- Name: places_new_place_types_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_new_place_types_index ON public.places USING btree (categories);


--
-- Name: places_new_rating_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_new_rating_index ON public.places USING btree (rating);


--
-- Name: pois_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pois_category_index ON public.pois USING btree (category);


--
-- Name: pois_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pois_latitude_longitude_index ON public.pois USING btree (latitude, longitude);


--
-- Name: pois_place_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pois_place_id_index ON public.pois USING btree (place_id);


--
-- Name: pois_rating_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pois_rating_index ON public.pois USING btree (rating);


--
-- Name: seasonal_travel_categories_display_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_categories_display_order_index ON public.seasonal_travel_categories USING btree (display_order);


--
-- Name: seasonal_travel_categories_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_categories_is_active_index ON public.seasonal_travel_categories USING btree (is_active);


--
-- Name: seasonal_travel_categories_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX seasonal_travel_categories_name_index ON public.seasonal_travel_categories USING btree (name);


--
-- Name: seasonal_travel_highlights_order_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_highlights_order_index_index ON public.seasonal_travel_highlights USING btree (order_index);


--
-- Name: seasonal_travel_highlights_travel_idea_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_highlights_travel_idea_id_index ON public.seasonal_travel_highlights USING btree (travel_idea_id);


--
-- Name: seasonal_travel_ideas_best_months_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_ideas_best_months_index ON public.seasonal_travel_ideas USING btree (best_months);


--
-- Name: seasonal_travel_ideas_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_ideas_category_id_index ON public.seasonal_travel_ideas USING btree (category_id);


--
-- Name: seasonal_travel_ideas_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_ideas_is_active_index ON public.seasonal_travel_ideas USING btree (is_active);


--
-- Name: seasonal_travel_ideas_is_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_ideas_is_featured_index ON public.seasonal_travel_ideas USING btree (is_featured);


--
-- Name: seasonal_travel_ideas_priority_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_travel_ideas_priority_index ON public.seasonal_travel_ideas USING btree (priority);


--
-- Name: seasonal_weather_info_month_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_weather_info_month_index ON public.seasonal_weather_info USING btree (month);


--
-- Name: seasonal_weather_info_travel_idea_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_weather_info_travel_idea_id_index ON public.seasonal_weather_info USING btree (travel_idea_id);


--
-- Name: seasonal_weather_info_travel_idea_id_month_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX seasonal_weather_info_travel_idea_id_month_index ON public.seasonal_weather_info USING btree (travel_idea_id, month);


--
-- Name: suggested_trips_difficulty_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggested_trips_difficulty_index ON public.suggested_trips USING btree (difficulty);


--
-- Name: suggested_trips_featured_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggested_trips_featured_order_index ON public.suggested_trips USING btree (featured_order);


--
-- Name: suggested_trips_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suggested_trips_is_active_index ON public.suggested_trips USING btree (is_active);


--
-- Name: suggested_trips_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX suggested_trips_slug_index ON public.suggested_trips USING btree (slug);


--
-- Name: trip_activities_action_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_activities_action_index ON public.trip_activities USING btree (action);


--
-- Name: trip_activities_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_activities_inserted_at_index ON public.trip_activities USING btree (inserted_at);


--
-- Name: trip_activities_trip_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_activities_trip_id_index ON public.trip_activities USING btree (trip_id);


--
-- Name: trip_activities_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_activities_user_id_index ON public.trip_activities USING btree (user_id);


--
-- Name: trip_collaborators_permission_level_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_collaborators_permission_level_index ON public.trip_collaborators USING btree (permission_level);


--
-- Name: trip_collaborators_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_collaborators_status_index ON public.trip_collaborators USING btree (status);


--
-- Name: trip_collaborators_trip_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX trip_collaborators_trip_id_user_id_index ON public.trip_collaborators USING btree (trip_id, user_id);


--
-- Name: trip_collaborators_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_collaborators_user_id_index ON public.trip_collaborators USING btree (user_id);


--
-- Name: trip_itinerary_order_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_itinerary_order_index_index ON public.trip_itinerary USING btree (order_index);


--
-- Name: trip_itinerary_trip_id_day_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_itinerary_trip_id_day_index ON public.trip_itinerary USING btree (trip_id, day);


--
-- Name: trip_itinerary_trip_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_itinerary_trip_id_index ON public.trip_itinerary USING btree (trip_id);


--
-- Name: trip_places_latitude_longitude_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_places_latitude_longitude_index ON public.trip_places USING btree (latitude, longitude);


--
-- Name: trip_places_order_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_places_order_index_index ON public.trip_places USING btree (order_index);


--
-- Name: trip_places_trip_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trip_places_trip_id_index ON public.trip_places USING btree (trip_id);


--
-- Name: trips_difficulty_level_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_difficulty_level_index ON public.trips USING btree (difficulty_level);


--
-- Name: trips_end_city_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_end_city_index ON public.trips USING btree (end_city);


--
-- Name: trips_end_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_end_date_index ON public.trips USING btree (end_date);


--
-- Name: trips_is_public_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_is_public_index ON public.trips USING btree (is_public);


--
-- Name: trips_last_modified_by_user_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_last_modified_by_user_at_index ON public.trips USING btree (last_modified_by_user_at);


--
-- Name: trips_share_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX trips_share_token_index ON public.trips USING btree (share_token);


--
-- Name: trips_start_city_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_start_city_index ON public.trips USING btree (start_city);


--
-- Name: trips_start_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_start_date_index ON public.trips USING btree (start_date);


--
-- Name: trips_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_status_index ON public.trips USING btree (status);


--
-- Name: trips_trip_tags_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_trip_tags_index ON public.trips USING gin (trip_tags);


--
-- Name: trips_trip_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_trip_type_index ON public.trips USING btree (trip_type);


--
-- Name: trips_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_user_id_index ON public.trips USING btree (user_id);


--
-- Name: user_interests_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_interests_category_id_index ON public.user_interests USING btree (category_id);


--
-- Name: user_interests_user_id_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_interests_user_id_category_id_index ON public.user_interests USING btree (user_id, category_id);


--
-- Name: user_interests_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_interests_user_id_index ON public.user_interests USING btree (user_id);


--
-- Name: users_new_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_new_email_index ON public.users USING btree (email);


--
-- Name: users_new_google_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_new_google_id_index ON public.users USING btree (google_id);


--
-- Name: users_new_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_new_username_index ON public.users USING btree (username);


--
-- Name: weekly_featured_trips_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_featured_trips_is_active_index ON public.weekly_featured_trips USING btree (is_active);


--
-- Name: weekly_featured_trips_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX weekly_featured_trips_slug_index ON public.weekly_featured_trips USING btree (slug);


--
-- Name: weekly_featured_trips_week_priority_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_featured_trips_week_priority_index ON public.weekly_featured_trips USING btree (week_priority);


--
-- Name: weekly_trip_highlights_order_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_trip_highlights_order_index_index ON public.weekly_trip_highlights USING btree (order_index);


--
-- Name: weekly_trip_highlights_trip_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_trip_highlights_trip_id_index ON public.weekly_trip_highlights USING btree (trip_id);


--
-- Name: weekly_trip_stats_stat_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_trip_stats_stat_type_index ON public.weekly_trip_stats USING btree (stat_type);


--
-- Name: weekly_trip_stats_trip_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_trip_stats_trip_id_index ON public.weekly_trip_stats USING btree (trip_id);


--
-- Name: places places_location_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER places_location_trigger BEFORE INSERT OR UPDATE ON public.places FOR EACH ROW EXECUTE FUNCTION public.update_places_location();


--
-- Name: flight_tracks flight_tracks_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_tracks
    ADD CONSTRAINT flight_tracks_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- Name: flights flights_aircraft_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flights
    ADD CONSTRAINT flights_aircraft_id_fkey FOREIGN KEY (aircraft_id) REFERENCES public.aircraft(id) ON DELETE SET NULL;


--
-- Name: hero_carousel_images hero_carousel_images_approved_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_images
    ADD CONSTRAINT hero_carousel_images_approved_by_user_id_fkey FOREIGN KEY (approved_by_user_id) REFERENCES public.users(id);


--
-- Name: hero_carousel_images hero_carousel_images_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_images
    ADD CONSTRAINT hero_carousel_images_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: hero_carousel_images hero_carousel_images_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_images
    ADD CONSTRAINT hero_carousel_images_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id);


--
-- Name: hero_carousel_performance hero_carousel_performance_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_performance
    ADD CONSTRAINT hero_carousel_performance_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.hero_carousel_images(id) ON DELETE CASCADE;


--
-- Name: hero_carousel_schedules hero_carousel_schedules_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hero_carousel_schedules
    ADD CONSTRAINT hero_carousel_schedules_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.hero_carousel_images(id) ON DELETE CASCADE;


--
-- Name: hidden_gem_experiences hidden_gem_experiences_hidden_gem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_experiences
    ADD CONSTRAINT hidden_gem_experiences_hidden_gem_id_fkey FOREIGN KEY (hidden_gem_id) REFERENCES public.hidden_gems(id) ON DELETE CASCADE;


--
-- Name: hidden_gem_photos hidden_gem_photos_hidden_gem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gem_photos
    ADD CONSTRAINT hidden_gem_photos_hidden_gem_id_fkey FOREIGN KEY (hidden_gem_id) REFERENCES public.hidden_gems(id) ON DELETE CASCADE;


--
-- Name: hidden_gems_tags hidden_gems_tags_hidden_gem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gems_tags
    ADD CONSTRAINT hidden_gems_tags_hidden_gem_id_fkey FOREIGN KEY (hidden_gem_id) REFERENCES public.hidden_gems(id) ON DELETE CASCADE;


--
-- Name: hidden_gems_tags hidden_gems_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_gems_tags
    ADD CONSTRAINT hidden_gems_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.hidden_gem_tags(id) ON DELETE CASCADE;


--
-- Name: places places_default_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_default_image_id_fkey FOREIGN KEY (default_image_id) REFERENCES public.default_images(id) ON DELETE SET NULL;


--
-- Name: places_nearby places_nearby_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places_nearby
    ADD CONSTRAINT places_nearby_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(id) ON DELETE CASCADE;


--
-- Name: seasonal_travel_highlights seasonal_travel_highlights_travel_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_highlights
    ADD CONSTRAINT seasonal_travel_highlights_travel_idea_id_fkey FOREIGN KEY (travel_idea_id) REFERENCES public.seasonal_travel_ideas(id) ON DELETE CASCADE;


--
-- Name: seasonal_travel_ideas seasonal_travel_ideas_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_travel_ideas
    ADD CONSTRAINT seasonal_travel_ideas_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.seasonal_travel_categories(id) ON DELETE RESTRICT;


--
-- Name: seasonal_weather_info seasonal_weather_info_travel_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_weather_info
    ADD CONSTRAINT seasonal_weather_info_travel_idea_id_fkey FOREIGN KEY (travel_idea_id) REFERENCES public.seasonal_travel_ideas(id) ON DELETE CASCADE;


--
-- Name: trip_activities trip_activities_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_activities
    ADD CONSTRAINT trip_activities_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(id) ON DELETE CASCADE;


--
-- Name: trip_activities trip_activities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_activities
    ADD CONSTRAINT trip_activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: trip_collaborators trip_collaborators_invited_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_collaborators
    ADD CONSTRAINT trip_collaborators_invited_by_id_fkey FOREIGN KEY (invited_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: trip_collaborators trip_collaborators_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_collaborators
    ADD CONSTRAINT trip_collaborators_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(id) ON DELETE CASCADE;


--
-- Name: trip_collaborators trip_collaborators_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_collaborators
    ADD CONSTRAINT trip_collaborators_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: trip_itinerary trip_itinerary_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_itinerary
    ADD CONSTRAINT trip_itinerary_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.suggested_trips(id) ON DELETE CASCADE;


--
-- Name: trip_places trip_places_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_places
    ADD CONSTRAINT trip_places_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.suggested_trips(id) ON DELETE CASCADE;


--
-- Name: trips trips_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_interests user_interests_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interests
    ADD CONSTRAINT user_interests_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.interest_categories(id) ON DELETE CASCADE;


--
-- Name: user_interests user_interests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interests
    ADD CONSTRAINT user_interests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: weekly_trip_highlights weekly_trip_highlights_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_trip_highlights
    ADD CONSTRAINT weekly_trip_highlights_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.weekly_featured_trips(id) ON DELETE CASCADE;


--
-- Name: weekly_trip_stats weekly_trip_stats_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_trip_stats
    ADD CONSTRAINT weekly_trip_stats_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.weekly_featured_trips(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20250804004610);
INSERT INTO public."schema_migrations" (version) VALUES (20250804184355);
INSERT INTO public."schema_migrations" (version) VALUES (20250804201835);
INSERT INTO public."schema_migrations" (version) VALUES (20250804203749);
INSERT INTO public."schema_migrations" (version) VALUES (20250804204200);
INSERT INTO public."schema_migrations" (version) VALUES (20250806190814);
INSERT INTO public."schema_migrations" (version) VALUES (20250807205320);
INSERT INTO public."schema_migrations" (version) VALUES (20250808232854);
INSERT INTO public."schema_migrations" (version) VALUES (20250809015642);
INSERT INTO public."schema_migrations" (version) VALUES (20250809185328);
INSERT INTO public."schema_migrations" (version) VALUES (20250811075539);
INSERT INTO public."schema_migrations" (version) VALUES (20250811075719);
INSERT INTO public."schema_migrations" (version) VALUES (20250811075738);
INSERT INTO public."schema_migrations" (version) VALUES (20250811075809);
INSERT INTO public."schema_migrations" (version) VALUES (20250811192457);
INSERT INTO public."schema_migrations" (version) VALUES (20250812190716);
INSERT INTO public."schema_migrations" (version) VALUES (20250812204050);
INSERT INTO public."schema_migrations" (version) VALUES (20250813070121);
INSERT INTO public."schema_migrations" (version) VALUES (20250813085955);
INSERT INTO public."schema_migrations" (version) VALUES (20250813100735);
INSERT INTO public."schema_migrations" (version) VALUES (20250813113626);
INSERT INTO public."schema_migrations" (version) VALUES (20250813231351);
INSERT INTO public."schema_migrations" (version) VALUES (20250814172443);
INSERT INTO public."schema_migrations" (version) VALUES (20250814172850);
INSERT INTO public."schema_migrations" (version) VALUES (20250815060112);
INSERT INTO public."schema_migrations" (version) VALUES (20250815070254);
INSERT INTO public."schema_migrations" (version) VALUES (20250815194719);
INSERT INTO public."schema_migrations" (version) VALUES (20250815195214);
INSERT INTO public."schema_migrations" (version) VALUES (20250815200027);
INSERT INTO public."schema_migrations" (version) VALUES (20250815203012);
INSERT INTO public."schema_migrations" (version) VALUES (20250815203052);
INSERT INTO public."schema_migrations" (version) VALUES (20250815224105);
INSERT INTO public."schema_migrations" (version) VALUES (20250817011006);
INSERT INTO public."schema_migrations" (version) VALUES (20250817012220);
INSERT INTO public."schema_migrations" (version) VALUES (20250817024814);
INSERT INTO public."schema_migrations" (version) VALUES (20250817035454);
INSERT INTO public."schema_migrations" (version) VALUES (20250817203946);
INSERT INTO public."schema_migrations" (version) VALUES (20250818011227);
INSERT INTO public."schema_migrations" (version) VALUES (20250818030028);
INSERT INTO public."schema_migrations" (version) VALUES (20250818143338);
INSERT INTO public."schema_migrations" (version) VALUES (20250924021757);
INSERT INTO public."schema_migrations" (version) VALUES (20250924023603);
INSERT INTO public."schema_migrations" (version) VALUES (20250924080647);
INSERT INTO public."schema_migrations" (version) VALUES (20250925212026);
INSERT INTO public."schema_migrations" (version) VALUES (20250925212058);
INSERT INTO public."schema_migrations" (version) VALUES (20250927032459);
