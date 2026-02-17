SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: clicks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clicks (
    uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    data_source_uuid uuid NOT NULL,
    session_uuid uuid NOT NULL,
    visitor_uuid uuid NOT NULL,
    "timestamp" bigint NOT NULL,
    coordinates_x integer NOT NULL,
    coordinates_y integer NOT NULL,
    selector character varying NOT NULL,
    inner_text character varying,
    attribute_id character varying,
    attribute_class character varying
);

ALTER TABLE ONLY public.clicks FORCE ROW LEVEL SECURITY;


--
-- Name: page_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.page_views (
    uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    data_source_uuid uuid NOT NULL,
    session_uuid uuid NOT NULL,
    visitor_uuid uuid NOT NULL,
    "timestamp" bigint NOT NULL,
    url character varying NOT NULL
);

ALTER TABLE ONLY public.page_views FORCE ROW LEVEL SECURITY;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    data_source_uuid uuid NOT NULL,
    session_uuid uuid NOT NULL,
    visitor_uuid uuid NOT NULL,
    "timestamp" bigint NOT NULL,
    viewport_x integer NOT NULL,
    viewport_y integer NOT NULL,
    device_x integer NOT NULL,
    device_y integer NOT NULL,
    referrer character varying,
    locale character varying,
    useragent character varying,
    browser character varying,
    timezone character varying,
    country_code character varying,
    utm_source character varying,
    utm_medium character varying,
    utm_campaign character varying,
    utm_content character varying,
    utm_term character varying
);

ALTER TABLE ONLY public.sessions FORCE ROW LEVEL SECURITY;


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: clicks clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clicks
    ADD CONSTRAINT clicks_pkey PRIMARY KEY (uuid);


--
-- Name: page_views page_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_views
    ADD CONSTRAINT page_views_pkey PRIMARY KEY (uuid);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (uuid);


--
-- Name: index_clicks_on_data_source_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clicks_on_data_source_uuid ON public.clicks USING btree (data_source_uuid);


--
-- Name: index_page_views_on_data_source_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_page_views_on_data_source_uuid ON public.page_views USING btree (data_source_uuid);


--
-- Name: index_sessions_on_data_source_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_data_source_uuid ON public.sessions USING btree (data_source_uuid);


--
-- Name: clicks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.clicks ENABLE ROW LEVEL SECURITY;

--
-- Name: clicks clicks_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clicks_policy ON public.clicks FOR SELECT USING ((data_source_uuid = (current_setting('app.current_data_source_uuid'::text, true))::uuid));


--
-- Name: page_views; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.page_views ENABLE ROW LEVEL SECURITY;

--
-- Name: page_views page_views_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY page_views_policy ON public.page_views FOR SELECT USING ((data_source_uuid = (current_setting('app.current_data_source_uuid'::text, true))::uuid));


--
-- Name: sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions sessions_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sessions_policy ON public.sessions FOR SELECT USING ((data_source_uuid = (current_setting('app.current_data_source_uuid'::text, true))::uuid));


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260217161000'),
('20240120104626'),
('20240120104604'),
('20240120104545');

