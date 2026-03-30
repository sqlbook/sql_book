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
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


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
-- Name: chat_action_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_action_requests (
    id bigint NOT NULL,
    chat_thread_id bigint NOT NULL,
    chat_message_id bigint,
    requested_by_id bigint,
    action_type character varying NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    result_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    confirmation_token character varying,
    confirmation_expires_at timestamp(6) without time zone,
    executed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    idempotency_key character varying,
    source_message_id bigint,
    action_fingerprint character varying,
    superseded_at timestamp(6) without time zone
);


--
-- Name: chat_action_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_action_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_action_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_action_requests_id_seq OWNED BY public.chat_action_requests.id;


--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_messages (
    id bigint NOT NULL,
    chat_thread_id bigint NOT NULL,
    user_id bigint,
    role integer NOT NULL,
    status integer DEFAULT 2 NOT NULL,
    content text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;


--
-- Name: chat_pending_follow_ups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_pending_follow_ups (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    chat_thread_id bigint NOT NULL,
    created_by_id bigint NOT NULL,
    source_message_id bigint,
    status integer DEFAULT 1 NOT NULL,
    kind character varying NOT NULL,
    domain character varying NOT NULL,
    target_type character varying,
    target_id bigint,
    payload json DEFAULT '{}'::json NOT NULL,
    resolved_at timestamp(6) without time zone,
    superseded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_pending_follow_ups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_pending_follow_ups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_pending_follow_ups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_pending_follow_ups_id_seq OWNED BY public.chat_pending_follow_ups.id;


--
-- Name: chat_query_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_query_references (
    id bigint NOT NULL,
    chat_thread_id bigint NOT NULL,
    source_message_id bigint,
    result_message_id bigint,
    data_source_id bigint,
    saved_query_id bigint,
    original_question text,
    sql text,
    current_name character varying,
    name_aliases jsonb DEFAULT '[]'::jsonb NOT NULL,
    row_count integer,
    columns jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    refined_from_reference_id bigint
);


--
-- Name: chat_query_references_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_query_references_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_query_references_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_query_references_id_seq OWNED BY public.chat_query_references.id;


--
-- Name: chat_threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_threads (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    created_by_id bigint,
    title character varying,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: chat_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_threads_id_seq OWNED BY public.chat_threads.id;


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
    url character varying,
    external_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    verified_at timestamp(6) without time zone,
    workspace_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    source_type integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    last_checked_at timestamp(6) without time zone,
    last_error text,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    encrypted_connection_password text
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
    chart_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    query_fingerprint character varying
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
    preferred_locale character varying,
    last_active_at timestamp(6) without time zone
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
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: chat_action_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_action_requests ALTER COLUMN id SET DEFAULT nextval('public.chat_action_requests_id_seq'::regclass);


--
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);


--
-- Name: chat_pending_follow_ups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pending_follow_ups ALTER COLUMN id SET DEFAULT nextval('public.chat_pending_follow_ups_id_seq'::regclass);


--
-- Name: chat_query_references id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references ALTER COLUMN id SET DEFAULT nextval('public.chat_query_references_id_seq'::regclass);


--
-- Name: chat_threads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_threads ALTER COLUMN id SET DEFAULT nextval('public.chat_threads_id_seq'::regclass);


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
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: chat_action_requests chat_action_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_action_requests
    ADD CONSTRAINT chat_action_requests_pkey PRIMARY KEY (id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_pending_follow_ups chat_pending_follow_ups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pending_follow_ups
    ADD CONSTRAINT chat_pending_follow_ups_pkey PRIMARY KEY (id);


--
-- Name: chat_query_references chat_query_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT chat_query_references_pkey PRIMARY KEY (id);


--
-- Name: chat_threads chat_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT chat_threads_pkey PRIMARY KEY (id);


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
-- Name: idx_chat_action_requests_active_pending_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_chat_action_requests_active_pending_fingerprint ON public.chat_action_requests USING btree (chat_thread_id, requested_by_id, action_fingerprint) WHERE ((status = 1) AND (superseded_at IS NULL));


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_chat_action_requests_on_action_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_action_requests_on_action_fingerprint ON public.chat_action_requests USING btree (action_fingerprint);


--
-- Name: index_chat_action_requests_on_chat_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_action_requests_on_chat_message_id ON public.chat_action_requests USING btree (chat_message_id);


--
-- Name: index_chat_action_requests_on_chat_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_action_requests_on_chat_thread_id ON public.chat_action_requests USING btree (chat_thread_id);


--
-- Name: index_chat_action_requests_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_action_requests_on_confirmation_token ON public.chat_action_requests USING btree (confirmation_token);


--
-- Name: index_chat_action_requests_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_action_requests_on_idempotency_key ON public.chat_action_requests USING btree (idempotency_key);


--
-- Name: index_chat_action_requests_on_requested_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_action_requests_on_requested_by_id ON public.chat_action_requests USING btree (requested_by_id);


--
-- Name: index_chat_messages_on_chat_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_messages_on_chat_thread_id ON public.chat_messages USING btree (chat_thread_id);


--
-- Name: index_chat_messages_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_messages_on_user_id ON public.chat_messages USING btree (user_id);


--
-- Name: index_chat_pending_follow_ups_on_active_thread_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_pending_follow_ups_on_active_thread_actor ON public.chat_pending_follow_ups USING btree (chat_thread_id, created_by_id) WHERE ((status = 1) AND (superseded_at IS NULL));


--
-- Name: index_chat_pending_follow_ups_on_chat_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_pending_follow_ups_on_chat_thread_id ON public.chat_pending_follow_ups USING btree (chat_thread_id);


--
-- Name: index_chat_pending_follow_ups_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_pending_follow_ups_on_created_by_id ON public.chat_pending_follow_ups USING btree (created_by_id);


--
-- Name: index_chat_pending_follow_ups_on_source_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_pending_follow_ups_on_source_message_id ON public.chat_pending_follow_ups USING btree (source_message_id);


--
-- Name: index_chat_pending_follow_ups_on_thread_kind_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_pending_follow_ups_on_thread_kind_status ON public.chat_pending_follow_ups USING btree (chat_thread_id, kind, status);


--
-- Name: index_chat_pending_follow_ups_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_pending_follow_ups_on_workspace_id ON public.chat_pending_follow_ups USING btree (workspace_id);


--
-- Name: index_chat_query_references_on_chat_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_chat_thread_id ON public.chat_query_references USING btree (chat_thread_id);


--
-- Name: index_chat_query_references_on_data_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_data_source_id ON public.chat_query_references USING btree (data_source_id);


--
-- Name: index_chat_query_references_on_refined_from_reference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_refined_from_reference_id ON public.chat_query_references USING btree (refined_from_reference_id);


--
-- Name: index_chat_query_references_on_result_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_result_message_id ON public.chat_query_references USING btree (result_message_id);


--
-- Name: index_chat_query_references_on_saved_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_saved_query_id ON public.chat_query_references USING btree (saved_query_id);


--
-- Name: index_chat_query_references_on_source_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_source_message_id ON public.chat_query_references USING btree (source_message_id);


--
-- Name: index_chat_query_references_on_thread_and_saved_query; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_query_references_on_thread_and_saved_query ON public.chat_query_references USING btree (chat_thread_id, saved_query_id) WHERE (saved_query_id IS NOT NULL);


--
-- Name: index_chat_query_references_on_thread_recency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_query_references_on_thread_recency ON public.chat_query_references USING btree (chat_thread_id, updated_at, id);


--
-- Name: index_chat_threads_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_created_by_id ON public.chat_threads USING btree (created_by_id);


--
-- Name: index_chat_threads_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_workspace_id ON public.chat_threads USING btree (workspace_id);


--
-- Name: index_dashboards_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboards_on_workspace_id ON public.dashboards USING btree (workspace_id);


--
-- Name: index_data_sources_on_external_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_data_sources_on_external_uuid ON public.data_sources USING btree (external_uuid);


--
-- Name: index_data_sources_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_sources_on_workspace_id ON public.data_sources USING btree (workspace_id);


--
-- Name: index_data_sources_on_workspace_id_and_source_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_sources_on_workspace_id_and_source_type ON public.data_sources USING btree (workspace_id, source_type);


--
-- Name: index_data_sources_on_workspace_id_and_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_data_sources_on_workspace_id_and_url ON public.data_sources USING btree (workspace_id, url) WHERE (url IS NOT NULL);


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
-- Name: index_queries_on_data_source_and_query_fingerprint_saved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_queries_on_data_source_and_query_fingerprint_saved ON public.queries USING btree (data_source_id, query_fingerprint) WHERE ((saved = true) AND (query_fingerprint IS NOT NULL));


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
-- Name: index_users_on_last_active_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_active_at ON public.users USING btree (last_active_at);


--
-- Name: chat_query_references fk_rails_1c34be061a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT fk_rails_1c34be061a FOREIGN KEY (data_source_id) REFERENCES public.data_sources(id);


--
-- Name: chat_pending_follow_ups fk_rails_3b588cfbf4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pending_follow_ups
    ADD CONSTRAINT fk_rails_3b588cfbf4 FOREIGN KEY (chat_thread_id) REFERENCES public.chat_threads(id);


--
-- Name: chat_messages fk_rails_43b6215c4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT fk_rails_43b6215c4f FOREIGN KEY (chat_thread_id) REFERENCES public.chat_threads(id);


--
-- Name: chat_threads fk_rails_6c21a7e19d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT fk_rails_6c21a7e19d FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


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
-- Name: chat_query_references fk_rails_85c07b9570; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT fk_rails_85c07b9570 FOREIGN KEY (refined_from_reference_id) REFERENCES public.chat_query_references(id);


--
-- Name: chat_query_references fk_rails_87563b0ae2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT fk_rails_87563b0ae2 FOREIGN KEY (chat_thread_id) REFERENCES public.chat_threads(id);


--
-- Name: chat_pending_follow_ups fk_rails_88d3cce4f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pending_follow_ups
    ADD CONSTRAINT fk_rails_88d3cce4f3 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: chat_action_requests fk_rails_90dd8c1a9a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_action_requests
    ADD CONSTRAINT fk_rails_90dd8c1a9a FOREIGN KEY (chat_thread_id) REFERENCES public.chat_threads(id);


--
-- Name: chat_messages fk_rails_918ef7acc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT fk_rails_918ef7acc4 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: chat_action_requests fk_rails_950b283dab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_action_requests
    ADD CONSTRAINT fk_rails_950b283dab FOREIGN KEY (chat_message_id) REFERENCES public.chat_messages(id);


--
-- Name: chat_query_references fk_rails_98b2326ff1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT fk_rails_98b2326ff1 FOREIGN KEY (source_message_id) REFERENCES public.chat_messages(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: chat_pending_follow_ups fk_rails_a7931f28bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pending_follow_ups
    ADD CONSTRAINT fk_rails_a7931f28bb FOREIGN KEY (source_message_id) REFERENCES public.chat_messages(id);


--
-- Name: translation_value_revisions fk_rails_a84de18dce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_value_revisions
    ADD CONSTRAINT fk_rails_a84de18dce FOREIGN KEY (changed_by_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: chat_query_references fk_rails_d1d24bdc87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT fk_rails_d1d24bdc87 FOREIGN KEY (result_message_id) REFERENCES public.chat_messages(id);


--
-- Name: chat_query_references fk_rails_d27cdc8ea3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_query_references
    ADD CONSTRAINT fk_rails_d27cdc8ea3 FOREIGN KEY (saved_query_id) REFERENCES public.queries(id);


--
-- Name: translation_values fk_rails_d2e300e7c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_values
    ADD CONSTRAINT fk_rails_d2e300e7c2 FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- Name: chat_threads fk_rails_e7b44b3252; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT fk_rails_e7b44b3252 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: chat_action_requests fk_rails_ecc9b5dd91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_action_requests
    ADD CONSTRAINT fk_rails_ecc9b5dd91 FOREIGN KEY (requested_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: chat_action_requests fk_rails_f0e2d1b847; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_action_requests
    ADD CONSTRAINT fk_rails_f0e2d1b847 FOREIGN KEY (source_message_id) REFERENCES public.chat_messages(id);


--
-- Name: chat_pending_follow_ups fk_rails_f7f0ffd59d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pending_follow_ups
    ADD CONSTRAINT fk_rails_f7f0ffd59d FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260330100000'),
('20260322110000'),
('20260321170000'),
('20260321113000'),
('20260320110000'),
('20260316143000'),
('20260309102000'),
('20260307150100'),
('20260307150000'),
('20260305091000'),
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

