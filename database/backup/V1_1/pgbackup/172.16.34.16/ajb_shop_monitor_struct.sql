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


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

--
-- Name: dmlac; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE dmlac AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE'
);


ALTER TYPE dmlac OWNER TO admin;

--
-- Name: ajb_shop_monitor_audit(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION ajb_shop_monitor_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
id uuid;
action dmlac;
client_addr inet;
client_port integer;
client_user text;
table_name text;
current_command text;
current_txid bigint;
trigger_time timestamp without time zone;
old_values text;
new_values text;
ins_sql text;
exception_info text;
begin
id := uuid_generate_v4();
action := TG_OP;
client_addr := inet_client_addr();
client_port := inet_client_port();
client_user := current_user;
table_name := TG_TABLE_NAME;
current_command := current_query();
current_txid := txid_current();
trigger_time := now();
IF (TG_OP = 'INSERT') THEN
old_values := '';
new_values := NEW;
ELSIF (TG_OP = 'UPDATE') THEN
old_values := OLD;
new_values := NEW;
ELSIF (TG_OP = 'DELETE') THEN
old_values := OLD;
new_values := '';
ELSE 
old_values := '';
new_values := '';
END IF;
ins_sql := '';

--raise notice 'id: %',id;
--raise notice 'action: %',action;
--raise notice 'client_addr: %',client_addr;
--raise notice 'client_port: %',client_port;
--raise notice 'client_user: %',client_user;
--raise notice 'table_name: %',table_name;
--raise notice 'current_command: %',current_command;
--raise notice 'current_txid: %',current_txid;
--raise notice 'trigger_time: %',trigger_time;
--raise notice 'old_values: %',old_values;
--raise notice 'new_values: %',new_values;
IF (table_name = 'tb_audit_info') THEN
	raise WARNING 'tb_audit_info is not allowed to reference triggers ajb_shop_monitor_audit()';
	return NULL;
END IF;

ins_sql := 'INSERT INTO ' || quote_ident('tb_audit_info') || '(audit_id, audit_action, audit_client_addr, 
audit_client_port, audit_user, audit_tale_name, audit_current_command, audit_current_txid, audit_time,
old_values, new_values) VALUES(''' || id || ''', '''|| action ||''', ''' || client_addr || ''', ''' || 
client_port || ''', ' || quote_literal(client_user) || ', ' || quote_literal(table_name) || ', ' 
|| quote_literal(current_command) || ', ' || current_txid || ', ''' || trigger_time || ''', ' || 
quote_literal(old_values) || ', ' || quote_literal(new_values) || ')';

--raise notice 'ins_sql: %', ins_sql;
EXECUTE ins_sql;
--EXCEPTION 
--	WHEN OTHERS THEN
--	GET STACKED DIAGNOSTICS exception_info = MESSAGE_TEXT;
--	RAISE NOTICE 'EXCEPTION location: % \n ins_sql: % \n MESSAGE_TEXT: %',TG_NAME,ins_sql,exception_info;

RETURN NULL;
end;

$$;


ALTER FUNCTION public.ajb_shop_monitor_audit() OWNER TO admin;

--
-- Name: clean_user_info(text, integer, text); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION clean_user_info(user_mobile text, app_type integer, app_factory text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare

current_user_info tb_user_info%ROWTYPE;	--保存根据函数参数查到的用户信息
loop_user_info tb_user_info%ROWTYPE;--用于循环处理查询到的记录(包括子账号)
integer_row_count integer default 0;--每条命令影响的行数
integer_num_user integer default 0;--处理的用户数 

begin

execute 'select * from tb_user_info where user_mobile = ' || quote_literal(user_mobile) || ' and user_app_type = ' || app_type || ' and user_app_factory = ' || quote_literal(app_factory) || ';' into current_user_info;

if current_user_info is null then
	raise notice 'could not find record in tb_user_info';
	return false;
end if;

raise notice '------deleted statistics------';

for loop_user_info in select * from tb_user_info where user_id = current_user_info.user_id or user_parent_id = current_user_info.user_id loop
	--通过 user_id 删除
	delete from tb_user_watch_video_info where user_watch_uid = loop_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_user_watch_video_info: %', integer_row_count;
	
	delete from tb_user_event_info where user_event_uid = loop_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_user_event_info: %', integer_row_count;
	
	delete from tb_timer_work_info where timer_work_userid = loop_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_timer_work_info: %', integer_row_count;
	
	delete from tb_push_info where push_user_id = loop_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_push_info: %', integer_row_count;
	
	delete from tb_address_lease_info where lease_userid = loop_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_address_lease_info: %', integer_row_count;
	
	if loop_user_info.user_parent_id is not null then
		delete from tb_user_addrs_info where user_addrs_uid = loop_user_info.user_id;
		GET DIAGNOSTICS integer_row_count = ROW_COUNT;
		raise notice 'tb_user_addrs_info: %', integer_row_count;
		
		delete from tb_user_info where user_id = loop_user_info.user_id;
		integer_num_user = integer_num_user + 1;
		GET DIAGNOSTICS integer_row_count = ROW_COUNT;
		raise notice 'tb_user_info: %', integer_row_count;
		raise notice '^^^^^^(child user)^^^^^^';
		raise notice '';
		continue;
	end if;
	
	--情景 user_id -> scence_id -> 
	--通过 scence_id 删除
	delete from tb_device_scence_info where device_scence_sid in (select scence_id from tb_scence_info where scence_uid = current_user_info.user_id);
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_device_scence_info: %', integer_row_count;
	
	delete from tb_fingerprint_scence where fps_scence_id in (select scence_id from tb_scence_info where scence_uid = current_user_info.user_id);
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_fingerprint_scence: %', integer_row_count;
	
	delete from tb_sence_alarm_info where sence_id in (select scence_id from tb_scence_info where scence_uid = current_user_info.user_id);
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_sence_alarm_info: %', integer_row_count;
	
	delete from tb_scence_info where scence_uid = current_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_scence_info: %', integer_row_count;
	
	
	--传感器 user_id -> home_id -> sensor_id ->
	--		 user_id -> user_addrs -> addr_id(home_id) -> ipc_id -> sensor_ipc -> sensor_id ->
	
	--通过 sensor_id 删除
	--(tb_sensor_equipment_info 还有直接属于 home_id 的)
	delete from tb_sensor_equipment_info where sensor_mac in (select sensors_production_id from tb_sensors_info where sensors_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id) or sensors_id in (select sensor_ipc_sid from tb_sensor_ipc_info where sensor_ipc_iid in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id)))) or home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id);
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_sensor_equipment_info: %', integer_row_count;
	
	delete from tb_sensors_info where sensors_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id) or sensors_id in (select sensor_ipc_sid from tb_sensor_ipc_info where sensor_ipc_iid in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id)));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_sensors_info: %', integer_row_count;
	
	--通过 ipc_id 删除
	delete from tb_sensor_ipc_info where sensor_ipc_iid in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_sensor_ipc_info: %', integer_row_count;
	
	delete from tb_rtsp_file_info where rtsp_ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_rtsp_file_info: %', integer_row_count;
	
	delete from tb_rtsp_stream_info where rtsp_ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_rtsp_stream_info: %', integer_row_count;
	
	delete from tb_record_info where record_ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_record_info: %', integer_row_count;
	
	--v2
	--delete from tb_record_status_info where ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	--GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	--raise notice 'tb_record_status_info: %', integer_row_count;
	
	--v2
	--delete from tb_client_url_info where client_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id) union select current_user_info.user_id);
	--GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	--raise notice 'tb_client_url_info: %', integer_row_count;
	
	delete from tb_ipc_sensordata where sensordata_ipcid in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_ipc_sensordata: %', integer_row_count;
	
	delete from tb_operater_event_info where event_id in (select alarm_id from tb_alarm_info where alarm_ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id)));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_operater_event_info: %', integer_row_count;
	
	delete from tb_alarm_info where alarm_ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_alarm_info: %', integer_row_count;
	
	delete from tb_ipc_session_info where ipc_id in (select ipc_id from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id));
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_ipc_session_info: %', integer_row_count;
	
	delete from tb_ipc_info where ipc_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id) or ipc_home_id in (select home_id from tb_home_info where home_user_id = current_user_info.user_id);
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_ipc_info: %', integer_row_count;
	
	--通过 user_id 删除
	--v2
	--delete from tb_op_address_alloc_info where op_addr_addrid in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id);
	--GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	--raise notice 'tb_op_address_alloc_info: %', integer_row_count;
	
	--v2
	--delete from tb_op_alarm_alloc_info where alloc_alarm_id in (select op_alarm_id from tb_op_alarm_info where op_alarm_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id));
	--GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	--raise notice 'tb_op_alarm_alloc_info: %', integer_row_count;
	
	--v2
	--delete from tb_op_alarm_info where op_alarm_address_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id);
	--GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	--raise notice 'tb_op_alarm_info: %', integer_row_count;
	
	delete from tb_address_info where addr_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id);
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_address_info: %', integer_row_count;
	
	delete from tb_user_addrs_info where user_addrs_uid = current_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_user_addrs_info: %', integer_row_count;
	
	delete from tb_home_info where home_user_id = current_user_info.user_id;
	GET DIAGNOSTICS integer_row_count = ROW_COUNT;
	raise notice 'tb_home_info: %', integer_row_count;
	
	delete from tb_user_info where user_id = current_user_info.user_id;
	integer_num_user = integer_num_user + 1;
	
end loop;

raise notice 'tb_user_info: %', integer_num_user;

return true;
end;
$$;


ALTER FUNCTION public.clean_user_info(user_mobile text, app_type integer, app_factory text) OWNER TO admin;

--
-- Name: FUNCTION clean_user_info(user_mobile text, app_type integer, app_factory text); Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON FUNCTION clean_user_info(user_mobile text, app_type integer, app_factory text) IS '删除一个用户在数据库中所有相关信息';


--
-- Name: fill_home_addressid(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION fill_home_addressid() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
	cur_id refcursor;
	HomeId uuid;
	UserId uuid;
	AddrId uuid;
begin
	open cur_id for execute 'select home_id,home_user_id from tb_home_info where home_addressid is null';
	
	loop
		fetch cur_id into HomeId,UserId;   
		Exit when NOT found;
		
		AddrId = null;
		
		if UserId is not null then
			select addr_id into AddrId from tb_address_info where addr_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = UserId) order by addr_register_time limit 1;
			
			if found and AddrId is not null then
				raise notice 'home_user_id:%,addr_id:%', UserId, AddrId;
				
				update tb_home_info set home_addressid = AddrId where home_id = HomeId;
			end if;
		end if;
	end loop;
	
	close cur_id;
	
	return true;
end;
$$;


ALTER FUNCTION public.fill_home_addressid() OWNER TO admin;

--
-- Name: fill_scence_addressid(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION fill_scence_addressid() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
	cur_id refcursor;
	ScenceId uuid;
	UserId uuid;
	AddrId uuid;
begin
	open cur_id for execute 'select scence_id,scence_uid from tb_scence_info where scence_addressid is null';
	
	loop
		fetch cur_id into ScenceId,UserId;   
		Exit when NOT found;
		
		AddrId = null;
		
		if UserId is not null then
			select addr_id into AddrId from tb_address_info where addr_id in (select user_addrs_sid from tb_user_addrs_info where user_addrs_uid = UserId) order by addr_register_time limit 1;
			
			if found and AddrId is not null then
				raise notice 'scence_uid:%,addr_id:%', UserId, AddrId;
				
				update tb_scence_info set scence_addressid = AddrId where scence_id = ScenceId;
			end if;
		end if;
	end loop;
	
	close cur_id;
	
	return true;
end;
$$;


ALTER FUNCTION public.fill_scence_addressid() OWNER TO admin;

--
-- Name: find_error(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION find_error() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	user_info_tmp tb_user_info%ROWTYPE;	--循环使用的用户信息表结构
	parent_id_temp uuid;			--主账号临时id
	parent_id_temp1 uuid;
	user_id_temp uuid;			--user临时id
	addr_id_temp uuid;			
	mobile_temp text;
	compare_parent_id uuid:=NULL;		--用于控制循环
	compare_addr_id uuid;			--用于循环中比较，判断是否有误
BEGIN	
	--需要重新修改存储过程时在会话未结束或者重新刷洗连接时需要先删除临时表
	--下面临时表只要会话结束就会自动删除
	CREATE TEMP TABLE user_parent_addrs(parent_id uuid,user_id uuid,addrs_id uuid,mobile text);		--user parent 和 addrs 匹配信息表
	CREATE TEMP TABLE result_find_error(parent_id uuid,user_id uuid,addrs_id uuid,mobile text);		--保存错误结果的信息表
	CREATE TEMP TABLE parent_table_tmp(parent_id uuid);							--中间转存有错误信息的parent表
	--收集parent_id、user_id和addr_id信息
	FOR user_info_tmp IN SELECT * FROM tb_user_info LOOP
		IF(user_info_tmp.user_id='00000000-0000-0000-0000-000000000000' or user_info_tmp.user_parent_id='00000000-0000-0000-0000-000000000000') THEN
-- 			RAISE NOTICE 'user_id = %,parent_id = %',user_info_tmp.user_id,user_info_tmp.user_parent_id;	--由于之前规则问题，现在不管全0项
-- 			SELECT user_addrs_sid INTO addr_id_temp FROM tb_user_addrs_info WHERE user_addrs_uid=user_info_tmp.user_id;
-- 			INSERT INTO result_find_error values(user_info_tmp.user_parent_id,user_info_tmp.user_id,addr_id_temp);
			CONTINUE;
		END IF;
		SELECT user_addrs_sid INTO addr_id_temp FROM tb_user_addrs_info WHERE user_addrs_uid=user_info_tmp.user_id;
		INSERT INTO user_parent_addrs values(user_info_tmp.user_parent_id,user_info_tmp.user_id,addr_id_temp,user_info_tmp.user_mobile);
	END LOOP;
-- 	--通过parent列，结合addr_id判断数据正确性
	FOR parent_id_temp,user_id_temp,addr_id_temp IN SELECT * FROM user_parent_addrs ORDER BY user_parent_addrs.parent_id ASC LOOP
-- 		--给比较参数赋初值
		IF (compare_parent_id=NULL) THEN
			compare_parent_id=parent_id_temp;
			compare_addr_id=addr_id_temp;
		END IF;
-- 		--比较主账号相同的账号的家id是否一致
		IF  (parent_id_temp=compare_parent_id) THEN
			IF (addr_id_temp=compare_addr_id) THEN
				CONTINUE;
			ELSE
-- 				--记录此种情况下的数据(重复无影响，后期查询时去重)
				INSERT INTO parent_table_tmp VALUES(parent_id_temp);
				CONTINUE; 
			END IF;
		ELSE
			--修改比较参数
			compare_parent_id=parent_id_temp;
			compare_addr_id=addr_id_temp;
		END IF;
	END LOOP;
-- 	--根据查询出的有不同记录的parent_id_temp，统计所有相关user_parent_addrs
	FOR parent_id_temp IN SELECT DISTINCT parent_id FROM parent_table_tmp LOOP
		FOR user_id_temp,parent_id_temp1,addr_id_temp,mobile_temp IN SELECT * FROM user_parent_addrs WHERE user_parent_addrs.parent_id = parent_id_temp OR user_parent_addrs.user_id = parent_id_temp LOOP
			INSERT INTO result_find_error VALUES(user_id_temp,parent_id_temp1,addr_id_temp,mobile_temp);
		END LOOP;
	END LOOP;
-- 	RAISE NOTICE '%',result_find_error;
END;
$$;


ALTER FUNCTION public.find_error() OWNER TO admin;

--
-- Name: find_error_parent_id(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION find_error_parent_id() RETURNS void
    LANGUAGE plpgsql
    AS $$
	--辅助测试过程，需在find_error存储过程执行后执行这个
DECLARE
	parent_id_tmp_327 	uuid;
	test_if_tmp 		uuid;
BEGIN
	FOR parent_id_tmp_327 IN SELECT DISTINCT result_find_error.parent_id FROM result_find_error LOOP
		SELECT tb_user_info.user_id INTO test_if_tmp FROM tb_user_info WHERE tb_user_info.user_id=parent_id_tmp_327;
		IF test_if_tmp IS NOT NULL THEN
			CONTINUE;
		ELSE
			RAISE NOTICE '%',parent_id_tmp_327;
			UPDATE tb_user_info SET user_parent_id = '00000000-0000-0000-0000-000000000000' WHERE tb_user_info.user_parent_id=parent_id_tmp_327;
		END IF;
	END LOOP;
END;
$$;


ALTER FUNCTION public.find_error_parent_id() OWNER TO admin;

--
-- Name: find_error_parent_id2(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION find_error_parent_id2() RETURNS void
    LANGUAGE plpgsql
    AS $$
	--找出本身是主账号的账号却还有主账号的账号
DECLARE
	parent_id_tmp_3281 	uuid;
	parent_id_tmp_3282 	uuid;
	addr_id_tmp_3281 	uuid;	
	test_if_tmp 		uuid;
	mobile_tmp		text;
	error_parent_id_3281	uuid;
BEGIN
	CREATE TEMP TABLE user_parent_addrs1(parent_id uuid,user_id uuid,addrs_id uuid,mobile text);
	FOR parent_id_tmp_3281 IN SELECT DISTINCT tb_user_info.user_parent_id FROM tb_user_info LOOP
-- 		SELECT tb_user_info.user_id INTO test_if_tmp FROM tb_user_info WHERE tb_user_info.user_id=parent_id_tmp_3281;
		IF (parent_id_tmp_3281 IS NULL or parent_id_tmp_3281 = '00000000-0000-0000-0000-000000000000') THEN
			CONTINUE;		
		ELSE
			SELECT tb_user_info.user_parent_id INTO parent_id_tmp_3282 FROM tb_user_info WHERE tb_user_info.user_id=parent_id_tmp_3281;
			IF (parent_id_tmp_3282 IS NULL or parent_id_tmp_3282 = '00000000-0000-0000-0000-000000000000') THEN
				RAISE NOTICE 'P:% U:%',parent_id_tmp_3282,parent_id_tmp_3281;
			ELSE
				SELECT user_addrs_sid INTO addr_id_tmp_3281 FROM tb_user_addrs_info WHERE user_addrs_uid=parent_id_tmp_3281;
				SELECT user_mobile INTO mobile_tmp FROM tb_user_info WHERE user_id=parent_id_tmp_3281;
				INSERT INTO user_parent_addrs1 VALUES(parent_id_tmp_3282,parent_id_tmp_3281,addr_id_tmp_3281,mobile_tmp);
			END IF;
		END IF;
	END LOOP;
END;
$$;


ALTER FUNCTION public.find_error_parent_id2() OWNER TO admin;

--
-- Name: tb_alarm_info_delete_trigger(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION tb_alarm_info_delete_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

begin
insert into tb_alarm_info_history values(OLD.*);
return null;
end;

$$;


ALTER FUNCTION public.tb_alarm_info_delete_trigger() OWNER TO admin;

--
-- Name: tb_ipc_session_info_record_timeout_notify(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION tb_ipc_session_info_record_timeout_notify() RETURNS integer
    LANGUAGE plpgsql
    AS $$declare
curren_record tb_ipc_info%ROWTYPE;
time_out_record_num integer default 0;

begin
for curren_record in select * from tb_ipc_info where now() - ipc_last_req_time >= interval '2 MINUTE' and ipc_online = true loop
	execute 'notify tb_ipc_info_record_timeout,''' || curren_record.ipc_services_id || ':' || curren_record.ipc_id || '''';
	time_out_record_num := time_out_record_num + 1;
end loop;

return time_out_record_num;
end;
$$;


ALTER FUNCTION public.tb_ipc_session_info_record_timeout_notify() OWNER TO admin;

--
-- Name: FUNCTION tb_ipc_session_info_record_timeout_notify(); Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON FUNCTION tb_ipc_session_info_record_timeout_notify() IS '检查ipc表里超时的ipc,并发出 notify';


--
-- Name: push_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE push_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE push_id_seq OWNER TO admin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: tb_ac_control_pfile; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ac_control_pfile (
    ac_type_code text NOT NULL,
    ac_brand_name text NOT NULL,
    ac_release_date timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    ac_release_address text DEFAULT ''::text NOT NULL,
    ac_versions_description text
);


ALTER TABLE tb_ac_control_pfile OWNER TO admin;

--
-- Name: TABLE tb_ac_control_pfile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ac_control_pfile IS '保存各种类型的空调的控制参数';


--
-- Name: COLUMN tb_ac_control_pfile.ac_type_code; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ac_control_pfile.ac_type_code IS '空调的类型编码，一般贴在空调的铭牌上';


--
-- Name: COLUMN tb_ac_control_pfile.ac_brand_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ac_control_pfile.ac_brand_name IS '空调品牌名称,如 海尔 格力';


--
-- Name: COLUMN tb_ac_control_pfile.ac_release_address; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ac_control_pfile.ac_release_address IS '参数文件的下载地址';


--
-- Name: COLUMN tb_ac_control_pfile.ac_versions_description; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ac_control_pfile.ac_versions_description IS '说明';


--
-- Name: tb_address_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_address_info (
    addr_id uuid NOT NULL,
    addr_name text,
    addr_type_name text,
    addr_mobile text,
    addr_phone text,
    addr_address text,
    addr_longitude text DEFAULT '0'::text NOT NULL,
    addr_latitude text DEFAULT '0'::text NOT NULL,
    addr_country text,
    addr_province text,
    addr_city text,
    addr_district text,
    addr_safe_status boolean DEFAULT false NOT NULL,
    addr_register_time timestamp without time zone,
    addr_on_defence_time text,
    addr_off_defence_time text,
    addr_timer_switch boolean DEFAULT false NOT NULL,
    addr_type integer DEFAULT 1 NOT NULL,
    addr_public_type integer DEFAULT 0 NOT NULL,
    addr_phone_name_1 text,
    addr_phone_2 text,
    addr_phone_name_2 text,
    addr_licensed_type integer DEFAULT 0 NOT NULL,
    addr_op_point_id uuid,
    addr_av_switch boolean DEFAULT false NOT NULL,
    CONSTRAINT tb_address_info_addr_id_check CHECK ((addr_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_address_info_addr_licensed_type_check CHECK (((addr_licensed_type >= 0) AND (addr_licensed_type <= 2))),
    CONSTRAINT tb_address_info_addr_public_type_check CHECK (((addr_public_type >= 0) AND (addr_public_type <= 1))),
    CONSTRAINT tb_address_info_addr_type_check CHECK (((addr_type >= 1) AND (addr_type <= 4)))
);


ALTER TABLE tb_address_info OWNER TO admin;

--
-- Name: COLUMN tb_address_info.addr_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_name IS '商铺名称';


--
-- Name: COLUMN tb_address_info.addr_phone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_phone IS '联系人1 电话';


--
-- Name: COLUMN tb_address_info.addr_longitude; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_longitude IS '商铺的经度';


--
-- Name: COLUMN tb_address_info.addr_latitude; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_latitude IS '商铺的纬度';


--
-- Name: COLUMN tb_address_info.addr_country; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_country IS '所在的国家';


--
-- Name: COLUMN tb_address_info.addr_province; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_province IS '所在的省';


--
-- Name: COLUMN tb_address_info.addr_city; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_city IS '城市';


--
-- Name: COLUMN tb_address_info.addr_district; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_district IS '区县';


--
-- Name: COLUMN tb_address_info.addr_safe_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_safe_status IS '安防状态（false：撤防，true：布防）';


--
-- Name: COLUMN tb_address_info.addr_on_defence_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_on_defence_time IS '开始布防时间，准备以后删除这个字段';


--
-- Name: COLUMN tb_address_info.addr_off_defence_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_off_defence_time IS '关闭布防时间，准备以后删除这个字段';


--
-- Name: COLUMN tb_address_info.addr_timer_switch; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_timer_switch IS '定时布防开关(false: 默认值关闭，true: 打开)';


--
-- Name: COLUMN tb_address_info.addr_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_type IS '商铺类型（缺省值为：1 运营商铺， 2：测试商铺, 3: 付费商铺,4:欠费商铺-租借方式）';


--
-- Name: COLUMN tb_address_info.addr_public_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_public_type IS '商铺公共类型（0：私有类型， 1：公共类型，2...）';


--
-- Name: COLUMN tb_address_info.addr_phone_name_1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_phone_name_1 IS '联系人1姓名';


--
-- Name: COLUMN tb_address_info.addr_phone_2; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_phone_2 IS '联系人2电话';


--
-- Name: COLUMN tb_address_info.addr_phone_name_2; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_phone_name_2 IS '联系人2姓名';


--
-- Name: COLUMN tb_address_info.addr_licensed_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_licensed_type IS '用户授权（0: 关闭授权，1：等待审核， 2：审核通过）';


--
-- Name: COLUMN tb_address_info.addr_op_point_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_op_point_id IS '关联的接警点id';


--
-- Name: COLUMN tb_address_info.addr_av_switch; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_info.addr_av_switch IS '是否授权接警点音视频';


--
-- Name: tb_address_lease_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_address_lease_info (
    lease_id uuid NOT NULL,
    lease_userid uuid,
    lease_addressid uuid,
    lease_begin_time timestamp without time zone,
    lease_end_time timestamp without time zone,
    lease_enable integer,
    CONSTRAINT tb_address_lease_info_lease_enable_check CHECK (((lease_enable >= 0) AND (lease_enable <= 2))),
    CONSTRAINT tb_address_lease_info_lease_id_check CHECK ((lease_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_address_lease_info OWNER TO admin;

--
-- Name: TABLE tb_address_lease_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_address_lease_info IS '商铺租赁表';


--
-- Name: COLUMN tb_address_lease_info.lease_userid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_lease_info.lease_userid IS '用户id';


--
-- Name: COLUMN tb_address_lease_info.lease_addressid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_lease_info.lease_addressid IS '商铺id';


--
-- Name: COLUMN tb_address_lease_info.lease_begin_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_lease_info.lease_begin_time IS '租借开始时间';


--
-- Name: COLUMN tb_address_lease_info.lease_end_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_lease_info.lease_end_time IS '租借结束时间';


--
-- Name: COLUMN tb_address_lease_info.lease_enable; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_address_lease_info.lease_enable IS '0：租赁期内，1：租赁过期，2：租赁服务还没有开始';


--
-- Name: tb_admin_user_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_admin_user_info (
    admin_id uuid NOT NULL,
    admin_account text NOT NULL,
    admin_password text NOT NULL,
    admin_register_time timestamp without time zone NOT NULL,
    admin_last_req_time timestamp without time zone,
    admin_token text,
    admin_token_expire timestamp without time zone,
    admin_permissions json
);


ALTER TABLE tb_admin_user_info OWNER TO admin;

--
-- Name: tb_advertisement_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_advertisement_info (
    ad_id uuid NOT NULL,
    ad_download_path text,
    ad_app_type integer,
    ad_langtype integer,
    ad_play_time timestamp without time zone,
    ad_stop_time timestamp without time zone
);


ALTER TABLE tb_advertisement_info OWNER TO admin;

--
-- Name: COLUMN tb_advertisement_info.ad_download_path; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_advertisement_info.ad_download_path IS '广告下载路径';


--
-- Name: COLUMN tb_advertisement_info.ad_app_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_advertisement_info.ad_app_type IS '1:安店宝 2：安居小宝';


--
-- Name: COLUMN tb_advertisement_info.ad_langtype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_advertisement_info.ad_langtype IS '1:中文  2:英文';


--
-- Name: COLUMN tb_advertisement_info.ad_play_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_advertisement_info.ad_play_time IS '广告投放时间';


--
-- Name: COLUMN tb_advertisement_info.ad_stop_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_advertisement_info.ad_stop_time IS '广告结束时间';


--
-- Name: tb_alarm_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_alarm_info (
    alarm_id uuid NOT NULL,
    alarm_address_id uuid,
    alarm_ipc_id uuid NOT NULL,
    alarm_sensors_id uuid,
    ararm_event text,
    alarm_report_status boolean DEFAULT false NOT NULL,
    alarm_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    alarm_event_type integer DEFAULT 0 NOT NULL,
    alarm_record_id uuid,
    alarm_alloc_status boolean DEFAULT false NOT NULL,
    alarm_ipc_time timestamp without time zone DEFAULT now() NOT NULL,
    alarm_userid uuid,
    ararm_usermobile text,
    ararm_userfactory text,
    alarm_is_push_to_third_party boolean DEFAULT false NOT NULL,
    alarm_time_push_to_third_party timestamp without time zone,
    alarm_sensor_name text,
    alarm_fingerprint_name text,
    alarm_child_dev_number integer DEFAULT 99999,
    alarm_fingerprint_id text,
    CONSTRAINT tb_alarm_info_alarm_event_type_check CHECK (((alarm_event_type >= 0) AND (alarm_event_type <= 100))),
    CONSTRAINT tb_alarm_info_alarm_id_check CHECK ((alarm_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_alarm_info OWNER TO admin;

--
-- Name: COLUMN tb_alarm_info.alarm_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_address_id IS '商铺id';


--
-- Name: COLUMN tb_alarm_info.alarm_ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_ipc_id IS '报警ipc的id';


--
-- Name: COLUMN tb_alarm_info.alarm_sensors_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_sensors_id IS '如果是传感器报警 这里是传感器id';


--
-- Name: COLUMN tb_alarm_info.ararm_event; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.ararm_event IS '告警事件信息';


--
-- Name: COLUMN tb_alarm_info.alarm_report_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_report_status IS '告警推送（false：未推送，true：已推送）';


--
-- Name: COLUMN tb_alarm_info.alarm_event_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_event_type IS '告警类型（0：其它，1：门磁，2：红外，3：烟感，4：移动侦测，5：。。。）';


--
-- Name: COLUMN tb_alarm_info.alarm_record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_record_id IS '告警录制视频ID';


--
-- Name: COLUMN tb_alarm_info.alarm_alloc_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_alloc_status IS '报警信息分派状态 true:已经分派 false:还没有分派';


--
-- Name: COLUMN tb_alarm_info.alarm_ipc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_ipc_time IS 'ipc报警时间';


--
-- Name: COLUMN tb_alarm_info.alarm_userid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_userid IS '用户id';


--
-- Name: COLUMN tb_alarm_info.ararm_usermobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.ararm_usermobile IS '手机号';


--
-- Name: COLUMN tb_alarm_info.ararm_userfactory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.ararm_userfactory IS '用户厂商';


--
-- Name: COLUMN tb_alarm_info.alarm_is_push_to_third_party; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_is_push_to_third_party IS '报警消息是否推送给了第三方';


--
-- Name: COLUMN tb_alarm_info.alarm_time_push_to_third_party; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_time_push_to_third_party IS '报警信息推送给第三方的时间';


--
-- Name: COLUMN tb_alarm_info.alarm_sensor_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_sensor_name IS 'sensor名字  弃用，动态查询';


--
-- Name: COLUMN tb_alarm_info.alarm_fingerprint_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_fingerprint_name IS '指纹名字';


--
-- Name: COLUMN tb_alarm_info.alarm_child_dev_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_child_dev_number IS '子设备序号
99999：无效的序号';


--
-- Name: COLUMN tb_alarm_info.alarm_fingerprint_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info.alarm_fingerprint_id IS '钥匙id';


--
-- Name: tb_alarm_info_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_alarm_info_history (
    alarm_id uuid NOT NULL,
    alarm_address_id uuid,
    alarm_ipc_id uuid NOT NULL,
    alarm_sensors_id uuid,
    ararm_event text,
    alarm_report_status boolean DEFAULT false NOT NULL,
    alarm_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    alarm_event_type integer DEFAULT 0 NOT NULL,
    alarm_record_id uuid,
    alarm_alloc_status boolean DEFAULT false NOT NULL,
    alarm_ipc_time timestamp without time zone DEFAULT now() NOT NULL,
    alarm_userid uuid,
    ararm_usermobile text,
    ararm_userfactory text,
    alarm_is_push_to_third_party boolean DEFAULT false NOT NULL,
    alarm_time_push_to_third_party timestamp without time zone,
    alarm_sensor_name text,
    alarm_fingerprint_name text,
    alarm_child_dev_number integer DEFAULT 99999,
    alarm_fingerprint_id text
);


ALTER TABLE tb_alarm_info_history OWNER TO admin;

--
-- Name: COLUMN tb_alarm_info_history.alarm_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_address_id IS '商铺id';


--
-- Name: COLUMN tb_alarm_info_history.alarm_ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_ipc_id IS '报警ipc的id';


--
-- Name: COLUMN tb_alarm_info_history.alarm_sensors_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_sensors_id IS '如果是传感器报警 这里是传感器id';


--
-- Name: COLUMN tb_alarm_info_history.ararm_event; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.ararm_event IS '告警事件信息';


--
-- Name: COLUMN tb_alarm_info_history.alarm_report_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_report_status IS '告警推送（false：未推送，true：已推送）';


--
-- Name: COLUMN tb_alarm_info_history.alarm_event_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_event_type IS '告警类型（0：其它，1：门磁，2：红外，3：烟感，4：移动侦测，5：。。。）';


--
-- Name: COLUMN tb_alarm_info_history.alarm_record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_record_id IS '告警录制视频ID';


--
-- Name: COLUMN tb_alarm_info_history.alarm_alloc_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_alloc_status IS '报警信息分派状态 true:已经分派 false:还没有分派';


--
-- Name: COLUMN tb_alarm_info_history.alarm_ipc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_ipc_time IS 'ipc报警时间';


--
-- Name: COLUMN tb_alarm_info_history.alarm_userid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_userid IS '用户id';


--
-- Name: COLUMN tb_alarm_info_history.ararm_usermobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.ararm_usermobile IS '手机号';


--
-- Name: COLUMN tb_alarm_info_history.ararm_userfactory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.ararm_userfactory IS '用户厂商';


--
-- Name: COLUMN tb_alarm_info_history.alarm_is_push_to_third_party; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_is_push_to_third_party IS '报警消息是否推送给了第三方';


--
-- Name: COLUMN tb_alarm_info_history.alarm_time_push_to_third_party; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_time_push_to_third_party IS '报警信息推送给第三方的时间';


--
-- Name: COLUMN tb_alarm_info_history.alarm_sensor_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_sensor_name IS 'sensor名字';


--
-- Name: COLUMN tb_alarm_info_history.alarm_fingerprint_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_fingerprint_name IS '指纹名字';


--
-- Name: COLUMN tb_alarm_info_history.alarm_child_dev_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_child_dev_number IS '子设备序号
99999：无效的序号';


--
-- Name: COLUMN tb_alarm_info_history.alarm_fingerprint_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_alarm_info_history.alarm_fingerprint_id IS '钥匙id';


--
-- Name: tb_apple_message_badge_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_apple_message_badge_info (
    userid uuid NOT NULL,
    badge integer,
    token text,
    badge_id uuid,
    CONSTRAINT tb_apple_message_badge_info_userid_check CHECK ((userid <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_apple_message_badge_info OWNER TO admin;

--
-- Name: COLUMN tb_apple_message_badge_info.badge; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_apple_message_badge_info.badge IS '0：计数重置
非0：顺序计数';


--
-- Name: tb_audit_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_audit_info (
    audit_id uuid NOT NULL,
    audit_action dmlac,
    audit_client_addr inet,
    audit_client_port integer,
    audit_user text,
    audit_tale_name text,
    audit_current_command text,
    audit_current_txid bigint,
    audit_time timestamp without time zone,
    old_values text,
    new_values text
);


ALTER TABLE tb_audit_info OWNER TO admin;

--
-- Name: COLUMN tb_audit_info.audit_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_id IS '审计编号';


--
-- Name: COLUMN tb_audit_info.audit_action; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_action IS '操作类型  create TYPE dmlac AS ENUM (''INSERT'', ''UPDATE'', ''DELETE'')';


--
-- Name: COLUMN tb_audit_info.audit_client_addr; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_client_addr IS '执行该操作的客户端IP地址';


--
-- Name: COLUMN tb_audit_info.audit_client_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_client_port IS '执行该操作的客户端端口号';


--
-- Name: COLUMN tb_audit_info.audit_user; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_user IS '执行该操作的用户名';


--
-- Name: COLUMN tb_audit_info.audit_tale_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_tale_name IS '操作的表名';


--
-- Name: COLUMN tb_audit_info.audit_current_command; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_current_command IS '执行的命令';


--
-- Name: COLUMN tb_audit_info.audit_current_txid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_current_txid IS '该操作的事务ID';


--
-- Name: COLUMN tb_audit_info.audit_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.audit_time IS '审计时间';


--
-- Name: COLUMN tb_audit_info.old_values; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.old_values IS 'delete 或 update 的旧数据';


--
-- Name: COLUMN tb_audit_info.new_values; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_audit_info.new_values IS 'insert 或 update 的新数据';


--
-- Name: tb_client_url_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_client_url_info (
    client_id uuid NOT NULL,
    client_type integer DEFAULT 0 NOT NULL,
    control_server_id uuid,
    real_time_url text,
    ios_url text,
    non_real_time_url text,
    pull_url text,
    client_remote_ip text,
    area_type smallint DEFAULT 1 NOT NULL,
    update_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    non_real_time_url_alone text,
    CONSTRAINT tb_client_url_info_area_type_check CHECK (((area_type >= 0) AND (area_type <= 2))),
    CONSTRAINT tb_client_url_info_client_id_check CHECK ((client_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_client_url_info_client_type_check CHECK (((client_type >= 0) AND (client_type <= 2)))
);


ALTER TABLE tb_client_url_info OWNER TO admin;

--
-- Name: TABLE tb_client_url_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_client_url_info IS 'app、ipc、alarm位置信息表';


--
-- Name: COLUMN tb_client_url_info.client_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.client_id IS '对应app、ipc、alarm的UUID';


--
-- Name: COLUMN tb_client_url_info.client_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.client_type IS 'client的类型：0=app，1=ipc，2=alarm';


--
-- Name: COLUMN tb_client_url_info.control_server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.control_server_id IS '所属control_server';


--
-- Name: COLUMN tb_client_url_info.real_time_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.real_time_url IS '实时推送地址';


--
-- Name: COLUMN tb_client_url_info.ios_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.ios_url IS 'ios非实时推送';


--
-- Name: COLUMN tb_client_url_info.non_real_time_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.non_real_time_url IS 'android 非实时http推送url';


--
-- Name: COLUMN tb_client_url_info.pull_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.pull_url IS '订阅url';


--
-- Name: COLUMN tb_client_url_info.client_remote_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.client_remote_ip IS '客户端连接时的ip地址';


--
-- Name: COLUMN tb_client_url_info.area_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.area_type IS '1：大陆 2：香港';


--
-- Name: COLUMN tb_client_url_info.update_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.update_time IS '最后一次更新时间';


--
-- Name: COLUMN tb_client_url_info.non_real_time_url_alone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_client_url_info.non_real_time_url_alone IS '存放单独发送url';


--
-- Name: tb_device_scence_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_device_scence_info (
    device_scence_did uuid NOT NULL,
    device_scence_sid uuid NOT NULL,
    device_scence_status integer DEFAULT 0 NOT NULL,
    device_scence_iid uuid,
    device_scence_status_type integer,
    CONSTRAINT tb_device_scence_info_device_scence_did_check CHECK ((device_scence_did <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_device_scence_info OWNER TO admin;

--
-- Name: COLUMN tb_device_scence_info.device_scence_did; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_device_scence_info.device_scence_did IS '设备（ipc，传感器等）ID';


--
-- Name: COLUMN tb_device_scence_info.device_scence_sid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_device_scence_info.device_scence_sid IS '情景ID';


--
-- Name: COLUMN tb_device_scence_info.device_scence_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_device_scence_info.device_scence_status IS '开关状态（0：关，1：开）';


--
-- Name: COLUMN tb_device_scence_info.device_scence_iid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_device_scence_info.device_scence_iid IS 'IPC ID';


--
-- Name: COLUMN tb_device_scence_info.device_scence_status_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_device_scence_info.device_scence_status_type IS '设备值类型';


--
-- Name: tb_fingerprint_scence; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_fingerprint_scence (
    fps_id uuid NOT NULL,
    fps_ipc_id uuid,
    fps_sensor_mac text,
    fps_fingerprint_name text,
    fps_fingerprint_id text,
    fps_scence_id uuid,
    fps_fingerprint_name1 text,
    fps_type integer DEFAULT 29 NOT NULL,
    fps_start_timer text,
    fps_stop_timer text,
    CONSTRAINT tb_fingerprint_scence_fps_id_check CHECK ((fps_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_fingerprint_scence OWNER TO admin;

--
-- Name: TABLE tb_fingerprint_scence; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_fingerprint_scence IS '保存指纹锁的指纹跟情景的关系';


--
-- Name: COLUMN tb_fingerprint_scence.fps_sensor_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_sensor_mac IS '传感器mac';


--
-- Name: COLUMN tb_fingerprint_scence.fps_fingerprint_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_fingerprint_name IS '指纹名称';


--
-- Name: COLUMN tb_fingerprint_scence.fps_fingerprint_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_fingerprint_id IS '指纹 ID ';


--
-- Name: COLUMN tb_fingerprint_scence.fps_scence_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_scence_id IS '情景ID';


--
-- Name: COLUMN tb_fingerprint_scence.fps_fingerprint_name1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_fingerprint_name1 IS '指纹名称1';


--
-- Name: COLUMN tb_fingerprint_scence.fps_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_type IS '开锁类型
29 // 指纹开锁  
30 // 密码开锁    设备事件
31 // 射频开锁    设备事件';


--
-- Name: COLUMN tb_fingerprint_scence.fps_start_timer; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_start_timer IS '情景开始时间';


--
-- Name: COLUMN tb_fingerprint_scence.fps_stop_timer; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_fingerprint_scence.fps_stop_timer IS '情景结束时间';


--
-- Name: tb_home_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_home_info (
    home_id uuid NOT NULL,
    home_name text,
    home_type integer DEFAULT 0,
    home_status integer DEFAULT 0,
    home_user_id uuid NOT NULL,
    home_icon text,
    home_register_time timestamp without time zone DEFAULT now() NOT NULL,
    home_addressid uuid,
    CONSTRAINT tb_home_info_home_id_check CHECK ((home_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_home_info OWNER TO admin;

--
-- Name: TABLE tb_home_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_home_info IS '房间表';


--
-- Name: COLUMN tb_home_info.home_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_id IS '房间ID';


--
-- Name: COLUMN tb_home_info.home_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_name IS '房间名称';


--
-- Name: COLUMN tb_home_info.home_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_type IS ' 0 默认 1 卧室 2  客厅 3 浴室 4 书房 5 餐厅 6 厨房 7 仓库 8 车库 9 阳台
';


--
-- Name: COLUMN tb_home_info.home_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_status IS '房间状态（）';


--
-- Name: COLUMN tb_home_info.home_user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_user_id IS '房间用户ID';


--
-- Name: COLUMN tb_home_info.home_icon; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_icon IS '房间图标';


--
-- Name: COLUMN tb_home_info.home_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_register_time IS '创建时间';


--
-- Name: COLUMN tb_home_info.home_addressid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_home_info.home_addressid IS '家庭地址（商铺）';


--
-- Name: tb_ip_address_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ip_address_info (
    ip_start_point inet NOT NULL,
    ip_end_point inet,
    ip_area integer DEFAULT 2 NOT NULL
);


ALTER TABLE tb_ip_address_info OWNER TO admin;

--
-- Name: COLUMN tb_ip_address_info.ip_start_point; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ip_address_info.ip_start_point IS '网段起点';


--
-- Name: COLUMN tb_ip_address_info.ip_end_point; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ip_address_info.ip_end_point IS '网段终点';


--
-- Name: COLUMN tb_ip_address_info.ip_area; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ip_address_info.ip_area IS '1：大陆 2：香港';


--
-- Name: tb_ipc_detector_rect; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_detector_rect (
    id uuid NOT NULL,
    ipc_id uuid NOT NULL,
    x1 integer DEFAULT 0,
    y1 integer DEFAULT 0,
    rect_width integer DEFAULT 0,
    rect_high integer DEFAULT 0,
    img_width integer DEFAULT 0,
    img_high integer DEFAULT 0,
    CONSTRAINT tb_ipc_detector_rect_id_check CHECK ((id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_ipc_detector_rect OWNER TO admin;

--
-- Name: TABLE tb_ipc_detector_rect; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_detector_rect IS 'ipc移动侦测区域';


--
-- Name: COLUMN tb_ipc_detector_rect.ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.ipc_id IS 'ipc的id';


--
-- Name: COLUMN tb_ipc_detector_rect.x1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.x1 IS '移动侦测区域起点坐标-x';


--
-- Name: COLUMN tb_ipc_detector_rect.y1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.y1 IS '移动侦测区域起点坐标-y';


--
-- Name: COLUMN tb_ipc_detector_rect.rect_width; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.rect_width IS '区域宽';


--
-- Name: COLUMN tb_ipc_detector_rect.rect_high; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.rect_high IS '区域高';


--
-- Name: COLUMN tb_ipc_detector_rect.img_width; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.img_width IS '图像宽';


--
-- Name: COLUMN tb_ipc_detector_rect.img_high; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_detector_rect.img_high IS '图像高';


--
-- Name: tb_ipc_exception; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_exception (
    exception_id uuid NOT NULL,
    exception_time timestamp without time zone,
    exception_desc text,
    exception_production_id text
);


ALTER TABLE tb_ipc_exception OWNER TO admin;

--
-- Name: TABLE tb_ipc_exception; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_exception IS 'IPC上报的异常';


--
-- Name: COLUMN tb_ipc_exception.exception_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_exception.exception_time IS 'UTC时间';


--
-- Name: COLUMN tb_ipc_exception.exception_desc; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_exception.exception_desc IS '异常';


--
-- Name: COLUMN tb_ipc_exception.exception_production_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_exception.exception_production_id IS 'IPC生产序列号，十六进制';


--
-- Name: tb_ipc_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_info (
    ipc_id uuid NOT NULL,
    ipc_name text,
    ipc_online boolean DEFAULT false NOT NULL,
    ipc_lan_ip text,
    ipc_mac text,
    ipc_register_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    ipc_device_model text,
    ipc_production_date timestamp without time zone,
    ipc_other_info text,
    ipc_safe_status boolean DEFAULT false NOT NULL,
    ipc_address_id uuid,
    ipc_broker_ip text,
    ipc_broker_queue_name text,
    ipc_wan_ip text,
    ipc_join_safe boolean DEFAULT true NOT NULL,
    ipc_broker_port integer,
    ipc_support_streamtype integer[],
    ipc_factory text DEFAULT 'ajb-ipc'::text,
    ipc_production_id text,
    ipc_services_id uuid,
    ipc_versions text NOT NULL,
    ipc_http_broker_ip text,
    ipc_http_broker_port integer,
    ipc_http_broker_queue_name text,
    ipc_stream_type integer DEFAULT 5 NOT NULL,
    ipc_home_id uuid,
    ipc_vmd_status boolean DEFAULT true NOT NULL,
    ipc_enable integer,
    voice_prompt_active boolean DEFAULT false NOT NULL,
    ipc_auto_upgrade boolean DEFAULT true NOT NULL,
    ipc_anti_flicker boolean DEFAULT false NOT NULL,
    ipc_has_tf boolean DEFAULT false NOT NULL,
    ipc_time_zone_name text DEFAULT 'UTC+8'::text,
    ipc_time_zone_offset integer DEFAULT (8 * 3600),
    ipc_videoswitch_status boolean DEFAULT true NOT NULL,
    ipc_switc_level integer DEFAULT 3 NOT NULL,
    ipc_wifi text,
    reversetype integer DEFAULT 4 NOT NULL,
    ipcosd text,
    ipc_sensor_num integer DEFAULT 18 NOT NULL,
    ipc_sensorlock_num integer DEFAULT 4 NOT NULL,
    sensor_type integer DEFAULT 1 NOT NULL,
    ipc_last_req_time timestamp without time zone,
    ipc_tf_record_type integer,
    ipc_delay_defence_times integer DEFAULT 90,
    app_factory text,
    ipc_wifi_name bytea,
    ipc_start_defence_time timestamp without time zone,
    CONSTRAINT tb_ipc_info_ipc_enable_check CHECK (((ipc_enable >= 0) AND (ipc_enable <= 1))),
    CONSTRAINT tb_ipc_info_ipc_id_check CHECK ((ipc_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_ipc_info_ipc_stream_type_check CHECK (((ipc_stream_type >= 1) AND (ipc_stream_type <= 6))),
    CONSTRAINT tb_ipc_info_ipc_switc_level_check CHECK (((ipc_switc_level >= 0) AND (ipc_switc_level <= 3))),
    CONSTRAINT tb_ipc_info_reversetype_check CHECK (((reversetype >= 1) AND (reversetype <= 4))),
    CONSTRAINT tb_ipc_info_reversetype_check1 CHECK (((reversetype >= 0) AND (reversetype <= 4))),
    CONSTRAINT tb_ipc_info_sensor_type_check CHECK (((sensor_type >= 0) AND (sensor_type <= 100)))
);


ALTER TABLE tb_ipc_info OWNER TO admin;

--
-- Name: COLUMN tb_ipc_info.ipc_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_name IS 'ipc的名称';


--
-- Name: COLUMN tb_ipc_info.ipc_online; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_online IS '在线状态（false：离线，true：在线）';


--
-- Name: COLUMN tb_ipc_info.ipc_lan_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_lan_ip IS 'lan ip';


--
-- Name: COLUMN tb_ipc_info.ipc_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_mac IS 'mac地址';


--
-- Name: COLUMN tb_ipc_info.ipc_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_register_time IS '注册时间';


--
-- Name: COLUMN tb_ipc_info.ipc_device_model; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_device_model IS '设备型号
';


--
-- Name: COLUMN tb_ipc_info.ipc_production_date; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_production_date IS 'ipc生产日期';


--
-- Name: COLUMN tb_ipc_info.ipc_other_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_other_info IS '描述信息';


--
-- Name: COLUMN tb_ipc_info.ipc_safe_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_safe_status IS '安防状态（false：撤防，true：布防）';


--
-- Name: COLUMN tb_ipc_info.ipc_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_address_id IS '所属商铺的id';


--
-- Name: COLUMN tb_ipc_info.ipc_broker_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_broker_ip IS 'qpid队列ip——暂时停用';


--
-- Name: COLUMN tb_ipc_info.ipc_broker_queue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_broker_queue_name IS 'qpid队列名称——暂时停用';


--
-- Name: COLUMN tb_ipc_info.ipc_wan_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_wan_ip IS 'wan ip';


--
-- Name: COLUMN tb_ipc_info.ipc_join_safe; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_join_safe IS '加入布防计划（false：不加入，true：加入）';


--
-- Name: COLUMN tb_ipc_info.ipc_broker_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_broker_port IS 'qpid队列端口——暂时停用';


--
-- Name: COLUMN tb_ipc_info.ipc_support_streamtype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_support_streamtype IS 'ipc支持的码流类型';


--
-- Name: COLUMN tb_ipc_info.ipc_factory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_factory IS 'ipc厂商';


--
-- Name: COLUMN tb_ipc_info.ipc_production_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_production_id IS '生产序列号';


--
-- Name: COLUMN tb_ipc_info.ipc_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_services_id IS 'ipc服务ID';


--
-- Name: COLUMN tb_ipc_info.ipc_versions; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_versions IS 'ipc版本号';


--
-- Name: COLUMN tb_ipc_info.ipc_http_broker_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_http_broker_ip IS '网关qpid队列ip';


--
-- Name: COLUMN tb_ipc_info.ipc_http_broker_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_http_broker_port IS '网关qpid队列端口';


--
-- Name: COLUMN tb_ipc_info.ipc_http_broker_queue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_http_broker_queue_name IS '网关qpid队列名称';


--
-- Name: COLUMN tb_ipc_info.ipc_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_stream_type IS '默认类型为5;
E_STR_MAIN_1080P = 1;
E_STR_SUB_720P = 2;
E_STR_SUB_D1 = 3;
E_STR_SUB_CIF = 4;
E_STR_NOTYPE=5;
E_STR_VGA = 6;	';


--
-- Name: COLUMN tb_ipc_info.ipc_home_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_home_id IS '房间id';


--
-- Name: COLUMN tb_ipc_info.ipc_vmd_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_vmd_status IS '移动侦测开启状态，默认 true';


--
-- Name: COLUMN tb_ipc_info.ipc_enable; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_enable IS '0：ipc正常使用，1：ipc不能使用--商铺欠费
';


--
-- Name: COLUMN tb_ipc_info.voice_prompt_active; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.voice_prompt_active IS 'ipc语音报警开关
';


--
-- Name: COLUMN tb_ipc_info.ipc_auto_upgrade; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_auto_upgrade IS '是否自动升级';


--
-- Name: COLUMN tb_ipc_info.ipc_anti_flicker; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_anti_flicker IS '抗闪烁开关';


--
-- Name: COLUMN tb_ipc_info.ipc_has_tf; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_has_tf IS '是否有tf卡 false 没有 true 有';


--
-- Name: COLUMN tb_ipc_info.ipc_time_zone_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_time_zone_name IS '所在时区';


--
-- Name: COLUMN tb_ipc_info.ipc_time_zone_offset; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_time_zone_offset IS '时区偏移值';


--
-- Name: COLUMN tb_ipc_info.ipc_videoswitch_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_videoswitch_status IS '音视频开关';


--
-- Name: COLUMN tb_ipc_info.ipc_switc_level; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_switc_level IS '移动侦测等级 ';


--
-- Name: COLUMN tb_ipc_info.reversetype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.reversetype IS '图像反转类型';


--
-- Name: COLUMN tb_ipc_info.ipcosd; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipcosd IS 'ipc通道名称';


--
-- Name: COLUMN tb_ipc_info.ipc_sensor_num; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_sensor_num IS 'ipc传感器个数 默认18';


--
-- Name: COLUMN tb_ipc_info.ipc_sensorlock_num; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_sensorlock_num IS 'ipc锁的个数 默认4';


--
-- Name: COLUMN tb_ipc_info.sensor_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.sensor_type IS '传感器类型(01:ipc， 35，36：智能网关)';


--
-- Name: COLUMN tb_ipc_info.ipc_last_req_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_last_req_time IS '最后一次访问的时间';


--
-- Name: COLUMN tb_ipc_info.ipc_tf_record_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_tf_record_type IS 'ipc tf卡录像类型
0 报警时录像
1 永久录像';


--
-- Name: COLUMN tb_ipc_info.ipc_delay_defence_times; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_delay_defence_times IS 'ipc延时布防时间，单位秒';


--
-- Name: COLUMN tb_ipc_info.app_factory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.app_factory IS '标记给哪个厂商用';


--
-- Name: COLUMN tb_ipc_info.ipc_wifi_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_wifi_name IS 'ipc wifi名称';


--
-- Name: COLUMN tb_ipc_info.ipc_start_defence_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_info.ipc_start_defence_time IS 'ipc开始布防时间';


--
-- Name: tb_ipc_ptz_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_ptz_info (
    ptz_id uuid NOT NULL,
    ptz_ipc_id uuid,
    ptz_preset_name text,
    ptz_preset_number integer,
    ptz_preset_x integer,
    ptz_preset_y integer
);


ALTER TABLE tb_ipc_ptz_info OWNER TO admin;

--
-- Name: COLUMN tb_ipc_ptz_info.ptz_ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_ptz_info.ptz_ipc_id IS 'ipc id';


--
-- Name: COLUMN tb_ipc_ptz_info.ptz_preset_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_ptz_info.ptz_preset_name IS '预置点名称';


--
-- Name: COLUMN tb_ipc_ptz_info.ptz_preset_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_ptz_info.ptz_preset_number IS '预置点标记';


--
-- Name: COLUMN tb_ipc_ptz_info.ptz_preset_x; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_ptz_info.ptz_preset_x IS '预置点x坐标';


--
-- Name: COLUMN tb_ipc_ptz_info.ptz_preset_y; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_ptz_info.ptz_preset_y IS '预置点y坐标';


--
-- Name: tb_ipc_restore_settings; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_restore_settings (
    ipc_device_model text NOT NULL,
    ipc_vmd_status boolean DEFAULT true NOT NULL,
    voice_prompt_active boolean DEFAULT false NOT NULL,
    ipc_auto_upgrade boolean DEFAULT true NOT NULL,
    ipc_anti_flicker boolean DEFAULT false NOT NULL,
    ipc_videoswitch_status boolean DEFAULT true NOT NULL,
    ipc_switc_level integer DEFAULT 3 NOT NULL,
    reversetype integer DEFAULT 4 NOT NULL,
    ipcosd text,
    ipc_time_zone_name text DEFAULT 'UTC+8'::text,
    ipc_time_zone_offset integer DEFAULT (8 * 3600),
    ipc_delay_defence_times integer DEFAULT 90,
    ipc_tf_record_forever integer DEFAULT 0,
    ipc_functions text[]
);


ALTER TABLE tb_ipc_restore_settings OWNER TO admin;

--
-- Name: TABLE tb_ipc_restore_settings; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_restore_settings IS 'ipc默认出厂状态值';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_device_model; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_device_model IS 'ipc设备类型';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_vmd_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_vmd_status IS '移动侦测开启状态，默认 true';


--
-- Name: COLUMN tb_ipc_restore_settings.voice_prompt_active; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.voice_prompt_active IS 'ipc语音报警开关';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_auto_upgrade; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_auto_upgrade IS '是否自动升级';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_anti_flicker; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_anti_flicker IS '抗闪烁开关';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_videoswitch_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_videoswitch_status IS '音视频开关';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_switc_level; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_switc_level IS '移动侦测等级 ';


--
-- Name: COLUMN tb_ipc_restore_settings.reversetype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.reversetype IS '图像反转类型';


--
-- Name: COLUMN tb_ipc_restore_settings.ipcosd; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipcosd IS 'ipc通道名称';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_time_zone_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_time_zone_name IS '所在时区';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_time_zone_offset; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_time_zone_offset IS '时区偏移值';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_delay_defence_times; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_delay_defence_times IS 'ipc延时布防时间，单位秒';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_tf_record_forever; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_tf_record_forever IS 'ipc tf卡录像类型
0 报警时录像
1 永久录像';


--
-- Name: COLUMN tb_ipc_restore_settings.ipc_functions; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_restore_settings.ipc_functions IS 'IPC拥有的功能';


--
-- Name: tb_ipc_sensor_log; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_sensor_log (
    isl_id uuid NOT NULL,
    isl_address_id uuid,
    isl_user_id uuid,
    isl_ipc_or_sensor_id uuid,
    isl_sensor_type integer,
    isl_production_mac_id text,
    isl_user_mobile text,
    isl_operating_mode integer,
    isl_operating_time timestamp without time zone
);


ALTER TABLE tb_ipc_sensor_log OWNER TO admin;

--
-- Name: TABLE tb_ipc_sensor_log; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_sensor_log IS '用户操作IPC、sensor记录，只记录包括添加、删除等记录';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_address_id IS '家id';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_user_id IS '用户id';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_ipc_or_sensor_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_ipc_or_sensor_id IS 'ipc_id或sensor_id';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_sensor_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_sensor_type IS '传感器类型；';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_production_mac_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_production_mac_id IS 'ipc的production_id或sensor的sensor_mac';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_user_mobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_user_mobile IS '用户手机号码';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_operating_mode; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_operating_mode IS '用户操作方式， -1：删除 0：其他 1：添加';


--
-- Name: COLUMN tb_ipc_sensor_log.isl_operating_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensor_log.isl_operating_time IS '操作记录时间，UTC时间';


--
-- Name: tb_ipc_sensordata; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_sensordata (
    sensordata_dataid uuid NOT NULL,
    sensordata_sensormac text,
    sensordata_ipcid uuid NOT NULL,
    sensordata_datatime timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    sensordata_sensortype integer,
    sensordata_value integer,
    sensordata_value1 integer,
    sensordata_value_type integer,
    sensordata_sequence integer,
    CONSTRAINT tb_ipc_sensordata_sensordata_dataid_check CHECK ((sensordata_dataid <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_ipc_sensordata OWNER TO admin;

--
-- Name: TABLE tb_ipc_sensordata; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_sensordata IS '保存ipc上报的传感器数据';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_sensormac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_sensormac IS '传感器mac地址';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_ipcid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_ipcid IS 'ipcid';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_datatime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_datatime IS '数据上报的时间';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_sensortype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_sensortype IS '传感器类型';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_value; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_value IS '传感器值';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_value1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_value1 IS '传感器值1';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_value_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_value_type IS '值的类型';


--
-- Name: COLUMN tb_ipc_sensordata.sensordata_sequence; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata.sensordata_sequence IS '用电量次数序号，ipc上传当次用电的累积值，连续相同的序号标明是同一次用电';


--
-- Name: tb_ipc_sensordata_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_sensordata_history (
    sensordata_dataid uuid NOT NULL,
    sensordata_sensormac text,
    sensordata_ipcid uuid NOT NULL,
    sensordata_datatime timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    sensordata_sensortype integer,
    sensordata_value integer,
    sensordata_value1 integer,
    sensordata_value_type integer,
    sensordata_sequence integer
);


ALTER TABLE tb_ipc_sensordata_history OWNER TO admin;

--
-- Name: TABLE tb_ipc_sensordata_history; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_sensordata_history IS '保存ipc上报的传感器数据';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_sensormac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_sensormac IS '传感器mac地址';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_ipcid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_ipcid IS 'ipcid';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_datatime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_datatime IS '数据上报的时间';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_sensortype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_sensortype IS '传感器类型';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_value; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_value IS '传感器值';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_value1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_value1 IS '传感器值1';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_value_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_value_type IS '值的类型';


--
-- Name: COLUMN tb_ipc_sensordata_history.sensordata_sequence; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_sensordata_history.sensordata_sequence IS '用电量次数序号，ipc上传当次用电的累积值，连续相同的序号标明是同一次用电';


--
-- Name: tb_ipc_session_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_session_info (
    ipc_id uuid NOT NULL,
    ipc_factory text DEFAULT 'ajb-ipc'::text NOT NULL,
    product_code text NOT NULL,
    server_id uuid NOT NULL,
    on_line boolean NOT NULL,
    last_login_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    last_req_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    ipc_version text,
    CONSTRAINT tb_ipc_session_info_ipc_id_check CHECK ((ipc_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_ipc_session_info OWNER TO admin;

--
-- Name: TABLE tb_ipc_session_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_session_info IS 'ipc全局会话信息表';


--
-- Name: COLUMN tb_ipc_session_info.ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.ipc_id IS 'ipc_uuid';


--
-- Name: COLUMN tb_ipc_session_info.product_code; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.product_code IS 'ipc产品标识码(16进制字符串)';


--
-- Name: COLUMN tb_ipc_session_info.server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.server_id IS '所属的control_server';


--
-- Name: COLUMN tb_ipc_session_info.on_line; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.on_line IS '在线状态';


--
-- Name: COLUMN tb_ipc_session_info.last_login_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.last_login_time IS '最后登录时间';


--
-- Name: COLUMN tb_ipc_session_info.last_req_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.last_req_time IS '最后一次请求时间';


--
-- Name: COLUMN tb_ipc_session_info.ipc_version; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_session_info.ipc_version IS '版本号';


--
-- Name: tb_ipc_versions_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ipc_versions_info (
    ipc_device_model text NOT NULL,
    ipc_versions text NOT NULL,
    ipc_release_date timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    ipc_release_address text NOT NULL,
    ipc_versions_description text NOT NULL,
    ipc_versions_type integer NOT NULL
);


ALTER TABLE tb_ipc_versions_info OWNER TO admin;

--
-- Name: TABLE tb_ipc_versions_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_ipc_versions_info IS 'IPC版本管理信息';


--
-- Name: COLUMN tb_ipc_versions_info.ipc_device_model; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_versions_info.ipc_device_model IS 'IPC设备型号';


--
-- Name: COLUMN tb_ipc_versions_info.ipc_versions; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_versions_info.ipc_versions IS 'IPC版本号';


--
-- Name: COLUMN tb_ipc_versions_info.ipc_release_date; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_versions_info.ipc_release_date IS 'IPC发布时间';


--
-- Name: COLUMN tb_ipc_versions_info.ipc_release_address; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_versions_info.ipc_release_address IS 'IPC发布地址';


--
-- Name: COLUMN tb_ipc_versions_info.ipc_versions_description; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_versions_info.ipc_versions_description IS 'IPC版本说明信息';


--
-- Name: COLUMN tb_ipc_versions_info.ipc_versions_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_ipc_versions_info.ipc_versions_type IS 'IPC版本类型：
E_FS = 1;              //文件系统；
E_KERNAL = 2;          //内核；
E_FS_KERNAL =3;        //文件系统 和 内核；
E_APP = 4;             //应用程序
';


--
-- Name: tb_key_homeappliance_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_key_homeappliance_info (
    key_homeappliance_id uuid NOT NULL,
    key_homeappliance_name text,
    key_number integer NOT NULL,
    sensor_mac text,
    home_appliance_id uuid
);


ALTER TABLE tb_key_homeappliance_info OWNER TO admin;

--
-- Name: TABLE tb_key_homeappliance_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_key_homeappliance_info IS '情景按键信息';


--
-- Name: COLUMN tb_key_homeappliance_info.key_homeappliance_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_key_homeappliance_info.key_homeappliance_id IS '按键情景id';


--
-- Name: COLUMN tb_key_homeappliance_info.key_homeappliance_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_key_homeappliance_info.key_homeappliance_name IS '按键情景名称';


--
-- Name: COLUMN tb_key_homeappliance_info.key_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_key_homeappliance_info.key_number IS '按键号';


--
-- Name: COLUMN tb_key_homeappliance_info.sensor_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_key_homeappliance_info.sensor_mac IS '传感器mac地址---该设备父节点的id 一般是传感器的mac';


--
-- Name: COLUMN tb_key_homeappliance_info.home_appliance_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_key_homeappliance_info.home_appliance_id IS '子设备ID---情景属于哪个子设备';


--
-- Name: tb_linkage_action_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_linkage_action_info (
    action_id uuid NOT NULL,
    action_type integer,
    action_value integer,
    action_event_id uuid,
    action_sensor_id uuid
);


ALTER TABLE tb_linkage_action_info OWNER TO admin;

--
-- Name: TABLE tb_linkage_action_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_linkage_action_info IS '联动事件动作表';


--
-- Name: COLUMN tb_linkage_action_info.action_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_action_info.action_type IS '联动动作类型. 0：关闭 1：打开';


--
-- Name: COLUMN tb_linkage_action_info.action_value; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_action_info.action_value IS '档次（值）';


--
-- Name: COLUMN tb_linkage_action_info.action_event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_action_info.action_event_id IS '联动事件id';


--
-- Name: COLUMN tb_linkage_action_info.action_sensor_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_action_info.action_sensor_id IS '联动传感器id';


--
-- Name: tb_linkage_answer_sensor_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_linkage_answer_sensor_info (
    act_id uuid NOT NULL,
    act_link_event_id uuid,
    act_answer_sensor_id uuid,
    act_answer_sensor_type integer,
    act_answer_sensor_name text,
    act_answer_sensor_mac text,
    act_answer_ipc_id uuid
);


ALTER TABLE tb_linkage_answer_sensor_info OWNER TO admin;

--
-- Name: TABLE tb_linkage_answer_sensor_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_linkage_answer_sensor_info IS '联动响应传感器信息表';


--
-- Name: COLUMN tb_linkage_answer_sensor_info.act_link_event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_answer_sensor_info.act_link_event_id IS '联动事件id';


--
-- Name: COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_id IS '响应联动事件的传感器id';


--
-- Name: COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_type IS '响应联动事件的传感器类型';


--
-- Name: COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_name IS '响应联动事件的传感器名称';


--
-- Name: COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_answer_sensor_info.act_answer_sensor_mac IS '响应联动事件的传感器mac';


--
-- Name: tb_linkage_condition_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_linkage_condition_info (
    cond_id uuid NOT NULL,
    cond_value integer,
    cond_value_type integer,
    cond_function_type integer,
    cond_event_id uuid
);


ALTER TABLE tb_linkage_condition_info OWNER TO admin;

--
-- Name: TABLE tb_linkage_condition_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_linkage_condition_info IS '联动条件信息';


--
-- Name: COLUMN tb_linkage_condition_info.cond_value_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_condition_info.cond_value_type IS '1:< 2:>';


--
-- Name: COLUMN tb_linkage_condition_info.cond_function_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_condition_info.cond_function_type IS '1:温度 2：湿度';


--
-- Name: COLUMN tb_linkage_condition_info.cond_event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_condition_info.cond_event_id IS '联动事件id';


--
-- Name: tb_linkage_trigger_sensor_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_linkage_trigger_sensor_info (
    link_id uuid NOT NULL,
    link_trigger_sensor_id uuid,
    link_ipc_id uuid,
    link_event_id uuid,
    link_trigger_sensor_type integer,
    link_trigger_sensor_name text,
    link_trigger_sensor_mac text,
    link_enable boolean,
    link_cond_union integer,
    link_day_of_week integer[],
    link_begin_time text,
    link_per integer,
    link_end_time text,
    link_register_time timestamp without time zone
);


ALTER TABLE tb_linkage_trigger_sensor_info OWNER TO admin;

--
-- Name: TABLE tb_linkage_trigger_sensor_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_linkage_trigger_sensor_info IS '联动触发传感器表';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_id IS '触发联动事件的传感器id';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_ipc_id IS 'ipc id';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_event_id IS '联动事件id
id相同表示同一个联动事件';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_type IS '触发联动事件的传感器类型';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_name IS '触发联动事件的传感器名称';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_trigger_sensor_mac IS '触发联动事件的传感器mac';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_enable; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_enable IS 'true: 打开联动 false: 关闭联动';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_cond_union; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_cond_union IS '1:满足所有触发条件才联动 
2:只要满足一个触发条件就会联动';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_day_of_week; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_day_of_week IS '周任务时要填';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_begin_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_begin_time IS '开始时间 格式 09:30:00 ';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_per; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_per IS '周期';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_end_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_end_time IS '结束时间';


--
-- Name: COLUMN tb_linkage_trigger_sensor_info.link_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_linkage_trigger_sensor_info.link_register_time IS '联动注册时间';


--
-- Name: tb_login_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_login_info (
    login_id uuid NOT NULL,
    login_user text,
    login_time timestamp without time zone,
    login_result integer,
    login_app_type integer,
    login_ostype integer,
    login_app_factory text
);


ALTER TABLE tb_login_info OWNER TO admin;

--
-- Name: COLUMN tb_login_info.login_user; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_login_info.login_user IS '登录帐号';


--
-- Name: COLUMN tb_login_info.login_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_login_info.login_time IS '登录时间';


--
-- Name: COLUMN tb_login_info.login_result; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_login_info.login_result IS '登录结果
0：成功
1：密码错误，登录失败
2：最近1小时内连续登录失败10次，帐号被锁定1小时';


--
-- Name: COLUMN tb_login_info.login_app_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_login_info.login_app_type IS '登录app类型';


--
-- Name: COLUMN tb_login_info.login_ostype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_login_info.login_ostype IS '登录系统';


--
-- Name: COLUMN tb_login_info.login_app_factory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_login_info.login_app_factory IS 'app厂家';


--
-- Name: tb_oauth_authentication; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_oauth_authentication (
    user_id uuid NOT NULL,
    expired_time text NOT NULL,
    access_token text NOT NULL,
    refresh_token text NOT NULL,
    party_name text NOT NULL,
    id uuid NOT NULL
);


ALTER TABLE tb_oauth_authentication OWNER TO admin;

--
-- Name: tb_op_address_alloc_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_op_address_alloc_info (
    op_addr_id uuid NOT NULL,
    op_addr_uid uuid,
    op_addr_addrid uuid,
    op_addr_alloc_time timestamp without time zone,
    op_addr_alarm_point uuid,
    op_addr_user_mobile text,
    CONSTRAINT tb_op_address_alloc_info_op_addr_id_check CHECK ((op_addr_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_op_address_alloc_info OWNER TO admin;

--
-- Name: COLUMN tb_op_address_alloc_info.op_addr_uid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_address_alloc_info.op_addr_uid IS '接警人员id';


--
-- Name: COLUMN tb_op_address_alloc_info.op_addr_addrid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_address_alloc_info.op_addr_addrid IS '商铺id';


--
-- Name: COLUMN tb_op_address_alloc_info.op_addr_alloc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_address_alloc_info.op_addr_alloc_time IS '分派时间';


--
-- Name: COLUMN tb_op_address_alloc_info.op_addr_alarm_point; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_address_alloc_info.op_addr_alarm_point IS '接警点';


--
-- Name: COLUMN tb_op_address_alloc_info.op_addr_user_mobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_address_alloc_info.op_addr_user_mobile IS '运营人员电话号码';


--
-- Name: tb_op_alarm_alloc_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_op_alarm_alloc_info (
    alloc_id uuid NOT NULL,
    alloc_user_id uuid,
    alloc_alarm_id uuid,
    alloc_remarks text,
    alloc_time timestamp without time zone,
    alloc_handle_time timestamp without time zone,
    alloc_handle_status integer,
    alloc_op_user_number text,
    alloc_police_man text,
    alloc_attendance_time time without time zone,
    alloc_event_trace text,
    CONSTRAINT tb_op_alarm_alloc_info_alloc_handle_status_check CHECK (((alloc_handle_status >= 1) AND (alloc_handle_status <= 4))),
    CONSTRAINT tb_op_alarm_alloc_info_alloc_id_check CHECK ((alloc_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_op_alarm_alloc_info OWNER TO admin;

--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_user_id IS '运营用户id';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_alarm_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_alarm_id IS '报警事件id';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_remarks; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_remarks IS '备注';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_time IS '报警事件分派给时间';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_handle_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_handle_time IS '报警事件处理时间';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_handle_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_handle_status IS '处理状态 1：已经处理 2:未处理 3：未成功处理 4:已挂起';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_op_user_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_op_user_number IS '运维人员编号。';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_police_man; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_police_man IS '出警人';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_attendance_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_attendance_time IS '到场时间';


--
-- Name: COLUMN tb_op_alarm_alloc_info.alloc_event_trace; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_alloc_info.alloc_event_trace IS '事件跟踪';


--
-- Name: tb_op_alarm_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_op_alarm_info (
    op_alarm_id uuid NOT NULL,
    op_alarm_address_id uuid,
    op_alarm_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    op_alarm_record_id uuid,
    op_alarm_alloc_status integer,
    op_alarm_point_id uuid,
    op_alarm_content bytea,
    op_alarm_type integer,
    op_alarm_level integer DEFAULT 1 NOT NULL,
    op_alarm_av_switch boolean DEFAULT false NOT NULL,
    CONSTRAINT tb_op_alarm_info_op_alarm_id_check CHECK ((op_alarm_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_op_alarm_info_op_alarm_type_check CHECK (((op_alarm_type >= 0) AND (op_alarm_type <= 42)))
);


ALTER TABLE tb_op_alarm_info OWNER TO admin;

--
-- Name: COLUMN tb_op_alarm_info.op_alarm_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_address_id IS '商铺id';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_record_id IS '告警录制视频ID';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_alloc_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_alloc_status IS '1：已分派 2：未分派 3：正在分派';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_point_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_point_id IS '接警点id';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_content; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_content IS '报警内容';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_type IS '告警类型（0：其它，1：门磁，2：红外，3：烟感，4：移动侦测，5：。。。）';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_level; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_level IS '报警等级，数值越大等级越高';


--
-- Name: COLUMN tb_op_alarm_info.op_alarm_av_switch; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_alarm_info.op_alarm_av_switch IS '音视频开关状态  开：true 关：false';


--
-- Name: tb_op_point_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_op_point_info (
    op_point_id uuid NOT NULL,
    op_point_name text,
    op_point_mobile text NOT NULL,
    op_point_phone text,
    op_point_address text,
    op_point_longitude text DEFAULT '0'::text NOT NULL,
    op_point_latitude text DEFAULT '0'::text NOT NULL,
    op_point_country text,
    op_point_province text,
    op_point_city text,
    op_point_district text,
    op_point_register_time timestamp without time zone DEFAULT (now())::timestamp without time zone,
    op_point_contact text,
    op_point_contact_phone text,
    op_point_status integer,
    CONSTRAINT tb_op_point_info_op_point_id_check CHECK ((op_point_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_op_point_info_op_point_status_check CHECK (((op_point_status >= 1) AND (op_point_status <= 3)))
);


ALTER TABLE tb_op_point_info OWNER TO admin;

--
-- Name: TABLE tb_op_point_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_op_point_info IS '接警点';


--
-- Name: COLUMN tb_op_point_info.op_point_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_name IS '接警点名称';


--
-- Name: COLUMN tb_op_point_info.op_point_mobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_mobile IS '注册时要填写，审核通过后，这个电话作为这个接警点的管理员账号，写入 tb_op_user_info表中';


--
-- Name: COLUMN tb_op_point_info.op_point_phone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_phone IS '接警点电话';


--
-- Name: COLUMN tb_op_point_info.op_point_address; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_address IS '接警点地址';


--
-- Name: COLUMN tb_op_point_info.op_point_longitude; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_longitude IS '接警点的经度';


--
-- Name: COLUMN tb_op_point_info.op_point_latitude; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_latitude IS '接警点的纬度';


--
-- Name: COLUMN tb_op_point_info.op_point_country; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_country IS '接警点所在国家';


--
-- Name: COLUMN tb_op_point_info.op_point_province; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_province IS '接警点所在省份';


--
-- Name: COLUMN tb_op_point_info.op_point_city; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_city IS '接警点所在市';


--
-- Name: COLUMN tb_op_point_info.op_point_district; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_district IS '接警点所在区';


--
-- Name: COLUMN tb_op_point_info.op_point_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_register_time IS '注册时间';


--
-- Name: COLUMN tb_op_point_info.op_point_contact; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_contact IS '联系人';


--
-- Name: COLUMN tb_op_point_info.op_point_contact_phone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_contact_phone IS '联系电话';


--
-- Name: COLUMN tb_op_point_info.op_point_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_point_info.op_point_status IS '接警点状态
1 审核中
2 审核通过
3 欠费';


--
-- Name: tb_op_user_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_op_user_info (
    op_user_id uuid NOT NULL,
    op_user_name text,
    op_user_password text NOT NULL,
    op_user_email text,
    op_user_phone text NOT NULL,
    op_user_mobile text NOT NULL,
    op_user_online boolean DEFAULT false NOT NULL,
    op_user_register_time timestamp without time zone DEFAULT (now())::timestamp without time zone,
    op_user_login_time timestamp without time zone,
    op_user_broker_ip text,
    op_user_broker_queue_name text,
    op_user_broker_port integer,
    op_user_clientid uuid,
    op_user_type integer,
    op_user_point_id uuid NOT NULL,
    CONSTRAINT tb_op_user_info_op_user_id_check CHECK ((op_user_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_op_user_info_op_user_type_check CHECK (((op_user_type >= 1) AND (op_user_type <= 3)))
);


ALTER TABLE tb_op_user_info OWNER TO admin;

--
-- Name: TABLE tb_op_user_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_op_user_info IS 'op用户表';


--
-- Name: COLUMN tb_op_user_info.op_user_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_name IS '运营人员账户';


--
-- Name: COLUMN tb_op_user_info.op_user_password; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_password IS '密码';


--
-- Name: COLUMN tb_op_user_info.op_user_email; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_email IS '运营用户邮件地址';


--
-- Name: COLUMN tb_op_user_info.op_user_phone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_phone IS '运营人员联系电话';


--
-- Name: COLUMN tb_op_user_info.op_user_mobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_mobile IS '运营人员手机号码';


--
-- Name: COLUMN tb_op_user_info.op_user_online; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_online IS '在线状态
false 离线
true 在线';


--
-- Name: COLUMN tb_op_user_info.op_user_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_register_time IS '运营用户注册时间';


--
-- Name: COLUMN tb_op_user_info.op_user_login_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_login_time IS '运营用户登录时间';


--
-- Name: COLUMN tb_op_user_info.op_user_broker_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_broker_ip IS '消息中间件所在主机IP';


--
-- Name: COLUMN tb_op_user_info.op_user_broker_queue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_broker_queue_name IS '用户在消息中间件上的消息队列';


--
-- Name: COLUMN tb_op_user_info.op_user_broker_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_broker_port IS '消息中间件使用的端口';


--
-- Name: COLUMN tb_op_user_info.op_user_clientid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_clientid IS '客户端唯一识别码';


--
-- Name: COLUMN tb_op_user_info.op_user_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_type IS '用户类型
1 超级管理员
2 接警点管理员
3 接警点普通运维人员';


--
-- Name: COLUMN tb_op_user_info.op_user_point_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_info.op_user_point_id IS '关联的接警点id';


--
-- Name: tb_op_user_record; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_op_user_record (
    record_id uuid NOT NULL,
    record_user_id uuid NOT NULL,
    record_event_type integer NOT NULL,
    record_source_id uuid NOT NULL,
    record_destinations_id uuid,
    record_note text,
    record_event_time timestamp without time zone DEFAULT (now())::timestamp without time zone,
    CONSTRAINT tb_op_user_record_record_id_check CHECK ((record_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_op_user_record OWNER TO admin;

--
-- Name: COLUMN tb_op_user_record.record_event_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_record.record_event_type IS 'update_addr_mobile =1;	//修改商铺注册手机号
removes_ipc =2;			//解绑IPC
removes_sensor=3;		//解绑传感器
update_all_addr_mobile=4;	//转移用户商铺所有权review_alarm_point=5;		//审核接警点';


--
-- Name: COLUMN tb_op_user_record.record_source_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_record.record_source_id IS '操作对象id';


--
-- Name: COLUMN tb_op_user_record.record_destinations_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_record.record_destinations_id IS '变更对象ID';


--
-- Name: COLUMN tb_op_user_record.record_note; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_record.record_note IS '说明';


--
-- Name: COLUMN tb_op_user_record.record_event_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_op_user_record.record_event_time IS '事件操作时间';


--
-- Name: tb_operater_event_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_operater_event_info (
    id uuid NOT NULL,
    user_id uuid,
    event_id uuid,
    remarks text,
    alloc_time timestamp without time zone,
    handle_time timestamp without time zone,
    handle_status integer,
    op_user_number text,
    CONSTRAINT tb_operater_event_info_handle_status_check CHECK (((handle_status >= 0) AND (handle_status <= 3))),
    CONSTRAINT tb_operater_event_info_id_check CHECK ((id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_operater_event_info OWNER TO admin;

--
-- Name: COLUMN tb_operater_event_info.user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.user_id IS '运营用户id';


--
-- Name: COLUMN tb_operater_event_info.event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.event_id IS '报警事件id';


--
-- Name: COLUMN tb_operater_event_info.remarks; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.remarks IS '备注';


--
-- Name: COLUMN tb_operater_event_info.alloc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.alloc_time IS '报警事件分派给时间';


--
-- Name: COLUMN tb_operater_event_info.handle_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.handle_time IS '报警事件处理时间';


--
-- Name: COLUMN tb_operater_event_info.handle_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.handle_status IS '处理状态 1：已经处理 2:未处理 3：未成功处理';


--
-- Name: COLUMN tb_operater_event_info.op_user_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_operater_event_info.op_user_number IS '运维人员编号。';


--
-- Name: tb_product_id; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_product_id (
    product_id text NOT NULL,
    create_time timestamp without time zone NOT NULL,
    company text,
    type text,
    model text
);


ALTER TABLE tb_product_id OWNER TO admin;

--
-- Name: TABLE tb_product_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_product_id IS '产品id集合';


--
-- Name: tb_product_id_ipc; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_product_id_ipc (
    product_id text NOT NULL,
    create_time timestamp without time zone NOT NULL,
    company text,
    model text,
    type text
);


ALTER TABLE tb_product_id_ipc OWNER TO admin;

--
-- Name: TABLE tb_product_id_ipc; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_product_id_ipc IS 'ipc产品id集合';


--
-- Name: tb_product_id_ipc_conf; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_product_id_ipc_conf (
    model character varying(255) NOT NULL,
    serial_prefix character varying(10) NOT NULL,
    id_prefix character varying(10) NOT NULL,
    last_num bigint NOT NULL
);


ALTER TABLE tb_product_id_ipc_conf OWNER TO admin;

--
-- Name: tb_push_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_push_info (
    push_id uuid NOT NULL,
    push_type integer DEFAULT 0 NOT NULL,
    push_report_status boolean DEFAULT false NOT NULL,
    push_user_id uuid NOT NULL,
    push_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    push_content bytea,
    push_admin_status boolean DEFAULT false,
    CONSTRAINT tb_push_info_push_id_check CHECK ((push_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_push_info_push_type_check CHECK (((push_type >= 0) AND (push_type <= 11)))
);


ALTER TABLE tb_push_info OWNER TO admin;

--
-- Name: COLUMN tb_push_info.push_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_id IS '推送ID';


--
-- Name: COLUMN tb_push_info.push_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_type IS '1 告警
2 邀请用户
3 设备掉线
4 切换视频
5 踢出邀请 
6 ipc升级结果
7 设备上线
8 下载提示
9 硬件告警
10 传感器上下线
11 传感器提醒';


--
-- Name: COLUMN tb_push_info.push_report_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_report_status IS '推送状态（false：未推送，true：已推送）';


--
-- Name: COLUMN tb_push_info.push_user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_user_id IS '推送用户';


--
-- Name: COLUMN tb_push_info.push_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_time IS '推送时间';


--
-- Name: COLUMN tb_push_info.push_content; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_content IS '推送消息';


--
-- Name: COLUMN tb_push_info.push_admin_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info.push_admin_status IS '分配给管理员处理状态：true 已分配，flase 未分配。';


--
-- Name: tb_push_info_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_push_info_history (
    push_id uuid NOT NULL,
    push_type integer DEFAULT 0 NOT NULL,
    push_report_status boolean DEFAULT false NOT NULL,
    push_user_id uuid NOT NULL,
    push_time timestamp without time zone DEFAULT (now())::timestamp without time zone NOT NULL,
    push_content bytea,
    push_admin_status boolean DEFAULT false
);


ALTER TABLE tb_push_info_history OWNER TO admin;

--
-- Name: COLUMN tb_push_info_history.push_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_id IS '推送ID';


--
-- Name: COLUMN tb_push_info_history.push_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_type IS '推送类型（0：通知消息 1：。。。）';


--
-- Name: COLUMN tb_push_info_history.push_report_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_report_status IS '推送状态（false：未推送，true：已推送）';


--
-- Name: COLUMN tb_push_info_history.push_user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_user_id IS '推送用户';


--
-- Name: COLUMN tb_push_info_history.push_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_time IS '推送时间';


--
-- Name: COLUMN tb_push_info_history.push_content; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_content IS '推送消息';


--
-- Name: COLUMN tb_push_info_history.push_admin_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_info_history.push_admin_status IS '分配给管理员处理状态：true 已分配，flase 未分配。';


--
-- Name: tb_record_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_record_info (
    record_id uuid NOT NULL,
    record_ipc_id uuid NOT NULL,
    record_address_id uuid,
    record_url text,
    record_start_time timestamp without time zone NOT NULL,
    record_stop_time timestamp without time zone NOT NULL,
    record_type integer DEFAULT 0 NOT NULL,
    record_user_id uuid,
    record_file_name text,
    record_timerworkid uuid,
    record_ipc_url text,
    record_live_stream_id uuid,
    record_duration integer,
    record_inner_file_name text,
    record_services_id uuid,
    record_status integer DEFAULT 1,
    record_img_url text,
    record_file_size integer DEFAULT 0 NOT NULL,
    record_http_url text,
    record_start_ipc_time timestamp without time zone,
    record_stop_ipc_time timestamp without time zone,
    record_picture_size integer DEFAULT 0 NOT NULL,
    CONSTRAINT tb_record_info_record_id_check CHECK ((record_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_record_info_record_status_check CHECK (((record_status >= 1) AND (record_status <= 3))),
    CONSTRAINT tb_record_info_record_type_check CHECK (((record_type >= 0) AND (record_type <= 1)))
);


ALTER TABLE tb_record_info OWNER TO admin;

--
-- Name: COLUMN tb_record_info.record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_id IS '唯一标识';


--
-- Name: COLUMN tb_record_info.record_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_address_id IS '地点的标识，uuid类型，可以是商铺、家庭等';


--
-- Name: COLUMN tb_record_info.record_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_url IS '录像回放的流地址';


--
-- Name: COLUMN tb_record_info.record_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_start_time IS '录像（操作）开始的时间';


--
-- Name: COLUMN tb_record_info.record_stop_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_stop_time IS '录像（操作）完成的时间';


--
-- Name: COLUMN tb_record_info.record_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_type IS '0：告警视频，1：定时录制视频';


--
-- Name: COLUMN tb_record_info.record_file_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_file_name IS '文件名称';


--
-- Name: COLUMN tb_record_info.record_timerworkid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_timerworkid IS '定时任务ID';


--
-- Name: COLUMN tb_record_info.record_ipc_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_ipc_url IS '录制rtsp url';


--
-- Name: COLUMN tb_record_info.record_live_stream_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_live_stream_id IS '对应的实时流id，暂未使用';


--
-- Name: COLUMN tb_record_info.record_duration; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_duration IS '录制时长，单位秒';


--
-- Name: COLUMN tb_record_info.record_inner_file_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_inner_file_name IS '内部使用文件名';


--
-- Name: COLUMN tb_record_info.record_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_services_id IS '录制服务ID';


--
-- Name: COLUMN tb_record_info.record_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_status IS '1 未开始 2 录像失败 3 录像成功';


--
-- Name: COLUMN tb_record_info.record_img_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_img_url IS '录象截图的url';


--
-- Name: COLUMN tb_record_info.record_file_size; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_file_size IS '录像文件大小';


--
-- Name: COLUMN tb_record_info.record_http_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_http_url IS '-- 录像的http下载url';


--
-- Name: COLUMN tb_record_info.record_start_ipc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_start_ipc_time IS '录像（操作）在ipc上开始的时间';


--
-- Name: COLUMN tb_record_info.record_stop_ipc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_stop_ipc_time IS '录像（操作）在ipc上完成的时间';


--
-- Name: COLUMN tb_record_info.record_picture_size; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info.record_picture_size IS '缩略图文件大小';


--
-- Name: tb_record_info_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_record_info_history (
    record_id uuid NOT NULL,
    record_ipc_id uuid NOT NULL,
    record_address_id uuid,
    record_url text,
    record_start_time timestamp without time zone NOT NULL,
    record_stop_time timestamp without time zone NOT NULL,
    record_type integer DEFAULT 0 NOT NULL,
    record_user_id uuid,
    record_file_name text,
    record_timerworkid uuid,
    record_ipc_url text,
    record_live_stream_id uuid,
    record_duration integer,
    record_inner_file_name text,
    record_services_id uuid,
    record_status integer DEFAULT 1,
    record_img_url text,
    record_file_size integer DEFAULT 0 NOT NULL,
    record_http_url text,
    record_start_ipc_time timestamp without time zone,
    record_stop_ipc_time timestamp without time zone,
    record_picture_size integer DEFAULT 0 NOT NULL
);


ALTER TABLE tb_record_info_history OWNER TO admin;

--
-- Name: COLUMN tb_record_info_history.record_address_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_address_id IS '地点的标识，uuid类型，可以是商铺、家庭等';


--
-- Name: COLUMN tb_record_info_history.record_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_url IS '录像回放的流地址';


--
-- Name: COLUMN tb_record_info_history.record_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_start_time IS '录像（操作）开始的时间';


--
-- Name: COLUMN tb_record_info_history.record_stop_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_stop_time IS '录像（操作）完成的时间';


--
-- Name: COLUMN tb_record_info_history.record_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_type IS '0：告警视频，1：定时录制视频';


--
-- Name: COLUMN tb_record_info_history.record_file_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_file_name IS '文件名称';


--
-- Name: COLUMN tb_record_info_history.record_timerworkid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_timerworkid IS '定时任务ID';


--
-- Name: COLUMN tb_record_info_history.record_ipc_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_ipc_url IS '录制rtsp url';


--
-- Name: COLUMN tb_record_info_history.record_live_stream_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_live_stream_id IS '对应的实时流id，暂未使用';


--
-- Name: COLUMN tb_record_info_history.record_duration; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_duration IS '录制时长，单位秒';


--
-- Name: COLUMN tb_record_info_history.record_inner_file_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_inner_file_name IS '内部使用文件名';


--
-- Name: COLUMN tb_record_info_history.record_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_services_id IS '录制服务ID';


--
-- Name: COLUMN tb_record_info_history.record_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_status IS '1 未开始 2 录像失败 3 录像成功';


--
-- Name: COLUMN tb_record_info_history.record_img_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_img_url IS '录象截图';


--
-- Name: COLUMN tb_record_info_history.record_file_size; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_file_size IS '录像文件大小';


--
-- Name: COLUMN tb_record_info_history.record_start_ipc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_start_ipc_time IS '录像（操作）在ipc上开始的时间';


--
-- Name: COLUMN tb_record_info_history.record_stop_ipc_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_stop_ipc_time IS '录像（操作）在ipc上完成的时间';


--
-- Name: COLUMN tb_record_info_history.record_picture_size; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_info_history.record_picture_size IS '缩略图文件大小';


--
-- Name: tb_record_status_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_record_status_info (
    ipc_id uuid NOT NULL,
    record_id uuid NOT NULL,
    server_id uuid,
    start_time timestamp without time zone NOT NULL,
    status integer,
    CONSTRAINT tb_record_status_info_ipc_id_check CHECK ((ipc_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_record_status_info_status_check CHECK (((status >= 0) AND (status <= 1)))
);


ALTER TABLE tb_record_status_info OWNER TO admin;

--
-- Name: TABLE tb_record_status_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_record_status_info IS '录像流表（重复告警检测）';


--
-- Name: COLUMN tb_record_status_info.ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_status_info.ipc_id IS 'ipc_id';


--
-- Name: COLUMN tb_record_status_info.record_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_status_info.record_id IS '对应录像文件编号';


--
-- Name: COLUMN tb_record_status_info.server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_status_info.server_id IS '所属control_server';


--
-- Name: COLUMN tb_record_status_info.start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_status_info.start_time IS '录像开始时间';


--
-- Name: COLUMN tb_record_status_info.status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_record_status_info.status IS '录像状态(0=空闲,1=录像中)';


--
-- Name: tb_rtp_interactive; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtp_interactive (
    rtp_id uuid NOT NULL,
    rtp_ssrc_side1 bigint,
    rtp_ssrc_side2 bigint,
    rtp_stream_type smallint,
    rtp_interactive_state smallint,
    CONSTRAINT tb_rtp_interactive_rtp_id_check CHECK ((rtp_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_rtp_interactive_rtp_interactive_state_check CHECK (((rtp_interactive_state >= 0) AND (rtp_interactive_state <= 2))),
    CONSTRAINT tb_rtp_interactive_rtp_stream_type_check CHECK (((rtp_stream_type >= 1) AND (rtp_stream_type <= 2)))
);


ALTER TABLE tb_rtp_interactive OWNER TO admin;

--
-- Name: TABLE tb_rtp_interactive; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_rtp_interactive IS '流之间的状态';


--
-- Name: COLUMN tb_rtp_interactive.rtp_ssrc_side1; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_interactive.rtp_ssrc_side1 IS '一端的ssrc';


--
-- Name: COLUMN tb_rtp_interactive.rtp_ssrc_side2; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_interactive.rtp_ssrc_side2 IS '另一端的ssrc';


--
-- Name: COLUMN tb_rtp_interactive.rtp_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_interactive.rtp_stream_type IS '1 视频
2 音频';


--
-- Name: COLUMN tb_rtp_interactive.rtp_interactive_state; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_interactive.rtp_interactive_state IS '0未开始
1已开始
2停止';


--
-- Name: tb_rtp_stream; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtp_stream (
    rtp_stream_id bigint,
    rtp_stream_type smallint,
    rtp_stream_location text,
    rtp_push_state smallint,
    CONSTRAINT tb_rtp_stream_rtp_push_state_check CHECK (((rtp_push_state >= 0) AND (rtp_push_state <= 2))),
    CONSTRAINT tb_rtp_stream_rtp_stream_type_check CHECK (((rtp_stream_type >= 1) AND (rtp_stream_type <= 2)))
);


ALTER TABLE tb_rtp_stream OWNER TO admin;

--
-- Name: TABLE tb_rtp_stream; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_rtp_stream IS '单条流的信息';


--
-- Name: COLUMN tb_rtp_stream.rtp_stream_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.rtp_stream_id IS '无符号整型ssrc';


--
-- Name: COLUMN tb_rtp_stream.rtp_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.rtp_stream_type IS '1视频
2音频';


--
-- Name: COLUMN tb_rtp_stream.rtp_stream_location; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.rtp_stream_location IS '流所在服务器位置，比如
rtp://192.168.34.203:1010';


--
-- Name: COLUMN tb_rtp_stream.rtp_push_state; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtp_stream.rtp_push_state IS '流到达服务器状态
0未开始
1已开始
2超时
';


--
-- Name: tb_rtsp_file_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtsp_file_info (
    rtsp_id uuid NOT NULL,
    rtsp_url text,
    rtsp_usr_name text,
    rtsp_usr_pwd text,
    rtsp_code_stream integer,
    rtsp_server_id uuid,
    rtsp_status integer,
    rtsp_stream_updt timestamp without time zone,
    rtsp_ipc_id uuid,
    rtsp_user_id uuid,
    rtsp_stream_type integer,
    rtsp_stream_direction integer,
    rtsp_session_id integer,
    rtsp_ipc_file_id uuid NOT NULL,
    CONSTRAINT tb_rtsp_file_info_rtsp_code_stream_check CHECK (((rtsp_code_stream >= 1) AND (rtsp_code_stream <= 4))),
    CONSTRAINT tb_rtsp_file_info_rtsp_id_check CHECK ((rtsp_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_rtsp_file_info_rtsp_status_check CHECK (((rtsp_status >= 1) AND (rtsp_status <= 3))),
    CONSTRAINT tb_rtsp_file_info_rtsp_stream_direction_check CHECK (((rtsp_stream_direction >= 0) AND (rtsp_stream_direction <= 2))),
    CONSTRAINT tb_rtsp_file_info_rtsp_stream_type_check CHECK (((rtsp_stream_type >= 1) AND (rtsp_stream_type <= 3)))
);


ALTER TABLE tb_rtsp_file_info OWNER TO admin;

--
-- Name: COLUMN tb_rtsp_file_info.rtsp_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_id IS '唯一主键';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_url IS 'rtsp url地址';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_usr_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_usr_name IS 'rtsp url 账号';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_usr_pwd; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_usr_pwd IS 'rtsp url密码';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_code_stream; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_code_stream IS '码流类型(1, 2, 3, 4 ...)';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_server_id IS 'rtsp服务器id';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_status IS 'rtsp流状态(1 已分配  2 已运行)';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_stream_updt; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_stream_updt IS 'rtsp流创建时间';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_stream_type IS '1 文件下载流 2 录制流 3 转发rtmp流';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_stream_direction; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_stream_direction IS '0 未知 1 push流 2 pull流';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_session_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_session_id IS 'rtsp会话ID';


--
-- Name: COLUMN tb_rtsp_file_info.rtsp_ipc_file_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_file_info.rtsp_ipc_file_id IS 'IPC 录像文件ID';


--
-- Name: tb_rtsp_stream_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_rtsp_stream_info (
    rtsp_id uuid NOT NULL,
    rtsp_url text,
    rtsp_usr_name text,
    rtsp_usr_pwd text,
    rtsp_code_stream integer,
    rtsp_server_id uuid,
    rtsp_status integer,
    rtsp_stream_updt timestamp without time zone,
    rtsp_ipc_id uuid,
    rtsp_user_id uuid,
    rtsp_stream_type integer,
    rtsp_stream_direction integer,
    rtsp_session_id integer,
    rtsp_broker_ip text,
    rtsp_broker_port integer,
    rtsp_queue_name text,
    CONSTRAINT tb_rtsp_stream_info_rtsp_code_stream_check CHECK (((rtsp_code_stream >= 1) AND (rtsp_code_stream <= 4))),
    CONSTRAINT tb_rtsp_stream_info_rtsp_id_check CHECK ((rtsp_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_rtsp_stream_info_rtsp_status_check CHECK (((rtsp_status >= 1) AND (rtsp_status <= 3))),
    CONSTRAINT tb_rtsp_stream_info_rtsp_stream_direction_check CHECK (((rtsp_stream_direction >= 0) AND (rtsp_stream_direction <= 2))),
    CONSTRAINT tb_rtsp_stream_info_rtsp_stream_type_check CHECK (((rtsp_stream_type >= 1) AND (rtsp_stream_type <= 3)))
);


ALTER TABLE tb_rtsp_stream_info OWNER TO admin;

--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_id IS '唯一主键';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_url IS 'rtsp url地址';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_usr_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_usr_name IS 'rtsp url 账号';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_usr_pwd; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_usr_pwd IS 'rtsp url密码';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_code_stream; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_code_stream IS '码流类型(1, 2, 3, 4 ...)';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_server_id IS 'rtsp服务器id';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_status IS 'rtsp流状态(1 已分配  2 已运行)';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_stream_updt; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_stream_updt IS 'rtsp流创建的时间';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_stream_type IS '1 实时流 2 录制流 3 转发rtmp流';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_stream_direction; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_stream_direction IS '0 未知 1 push流 2 pull流';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_session_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_session_id IS 'rtst会话ID';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_broker_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_broker_ip IS 'rtsp服务连接的Qpid broker ip';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_broker_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_broker_port IS 'rtsp服务连接的Qpid broker 端口';


--
-- Name: COLUMN tb_rtsp_stream_info.rtsp_queue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_rtsp_stream_info.rtsp_queue_name IS 'rtsp的qpid队列名';


--
-- Name: tb_scence_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_scence_info (
    scence_id uuid NOT NULL,
    scence_name text,
    scence_code integer NOT NULL,
    scence_type integer NOT NULL,
    scence_value integer DEFAULT 0 NOT NULL,
    scence_info text,
    scence_uid uuid,
    scence_linkage_info bytea,
    scence_linkage_description text,
    scence_register_time timestamp without time zone DEFAULT now() NOT NULL,
    scence_addressid uuid,
    CONSTRAINT tb_scence_info_scence_id_check CHECK ((scence_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_scence_info OWNER TO admin;

--
-- Name: COLUMN tb_scence_info.scence_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_id IS '情景ID';


--
-- Name: COLUMN tb_scence_info.scence_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_name IS '情景名称';


--
-- Name: COLUMN tb_scence_info.scence_code; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_code IS '情景编码（下发给ipc用）';


--
-- Name: COLUMN tb_scence_info.scence_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_type IS '情景类型（1：开关类型，2：联动操作，3.。。）';


--
-- Name: COLUMN tb_scence_info.scence_value; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_value IS '情景参数（0：关，1：开，2.。。）';


--
-- Name: COLUMN tb_scence_info.scence_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_info IS '情景详细参数（可按一定的格式，联动操作）';


--
-- Name: COLUMN tb_scence_info.scence_uid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_uid IS '用户id';


--
-- Name: COLUMN tb_scence_info.scence_linkage_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_linkage_info IS '告警联动信息';


--
-- Name: COLUMN tb_scence_info.scence_linkage_description; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_linkage_description IS '告警联动描述';


--
-- Name: COLUMN tb_scence_info.scence_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_register_time IS '创建时间';


--
-- Name: COLUMN tb_scence_info.scence_addressid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_scence_info.scence_addressid IS '情景所属的商铺（地址）';


--
-- Name: tb_sence_alarm_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_sence_alarm_info (
    sence_alarm_id uuid NOT NULL,
    ipc_id uuid,
    sensor_mac text,
    sence_id uuid,
    begintime timestamp without time zone,
    endtime timestamp without time zone,
    alarm_type integer DEFAULT 0,
    CONSTRAINT tb_sence_alarm_info_sence_alarm_id_check CHECK ((sence_alarm_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_sence_alarm_info OWNER TO admin;

--
-- Name: TABLE tb_sence_alarm_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_sence_alarm_info IS '告警与情景的关联关系表';


--
-- Name: COLUMN tb_sence_alarm_info.ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sence_alarm_info.ipc_id IS 'ipcID';


--
-- Name: COLUMN tb_sence_alarm_info.sensor_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sence_alarm_info.sensor_mac IS '传感器序列号';


--
-- Name: COLUMN tb_sence_alarm_info.sence_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sence_alarm_info.sence_id IS '情景id';


--
-- Name: COLUMN tb_sence_alarm_info.begintime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sence_alarm_info.begintime IS '开始时间';


--
-- Name: COLUMN tb_sence_alarm_info.endtime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sence_alarm_info.endtime IS '结束时间';


--
-- Name: COLUMN tb_sence_alarm_info.alarm_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sence_alarm_info.alarm_type IS '报警类型';


--
-- Name: tb_sensor_equipment_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_sensor_equipment_info (
    equipment_id uuid NOT NULL,
    sensor_mac text,
    equipment_name text,
    equipment_type integer DEFAULT 0 NOT NULL,
    home_id uuid,
    equipment_sequence integer DEFAULT 0 NOT NULL,
    equipment_value integer DEFAULT 0 NOT NULL,
    scence_id uuid,
    equipment_display integer DEFAULT 1,
    params text[],
    CONSTRAINT tb_sensor_equipment_info_equipment_id_check CHECK ((equipment_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_sensor_equipment_info OWNER TO admin;

--
-- Name: TABLE tb_sensor_equipment_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_sensor_equipment_info IS '传感器子设备表---传感器可以挂几个灯';


--
-- Name: COLUMN tb_sensor_equipment_info.equipment_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.equipment_id IS '子设备ID';


--
-- Name: COLUMN tb_sensor_equipment_info.sensor_mac; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.sensor_mac IS '传感器mac地址---该设备父节点的id 一般是传感器的mac';


--
-- Name: COLUMN tb_sensor_equipment_info.equipment_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.equipment_name IS '设备名称';


--
-- Name: COLUMN tb_sensor_equipment_info.equipment_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.equipment_type IS '设备类型';


--
-- Name: COLUMN tb_sensor_equipment_info.home_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.home_id IS '房间ID---设备属于哪个房间';


--
-- Name: COLUMN tb_sensor_equipment_info.equipment_sequence; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.equipment_sequence IS '设备的顺序---设备在父节点的顺序';


--
-- Name: COLUMN tb_sensor_equipment_info.equipment_value; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.equipment_value IS '设备的值----表示设备的开关状态';


--
-- Name: COLUMN tb_sensor_equipment_info.scence_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.scence_id IS '情景id';


--
-- Name: COLUMN tb_sensor_equipment_info.equipment_display; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.equipment_display IS '设置设备是否隐藏或显示在APP上';


--
-- Name: COLUMN tb_sensor_equipment_info.params; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_equipment_info.params IS '子设备参数,地暖使用';


--
-- Name: tb_sensor_ipc_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_sensor_ipc_info (
    sensor_ipc_id uuid NOT NULL,
    sensor_ipc_sid uuid NOT NULL,
    sensor_ipc_iid uuid,
    sensor_ipc_udtime timestamp without time zone NOT NULL,
    CONSTRAINT tb_sensor_ipc_info_sensor_ipc_id_check CHECK ((sensor_ipc_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_sensor_ipc_info OWNER TO admin;

--
-- Name: TABLE tb_sensor_ipc_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_sensor_ipc_info IS '传感器跟ipc的关系表';


--
-- Name: COLUMN tb_sensor_ipc_info.sensor_ipc_sid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_ipc_info.sensor_ipc_sid IS '传感器id';


--
-- Name: COLUMN tb_sensor_ipc_info.sensor_ipc_iid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_ipc_info.sensor_ipc_iid IS 'ipc id';


--
-- Name: COLUMN tb_sensor_ipc_info.sensor_ipc_udtime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensor_ipc_info.sensor_ipc_udtime IS '关系最后一次更新时间';


--
-- Name: tb_sensors_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_sensors_info (
    sensors_id uuid NOT NULL,
    sensors_name text,
    sensors_status boolean DEFAULT false NOT NULL,
    sensors_device_model text,
    sensors_other_info text,
    sensors_type integer DEFAULT 0 NOT NULL,
    sensors_factory text,
    sensors_production_id text,
    sensors_home_id uuid,
    sensors_value integer DEFAULT 0,
    sensors_countdown_duration integer,
    sensors_countdown_start_time timestamp without time zone,
    CONSTRAINT tb_sensors_info_sensors_id_check CHECK ((sensors_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_sensors_info_sensors_type_check CHECK (((sensors_type >= 0) AND (sensors_type <= 600)))
);


ALTER TABLE tb_sensors_info OWNER TO admin;

--
-- Name: COLUMN tb_sensors_info.sensors_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_name IS '传感器名称';


--
-- Name: COLUMN tb_sensors_info.sensors_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_status IS '设备状态（false：离线，true：在线）';


--
-- Name: COLUMN tb_sensors_info.sensors_device_model; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_device_model IS '设备型号';


--
-- Name: COLUMN tb_sensors_info.sensors_other_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_other_info IS '描述信息';


--
-- Name: COLUMN tb_sensors_info.sensors_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_type IS '传感器类型（0：其它，1：门磁，2：红外，3：烟感，4：。。。）';


--
-- Name: COLUMN tb_sensors_info.sensors_factory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_factory IS '厂商信息';


--
-- Name: COLUMN tb_sensors_info.sensors_production_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_production_id IS '传感器mac地址';


--
-- Name: COLUMN tb_sensors_info.sensors_home_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_home_id IS '房间ID';


--
-- Name: COLUMN tb_sensors_info.sensors_value; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_value IS '传感器的值，0  关灯 1 开灯 等等';


--
-- Name: COLUMN tb_sensors_info.sensors_countdown_duration; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_countdown_duration IS '传感器倒计时长 单位秒';


--
-- Name: COLUMN tb_sensors_info.sensors_countdown_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_sensors_info.sensors_countdown_start_time IS '传感器倒计开始时间';


--
-- Name: tb_services_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_services_info (
    service_id uuid NOT NULL,
    service_name text NOT NULL,
    service_update_time timestamp without time zone,
    service_type integer DEFAULT 0 NOT NULL,
    service_ip text NOT NULL,
    service_broker_ip text,
    service_queue_name text,
    service_status boolean DEFAULT false NOT NULL,
    service_listen_port integer,
    service_send_port integer,
    service_cpu_charge double precision,
    service_memory_usage double precision,
    service_disk_usage double precision,
    service_await double precision,
    service_avgqu_sz double precision,
    service_network_total integer,
    service_network_down integer,
    service_network_up integer,
    service_bandwidth integer,
    service_user_cpu double precision,
    service_nice_cpu double precision,
    service_sys_cpu double precision,
    service_hardware_iowait double precision,
    service_driver_read double precision,
    service_driver_write double precision,
    service_avgrq_sz double precision,
    service_util double precision,
    service_device_id text,
    service_monitor_time timestamp without time zone,
    service_area integer DEFAULT 1 NOT NULL,
    CONSTRAINT tb_services_info_service_area_check CHECK (((service_area >= 1) AND (service_area <= 2))),
    CONSTRAINT tb_services_info_service_id_check CHECK ((service_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_services_info OWNER TO admin;

--
-- Name: COLUMN tb_services_info.service_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_name IS '服务名';


--
-- Name: COLUMN tb_services_info.service_update_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_update_time IS '服务信息更新时间';


--
-- Name: COLUMN tb_services_info.service_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_type IS '服务类型（0:其它，1：app服务，2：ipc服务，3：分配服务，4：视频媒体服务，5：语音对讲服务，6：http消息网关，7：http消息推送服务，8：rtmp服务，9：rtsp服务，10：ipc服务V2版本，11：运维服务）';


--
-- Name: COLUMN tb_services_info.service_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_ip IS '服务所在主机的IP';


--
-- Name: COLUMN tb_services_info.service_broker_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_broker_ip IS '运行消息中间件的主机的IP';


--
-- Name: COLUMN tb_services_info.service_queue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_queue_name IS '服务在消息中间件上的消息队列的名称（uuid）';


--
-- Name: COLUMN tb_services_info.service_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_status IS '服务运行状态（false：离线，true：在线)';


--
-- Name: COLUMN tb_services_info.service_listen_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_listen_port IS '服务监听的端口';


--
-- Name: COLUMN tb_services_info.service_send_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_send_port IS '服务发送消息使用的端口';


--
-- Name: COLUMN tb_services_info.service_cpu_charge; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_cpu_charge IS 'cpu负载';


--
-- Name: COLUMN tb_services_info.service_memory_usage; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_memory_usage IS '内存使用率';


--
-- Name: COLUMN tb_services_info.service_disk_usage; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_disk_usage IS '磁盘使用率';


--
-- Name: COLUMN tb_services_info.service_await; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_await IS 'I/O请求平均执行时间.包括发送请求和执行的时间.单位是毫秒';


--
-- Name: COLUMN tb_services_info.service_avgqu_sz; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_avgqu_sz IS '平均I/O队列长度';


--
-- Name: COLUMN tb_services_info.service_network_total; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_network_total IS '网卡传输速率，单位为kb/s';


--
-- Name: COLUMN tb_services_info.service_network_down; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_network_down IS '网卡下载速率';


--
-- Name: COLUMN tb_services_info.service_network_up; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_network_up IS '网卡上传速率';


--
-- Name: COLUMN tb_services_info.service_bandwidth; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_bandwidth IS '带宽';


--
-- Name: COLUMN tb_services_info.service_user_cpu; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_user_cpu IS '在用户级别运行所使用的CPU的百分比.';


--
-- Name: COLUMN tb_services_info.service_nice_cpu; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_nice_cpu IS 'nice操作所使用的CPU的百分比.';


--
-- Name: COLUMN tb_services_info.service_sys_cpu; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_sys_cpu IS '在系统级别(kernel)运行所使用CPU的百分比';


--
-- Name: COLUMN tb_services_info.service_hardware_iowait; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_hardware_iowait IS 'CPU等待硬件I/O时,所占用CPU百分比';


--
-- Name: COLUMN tb_services_info.service_driver_read; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_driver_read IS '每秒从驱动器读入的数据量,单位为K';


--
-- Name: COLUMN tb_services_info.service_driver_write; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_driver_write IS '每秒向驱动器写入的数据量,单位为K';


--
-- Name: COLUMN tb_services_info.service_avgrq_sz; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_avgrq_sz IS 'io请求的平均大小，单位是扇区（一扇区大小为512byte，为0.5kb）';


--
-- Name: COLUMN tb_services_info.service_util; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_util IS '一秒中有百分之多少的时间用于 I/O 操作，或者说一秒中有多少时间 I/O 队列';


--
-- Name: COLUMN tb_services_info.service_device_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_device_id IS '所在的机器id';


--
-- Name: COLUMN tb_services_info.service_monitor_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_monitor_time IS '服务器实时状态更新时间';


--
-- Name: COLUMN tb_services_info.service_area; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_services_info.service_area IS '服务所处的地区，1是大陆、2是香港';


--
-- Name: tb_timer_work_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_timer_work_info (
    timer_work_id uuid NOT NULL,
    timer_work_taskid uuid NOT NULL,
    timer_work_userid uuid NOT NULL,
    timer_work_periodic integer DEFAULT 1 NOT NULL,
    timer_work_type integer DEFAULT 1 NOT NULL,
    timer_work_regtime timestamp without time zone NOT NULL,
    timer_work_starttime text,
    timer_work_stoptime text,
    timer_work_status integer DEFAULT 0 NOT NULL,
    timer_work_day_of_week integer[],
    timer_time_zone_name text DEFAULT 'UTC+8'::text,
    timer_time_zone_offset integer DEFAULT 28800,
    timer_start_time_utc text,
    CONSTRAINT tb_timer_work_info_timer_work_id_check CHECK ((timer_work_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_timer_work_info_timer_work_status_check CHECK (((timer_work_status >= 0) AND (timer_work_status <= 1)))
);


ALTER TABLE tb_timer_work_info OWNER TO admin;

--
-- Name: COLUMN tb_timer_work_info.timer_work_taskid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_taskid IS '执行任务的对象的 ID ，可能是ipc，商铺ID，传感器ID';


--
-- Name: COLUMN tb_timer_work_info.timer_work_userid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_userid IS '用户id';


--
-- Name: COLUMN tb_timer_work_info.timer_work_periodic; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_periodic IS '任务周期（1:单次; 2:每天;3:每周）';


--
-- Name: COLUMN tb_timer_work_info.timer_work_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_type IS '事件类型
1 定时撤防
2 定时布防
3 删除ipc数据
4 定时情景
5 存储空间检测
6 传感器定时打开
7 传感器定时关闭';


--
-- Name: COLUMN tb_timer_work_info.timer_work_regtime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_regtime IS '任务注册时间';


--
-- Name: COLUMN tb_timer_work_info.timer_work_starttime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_starttime IS '任务开始时间';


--
-- Name: COLUMN tb_timer_work_info.timer_work_stoptime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_stoptime IS '任务的结束时间（暂时停用）';


--
-- Name: COLUMN tb_timer_work_info.timer_work_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_status IS '任务状态
0 打开
1 关闭';


--
-- Name: COLUMN tb_timer_work_info.timer_work_day_of_week; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_work_day_of_week IS '用于周任务
0：星期日
1：星期一
2：星期二
3：星期三
4：星期四
5：星期五
6：星期六';


--
-- Name: COLUMN tb_timer_work_info.timer_time_zone_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_time_zone_name IS '所在时区';


--
-- Name: COLUMN tb_timer_work_info.timer_time_zone_offset; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_time_zone_offset IS '时区偏移值';


--
-- Name: COLUMN tb_timer_work_info.timer_start_time_utc; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_timer_work_info.timer_start_time_utc IS '基于utc的执行时间';


--
-- Name: tb_transaction_msg_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE UNLOGGED TABLE tb_transaction_msg_info (
    info_id uuid NOT NULL,
    trans_msg_id integer,
    control_serv_id uuid,
    reply_url text,
    req_type smallint,
    req_time timestamp without time zone,
    CONSTRAINT tb_transaction_msg_info_info_id_check CHECK ((info_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_transaction_msg_info_req_type_check CHECK (((req_type >= 0) AND (req_type <= 3)))
);


ALTER TABLE tb_transaction_msg_info OWNER TO admin;

--
-- Name: TABLE tb_transaction_msg_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_transaction_msg_info IS '事务消息表';


--
-- Name: COLUMN tb_transaction_msg_info.info_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_transaction_msg_info.info_id IS '主键';


--
-- Name: COLUMN tb_transaction_msg_info.trans_msg_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_transaction_msg_info.trans_msg_id IS 'control_server对应msg_session中存放的id';


--
-- Name: COLUMN tb_transaction_msg_info.control_serv_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_transaction_msg_info.control_serv_id IS '所属congtrol_server的会话id';


--
-- Name: COLUMN tb_transaction_msg_info.reply_url; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_transaction_msg_info.reply_url IS '回复的url地址("http://%s:%d/sap-ajb/controlserver/relay?id=%s&type=%d&trans_id=%d")';


--
-- Name: COLUMN tb_transaction_msg_info.req_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_transaction_msg_info.req_type IS '请求类型(app、ipc、alarm)';


--
-- Name: COLUMN tb_transaction_msg_info.req_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_transaction_msg_info.req_time IS '请求的时间';


--
-- Name: tb_user_addrs_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_user_addrs_info (
    user_addrs_id uuid NOT NULL,
    user_addrs_uid uuid NOT NULL,
    user_addrs_sid uuid NOT NULL,
    user_addrs_permission integer NOT NULL,
    user_addrs_udtime timestamp without time zone NOT NULL,
    CONSTRAINT tb_user_addrs_info_user_addrs_id_check CHECK ((user_addrs_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_user_addrs_info_user_addrs_permission_check CHECK (((user_addrs_permission >= 0) AND (user_addrs_permission <= 1)))
);


ALTER TABLE tb_user_addrs_info OWNER TO admin;

--
-- Name: COLUMN tb_user_addrs_info.user_addrs_uid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_addrs_info.user_addrs_uid IS '用户id';


--
-- Name: COLUMN tb_user_addrs_info.user_addrs_sid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_addrs_info.user_addrs_sid IS '对应tb_address_info中的主键,表示商铺,家庭id';


--
-- Name: COLUMN tb_user_addrs_info.user_addrs_permission; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_addrs_info.user_addrs_permission IS '用户访问权限（0：拥有者，1：访问者...）';


--
-- Name: COLUMN tb_user_addrs_info.user_addrs_udtime; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_addrs_info.user_addrs_udtime IS '更新时间';


--
-- Name: tb_user_casual_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_user_casual_info (
    casual_user_id uuid NOT NULL,
    mobile_number text NOT NULL,
    casual_user_type integer DEFAULT 1,
    sms_check_code text,
    sms_check_time timestamp without time zone,
    CONSTRAINT tb_user_casual_info_casual_user_id_check CHECK ((casual_user_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_user_casual_info OWNER TO admin;

--
-- Name: TABLE tb_user_casual_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_user_casual_info IS '临时用户表';


--
-- Name: COLUMN tb_user_casual_info.casual_user_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_casual_info.casual_user_id IS '临时用户ID';


--
-- Name: COLUMN tb_user_casual_info.mobile_number; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_casual_info.mobile_number IS '手机号';


--
-- Name: COLUMN tb_user_casual_info.casual_user_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_casual_info.casual_user_type IS '临时用户类型';


--
-- Name: COLUMN tb_user_casual_info.sms_check_code; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_casual_info.sms_check_code IS '短信验证码';


--
-- Name: COLUMN tb_user_casual_info.sms_check_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_casual_info.sms_check_time IS '短信校验时间';


--
-- Name: tb_user_event_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_user_event_info (
    user_event_id uuid NOT NULL,
    user_event_type integer DEFAULT 0 NOT NULL,
    user_event_time timestamp without time zone NOT NULL,
    user_event_uid uuid NOT NULL,
    user_event_msg text,
    CONSTRAINT tb_user_event_info_user_event_id_check CHECK ((user_event_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_user_event_info OWNER TO admin;

--
-- Name: TABLE tb_user_event_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_user_event_info IS '用户事件消息';


--
-- Name: COLUMN tb_user_event_info.user_event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info.user_event_id IS '事件ID';


--
-- Name: COLUMN tb_user_event_info.user_event_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info.user_event_type IS '事件类型(0:未知、10：布防成功、11:布防失败、12:撤防成功、13:撤防失败、20、添加商铺、21：删除商铺、30:添加IPC 31:删除IPC 32：升级成功 33：云储存空间不足 34:云存储空间快满(80%~100%)) ';


--
-- Name: COLUMN tb_user_event_info.user_event_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info.user_event_time IS '事件操作时间';


--
-- Name: COLUMN tb_user_event_info.user_event_uid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info.user_event_uid IS '操作用户ID';


--
-- Name: COLUMN tb_user_event_info.user_event_msg; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info.user_event_msg IS '事件文本消息';


--
-- Name: tb_user_event_info_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_user_event_info_history (
    user_event_id uuid NOT NULL,
    user_event_type integer DEFAULT 0 NOT NULL,
    user_event_time timestamp without time zone NOT NULL,
    user_event_uid uuid NOT NULL,
    user_event_msg text
);


ALTER TABLE tb_user_event_info_history OWNER TO admin;

--
-- Name: TABLE tb_user_event_info_history; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_user_event_info_history IS '用户事件消息';


--
-- Name: COLUMN tb_user_event_info_history.user_event_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info_history.user_event_id IS '事件ID';


--
-- Name: COLUMN tb_user_event_info_history.user_event_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info_history.user_event_type IS '事件类型(0:未知、10：布防成功、11:布防失败、12:撤防成功、13:撤防失败、20、添加商铺、21：删除商铺、30:添加IPC 31:删除IPC) ';


--
-- Name: COLUMN tb_user_event_info_history.user_event_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info_history.user_event_time IS '事件操作时间';


--
-- Name: COLUMN tb_user_event_info_history.user_event_uid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info_history.user_event_uid IS '操作用户ID';


--
-- Name: COLUMN tb_user_event_info_history.user_event_msg; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_event_info_history.user_event_msg IS '事件文本消息';


--
-- Name: tb_user_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_user_info (
    user_id uuid NOT NULL,
    user_name text DEFAULT ''::text NOT NULL,
    user_password text NOT NULL,
    user_email text,
    user_phone text NOT NULL,
    user_mobile text NOT NULL,
    user_online boolean DEFAULT false NOT NULL,
    user_register_time timestamp without time zone,
    user_login_time timestamp without time zone,
    user_broker_ip text,
    user_broker_queue_name text,
    user_broker_port integer,
    user_is_push boolean DEFAULT true NOT NULL,
    user_clientid uuid,
    user_type integer,
    user_ostype integer DEFAULT 1,
    user_device_id text,
    user_app_type integer DEFAULT 0 NOT NULL,
    user_parent_id uuid,
    user_sms_check_code text,
    user_sms_check_time timestamp without time zone,
    user_image_address text,
    user_account text,
    user_app_factory text DEFAULT 'anjubao'::text,
    user_soundfilename text,
    user_address text,
    user_area_type integer DEFAULT 1 NOT NULL,
    user_cloudfilesize_used bigint DEFAULT 0 NOT NULL,
    user_cloudfilesize_max bigint DEFAULT 10737418240::bigint NOT NULL,
    user_langtype integer,
    user_time_zone text,
    user_time_zone_offset integer,
    user_rights integer DEFAULT 1,
    CONSTRAINT tb_user_info_user_app_type_check CHECK (((user_app_type >= 0) AND (user_app_type <= 4))),
    CONSTRAINT tb_user_info_user_area_type_check CHECK (((user_area_type >= 1) AND (user_area_type <= 5))),
    CONSTRAINT tb_user_info_user_id_check CHECK ((user_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_user_info_user_type_check CHECK (((user_type >= 0) AND (user_type <= 4)))
);


ALTER TABLE tb_user_info OWNER TO admin;

--
-- Name: COLUMN tb_user_info.user_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_name IS '用户的名称';


--
-- Name: COLUMN tb_user_info.user_password; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_password IS '用户的密码';


--
-- Name: COLUMN tb_user_info.user_email; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_email IS '邮件地址';


--
-- Name: COLUMN tb_user_info.user_phone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_phone IS '固定电话';


--
-- Name: COLUMN tb_user_info.user_mobile; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_mobile IS '手机号码';


--
-- Name: COLUMN tb_user_info.user_online; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_online IS '在线状态（false：离线，true：在线）';


--
-- Name: COLUMN tb_user_info.user_register_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_register_time IS '注册的时间';


--
-- Name: COLUMN tb_user_info.user_login_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_login_time IS '每次登录的时间';


--
-- Name: COLUMN tb_user_info.user_broker_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_broker_ip IS 'qpid队列的ip';


--
-- Name: COLUMN tb_user_info.user_broker_queue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_broker_queue_name IS 'qpid队列名称';


--
-- Name: COLUMN tb_user_info.user_broker_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_broker_port IS 'qpid队列的端口';


--
-- Name: COLUMN tb_user_info.user_is_push; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_is_push IS '用户是否接收推送信息（true：接收，false：拒绝）';


--
-- Name: COLUMN tb_user_info.user_clientid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_clientid IS '客户端未一识别码，每次登录的时候服务端更新并下发给用户';


--
-- Name: COLUMN tb_user_info.user_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_type IS '用户类型 1 普通app用户 2 普通运维用户 3 高级运维用户4 开发人员 ，准备以后删除这个字段';


--
-- Name: COLUMN tb_user_info.user_ostype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_ostype IS 'Android=1;
Ios=2;
ios_hd=3;';


--
-- Name: COLUMN tb_user_info.user_device_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_device_id IS 'ios手机设备ID';


--
-- Name: COLUMN tb_user_info.user_app_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_app_type IS '用户所使用的APP类型：
1：安店宝
2：安居小宝
4：易视
';


--
-- Name: COLUMN tb_user_info.user_parent_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_parent_id IS '主账号ID';


--
-- Name: COLUMN tb_user_info.user_sms_check_code; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_sms_check_code IS '短信验证码';


--
-- Name: COLUMN tb_user_info.user_sms_check_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_sms_check_time IS '短信校验时间';


--
-- Name: COLUMN tb_user_info.user_image_address; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_image_address IS '存放用户的自拍图像地址';


--
-- Name: COLUMN tb_user_info.user_account; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_account IS '用户账户';


--
-- Name: COLUMN tb_user_info.user_app_factory; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_app_factory IS '厂商';


--
-- Name: COLUMN tb_user_info.user_soundfilename; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_soundfilename IS '声音文件名';


--
-- Name: COLUMN tb_user_info.user_address; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_address IS '用户住址';


--
-- Name: COLUMN tb_user_info.user_area_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_area_type IS '版本区域
1 国内版本
2 海外版本';


--
-- Name: COLUMN tb_user_info.user_cloudfilesize_used; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_cloudfilesize_used IS '用户已使用的云端存储空间';


--
-- Name: COLUMN tb_user_info.user_cloudfilesize_max; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_cloudfilesize_max IS '用户可使用云端存储空间上限';


--
-- Name: COLUMN tb_user_info.user_langtype; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_langtype IS '1：中文 2：英文 3：泰文';


--
-- Name: COLUMN tb_user_info.user_time_zone; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_time_zone IS '时区';


--
-- Name: COLUMN tb_user_info.user_time_zone_offset; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_time_zone_offset IS '时区偏移值';


--
-- Name: COLUMN tb_user_info.user_rights; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_info.user_rights IS '0：只能查看，不能修改
1：拥有所有权限
2：禁止访问
';


--
-- Name: tb_user_watch_video_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_user_watch_video_info (
    user_watch_id uuid NOT NULL,
    user_watch_uid uuid NOT NULL,
    user_watch_start_time timestamp without time zone NOT NULL,
    user_watch_stop_time timestamp without time zone NOT NULL,
    user_watch_stream_type integer DEFAULT 0 NOT NULL,
    user_watch_ipc_id uuid NOT NULL,
    CONSTRAINT tb_user_watch_video_info_user_watch_id_check CHECK ((user_watch_id <> '00000000-0000-0000-0000-000000000000'::uuid)),
    CONSTRAINT tb_user_watch_video_info_user_watch_stream_type_check CHECK (((user_watch_stream_type >= 0) AND (user_watch_stream_type <= 4)))
);


ALTER TABLE tb_user_watch_video_info OWNER TO admin;

--
-- Name: TABLE tb_user_watch_video_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_user_watch_video_info IS '用户查看视频事件记录';


--
-- Name: COLUMN tb_user_watch_video_info.user_watch_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_watch_video_info.user_watch_id IS '查看ID';


--
-- Name: COLUMN tb_user_watch_video_info.user_watch_uid; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_watch_video_info.user_watch_uid IS '用户ID';


--
-- Name: COLUMN tb_user_watch_video_info.user_watch_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_watch_video_info.user_watch_start_time IS '查看开始时间';


--
-- Name: COLUMN tb_user_watch_video_info.user_watch_stop_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_watch_video_info.user_watch_stop_time IS '查看结束时间';


--
-- Name: COLUMN tb_user_watch_video_info.user_watch_stream_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_watch_video_info.user_watch_stream_type IS '码流类型: (0，1，2，3，4...)
0：未知;';


--
-- Name: COLUMN tb_user_watch_video_info.user_watch_ipc_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_user_watch_video_info.user_watch_ipc_id IS '摄像机ID';


--
-- Name: tb_voice_info_new; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_voice_info_new (
    voice_id uuid NOT NULL,
    voice_brokerip text,
    voice_brokerport integer,
    voice_bqueue_name text,
    voice_services_ip text,
    voice_services_port integer,
    voice_updt timestamp without time zone NOT NULL,
    voice_type integer DEFAULT 0 NOT NULL,
    voice_services_id uuid,
    voice_src_id uuid NOT NULL,
    voice_dst_id uuid,
    voice_rtp_status integer,
    voice_rtp_packet_direction integer,
    voice_src_ssrc integer,
    voice_dst_ssrc integer,
    voice_src_type integer,
    voice_dst_type integer,
    CONSTRAINT tb_voice_info_new_voice_id_check CHECK ((voice_id <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_voice_info_new OWNER TO admin;

--
-- Name: COLUMN tb_voice_info_new.voice_brokerip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_brokerip IS '服务连接的Qpid broker ip';


--
-- Name: COLUMN tb_voice_info_new.voice_brokerport; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_brokerport IS '服务连接的Qpid broker端口';


--
-- Name: COLUMN tb_voice_info_new.voice_bqueue_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_bqueue_name IS '服务的qpid queue name';


--
-- Name: COLUMN tb_voice_info_new.voice_services_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_services_ip IS '服务的ip';


--
-- Name: COLUMN tb_voice_info_new.voice_services_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_services_port IS '服务监听的端口';


--
-- Name: COLUMN tb_voice_info_new.voice_updt; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_updt IS '更新时间';


--
-- Name: COLUMN tb_voice_info_new.voice_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_type IS '暂未使用';


--
-- Name: COLUMN tb_voice_info_new.voice_services_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_services_id IS '对讲所使用的对讲服务的id';


--
-- Name: COLUMN tb_voice_info_new.voice_rtp_status; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_rtp_status IS 'rtp包转发状态（1 已分配， 2 已运行--接收到包，正在转发）
	';


--
-- Name: COLUMN tb_voice_info_new.voice_rtp_packet_direction; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_rtp_packet_direction IS '0 未知 1 push流 2 pull流(对于ipc来说）
	';


--
-- Name: COLUMN tb_voice_info_new.voice_src_ssrc; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_src_ssrc IS 'ipc的ssrcs';


--
-- Name: COLUMN tb_voice_info_new.voice_dst_ssrc; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_dst_ssrc IS 'user的ssrc';


--
-- Name: COLUMN tb_voice_info_new.voice_src_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_src_type IS '类型， 0为ipc, 1为app';


--
-- Name: COLUMN tb_voice_info_new.voice_dst_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_voice_info_new.voice_dst_type IS '类型， 0为ipc, 1为app';


--
-- Name: tb_linkage_action_info action_id; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_linkage_action_info
    ADD CONSTRAINT action_id PRIMARY KEY (action_id);


--
-- Name: tb_sensor_ipc_info constraint_tb_sensor_ipc_sensor_ipc_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_sensor_ipc_info
    ADD CONSTRAINT constraint_tb_sensor_ipc_sensor_ipc_key UNIQUE (sensor_ipc_sid, sensor_ipc_iid);


--
-- Name: tb_ipc_info ipc_production_unique; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_info
    ADD CONSTRAINT ipc_production_unique UNIQUE (ipc_factory, ipc_production_id);


--
-- Name: tb_address_info pk_addr_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_address_info
    ADD CONSTRAINT pk_addr_info PRIMARY KEY (addr_id);


--
-- Name: tb_alarm_info pk_alarm_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_alarm_info
    ADD CONSTRAINT pk_alarm_info PRIMARY KEY (alarm_id);


--
-- Name: tb_alarm_info_history pk_alarm_info_history; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_alarm_info_history
    ADD CONSTRAINT pk_alarm_info_history PRIMARY KEY (alarm_id);


--
-- Name: tb_client_url_info pk_client_url_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_client_url_info
    ADD CONSTRAINT pk_client_url_info PRIMARY KEY (client_id);


--
-- Name: tb_ipc_exception pk_exception_id; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_exception
    ADD CONSTRAINT pk_exception_id PRIMARY KEY (exception_id);


--
-- Name: tb_ipc_info pk_ipc_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_info
    ADD CONSTRAINT pk_ipc_info PRIMARY KEY (ipc_id);


--
-- Name: tb_ipc_restore_settings pk_ipc_restore_settings; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_restore_settings
    ADD CONSTRAINT pk_ipc_restore_settings PRIMARY KEY (ipc_device_model);


--
-- Name: tb_ipc_session_info pk_ipc_session_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_session_info
    ADD CONSTRAINT pk_ipc_session_info PRIMARY KEY (ipc_id);


--
-- Name: tb_op_alarm_info pk_op_alarm_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_op_alarm_info
    ADD CONSTRAINT pk_op_alarm_info PRIMARY KEY (op_alarm_id);


--
-- Name: tb_sensor_ipc_info pk_sensor_ipc; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_sensor_ipc_info
    ADD CONSTRAINT pk_sensor_ipc PRIMARY KEY (sensor_ipc_id);


--
-- Name: tb_sensors_info pk_sensors_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_sensors_info
    ADD CONSTRAINT pk_sensors_info PRIMARY KEY (sensors_id);


--
-- Name: tb_transaction_msg_info pk_tb_transaction_msg_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_transaction_msg_info
    ADD CONSTRAINT pk_tb_transaction_msg_info PRIMARY KEY (info_id);


--
-- Name: tb_user_info pk_user_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_info
    ADD CONSTRAINT pk_user_info PRIMARY KEY (user_id);


--
-- Name: tb_record_info pk_video_info; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_record_info
    ADD CONSTRAINT pk_video_info PRIMARY KEY (record_id);


--
-- Name: tb_record_info_history pk_video_info_history; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_record_info_history
    ADD CONSTRAINT pk_video_info_history PRIMARY KEY (record_id);


--
-- Name: tb_sensors_info sensors_production_unique; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_sensors_info
    ADD CONSTRAINT sensors_production_unique UNIQUE (sensors_factory, sensors_production_id);


--
-- Name: tb_ac_control_pfile tb_ac_control_pfile_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ac_control_pfile
    ADD CONSTRAINT tb_ac_control_pfile_pkey PRIMARY KEY (ac_type_code, ac_brand_name);


--
-- Name: tb_address_lease_info tb_address_lease_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_address_lease_info
    ADD CONSTRAINT tb_address_lease_info_pkey PRIMARY KEY (lease_id);


--
-- Name: tb_admin_user_info tb_admin_user_info_admin_account_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_admin_user_info
    ADD CONSTRAINT tb_admin_user_info_admin_account_key UNIQUE (admin_account);


--
-- Name: tb_admin_user_info tb_admin_user_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_admin_user_info
    ADD CONSTRAINT tb_admin_user_info_pkey PRIMARY KEY (admin_id);


--
-- Name: tb_advertisement_info tb_advertisement_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_advertisement_info
    ADD CONSTRAINT tb_advertisement_info_pkey PRIMARY KEY (ad_id);


--
-- Name: tb_apple_message_badge_info tb_apple_message_badge_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_apple_message_badge_info
    ADD CONSTRAINT tb_apple_message_badge_info_pkey PRIMARY KEY (userid);


--
-- Name: tb_audit_info tb_audit_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_audit_info
    ADD CONSTRAINT tb_audit_info_pkey PRIMARY KEY (audit_id);


--
-- Name: tb_fingerprint_scence tb_fingerPrint_scence_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_fingerprint_scence
    ADD CONSTRAINT "tb_fingerPrint_scence_pkey" PRIMARY KEY (fps_id);


--
-- Name: tb_fingerprint_scence tb_fingerprint_scence_fps_sensor_mac_fps_fingerprint_id_fps_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_fingerprint_scence
    ADD CONSTRAINT tb_fingerprint_scence_fps_sensor_mac_fps_fingerprint_id_fps_key UNIQUE (fps_sensor_mac, fps_fingerprint_id, fps_type);


--
-- Name: tb_home_info tb_home_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_home_info
    ADD CONSTRAINT tb_home_info_pkey PRIMARY KEY (home_id);


--
-- Name: tb_ip_address_info tb_ip_address_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ip_address_info
    ADD CONSTRAINT tb_ip_address_info_pkey PRIMARY KEY (ip_start_point);


--
-- Name: tb_ipc_detector_rect tb_ipc_detector_rect_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_detector_rect
    ADD CONSTRAINT tb_ipc_detector_rect_pkey PRIMARY KEY (id);


--
-- Name: tb_ipc_ptz_info tb_ipc_ptz_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_ptz_info
    ADD CONSTRAINT tb_ipc_ptz_info_pkey PRIMARY KEY (ptz_id);


--
-- Name: tb_ipc_sensor_log tb_ipc_sensor_log_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_sensor_log
    ADD CONSTRAINT tb_ipc_sensor_log_pkey PRIMARY KEY (isl_id);


--
-- Name: tb_ipc_versions_info tb_ipc_versions_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ipc_versions_info
    ADD CONSTRAINT tb_ipc_versions_info_pkey PRIMARY KEY (ipc_device_model, ipc_versions);


--
-- Name: tb_key_homeappliance_info tb_key_homeappliance_info_key_number_home_appliance_id_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_key_homeappliance_info
    ADD CONSTRAINT tb_key_homeappliance_info_key_number_home_appliance_id_key UNIQUE (key_number, home_appliance_id);


--
-- Name: tb_key_homeappliance_info tb_key_homeappliance_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_key_homeappliance_info
    ADD CONSTRAINT tb_key_homeappliance_info_pkey PRIMARY KEY (key_homeappliance_id);


--
-- Name: tb_linkage_answer_sensor_info tb_linkage_answer_sensor_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_linkage_answer_sensor_info
    ADD CONSTRAINT tb_linkage_answer_sensor_info_pkey PRIMARY KEY (act_id);


--
-- Name: tb_linkage_condition_info tb_linkage_condition_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_linkage_condition_info
    ADD CONSTRAINT tb_linkage_condition_info_pkey PRIMARY KEY (cond_id);


--
-- Name: tb_linkage_trigger_sensor_info tb_linkage_trigger_sensor_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_linkage_trigger_sensor_info
    ADD CONSTRAINT tb_linkage_trigger_sensor_info_pkey PRIMARY KEY (link_id);


--
-- Name: tb_login_info tb_login_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_login_info
    ADD CONSTRAINT tb_login_info_pkey PRIMARY KEY (login_id);


--
-- Name: tb_oauth_authentication tb_oauth_authentication_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_oauth_authentication
    ADD CONSTRAINT tb_oauth_authentication_pkey PRIMARY KEY (id);


--
-- Name: tb_op_address_alloc_info tb_op_address_alloc_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_op_address_alloc_info
    ADD CONSTRAINT tb_op_address_alloc_info_pkey PRIMARY KEY (op_addr_id);


--
-- Name: tb_op_alarm_alloc_info tb_op_alarm_alloc_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_op_alarm_alloc_info
    ADD CONSTRAINT tb_op_alarm_alloc_info_pkey PRIMARY KEY (alloc_id);


--
-- Name: tb_op_user_info tb_op_user_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_op_user_info
    ADD CONSTRAINT tb_op_user_info_pkey PRIMARY KEY (op_user_id);


--
-- Name: tb_op_user_record tb_op_user_record_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_op_user_record
    ADD CONSTRAINT tb_op_user_record_pkey PRIMARY KEY (record_id);


--
-- Name: tb_operater_event_info tb_operater_event_info_event_id_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_operater_event_info
    ADD CONSTRAINT tb_operater_event_info_event_id_key UNIQUE (event_id);


--
-- Name: tb_operater_event_info tb_operater_event_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_operater_event_info
    ADD CONSTRAINT tb_operater_event_info_pkey PRIMARY KEY (id);


--
-- Name: tb_product_id_ipc_conf tb_product_id_ipc_conf_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_product_id_ipc_conf
    ADD CONSTRAINT tb_product_id_ipc_conf_pkey PRIMARY KEY (model);


--
-- Name: tb_product_id_ipc tb_product_id_ipc_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_product_id_ipc
    ADD CONSTRAINT tb_product_id_ipc_pkey PRIMARY KEY (product_id);


--
-- Name: tb_product_id tb_product_id_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_product_id
    ADD CONSTRAINT tb_product_id_pkey PRIMARY KEY (product_id);


--
-- Name: tb_push_info_history tb_push_info_history_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_push_info_history
    ADD CONSTRAINT tb_push_info_history_pkey PRIMARY KEY (push_id);


--
-- Name: tb_push_info tb_push_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_push_info
    ADD CONSTRAINT tb_push_info_pkey PRIMARY KEY (push_id);


--
-- Name: tb_record_status_info tb_record_status_pk; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_record_status_info
    ADD CONSTRAINT tb_record_status_pk PRIMARY KEY (ipc_id);


--
-- Name: tb_rtp_interactive tb_rtp_interactive_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtp_interactive
    ADD CONSTRAINT tb_rtp_interactive_pkey PRIMARY KEY (rtp_id);


--
-- Name: tb_rtp_interactive tb_rtp_interactive_rtp_ssrc_side1_rtp_ssrc_side2_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtp_interactive
    ADD CONSTRAINT tb_rtp_interactive_rtp_ssrc_side1_rtp_ssrc_side2_key UNIQUE (rtp_ssrc_side1, rtp_ssrc_side2);


--
-- Name: tb_rtsp_file_info tb_rtsp_file_info_pk; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtsp_file_info
    ADD CONSTRAINT tb_rtsp_file_info_pk PRIMARY KEY (rtsp_id);


--
-- Name: tb_rtsp_file_info tb_rtsp_file_info_username_unique; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtsp_file_info
    ADD CONSTRAINT tb_rtsp_file_info_username_unique UNIQUE (rtsp_usr_name, rtsp_server_id);


--
-- Name: tb_rtsp_stream_info tb_rtsp_stream_info_pk; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtsp_stream_info
    ADD CONSTRAINT tb_rtsp_stream_info_pk PRIMARY KEY (rtsp_id);


--
-- Name: tb_rtsp_stream_info tb_rtsp_stream_info_username_unique; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_rtsp_stream_info
    ADD CONSTRAINT tb_rtsp_stream_info_username_unique UNIQUE (rtsp_usr_name, rtsp_server_id);


--
-- Name: tb_scence_info tb_scence_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_scence_info
    ADD CONSTRAINT tb_scence_info_pkey PRIMARY KEY (scence_id);


--
-- Name: tb_sence_alarm_info tb_sence_alarm_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_sence_alarm_info
    ADD CONSTRAINT tb_sence_alarm_info_pkey PRIMARY KEY (sence_alarm_id);


--
-- Name: tb_sensor_equipment_info tb_sensor_equipment_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_sensor_equipment_info
    ADD CONSTRAINT tb_sensor_equipment_info_pkey PRIMARY KEY (equipment_id);


--
-- Name: tb_services_info tb_services_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_services_info
    ADD CONSTRAINT tb_services_info_pkey PRIMARY KEY (service_id);


--
-- Name: tb_timer_work_info tb_timer_work_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_timer_work_info
    ADD CONSTRAINT tb_timer_work_info_pkey PRIMARY KEY (timer_work_id);


--
-- Name: tb_user_addrs_info tb_user_addrs_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_addrs_info
    ADD CONSTRAINT tb_user_addrs_pkey PRIMARY KEY (user_addrs_id);


--
-- Name: tb_user_addrs_info tb_user_addrs_user_addrs_uid_user_addrs_sid_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_addrs_info
    ADD CONSTRAINT tb_user_addrs_user_addrs_uid_user_addrs_sid_key UNIQUE (user_addrs_uid, user_addrs_sid);


--
-- Name: tb_user_casual_info tb_user_casual_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_casual_info
    ADD CONSTRAINT tb_user_casual_info_pkey PRIMARY KEY (casual_user_id);


--
-- Name: tb_user_event_info_history tb_user_event_info_history_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_event_info_history
    ADD CONSTRAINT tb_user_event_info_history_pkey PRIMARY KEY (user_event_id);


--
-- Name: tb_user_event_info tb_user_event_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_event_info
    ADD CONSTRAINT tb_user_event_info_pkey PRIMARY KEY (user_event_id);


--
-- Name: tb_user_info tb_user_info_user_mobile_user_app_factory_user_app_type_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_info
    ADD CONSTRAINT tb_user_info_user_mobile_user_app_factory_user_app_type_key UNIQUE (user_mobile, user_app_factory, user_app_type);


--
-- Name: tb_user_watch_video_info tb_user_watch_video_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_user_watch_video_info
    ADD CONSTRAINT tb_user_watch_video_info_pkey PRIMARY KEY (user_watch_id);


--
-- Name: tb_voice_info_new tb_voice_info_new_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_voice_info_new
    ADD CONSTRAINT tb_voice_info_new_pkey PRIMARY KEY (voice_id);


--
-- Name: tb_oauth_authentication unq_refresh_token; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_oauth_authentication
    ADD CONSTRAINT unq_refresh_token UNIQUE (refresh_token);


--
-- Name: tb_oauth_authentication unq_user_party; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_oauth_authentication
    ADD CONSTRAINT unq_user_party UNIQUE (user_id, party_name);


--
-- Name: tb_push_info_push_report_status_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX tb_push_info_push_report_status_idx ON tb_push_info USING btree (push_report_status);


--
-- Name: tb_push_info_push_time_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX tb_push_info_push_time_idx ON tb_push_info USING btree (push_time);


--
-- Name: tb_push_info_push_type_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX tb_push_info_push_type_idx ON tb_push_info USING btree (push_type);


--
-- Name: tb_push_info_push_user_id_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX tb_push_info_push_user_id_idx ON tb_push_info USING btree (push_user_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: tb_ac_control_pfile; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_ac_control_pfile FROM PUBLIC;
REVOKE ALL ON TABLE tb_ac_control_pfile FROM admin;
GRANT ALL ON TABLE tb_ac_control_pfile TO admin;


--
-- Name: tb_address_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_address_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_address_info FROM admin;
GRANT ALL ON TABLE tb_address_info TO admin;


--
-- Name: tb_alarm_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_alarm_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_alarm_info FROM admin;
GRANT ALL ON TABLE tb_alarm_info TO admin;


--
-- Name: tb_alarm_info_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_alarm_info_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_alarm_info_history FROM admin;
GRANT ALL ON TABLE tb_alarm_info_history TO admin;


--
-- Name: tb_apple_message_badge_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_apple_message_badge_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_apple_message_badge_info FROM admin;
GRANT ALL ON TABLE tb_apple_message_badge_info TO admin;


--
-- Name: tb_audit_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_audit_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_audit_info FROM admin;
GRANT ALL ON TABLE tb_audit_info TO admin;


--
-- Name: tb_device_scence_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_device_scence_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_device_scence_info FROM admin;
GRANT ALL ON TABLE tb_device_scence_info TO admin;


--
-- Name: tb_fingerprint_scence; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_fingerprint_scence FROM PUBLIC;
REVOKE ALL ON TABLE tb_fingerprint_scence FROM admin;
GRANT ALL ON TABLE tb_fingerprint_scence TO admin;


--
-- Name: tb_home_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_home_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_home_info FROM admin;
GRANT ALL ON TABLE tb_home_info TO admin;


--
-- Name: tb_ip_address_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_ip_address_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_ip_address_info FROM admin;
GRANT ALL ON TABLE tb_ip_address_info TO admin;


--
-- Name: tb_ipc_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_ipc_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_ipc_info FROM admin;
GRANT ALL ON TABLE tb_ipc_info TO admin;


--
-- Name: tb_ipc_sensordata_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_ipc_sensordata_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_ipc_sensordata_history FROM admin;
GRANT ALL ON TABLE tb_ipc_sensordata_history TO admin;


--
-- Name: tb_ipc_versions_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_ipc_versions_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_ipc_versions_info FROM admin;
GRANT ALL ON TABLE tb_ipc_versions_info TO admin;


--
-- Name: tb_key_homeappliance_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_key_homeappliance_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_key_homeappliance_info FROM admin;
GRANT ALL ON TABLE tb_key_homeappliance_info TO admin;


--
-- Name: tb_op_alarm_alloc_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_op_alarm_alloc_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_op_alarm_alloc_info FROM admin;
GRANT ALL ON TABLE tb_op_alarm_alloc_info TO admin;


--
-- Name: tb_op_alarm_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_op_alarm_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_op_alarm_info FROM admin;
GRANT ALL ON TABLE tb_op_alarm_info TO admin;


--
-- Name: tb_op_user_record; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_op_user_record FROM PUBLIC;
REVOKE ALL ON TABLE tb_op_user_record FROM admin;
GRANT ALL ON TABLE tb_op_user_record TO admin;


--
-- Name: tb_operater_event_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_operater_event_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_operater_event_info FROM admin;
GRANT ALL ON TABLE tb_operater_event_info TO admin;


--
-- Name: tb_push_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_push_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_push_info FROM admin;
GRANT ALL ON TABLE tb_push_info TO admin;


--
-- Name: tb_push_info_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_push_info_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_push_info_history FROM admin;
GRANT ALL ON TABLE tb_push_info_history TO admin;


--
-- Name: tb_record_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_record_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_record_info FROM admin;
GRANT ALL ON TABLE tb_record_info TO admin;


--
-- Name: tb_record_info_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_record_info_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_record_info_history FROM admin;
GRANT ALL ON TABLE tb_record_info_history TO admin;


--
-- Name: tb_rtsp_file_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_rtsp_file_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_rtsp_file_info FROM admin;
GRANT ALL ON TABLE tb_rtsp_file_info TO admin;


--
-- Name: tb_rtsp_stream_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_rtsp_stream_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_rtsp_stream_info FROM admin;
GRANT ALL ON TABLE tb_rtsp_stream_info TO admin;


--
-- Name: tb_scence_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_scence_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_scence_info FROM admin;
GRANT ALL ON TABLE tb_scence_info TO admin;


--
-- Name: tb_sence_alarm_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_sence_alarm_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_sence_alarm_info FROM admin;
GRANT ALL ON TABLE tb_sence_alarm_info TO admin;


--
-- Name: tb_sensor_equipment_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_sensor_equipment_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_sensor_equipment_info FROM admin;
GRANT ALL ON TABLE tb_sensor_equipment_info TO admin;


--
-- Name: tb_sensor_ipc_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_sensor_ipc_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_sensor_ipc_info FROM admin;
GRANT ALL ON TABLE tb_sensor_ipc_info TO admin;


--
-- Name: tb_sensors_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_sensors_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_sensors_info FROM admin;
GRANT ALL ON TABLE tb_sensors_info TO admin;


--
-- Name: tb_services_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_services_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_services_info FROM admin;
GRANT ALL ON TABLE tb_services_info TO admin;


--
-- Name: tb_timer_work_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_timer_work_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_timer_work_info FROM admin;
GRANT ALL ON TABLE tb_timer_work_info TO admin;


--
-- Name: tb_user_addrs_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_user_addrs_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_user_addrs_info FROM admin;
GRANT ALL ON TABLE tb_user_addrs_info TO admin;


--
-- Name: tb_user_event_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_user_event_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_user_event_info FROM admin;
GRANT ALL ON TABLE tb_user_event_info TO admin;


--
-- Name: tb_user_event_info_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_user_event_info_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_user_event_info_history FROM admin;
GRANT ALL ON TABLE tb_user_event_info_history TO admin;


--
-- Name: tb_user_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_user_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_user_info FROM admin;
GRANT ALL ON TABLE tb_user_info TO admin;


--
-- Name: tb_user_watch_video_info; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_user_watch_video_info FROM PUBLIC;
REVOKE ALL ON TABLE tb_user_watch_video_info FROM admin;
GRANT ALL ON TABLE tb_user_watch_video_info TO admin;


--
-- Name: tb_voice_info_new; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_voice_info_new FROM PUBLIC;
REVOKE ALL ON TABLE tb_voice_info_new FROM admin;
GRANT ALL ON TABLE tb_voice_info_new TO admin;


--
-- PostgreSQL database dump complete
--

