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
-- Name: tb_area_server_realtime; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_area_server_realtime (
    area_type smallint NOT NULL,
    server_id uuid
);


ALTER TABLE tb_area_server_realtime OWNER TO admin;

--
-- Name: tb_area_server_record; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_area_server_record (
    area_type smallint NOT NULL,
    server_id uuid
);


ALTER TABLE tb_area_server_record OWNER TO admin;

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
-- Name: tb_realtime_worker; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_realtime_worker (
    server_id uuid NOT NULL,
    server_ip text NOT NULL,
    server_http_port integer NOT NULL,
    server_rtsp_port integer NOT NULL,
    server_cpu_usage integer NOT NULL,
    server_mem_usage integer NOT NULL,
    rtsp_conn_num integer NOT NULL,
    last_update_time timestamp without time zone,
    server_available_bandwidth integer DEFAULT 0 NOT NULL,
    server_total_bandwidth integer DEFAULT 0 NOT NULL
);


ALTER TABLE tb_realtime_worker OWNER TO admin;

--
-- Name: COLUMN tb_realtime_worker.server_available_bandwidth; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_realtime_worker.server_available_bandwidth IS '服务器可用带宽';


--
-- Name: COLUMN tb_realtime_worker.server_total_bandwidth; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_realtime_worker.server_total_bandwidth IS '服务器总带宽';


--
-- Name: tb_record; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_record (
    record_id uuid NOT NULL,
    record_address_id text,
    record_services_id uuid NOT NULL,
    record_src_id text NOT NULL,
    record_replay_url text NOT NULL,
    record_inner_file_name text NOT NULL,
    record_img_url text NOT NULL,
    record_rtsp_url text NOT NULL,
    record_start_time timestamp without time zone,
    record_stop_time timestamp without time zone,
    record_type integer DEFAULT 0 NOT NULL,
    record_file_size bigint NOT NULL,
    record_status integer DEFAULT 1 NOT NULL,
    record_duration integer,
    record_resolution integer,
    record_http_url text NOT NULL,
    caller_type text,
    record_picture_size bigint
);


ALTER TABLE tb_record OWNER TO admin;

--
-- Name: COLUMN tb_record.record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_id IS '录像的唯一标识';


--
-- Name: COLUMN tb_record.record_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_address_id IS '地点的标识，字符串类型，可以是商铺、家庭等';


--
-- Name: COLUMN tb_record.record_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_services_id IS '录制服务ID';


--
-- Name: COLUMN tb_record.record_src_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_src_id IS '媒体源的唯一标识';


--
-- Name: COLUMN tb_record.record_replay_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_replay_url IS '录像回放的流地址';


--
-- Name: COLUMN tb_record.record_inner_file_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_inner_file_name IS '内部使用文件名';


--
-- Name: COLUMN tb_record.record_img_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_img_url IS '录象截图的url';


--
-- Name: COLUMN tb_record.record_rtsp_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_rtsp_url IS '录制rtsp url';


--
-- Name: COLUMN tb_record.record_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_start_time IS '录像（操作）开始的时间';


--
-- Name: COLUMN tb_record.record_stop_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_stop_time IS '录像（操作）完成的时间';


--
-- Name: COLUMN tb_record.record_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_type IS '0：告警视频，1：定时录制视频';


--
-- Name: COLUMN tb_record.record_file_size; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_file_size IS '录像文件大小';


--
-- Name: COLUMN tb_record.record_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_status IS '1 未开始 2 录像失败 3 录像成功';


--
-- Name: COLUMN tb_record.record_duration; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_duration IS '录制时长，单位秒';


--
-- Name: COLUMN tb_record.record_resolution; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_resolution IS '录像的分辨率';


--
-- Name: COLUMN tb_record.record_http_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.record_http_url IS '录像文件的http url';


--
-- Name: COLUMN tb_record.caller_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record.caller_type IS '调用者类型 sap--商铺报警，其他未定义';


--
-- Name: tb_record_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_record_history (
    record_id uuid NOT NULL,
    record_address_id text,
    record_services_id uuid NOT NULL,
    record_src_id text NOT NULL,
    record_replay_url text NOT NULL,
    record_inner_file_name text NOT NULL,
    record_img_url text NOT NULL,
    record_rtsp_url text NOT NULL,
    record_start_time timestamp without time zone,
    record_stop_time timestamp without time zone,
    record_type integer DEFAULT 0 NOT NULL,
    record_file_size integer NOT NULL,
    record_status integer DEFAULT 1 NOT NULL,
    record_duration integer,
    record_resolution integer,
    record_http_url text NOT NULL,
    caller_type text,
    record_picture_size bigint
);


ALTER TABLE tb_record_history OWNER TO admin;

--
-- Name: COLUMN tb_record_history.record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_id IS '录像的唯一标识';


--
-- Name: COLUMN tb_record_history.record_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_address_id IS '地点的标识，字符串类型，可以是商铺、家庭等';


--
-- Name: COLUMN tb_record_history.record_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_services_id IS '录制服务ID';


--
-- Name: COLUMN tb_record_history.record_src_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_src_id IS '媒体源的唯一标识';


--
-- Name: COLUMN tb_record_history.record_replay_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_replay_url IS '录像回放的流地址';


--
-- Name: COLUMN tb_record_history.record_inner_file_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_inner_file_name IS '内部使用文件名';


--
-- Name: COLUMN tb_record_history.record_img_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_img_url IS '录象截图的url';


--
-- Name: COLUMN tb_record_history.record_rtsp_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_rtsp_url IS '录制rtsp url';


--
-- Name: COLUMN tb_record_history.record_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_start_time IS '录像（操作）开始的时间';


--
-- Name: COLUMN tb_record_history.record_stop_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_stop_time IS '录像（操作）完成的时间';


--
-- Name: COLUMN tb_record_history.record_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_type IS '0：告警视频，1：定时录制视频';


--
-- Name: COLUMN tb_record_history.record_file_size; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_file_size IS '录像文件大小';


--
-- Name: COLUMN tb_record_history.record_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_status IS '1 未开始 2 录像失败 3 录像成功';


--
-- Name: COLUMN tb_record_history.record_duration; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_duration IS '录制时长，单位秒';


--
-- Name: COLUMN tb_record_history.record_resolution; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_resolution IS '录像的分辨率';


--
-- Name: COLUMN tb_record_history.record_http_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.record_http_url IS '录像文件的http url';


--
-- Name: COLUMN tb_record_history.caller_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_history.caller_type IS '调用者类型 sap--商铺报警，其他未定义';


--
-- Name: tb_record_worker; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_record_worker (
    server_id uuid NOT NULL,
    server_ip text NOT NULL,
    server_http_port integer NOT NULL,
    server_rtsp_port integer NOT NULL,
    server_http_prefix text NOT NULL,
    server_cpu_usage integer,
    server_mem_usage integer,
    rtsp_conn_num integer,
    server_total_bandwidth integer DEFAULT 0 NOT NULL,
    server_available_bandwidth integer DEFAULT 0 NOT NULL,
    last_update_time timestamp without time zone
);


ALTER TABLE tb_record_worker OWNER TO admin;

--
-- Name: COLUMN tb_record_worker.server_total_bandwidth; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_worker.server_total_bandwidth IS '服务器总带宽';


--
-- Name: COLUMN tb_record_worker.server_available_bandwidth; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_worker.server_available_bandwidth IS '服务器可用带宽';


--
-- Name: tb_rtsp_download; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtsp_download (
    rtsp_id uuid NOT NULL,
    rtsp_stream_updt timestamp without time zone,
    rtsp_dst_id text NOT NULL,
    rtsp_src_file_id text NOT NULL,
    rtsp_addr_id text NOT NULL,
    rtsp_stream_type integer NOT NULL,
    rtsp_usr_name text NOT NULL,
    rtsp_usr_pwd text NOT NULL,
    rtsp_src_id text NOT NULL,
    rtsp_url text NOT NULL,
    rtsp_services_id uuid,
    rtsp_status integer NOT NULL,
    rtsp_stream_direction integer NOT NULL,
    caller_type text NOT NULL
);


ALTER TABLE tb_rtsp_download OWNER TO admin;

--
-- Name: COLUMN tb_rtsp_download.rtsp_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_id IS '实时流的唯一标识';


--
-- Name: COLUMN tb_rtsp_download.rtsp_stream_updt; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_stream_updt IS '流创建时间';


--
-- Name: COLUMN tb_rtsp_download.rtsp_dst_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_dst_id IS '观看者的唯一标识';


--
-- Name: COLUMN tb_rtsp_download.rtsp_src_file_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_src_file_id IS '源文件的唯一标识';


--
-- Name: COLUMN tb_rtsp_download.rtsp_addr_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_addr_id IS '地点的标识，字符串类型，可以是商铺、家庭等';


--
-- Name: COLUMN tb_rtsp_download.rtsp_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_stream_type IS '0：实时流，1：待定义';


--
-- Name: COLUMN tb_rtsp_download.rtsp_usr_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_usr_name IS '用户名';


--
-- Name: COLUMN tb_rtsp_download.rtsp_usr_pwd; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_usr_pwd IS '密码';


--
-- Name: COLUMN tb_rtsp_download.rtsp_src_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_src_id IS '媒体源的唯一标识';


--
-- Name: COLUMN tb_rtsp_download.rtsp_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_url IS '实时流地址';


--
-- Name: COLUMN tb_rtsp_download.rtsp_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_services_id IS '本服务ID';


--
-- Name: COLUMN tb_rtsp_download.rtsp_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_status IS '1 ALLOC 已分配  2 RUNNING 已运行 3 TEARDOWN 无效';


--
-- Name: COLUMN tb_rtsp_download.rtsp_stream_direction; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_download.rtsp_stream_direction IS '0 未知 1 push流 2 pull流';


--
-- Name: tb_rtsp_real; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtsp_real (
    rtsp_id uuid NOT NULL,
    rtsp_url text NOT NULL,
    rtsp_usr_name text NOT NULL,
    rtsp_usr_pwd text NOT NULL,
    rtsp_services_id uuid,
    rtsp_status integer NOT NULL,
    rtsp_src_id text NOT NULL,
    rtsp_dst_id text NOT NULL,
    rtsp_stream_type integer NOT NULL,
    rtsp_stream_direction integer NOT NULL,
    caller text,
    rtsp_stream_updt timestamp without time zone,
    rtsp_resolution integer NOT NULL,
    rtsp_addr_id text NOT NULL
);


ALTER TABLE tb_rtsp_real OWNER TO admin;

--
-- Name: COLUMN tb_rtsp_real.rtsp_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_id IS '实时流的唯一标识';


--
-- Name: COLUMN tb_rtsp_real.rtsp_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_url IS '实时流地址';


--
-- Name: COLUMN tb_rtsp_real.rtsp_usr_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_usr_name IS '用户名';


--
-- Name: COLUMN tb_rtsp_real.rtsp_usr_pwd; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_usr_pwd IS '密码';


--
-- Name: COLUMN tb_rtsp_real.rtsp_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_services_id IS '本服务ID';


--
-- Name: COLUMN tb_rtsp_real.rtsp_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_status IS '1 ALLOC 已分配  2 RUNNING 已运行 3 TEARDOWN 无效';


--
-- Name: COLUMN tb_rtsp_real.rtsp_src_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_src_id IS '媒体源的唯一标识';


--
-- Name: COLUMN tb_rtsp_real.rtsp_dst_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_dst_id IS '观看者的唯一标识';


--
-- Name: COLUMN tb_rtsp_real.rtsp_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_stream_type IS '0：实时流，1：待定义';


--
-- Name: COLUMN tb_rtsp_real.rtsp_stream_direction; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_stream_direction IS '0 未知 1 push流 2 pull流';


--
-- Name: COLUMN tb_rtsp_real.caller; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.caller IS '调用者类型 sap --商铺报警，其他：待定义';


--
-- Name: COLUMN tb_rtsp_real.rtsp_stream_updt; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_stream_updt IS '流创建时间';


--
-- Name: COLUMN tb_rtsp_real.rtsp_resolution; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_resolution IS '分辨率';


--
-- Name: COLUMN tb_rtsp_real.rtsp_addr_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_real.rtsp_addr_id IS '地点的标识，字符串类型，可以是商铺、家庭等';


--
-- Name: tb_ip_area_info tb_ip_area_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ip_area_info
    ADD CONSTRAINT tb_ip_area_info_pkey PRIMARY KEY (ip_start_point);


--
-- Name: tb_realtime_worker tb_realtime_worker_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_realtime_worker
    ADD CONSTRAINT tb_realtime_worker_pkey PRIMARY KEY (server_id);


--
-- Name: tb_record_history tb_record_history_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_record_history
    ADD CONSTRAINT tb_record_history_pkey PRIMARY KEY (record_id);


--
-- Name: tb_record tb_record_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_record
    ADD CONSTRAINT tb_record_pkey PRIMARY KEY (record_id);


--
-- Name: tb_record_worker tb_record_worker_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_record_worker
    ADD CONSTRAINT tb_record_worker_pkey PRIMARY KEY (server_id);


--
-- Name: tb_rtsp_download tb_rtsp_download_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtsp_download
    ADD CONSTRAINT tb_rtsp_download_pkey PRIMARY KEY (rtsp_id);


--
-- Name: tb_rtsp_real tb_rtsp_real_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtsp_real
    ADD CONSTRAINT tb_rtsp_real_pkey PRIMARY KEY (rtsp_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: tb_record; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_record FROM PUBLIC;
REVOKE ALL ON TABLE tb_record FROM admin;
GRANT ALL ON TABLE tb_record TO admin;


--
-- Name: tb_record_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_record_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_record_history FROM admin;
GRANT ALL ON TABLE tb_record_history TO admin;


--
-- Name: tb_rtsp_download; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_rtsp_download FROM PUBLIC;
REVOKE ALL ON TABLE tb_rtsp_download FROM admin;
GRANT ALL ON TABLE tb_rtsp_download TO admin;


--
-- Name: tb_rtsp_real; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_rtsp_real FROM PUBLIC;
REVOKE ALL ON TABLE tb_rtsp_real FROM admin;
GRANT ALL ON TABLE tb_rtsp_real TO admin;


--
-- PostgreSQL database dump complete
--

