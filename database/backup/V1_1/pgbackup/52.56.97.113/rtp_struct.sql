--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.11
-- Dumped by pg_dump version 9.6.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: tb_area_server; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_area_server (
    area_type smallint NOT NULL,
    server_id uuid
);


ALTER TABLE tb_area_server OWNER TO admin;

--
-- Name: tb_ip_area_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ip_area_info (
    ip_start_point inet NOT NULL,
    ip_end_point inet NOT NULL,
    ip_area_type smallint DEFAULT 1 NOT NULL,
    ip_area_name text
);


ALTER TABLE tb_ip_area_info OWNER TO admin;

--
-- Name: COLUMN tb_ip_area_info.ip_start_point; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ip_area_info.ip_start_point IS '网段起点';


--
-- Name: COLUMN tb_ip_area_info.ip_end_point; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ip_area_info.ip_end_point IS '网段终点';


--
-- Name: COLUMN tb_ip_area_info.ip_area_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ip_area_info.ip_area_type IS '1：大陆 2：香港 ';


--
-- Name: tb_rtp_stream; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtp_stream (
    media_id integer NOT NULL,
    media_generate_time timestamp without time zone,
    media_module_id text DEFAULT 'unkown'::text NOT NULL,
    media_terminal_id text DEFAULT 'unkown'::text NOT NULL,
    media_type smallint DEFAULT 2 NOT NULL,
    media_codec text DEFAULT 'unkown'::text NOT NULL,
    media_worker_id uuid
);


ALTER TABLE tb_rtp_stream OWNER TO admin;

--
-- Name: COLUMN tb_rtp_stream.media_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.media_id IS 'ssrc';


--
-- Name: COLUMN tb_rtp_stream.media_module_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.media_module_id IS '模块名';


--
-- Name: COLUMN tb_rtp_stream.media_terminal_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.media_terminal_id IS '终端id';


--
-- Name: COLUMN tb_rtp_stream.media_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.media_type IS '终端类型, 1视频, 2语音';


--
-- Name: COLUMN tb_rtp_stream.media_worker_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.media_worker_id IS '所在worker id';


--
-- Name: tb_rtp_worker; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtp_worker (
    server_id uuid NOT NULL,
    server_ip text NOT NULL,
    http_port integer NOT NULL,
    tcp_port integer NOT NULL,
    rtp_port integer NOT NULL,
    rtcp_port integer NOT NULL,
    bandwidth_rate smallint NOT NULL,
    last_update_time timestamp without time zone NOT NULL,
    server_status smallint DEFAULT 0 NOT NULL
);


ALTER TABLE tb_rtp_worker OWNER TO admin;

--
-- Name: COLUMN tb_rtp_worker.server_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_worker.server_status IS '0不再使用, 1正在使用';


--
-- Name: tb_ssrc_gen; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ssrc_gen (
    ssrc_key_id uuid NOT NULL,
    ssrc_id integer NOT NULL,
    ssrc_update_time timestamp without time zone
);


ALTER TABLE tb_ssrc_gen OWNER TO admin;

--
-- Name: tb_stream_relationship; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_stream_relationship (
    relation_id uuid NOT NULL,
    part1_ssrc integer,
    part2_ssrc integer,
    relation_generate_time timestamp without time zone
);


ALTER TABLE tb_stream_relationship OWNER TO admin;

--
-- Name: tb_ip_area_info tb_ip_area_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ip_area_info
    ADD CONSTRAINT tb_ip_area_info_pkey PRIMARY KEY (ip_start_point);


--
-- Name: tb_rtp_stream tb_rtp_ssrc_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtp_stream
    ADD CONSTRAINT tb_rtp_ssrc_pkey PRIMARY KEY (media_id);


--
-- Name: tb_rtp_worker tb_rtp_worker_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtp_worker
    ADD CONSTRAINT tb_rtp_worker_pkey PRIMARY KEY (server_id);


--
-- Name: tb_ssrc_gen tb_ssrc_gen_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ssrc_gen
    ADD CONSTRAINT tb_ssrc_gen_pkey PRIMARY KEY (ssrc_key_id);


--
-- Name: tb_stream_relationship tb_stream_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_stream_relationship
    ADD CONSTRAINT tb_stream_relationship_pkey PRIMARY KEY (relation_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

