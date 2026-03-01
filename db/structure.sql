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
-- Name: dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboards (
    id bigint NOT NULL,
    name character varying NOT NULL,
    author_id bigint NOT NULL,
    workspace_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboards_id_seq OWNED BY public.dashboards.id;


--
-- Name: data_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_sources (
    id bigint NOT NULL,
    url character varying NOT NULL,
    external_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    verified_at timestamp(6) without time zone,
    workspace_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: data_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_sources_id_seq OWNED BY public.data_sources.id;


--
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    id bigint NOT NULL,
    role integer NOT NULL,
    user_id bigint,
    workspace_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status integer NOT NULL,
    invitation character varying,
    invited_by_id bigint
);


--
-- Name: members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.members_id_seq OWNED BY public.members.id;


--
-- Name: one_time_passwords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.one_time_passwords (
    id bigint NOT NULL,
    email character varying,
    token character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: one_time_passwords_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.one_time_passwords_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: one_time_passwords_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.one_time_passwords_id_seq OWNED BY public.one_time_passwords.id;


--
-- Name: queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.queries (
    id bigint NOT NULL,
    name character varying,
    query character varying NOT NULL,
    saved boolean DEFAULT false NOT NULL,
    last_run_at timestamp(6) without time zone,
    author_id bigint NOT NULL,
    last_updated_by_id bigint,
    data_source_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    chart_type character varying,
    chart_config jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.queries_id_seq OWNED BY public.queries.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: translation_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.translation_keys (
    id bigint NOT NULL,
    key character varying NOT NULL,
    notes text,
    area_tags text[] DEFAULT '{}'::text[] NOT NULL,
    type_tags text[] DEFAULT '{}'::text[] NOT NULL,
    used_in jsonb DEFAULT '[]'::jsonb NOT NULL,
    content_scope character varying DEFAULT 'system'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: translation_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.translation_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.translation_keys_id_seq OWNED BY public.translation_keys.id;


--
-- Name: translation_value_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.translation_value_revisions (
    id bigint NOT NULL,
    translation_value_id bigint NOT NULL,
    locale character varying NOT NULL,
    old_value text,
    new_value text,
    changed_by_id bigint,
    change_source character varying DEFAULT 'manual'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: translation_value_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.translation_value_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_value_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.translation_value_revisions_id_seq OWNED BY public.translation_value_revisions.id;


--
-- Name: translation_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.translation_values (
    id bigint NOT NULL,
    translation_key_id bigint NOT NULL,
    locale character varying NOT NULL,
    value text,
    source character varying DEFAULT 'seed'::character varying NOT NULL,
    updated_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: translation_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.translation_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.translation_values_id_seq OWNED BY public.translation_values.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    terms_accepted_at timestamp(6) without time zone,
    terms_version character varying,
    pending_email character varying,
    email_change_verification_token character varying,
    email_change_verification_sent_at timestamp(6) without time zone,
    super_admin boolean DEFAULT false NOT NULL,
    preferred_locale character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspaces (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspaces_id_seq OWNED BY public.workspaces.id;


--
-- Name: dashboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards ALTER COLUMN id SET DEFAULT nextval('public.dashboards_id_seq'::regclass);


--
-- Name: data_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources ALTER COLUMN id SET DEFAULT nextval('public.data_sources_id_seq'::regclass);


--
-- Name: members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members ALTER COLUMN id SET DEFAULT nextval('public.members_id_seq'::regclass);


--
-- Name: one_time_passwords id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_passwords ALTER COLUMN id SET DEFAULT nextval('public.one_time_passwords_id_seq'::regclass);


--
-- Name: queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queries ALTER COLUMN id SET DEFAULT nextval('public.queries_id_seq'::regclass);


--
-- Name: translation_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_keys ALTER COLUMN id SET DEFAULT nextval('public.translation_keys_id_seq'::regclass);


--
-- Name: translation_value_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_value_revisions ALTER COLUMN id SET DEFAULT nextval('public.translation_value_revisions_id_seq'::regclass);


--
-- Name: translation_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_values ALTER COLUMN id SET DEFAULT nextval('public.translation_values_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces ALTER COLUMN id SET DEFAULT nextval('public.workspaces_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: dashboards dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_pkey PRIMARY KEY (id);


--
-- Name: data_sources data_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_pkey PRIMARY KEY (id);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (id);


--
-- Name: one_time_passwords one_time_passwords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_passwords
    ADD CONSTRAINT one_time_passwords_pkey PRIMARY KEY (id);


--
-- Name: queries queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queries
    ADD CONSTRAINT queries_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: translation_keys translation_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_keys
    ADD CONSTRAINT translation_keys_pkey PRIMARY KEY (id);


--
-- Name: translation_value_revisions translation_value_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_value_revisions
    ADD CONSTRAINT translation_value_revisions_pkey PRIMARY KEY (id);


--
-- Name: translation_values translation_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_values
    ADD CONSTRAINT translation_values_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: index_dashboards_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboards_on_workspace_id ON public.dashboards USING btree (workspace_id);


--
-- Name: index_data_sources_on_external_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_data_sources_on_external_uuid ON public.data_sources USING btree (external_uuid);


--
-- Name: index_data_sources_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_data_sources_on_url ON public.data_sources USING btree (url);


--
-- Name: index_data_sources_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_sources_on_workspace_id ON public.data_sources USING btree (workspace_id);


--
-- Name: index_members_on_invitation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_invitation ON public.members USING btree (invitation);


--
-- Name: index_members_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_user_id ON public.members USING btree (user_id);


--
-- Name: index_members_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_workspace_id ON public.members USING btree (workspace_id);


--
-- Name: index_one_time_passwords_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_one_time_passwords_on_email ON public.one_time_passwords USING btree (email);


--
-- Name: index_queries_on_data_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_queries_on_data_source_id ON public.queries USING btree (data_source_id);


--
-- Name: index_translation_keys_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_translation_keys_on_key ON public.translation_keys USING btree (key);


--
-- Name: index_translation_value_revisions_on_changed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_value_revisions_on_changed_by_id ON public.translation_value_revisions USING btree (changed_by_id);


--
-- Name: index_translation_value_revisions_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_value_revisions_on_locale ON public.translation_value_revisions USING btree (locale);


--
-- Name: index_translation_value_revisions_on_translation_value_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_value_revisions_on_translation_value_id ON public.translation_value_revisions USING btree (translation_value_id);


--
-- Name: index_translation_values_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_values_on_locale ON public.translation_values USING btree (locale);


--
-- Name: index_translation_values_on_translation_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_values_on_translation_key_id ON public.translation_values USING btree (translation_key_id);


--
-- Name: index_translation_values_on_translation_key_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_translation_values_on_translation_key_id_and_locale ON public.translation_values USING btree (translation_key_id, locale);


--
-- Name: index_translation_values_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_values_on_updated_by_id ON public.translation_values USING btree (updated_by_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_email_change_verification_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_change_verification_token ON public.users USING btree (email_change_verification_token);


--
-- Name: translation_value_revisions fk_rails_6dd91d72ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_value_revisions
    ADD CONSTRAINT fk_rails_6dd91d72ee FOREIGN KEY (translation_value_id) REFERENCES public.translation_values(id);


--
-- Name: translation_values fk_rails_78f391b731; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_values
    ADD CONSTRAINT fk_rails_78f391b731 FOREIGN KEY (translation_key_id) REFERENCES public.translation_keys(id);


--
-- Name: translation_value_revisions fk_rails_a84de18dce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_value_revisions
    ADD CONSTRAINT fk_rails_a84de18dce FOREIGN KEY (changed_by_id) REFERENCES public.users(id);


--
-- Name: translation_values fk_rails_d2e300e7c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_values
    ADD CONSTRAINT fk_rails_d2e300e7c2 FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260301100100'),
('20260301100000'),
('20260220153000'),
('20260217221000'),
('20260216111500'),
('20240311191638'),
('20240122193609'),
('20240122193346'),
('20240112090044'),
('20231222144500'),
('20231221122435'),
('20231221102848');

