--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.8
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

--
-- Name: tb_soft_version_info_delete_trigger(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION tb_soft_version_info_delete_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
insert into tb_soft_version_info_history values(OLD.*);
return null;
end;
$$;


ALTER FUNCTION public.tb_soft_version_info_delete_trigger() OWNER TO admin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: tb_soft_version_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_soft_version_info (
    soft_id uuid NOT NULL,
    soft_name text,
    soft_version text NOT NULL,
    soft_upgrade_type integer NOT NULL,
    soft_release_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    soft_note text,
    soft_dowload_url text NOT NULL,
    soft_file_md5 text,
    soft_os_name text NOT NULL,
    soft_os_type integer NOT NULL,
    soft_os_version text NOT NULL
);


ALTER TABLE tb_soft_version_info OWNER TO admin;

--
-- Name: COLUMN tb_soft_version_info.soft_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_name IS '软件名称';


--
-- Name: COLUMN tb_soft_version_info.soft_version; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_version IS 'APP版本号';


--
-- Name: COLUMN tb_soft_version_info.soft_upgrade_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_upgrade_type IS '升级类型：
1、普通升级
2、强制升级';


--
-- Name: COLUMN tb_soft_version_info.soft_release_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_release_time IS '版本发布时间';


--
-- Name: COLUMN tb_soft_version_info.soft_note; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_note IS '版本说明';


--
-- Name: COLUMN tb_soft_version_info.soft_dowload_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_dowload_url IS 'APP版本下载地址';


--
-- Name: COLUMN tb_soft_version_info.soft_file_md5; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_file_md5 IS '上传文件签名';


--
-- Name: COLUMN tb_soft_version_info.soft_os_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_os_name IS '运行系统平台 1：android, 2：ios, 3：windows,4:elinux-arm';


--
-- Name: COLUMN tb_soft_version_info.soft_os_version; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info.soft_os_version IS '运行系统平台版本（x.x.x）';


--
-- Name: tb_soft_version_info_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_soft_version_info_history (
    soft_id uuid NOT NULL,
    soft_name text,
    soft_version text NOT NULL,
    soft_upgrade_type integer NOT NULL,
    soft_release_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    soft_note text,
    soft_dowload_url text NOT NULL,
    soft_file_md5 text,
    soft_os_name text NOT NULL,
    soft_os_type integer NOT NULL,
    soft_os_version text NOT NULL
);


ALTER TABLE tb_soft_version_info_history OWNER TO admin;

--
-- Name: COLUMN tb_soft_version_info_history.soft_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_name IS '软件名称';


--
-- Name: COLUMN tb_soft_version_info_history.soft_version; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_version IS 'APP版本号';


--
-- Name: COLUMN tb_soft_version_info_history.soft_upgrade_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_upgrade_type IS '升级类型：
1、普通升级
2、强制升级';


--
-- Name: COLUMN tb_soft_version_info_history.soft_release_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_release_time IS '版本发布时间';


--
-- Name: COLUMN tb_soft_version_info_history.soft_note; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_note IS '版本说明';


--
-- Name: COLUMN tb_soft_version_info_history.soft_dowload_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_dowload_url IS 'APP版本下载地址';


--
-- Name: COLUMN tb_soft_version_info_history.soft_file_md5; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_file_md5 IS '上传文件签名';


--
-- Name: COLUMN tb_soft_version_info_history.soft_os_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_os_name IS '运行系统平台 1：android, 2：ios, 3：windows,4:elinux-arm';


--
-- Name: COLUMN tb_soft_version_info_history.soft_os_version; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_soft_version_info_history.soft_os_version IS '运行系统平台版本（x.x.x）';


--
-- Name: tb_soft_version_info_history tb_soft_version_info_history_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_soft_version_info_history
    ADD CONSTRAINT tb_soft_version_info_history_pkey PRIMARY KEY (soft_id);


--
-- Name: tb_soft_version_info tb_soft_version_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_soft_version_info
    ADD CONSTRAINT tb_soft_version_info_pkey PRIMARY KEY (soft_id);


--
-- Name: tb_soft_version_info tb_soft_version_info_soft_name_soft_version_soft_system_typ_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_soft_version_info
    ADD CONSTRAINT tb_soft_version_info_soft_name_soft_version_soft_system_typ_key UNIQUE (soft_name, soft_os_type);


--
-- Name: tb_soft_version_info delete_insert_history; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER delete_insert_history AFTER DELETE ON tb_soft_version_info FOR EACH ROW EXECUTE PROCEDURE tb_soft_version_info_delete_trigger();


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

