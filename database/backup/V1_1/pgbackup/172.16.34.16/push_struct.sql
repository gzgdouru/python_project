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
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


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
-- Name: db_cluster_sync(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION db_cluster_sync() RETURNS boolean
    LANGUAGE plpgsql
    AS $$ 
declare

--local_db_tb_id 后续改为获取本地 tb_push_record 的 db_tb_id 的默认值，参考update触发器，注意需要检查一下是否存在 tb_network_sync_info 表以及 db_tb_id 的默认值为空的情况
tb_network_sync_info_record record;
local_db_tb_id_default text default null;
local_db_tb_id uuid;
extension_info text default null; --保存模块名
local_db_tb_id_record tb_network_sync_info%ROWTYPE;--保存 tb_network_sync_info 中本地数据库记录
current_db_tb_id_record tb_network_sync_info%ROWTYPE;--保存当前 tb_network_sync_info 中的记录，一般用于循环
count_net_db integer default 0;--tb_network_sync_info 中记录的需要同步的数据库的数量
count_net_db_new integer default 0;--tb_network_sync_info中新加入的需要同步的数据库（ last_sync_time 为空 ）
count_net_db_not_last integer default 0; --之前同步过，但 last_sync_time 比local_db_tb的 last_sync_time 小
sync_time timestamp with time zone;--本次同步的时间点（统一一个时间）

current_db_tb_id text default null;--current_db_tb_id_record 的 db_tb_id 的 text 类型
current_dblink text default null;--用于拼凑记录当前的 dblink 连接名
execute_sql text;--用于动态构建 sql 命令

local_dblink_err_msg text default null;--用于保存获取的本地 dblink 连接的执行结果 
net_dblink_err_msg text default null;--用于保存获取的远程数据库上 dblink 连接的执行结果 
local_dblink_connections text default null;--用于保存本地 dblink_get_connections() 函数的返回结果
net_dblink_connections text default null;--用于保存远程数据库上 dblink_get_connections() 函数的返回结果

--test
temp_record_count integer default 0;-- tb_push_record_sync_temp 表中记录的行数

begin

--检查是否安装了 dblink 模块 
select extname into extension_info from pg_extension where extname = 'dblink';
if not found then
	raise EXCEPTION 'cannot find the Modules of dblink';
	return false;
end if;

--检查是否存在 tb_network_sync_info 表	--这儿其实不需要检查，如果没有，在定义 local_db_tb_id_record 时就会抛出异常
select * into tb_network_sync_info_record from pg_class where relname = 'tb_network_sync_info';
if not found then
	raise exception 'can''t find the network database infomation table of tb_network_sync_info!';
	return false;
end if;

--查询 local_db_tb_id 字段的默认值，这样就可以不传参数了
select column_default into local_db_tb_id_default from information_schema.columns where table_schema = 'public' AND table_name = 'tb_push_record' and column_name = 'record_former_db_id';
select * into local_db_tb_id from substr(local_db_tb_id_default, 2, 36); 
if local_db_tb_id is null then 
	raise exception 'tb_push_record.record_former_db_id is null!';
	return false;
end if;
raise notice 'local_db_tb_id: %', local_db_tb_id;

/*--创建一个临时表 tb_push_record_sync_temp ，用于保存从所有需要同步的数据库收集上来的数据
create TEMPORARY table tb_push_record_sync_temp ON COMMIT DROP 
as 
select *, ''::text as db_tb_id from tb_push_record WITH NO DATA; 
--(此处应该用数据库里面的记录的 table_name 字段替换掉 tb_push_record)
--这儿可能会产生的异常： 找不到 tb_push_record 表，如果 tb_push_record 改名会触发
--可以尝试在这个临时表上创建一个触发器，用于处理重复写入的记录(就算有重复数据也不会有异常出现，创建临时表时只拷贝了表结构，没有拷贝约束之类的，但添加临时表，可以进一步减少需要传输的数据量)
CREATE TRIGGER anticollision_insert
  BEFORE INSERT
  ON tb_push_record_sync_temp
  FOR EACH ROW
  EXECUTE PROCEDURE insert_trigger_for_sync_tb_push_record_sync_temp();--尝试过将 insert_trigger_for_sync_tb_push_record_sync_temp 写成动态函数，以便 tb_push_record 和 tb_push_record_sync_temp 同时使用，但由于两表结构有差异，无法定义保存老数据的变量（使用 record 类型也不行，因为是动态 sql ，即使将数据写入 变量，在判断 该变量是否为空时也会失败，写成非动态的就可以），这个现就这样，用其他方法，反而弄得更复杂。
*/
--检查 tb_network_sync_info 是否有本地数据库的记录，如果没有，则直接退出函数 
select * into local_db_tb_id_record from tb_network_sync_info where db_tb_id = local_db_tb_id;
if not found then
	raise exception 'cannot find local db_tb_id infomation in tb_network_sync_info';
	return false;
end if;

--查询有多少需要同步的远程数据库、以及多少新加入的远程数据库
select count(*) into count_net_db from tb_network_sync_info;
select count(*) into count_net_db_new from tb_network_sync_info where last_sync_time is null;

--开发阶段，没怎么做异常处理，也很少检查各条 sql 命令的返回值，特别是 dblink相关的 每一条操作，比如创建连接时，就应该判断返回信息，否则后面的操作都是白瞎。这些问题后续完善时，最好将 sql 分成单条，每条检查返回结果，不要像开发时，将多条 sql 命令打包执行。


--如果 count_net_db 为 1 （经过前面的检查，记录数为 0 是不可能执行到这儿的，如果为 1 ，必然是本地数据库信息的记录）
--则将此记录的 last_sync_time 置为空，然后结束此函数	
if count_net_db = 1 then 
	update tb_network_sync_info set last_sync_time = null, last_read_time = null where db_tb_id = local_db_tb_id;
	raise notice 'Only the local database in a cluster, which does not require synchronization.';
	return true;
end if;
		
sync_time := now();
raise notice '------ sync_time: % ------', sync_time::text;
raise notice '';

if local_db_tb_id_record.last_read_time is null or local_db_tb_id_record.last_sync_time is null then
	update tb_network_sync_info set last_sync_time = null, last_read_time = null;
end if;

--经测试，远程的数据库中的 dblink 无法访问该事务中的临时表(GLOBAL 关键字已经被放弃使用了，无效)，因此只能让其访问 tb_push_record 表，就没必要将 local 的数据插入到临时表中了。
--将 local_db_tb 的 数据读取单独提出来，以防 temp 表中没有 local_db_tb 的数据，其他新加入的和未同步到一致的表以为成功同步了，将 last_sync_time 字段更新了，其他数据库能不能 select 到数据都无所谓，做个异常处理，继续往下执行即可
/*select * into current_db_tb_id_record from tb_network_sync_info where last_sync_time is not null order by last_sync_time limit 1;
raise notice '-84-last_sync_time min -- current_db_tb_id_record:
%', current_db_tb_id_record::text;

execute_sql := 'insert into tb_push_record_sync_temp select *, ' || quote_literal(local_db_tb_id_record.db_tb_id::text) || ' from tb_push_record where record_write_time ';
--如果 local_db_tb_id 的 last_read_time 为空，或者存在没更新过的数据库，都需要取 local_db_tb 的所有 <= sync_time 的数据
if local_db_tb_id_record.last_read_time is not null and count_net_db_new < 1 then 
	--注意应该是小于 最小的 last_sync_time，而不是最小的 last_read_time
	execute_sql := execute_sql || '> ' || quote_literal(current_db_tb_id_record.last_sync_time) || ' and  record_write_time ';
end if;
execute_sql := execute_sql || '<= ' || quote_literal(sync_time) || ';';
*/
execute 'update tb_network_sync_info set last_read_time = ' || quote_literal(sync_time) || ' where db_tb_id = ' || quote_literal(local_db_tb_id_record.db_tb_id::text) || ';';

/*
execute execute_sql;--暂不做异常处理，如果前面一旦出现异常，整个函数应该都会回滚的，update 的 tb_network_sync_info 都会回滚回去的，待验证
*/

for current_db_tb_id_record in select * from tb_network_sync_info where db_tb_id <> local_db_tb_id_record.db_tb_id loop
	current_db_tb_id := current_db_tb_id_record.db_tb_id::text;
		--创建 dblink 链接
		current_dblink := current_db_tb_id_record.db_tb_id::text || '_dblink';
		
		begin
			--connect_timeout=3 连接创建超时时间 3秒
			--keepalives=1 客户端保持连接
			--keepalives_idle=1 tcp心跳间隔的空闲时间 1秒
			--keepalives_interval=1 对方没有回应时发送 tcp心跳的间隔时间 1秒
			--keepalives_count=3 在认为客户端到服务器的连接死亡之前，可以丢失的TCP保持激活的数量 3个
			execute 'select dblink_connect(''' || current_dblink || ''','''|| 'host=' || host(current_db_tb_id_record.host) ||  ' port=' || current_db_tb_id_record.port || ' dbname=' || current_db_tb_id_record.db_name || ' user=' || current_db_tb_id_record.db_user || ' password=' || current_db_tb_id_record.db_password || ' connect_timeout=3  keepalives=1 keepalives_idle=1 keepalives_interval=1 keepalives_count=3'');';
		exception
			when OTHERS then
				raise notice 'obtain data --- create dblink connect:
				current_dblink: %
				ERROR CODE: %
				EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
				
				--Postgresql: 动态SQL语句中不能使用Select into，应该如下使用：
				execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
				execute execute_sql into local_dblink_connections;
				if local_dblink_connections is null then
					continue;
				end if;
				raise notice '';
		end;
		--远程查询记录，并插入本地表中
		execute_sql := 'insert into tb_push_record select * from dblink(''' || current_dblink ||''', ''select * from tb_push_record where record_former_db_id = ''' ||  quote_literal(current_db_tb_id) || ''' and  record_write_time ';

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
--这么做要保证每个表上的 update 触发器不但要在修改记录时修改 record_write_time，还需要将记录的 record_former_db_id 改为自己的。同时insert 触发器不执行 update 操作，直接删除 record_write_time 较小的记录，插入 record_write_time 较新的记录，并将此触发器创建到 tb_push_record_sync_temp 表上(需要测试能否在临时表上创建触发器)。
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

		if current_db_tb_id_record.last_read_time is not null then
			execute_sql := execute_sql || '> ''' ||  quote_literal(current_db_tb_id_record.last_read_time) || ''' and  record_write_time ';
		end if;
		execute_sql := execute_sql || '<= ''' || quote_literal(sync_time) || ''' '') as tb_push_record_temp(push_id uuid ,pull_id uuid , push_content bytea,push_start_time timestamp without time zone, push_finish_time timestamp without time zone, push_type smallint , record_write_time timestamp with time zone, record_former_db_id uuid);';
		--这儿是写死了，后续进行改进（通过系统表，查找出表结构，使用动态sql，拼出 tb_push_record_temp 的定义，以便适应数据表可能修改的问题，以及可以处理其他表的同步问题）
		
		begin	
			execute execute_sql;
		exception
			--特殊的条件名OTHERS匹配除了QUERY_CANCELED之外的所有错误类型
			when OTHERS then				
				raise notice 'obtain data --- select data into temp table:
				current_dblink: %
				ERROR CODE: %
				EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
				
				--释放 dblink 链接
				execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
				execute execute_sql into local_dblink_connections;
				if local_dblink_connections is not null then
					execute 'select dblink_disconnect(''' || current_dblink || ''');';	
				end if;
				raise notice '';		
				continue;
		end;
		
		--更新 tb_network_sync_info 表中该记录的 last_sync_time 
		execute_sql := 'update tb_network_sync_info set last_read_time = ' || quote_literal(sync_time) || ' where db_tb_id = ' || quote_literal(current_db_tb_id_record.db_tb_id::text) || ';';
		execute execute_sql;
		--如果在此处发生异常，则 tb_push_record_sync_temp 表里面其实已经有了该数据库的数据，但 tb_network_sync_info 里面该数据库的记录的 last_read_time 并未更新，下次更新又会读出来，重新同步到其他数据库，导致冲突（暂各表的 insert 触发器去解决）
		
		--释放 dblink 链接
		execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
		execute execute_sql into local_dblink_connections;
		if local_dblink_connections is not null then
			execute 'select dblink_disconnect(''' || current_dblink || ''');';	
		end if;
		
		raise notice '% --- Select data into local table successful!', current_dblink;
	
end loop;
raise notice '';

/*
select count(*) into temp_record_count from tb_push_record_sync_temp;
raise notice '------ temp_record_count: %', temp_record_count;
raise notice '';
*/


--先同步到 local_db_tb ,如果失败则直接结束，等待下一次同步，其他数据库也不能同步。
--如果 local_db_tb 同步失败，如何保证各个数据库的 last_read_time 回滚到以前的（函数会包在事务中执行，如果直接抛出异常，让事务直接回滚应该可以实现，需要测试一下）
--insert into tb_push_record select * from tb_push_record_sync_temp where record_former_db_id <> 'local_db_tb_id'
--execute_sql := 'insert into tb_push_record select push_id, pull_id, push_content, push_start_time, push_finish_time, push_type, record_write_time,record_former_db_id from tb_push_record_sync_temp where db_tb_id <> ' || quote_literal(local_db_tb_id_record.db_tb_id) || ';';
execute_sql := 'update tb_network_sync_info set last_sync_time = ' || quote_literal(sync_time) || ' where db_tb_id = ' || quote_literal(local_db_tb_id_record.db_tb_id::text) || ';';
execute execute_sql;
raise notice ' ------ local database --- Update local db infomation record of tb_network_sync_info.last_sync_time!';
raise notice '';
--同上，不做异常处理的目的也是为了在出现异常时直接抛出异常，引起回滚

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
		---下面这种同步方法，只能在 远程 dblink 等访问本会话中的 temp 才能生效，现在还没确认是否有此权限，由于 postgresql 
		---中的 create [ GLOBAL|LOCAL] TEMPORARY table  GLOBAL和LOCAL关键字不起作用，文档里面也不建议使用这两个关键字，
		---所以需要测试验证，如果不行的话，就直接创建实体表，在函数结尾 drop 掉就行
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
for current_db_tb_id_record in select * from tb_network_sync_info where db_tb_id <> local_db_tb_id_record.db_tb_id loop
	current_db_tb_id := current_db_tb_id_record.db_tb_id::text;
	--创建 dblink 链接
	current_dblink := current_db_tb_id || '_dblink';
	begin
		execute 'select dblink_connect(''' || current_dblink || ''','''|| 'host=' || host(current_db_tb_id_record.host) ||  ' port=' || current_db_tb_id_record.port ||  ' dbname=' || current_db_tb_id_record.db_name || ' user=' || current_db_tb_id_record.db_user || ' password=' || current_db_tb_id_record.db_password || ' connect_timeout=3 keepalives=1 keepalives_idle=1 keepalives_interval=1 keepalives_count=3'');';
	exception
		when OTHERS then
			raise notice 'write data --- Create local dblink connect:
			current_dblink: %
			ERROR CODE: %
			EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
			
			--Postgresql: 动态SQL语句中不能使用Select into，应该如下使用：
			execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
			execute execute_sql into local_dblink_connections;
			if local_dblink_connections is null then
				continue;
			end if;
			raise notice '';
	end;
	
	--向远程数据库写入数据
	
	begin
		--将远程的操作封装到一个事务里，以防止中途网络断开等意外造成数据只写一半等情况
		execute 'select dblink_exec(''' || current_dblink || ''', ''begin'');';
	
		--没有找到可以直接将某个表中的数据一次性写入远方表的方法，因此采用替代方法：通过建立的 dblink 链接，操作远方数据库建立一个到 local_db_tb 的链接，用远程数据库上的链接来查询插入
	
		--在远程数据库上创建一个到 local_db_tb 的 dblink
		--select * from dblink('test', 'select dblink_connect(''test'', ''host=192.168.34.249 port=6789 dbname=push user=admin password=admin'')') as dlk(dc text);
		execute 'select * from dblink(''' || current_dblink || ''', '' select dblink_connect(''''' || current_dblink || ''''', ''''host=' || host(local_db_tb_id_record.host) || ' port=' || local_db_tb_id_record.port || ' dbname=' || local_db_tb_id_record.db_name || ' user=' || local_db_tb_id_record.db_user || ' password=' || local_db_tb_id_record.db_password || ' connect_timeout=3 keepalives=1 keepalives_idle=1 keepalives_interval=1 keepalives_count=3'''')'') as ret_net_dblink(err_msg text);';
	exception
		when OTHERS then
			raise notice 'write data --- Create net dblink connect:
			current_dblink: %
			ERROR CODE: %
			EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
				
			--Postgresql: 动态SQL语句中不能使用Select into，应该如下使用：
			execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
			execute execute_sql into local_dblink_connections;
			if local_dblink_connections is not null then
				--断开连接后，自然会回滚，只要没有显示执行 commit 就不会保存数据
				--execute 'select dblink_exec(''' || current_dblink || ''', ''rollback'');';
				--断开本地数据里面的 dblink 连接
				execute 'select dblink_disconnect(''' || current_dblink || ''');';
				continue;
			end if;
			raise notice '';
	end;

	
	-- select dblink_exec('test', 'insert into tb_test_dblink select * from dblink(''test'', ''select * from tb_test_dblink where t_str = ''''qqqq'''' and push_id not in (select push_id from tb_push_record_sync_temp where db_tb_id = ''''local_db_tb_id'''' and record_write_time <= ''''current_db_tb_id_record.last_sync_time'''') '') as tb_test_dblink_temp(t_str text)');
	--不从 tb_push_record_sync_temp 表中取数据了，改为从 tb_push_record 表中 select into
	execute_sql := 'select dblink_exec(''' || current_dblink || ''', ''insert into tb_push_record select * from dblink(''''' || current_dblink || ''''', ''''select * from tb_push_record where record_former_db_id <> ''''''' || quote_literal(current_db_tb_id_record.db_tb_id) || ''''''' and record_write_time ';
	if current_db_tb_id_record.last_sync_time is null then 
		execute_sql := execute_sql || '< ''''''' || quote_literal(sync_time) || ''''''' '''') '; --这儿及下面的单引号逃逸有点懵逼，测试时需要仔细检查
	else
		execute_sql := execute_sql || '> ''''''' ||  quote_literal(current_db_tb_id_record.last_sync_time) || ''''''' and record_write_time < ''''''' || quote_literal(sync_time) || ''''''' '''') ';
	end if;
	execute_sql := execute_sql || 'as tb_push_record_temp(push_id uuid ,pull_id uuid , push_content bytea,push_start_time timestamp without time zone, push_finish_time timestamp without time zone, push_type smallint , record_write_time timestamp with time zone, record_former_db_id uuid)'');';

	begin	
		execute execute_sql;
	exception
		when OTHERS then
			raise notice 'write data --- Insert data into net tb_push_record table:
			current_dblink: %
			ERROR CODE: %
			EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
			
			--检查本地 dblink 连接是否还在
			--select dblink_get_connections into local_dblink_connections from dblink_get_connections() where 'tesat2' = any(dblink_get_connections);
			execute_sql := 'select dblink_get_connections from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';
			execute execute_sql into local_dblink_connections;
			if local_dblink_connections is not null then
				
				--检查远程 dblink 连接是否还在
				--select * from dblink('tesat', 'select dblink_get_connections()') as dblink_get_connections(db_connec text[]) where 'tesat' = any(db_connec);
				execute_sql := 'select * from dblink(''' || current_dblink || ''', ''select dblink_get_connections()'') as dblink_get_connections(db_connec text[]) where ''' || current_dblink || ''' = any(db_connec);';
				execute execute_sql into net_dblink_connections;
				if net_dblink_connections is not null then
					--检查一下远程数据库的 dblink 的错误信息
					--select * from dblink('test', 'select dblink_error_message(''test'')') as ret_temp(err_msg text);
					execute_sql := 'select err_msg from dblink(''' || current_dblink || ''', ''select dblink_error_message(''''' || current_dblink || ''''')'') as ret_temp(err_msg text);';
					execute execute_sql into net_dblink_err_msg;
					raise notice '%: net_dblink_err_msg: %', current_dblink, net_dblink_err_msg;
					--断开远程数据里面的 dblink 连接
					--select * from dblink('test', 'select dblink_disconnect(''test'')') as dlk(dc text);
					execute_sql := 'select * from dblink(''' || current_dblink || ''', ''select dblink_disconnect(''''' || current_dblink || ''''')'') as ret_temp(err_msg text);';
					execute execute_sql;

				end if;
			
				execute_sql := 'select dblink_exec(''' || current_dblink || ''', ''rollback'');';
				execute execute_sql;
				--断开本地数据里面的 dblink 连接
				execute_sql := 'select dblink_disconnect(''' || current_dblink || ''');';
				execute execute_sql;
			end if;
			raise notice '';
			continue;
				
			--其他错误、异常后续完善时再处理
		
	end;
				
	
	--结果正常时的处理
	--断开远程数据里面的 dblink 连接
	--select * from dblink('test', 'select dblink_disconnect(''test'')') as dlk(dc text);
	execute_sql := 'select * from dblink(''' || current_dblink || ''', ''select dblink_disconnect(''''' || current_dblink || ''''')'') as ret_temp(err_msg text);';
	--提交在远程数据库上的事务
	execute_sql := execute_sql || '
select dblink_exec(''' || current_dblink || ''', ''commit'');';
	--断开本地数据里面的 dblink 连接
	execute_sql := execute_sql || '
select dblink_disconnect(''' || current_dblink || ''');';

	execute execute_sql;
	raise notice '% --- Write data to network table successful!', current_dblink;
	
	--将 sync_time 更新到本条记录的 last_sync_time
	update tb_network_sync_info set last_sync_time = sync_time where db_tb_id = current_db_tb_id_record.db_tb_id;

				
end loop;
raise notice '';
--其他异常后续处理

return true;
end;
$$;


ALTER FUNCTION public.db_cluster_sync() OWNER TO admin;

--
-- Name: db_cluster_sync(text); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION db_cluster_sync(sync_table_name text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$ 
declare

local_db_tb_id_default text default null;--保存查询到的本地数据库里需要同步的表的record_former_db_id字段的默认值(text)
local_db_tb_id uuid;--保存本地数据库里需要同步的表的record_former_db_id字段的默认值
extension_info text default null; --保存模块名

column_struct text default null;--sync_table_name 表中列结构
table_struct text default null;--sync_table_name 表结构

--通过下面的数据定义，就能检验出数据库中是否存在 tb_network_sync_info 表，不用另外再检验 
local_db_tb_id_record tb_network_sync_info%ROWTYPE;--保存 tb_network_sync_info 中本地数据库记录
current_db_tb_id_record tb_network_sync_info%ROWTYPE;--保存当前 tb_network_sync_info 中的记录，一般用于循环
count_net_db integer default 0;--tb_network_sync_info 中记录的需要同步的数据库的数量
sync_time timestamp with time zone;--本次同步的时间点（统一一个时间）

current_db_tb_id text default null;--current_db_tb_id_record 的 db_tb_id 的 text 类型
current_dblink text default null;--用于拼凑记录当前的 dblink 连接名
execute_sql text;--用于动态构建 sql 命令

local_dblink_err_msg text default null;--用于保存获取的本地 dblink 连接的执行结果 
net_dblink_err_msg text default null;--用于保存获取的远程数据库上 dblink 连接的执行结果 
local_dblink_connections text default null;--用于保存本地 dblink_get_connections() 函数的返回结果
net_dblink_connections text default null;--用于保存远程数据库上 dblink_get_connections() 函数的返回结果


begin

--检查是否安装了 dblink 模块 
select extname into extension_info from pg_extension where extname = 'dblink';
if not found then
	raise EXCEPTION 'cannot find the Modules of dblink';
	return false;
end if;

--检查本地数据库是否存在 sync_table_name 表，并查询其表结构（必须存在 record_write_time、record_former_db_id字段）
table_struct = '';
--如果为 null 下面拼接时会直接返回 null，无法拼接，相应的，判断是否有记录就应该用 if table_struct = ''，不能使用 if table_struct is null
for column_struct in select format('%s %s, ',column_name, data_type) from information_schema.columns where table_name = sync_table_name loop
	table_struct := table_struct || column_struct;	
end loop;
if table_struct = '' then
	raise EXCEPTION 'can''t find the table of %', sync_table_name;
end if;
--去掉末尾的 ', ' 字符串
select * into table_struct from trim(trailing ', ' from table_struct);
--检查是否存在 record_write_time timestamp with time zone 和 record_former_db_id uuid，注意数据类型也必须一致
if position('record_write_time timestamp with time zone' in table_struct) = 0 or position('record_former_db_id uuid' in table_struct) = 0 then
	raise EXCEPTION 'can''t find the columns of ''record_write_time timestamp with time zone'' or ''record_former_db_id uuid'' in the % table(Tips: Please check data type)!', sync_table_name;
	return false;
end if;

--查询 local_db_tb_id 字段的默认值，这样就可以不传参数了
select column_default into local_db_tb_id_default from information_schema.columns where table_schema = 'public' AND table_name = sync_table_name and column_name = 'record_former_db_id';
select * into local_db_tb_id from substr(local_db_tb_id_default, 2, 36); 
if local_db_tb_id is null then 
	raise exception '%.record_former_db_id is null!', sync_table_name;
	return false;
end if;
raise notice 'local_db_tb_id: %', local_db_tb_id;

--检查 tb_network_sync_info 是否有本地数据库的记录，如果没有，则直接退出函数 
select * into local_db_tb_id_record from tb_network_sync_info where db_tb_id = local_db_tb_id and table_name = sync_table_name;
if not found then
	raise exception 'cannot find local db_tb_id infomation in tb_network_sync_info';
	return false;
end if;

--查询有多少需要同步的远程数据库、以及多少新加入的远程数据库
select count(*) into count_net_db from tb_network_sync_info where table_name = sync_table_name;

--如果 count_net_db 为 1 （经过前面的检查，记录数为 0 是不可能执行到这儿的，如果为 1 ，必然是本地数据库信息的记录）
--则将此记录的 last_sync_time 置为空，然后结束此函数	
if count_net_db = 1 then 
	update tb_network_sync_info set last_sync_time = null, last_read_time = null where db_tb_id = local_db_tb_id and table_name = sync_table_name;
	raise notice 'Only the local database in a cluster, which does not require synchronization.';
	return true;
end if;
		
sync_time := now();
raise notice '------ sync_time: % ------', sync_time::text;
raise notice '';

--如果 tb_network_sync_info 表中本地数据库记录的 last_read_time 或者 last_sync_time 为空，则将所有数据库记录的 last_read_time 和 last_sync_time全部置空，以便重新全部同步
if local_db_tb_id_record.last_read_time is null or local_db_tb_id_record.last_sync_time is null then
	update tb_network_sync_info set last_sync_time = null, last_read_time = null where table_name = sync_table_name;
end if;

execute 'update tb_network_sync_info set last_read_time = ' || quote_literal(sync_time) || ' where db_tb_id = ' || quote_literal(local_db_tb_id_record.db_tb_id::text) || ' and table_name = ' || quote_literal(sync_table_name) || ';';

/*
execute execute_sql;--暂不做异常处理，如果前面一旦出现异常，整个函数应该都会回滚的，update 的 tb_network_sync_info 都会回滚回去的，待验证
*/

for current_db_tb_id_record in select * from tb_network_sync_info where table_name = sync_table_name and db_tb_id <> local_db_tb_id_record.db_tb_id loop
	current_db_tb_id := current_db_tb_id_record.db_tb_id::text;
		--创建 dblink 链接
		current_dblink := current_db_tb_id_record.db_tb_id::text || '_dblink';

		begin
			--connect_timeout=3 连接创建超时时间 3秒
			--keepalives=1 客户端保持连接
			--keepalives_idle=1 tcp心跳间隔的空闲时间 1秒
			--keepalives_interval=1 对方没有回应时发送 tcp心跳的间隔时间 1秒
			--keepalives_count=3 在认为客户端到服务器的连接死亡之前，可以丢失的TCP保持激活的数量 3个
			execute 'select dblink_connect(''' || current_dblink || ''','''|| 'host=' || host(current_db_tb_id_record.host) ||  ' port=' || current_db_tb_id_record.port || ' dbname=' || current_db_tb_id_record.db_name || ' user=' || current_db_tb_id_record.db_user || ' password=' || current_db_tb_id_record.db_password || ' connect_timeout=3  keepalives=1 keepalives_idle=1 keepalives_interval=1 keepalives_count=3'');';
		exception
			when OTHERS then
				raise notice 'obtain data --- create dblink connect:
				current_dblink: %
				ERROR CODE: %
				EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
				
				--Postgresql: 动态SQL语句中不能使用Select into，应该如下使用：
				execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
				execute execute_sql into local_dblink_connections;
				if local_dblink_connections is null then
					continue;
				end if;
				raise notice '';
		end;
		--远程查询记录，并插入本地表中
		execute_sql := 'insert into ' || sync_table_name ||' select * from dblink(''' || current_dblink ||''', ''select * from ' || sync_table_name || ' where record_former_db_id = ''' ||  quote_literal(current_db_tb_id) || ''' and  record_write_time ';

		if current_db_tb_id_record.last_read_time is not null then
			execute_sql := execute_sql || '> ''' ||  quote_literal(current_db_tb_id_record.last_read_time) || ''' and  record_write_time ';
		end if;
		execute_sql := execute_sql || '<= ''' || quote_literal(sync_time) || ''' '') as tb_sync_temp(' || table_struct || ');';
		
		begin	
			execute execute_sql;
		exception
			--特殊的条件名OTHERS匹配除了QUERY_CANCELED之外的所有错误类型
			when OTHERS then				
				raise notice 'obtain data --- select data into temp table:
				current_dblink: %
				ERROR CODE: %
				EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
				
				--释放 dblink 链接
				execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
				execute execute_sql into local_dblink_connections;
				if local_dblink_connections is not null then
					execute 'select dblink_disconnect(''' || current_dblink || ''');';	
				end if;
				raise notice '';		
				continue;
		end;
		
		--更新 tb_network_sync_info 表中该记录的 last_sync_time 
		execute_sql := 'update tb_network_sync_info set last_read_time = ' || quote_literal(sync_time) || ' where db_tb_id = ' || quote_literal(current_db_tb_id_record.db_tb_id::text) || ' and table_name = ' || quote_literal(sync_table_name) || ';';
		execute execute_sql;
		--如果在此处发生异常，则 tb_push_record_sync_temp 表里面其实已经有了该数据库的数据，但 tb_network_sync_info 里面该数据库的记录的 last_read_time 并未更新，下次更新又会读出来，重新同步到其他数据库，导致冲突（暂各表的 insert 触发器去解决）
		
		--释放 dblink 链接
		execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
		execute execute_sql into local_dblink_connections;
		if local_dblink_connections is not null then
			execute 'select dblink_disconnect(''' || current_dblink || ''');';	
		end if;
		
		raise notice '% --- Select data into local table successful!', current_dblink;
	
end loop;
raise notice '';


--先同步到 local_db_tb ,如果失败则直接结束，等待下一次同步，其他数据库也不能同步。
--如果 local_db_tb 同步失败，如何保证各个数据库的 last_read_time 回滚到以前的（函数会包在事务中执行，如果直接抛出异常，让事务直接回滚应该可以实现，需要测试一下）
execute_sql := 'update tb_network_sync_info set last_sync_time = ' || quote_literal(sync_time) || ' where db_tb_id = ' || quote_literal(local_db_tb_id_record.db_tb_id::text) || 'and table_name = ' || quote_literal(sync_table_name) || ';';
execute execute_sql;
raise notice ' ------ local database --- Update local db infomation record of tb_network_sync_info.last_sync_time!';
raise notice '';
--同上，不做异常处理的目的也是为了在出现异常时直接抛出异常，引起回滚

for current_db_tb_id_record in select * from tb_network_sync_info where table_name = sync_table_name and db_tb_id <> local_db_tb_id_record.db_tb_id loop
	current_db_tb_id := current_db_tb_id_record.db_tb_id::text;
	--创建 dblink 链接
	current_dblink := current_db_tb_id || '_dblink';
	begin
		execute 'select dblink_connect(''' || current_dblink || ''','''|| 'host=' || host(current_db_tb_id_record.host) ||  ' port=' || current_db_tb_id_record.port ||  ' dbname=' || current_db_tb_id_record.db_name || ' user=' || current_db_tb_id_record.db_user || ' password=' || current_db_tb_id_record.db_password || ' connect_timeout=3 keepalives=1 keepalives_idle=1 keepalives_interval=1 keepalives_count=3'');';
	exception
		when OTHERS then
			raise notice 'write data --- Create local dblink connect:
			current_dblink: %
			ERROR CODE: %
			EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
			
			--Postgresql: 动态SQL语句中不能使用Select into，应该如下使用：
			execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
			execute execute_sql into local_dblink_connections;
			if local_dblink_connections is null then
				continue;
			end if;
			raise notice '';
	end;
	
	--向远程数据库写入数据
	
	begin
		--将远程的操作封装到一个事务里，以防止中途网络断开等意外造成数据只写一半等情况
		execute 'select dblink_exec(''' || current_dblink || ''', ''begin'');';
	
		--没有找到可以直接将某个表中的数据一次性写入远方表的方法，因此采用替代方法：通过建立的 dblink 链接，操作远方数据库建立一个到 local_db_tb 的链接，用远程数据库上的链接来查询插入
	
		--在远程数据库上创建一个到 local_db_tb 的 dblink
		--select * from dblink('test', 'select dblink_connect(''test'', ''host=192.168.34.249 port=6789 dbname=push user=admin password=admin'')') as dlk(dc text);
		execute 'select * from dblink(''' || current_dblink || ''', '' select dblink_connect(''''' || current_dblink || ''''', ''''host=' || host(local_db_tb_id_record.host) || ' port=' || local_db_tb_id_record.port || ' dbname=' || local_db_tb_id_record.db_name || ' user=' || local_db_tb_id_record.db_user || ' password=' || local_db_tb_id_record.db_password || ' connect_timeout=3 keepalives=1 keepalives_idle=1 keepalives_interval=1 keepalives_count=3'''')'') as ret_net_dblink(err_msg text);';
	exception
		when OTHERS then
			raise notice 'write data --- Create net dblink connect:
			current_dblink: %
			ERROR CODE: %
			EXCEPTION MESSAGE: %',current_dblink, SQLSTATE, SQLERRM;
				
			--Postgresql: 动态SQL语句中不能使用Select into，应该如下使用：
			execute_sql := 'select dblink_get_connections::text from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';				
			execute execute_sql into local_dblink_connections;
			if local_dblink_connections is not null then
				--断开连接后，自然会回滚，只要没有显示执行 commit 就不会保存数据
				--execute 'select dblink_exec(''' || current_dblink || ''', ''rollback'');';
				--断开本地数据里面的 dblink 连接
				execute 'select dblink_disconnect(''' || current_dblink || ''');';
				continue;
			end if;
			raise notice '';
	end;

	
	-- select dblink_exec('test', 'insert into tb_test_dblink select * from dblink(''test'', ''select * from tb_test_dblink where t_str = ''''qqqq'''' and push_id not in (select push_id from tb_push_record_sync_temp where db_tb_id = ''''local_db_tb_id'''' and record_write_time <= ''''current_db_tb_id_record.last_sync_time'''') '') as tb_test_dblink_temp(t_str text)');
	--不从 tb_push_record_sync_temp 表中取数据了，改为从 tb_push_record 表中 select into
	execute_sql := 'select dblink_exec(''' || current_dblink || ''', ''insert into ' || sync_table_name || ' select * from dblink(''''' || current_dblink || ''''', ''''select * from ' || sync_table_name || ' where record_former_db_id <> ''''''' || quote_literal(current_db_tb_id_record.db_tb_id) || ''''''' and record_write_time ';
	if current_db_tb_id_record.last_sync_time is null then 
		execute_sql := execute_sql || '< ''''''' || quote_literal(sync_time) || ''''''' '''') '; --这儿及下面的单引号逃逸有点懵逼，测试时需要仔细检查
	else
		execute_sql := execute_sql || '> ''''''' ||  quote_literal(current_db_tb_id_record.last_sync_time) || ''''''' and record_write_time < ''''''' || quote_literal(sync_time) || ''''''' '''') ';
	end if;
	execute_sql := execute_sql || 'as tb_sync_temp(' || table_struct || ')'');';

	begin	
		execute execute_sql;
	exception
		when OTHERS then
			raise notice 'write data --- Insert data into net % table:
			current_dblink: %
			ERROR CODE: %
			EXCEPTION MESSAGE: %',sync_table_name, current_dblink, SQLSTATE, SQLERRM;
			
			--检查本地 dblink 连接是否还在
			--select dblink_get_connections into local_dblink_connections from dblink_get_connections() where 'tesat2' = any(dblink_get_connections);
			execute_sql := 'select dblink_get_connections from dblink_get_connections() where ''' || current_dblink || ''' = any(dblink_get_connections);';
			execute execute_sql into local_dblink_connections;
			if local_dblink_connections is not null then
				
				--检查远程 dblink 连接是否还在
				--select * from dblink('tesat', 'select dblink_get_connections()') as dblink_get_connections(db_connec text[]) where 'tesat' = any(db_connec);
				execute_sql := 'select * from dblink(''' || current_dblink || ''', ''select dblink_get_connections()'') as dblink_get_connections(db_connec text[]) where ''' || current_dblink || ''' = any(db_connec);';
				execute execute_sql into net_dblink_connections;
				if net_dblink_connections is not null then
					--检查一下远程数据库的 dblink 的错误信息
					--select * from dblink('test', 'select dblink_error_message(''test'')') as ret_temp(err_msg text);
					execute_sql := 'select err_msg from dblink(''' || current_dblink || ''', ''select dblink_error_message(''''' || current_dblink || ''''')'') as ret_temp(err_msg text);';
					execute execute_sql into net_dblink_err_msg;
					raise notice '%: net_dblink_err_msg: %', current_dblink, net_dblink_err_msg;
					--断开远程数据里面的 dblink 连接
					--select * from dblink('test', 'select dblink_disconnect(''test'')') as dlk(dc text);
					execute_sql := 'select * from dblink(''' || current_dblink || ''', ''select dblink_disconnect(''''' || current_dblink || ''''')'') as ret_temp(err_msg text);';
					execute execute_sql;

				end if;
			
				execute_sql := 'select dblink_exec(''' || current_dblink || ''', ''rollback'');';
				execute execute_sql;
				--断开本地数据里面的 dblink 连接
				execute_sql := 'select dblink_disconnect(''' || current_dblink || ''');';
				execute execute_sql;
			end if;
			raise notice '';
			continue;
				
			--其他错误、异常后续完善时再处理
		
	end;
				
	
	--结果正常时的处理
	--断开远程数据里面的 dblink 连接
	--select * from dblink('test', 'select dblink_disconnect(''test'')') as dlk(dc text);
	execute_sql := 'select * from dblink(''' || current_dblink || ''', ''select dblink_disconnect(''''' || current_dblink || ''''')'') as ret_temp(err_msg text);';
	--提交在远程数据库上的事务
	execute_sql := execute_sql || '
select dblink_exec(''' || current_dblink || ''', ''commit'');';
	--断开本地数据里面的 dblink 连接
	execute_sql := execute_sql || '
select dblink_disconnect(''' || current_dblink || ''');';

	execute execute_sql;
	raise notice '% --- Write data to network table successful!', current_dblink;
	
	--将 sync_time 更新到本条记录的 last_sync_time
	update tb_network_sync_info set last_sync_time = sync_time where db_tb_id = current_db_tb_id_record.db_tb_id and table_name = sync_table_name;

				
end loop;
raise notice '';

return true;
end;
$$;


ALTER FUNCTION public.db_cluster_sync(sync_table_name text) OWNER TO admin;

--
-- Name: insert_trigger_for_sync_tb_push_record(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION insert_trigger_for_sync_tb_push_record() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
trigger_when text default null;
trigger_level text default null;
trigger_op text default null;
trigger_table_name text default null;
trigger_table_schema text default null;
old_record tb_push_record%ROWTYPE;

begin
trigger_when := TG_WHEN;
trigger_level := TG_LEVEL;
trigger_op := TG_OP;
trigger_table_name := TG_TABLE_NAME;
trigger_table_schema := TG_TABLE_SCHEMA;

--因BEFORE触发的行级别触发器可以返回一个NULL， 告诉触发器管理器忽略对该行剩下的操作，也就是说，随后的触发器将不再执行， 并且不会对该行产生INSERT/UPDATE/DELETE动作)。 如果返回了一个非NULL的行，那么将继续对该行数值进行处理。
if trigger_when = 'BEFORE' and trigger_level = 'ROW' and trigger_op = 'INSERT' and trigger_table_name = 'tb_push_record' and trigger_table_schema = 'public' then

	select * into old_record from tb_push_record where push_id = new.push_id;
	if found then
		if new.record_write_time > old_record.record_write_time then
			--tb_push_record 上面有一个 delete 触发器，会将删除的记录插入到 tb_push_record_history 表中，存在 tb_push_record_history 表中主键冲突的可能，此情况下会导致本触发器抛出异常。此外，tb_push_record 还有一个 update 触发器，用于在 update 时修改 record_write_time 和 record_former_db_id ，因此此处也不能使用 update 去修改原记录的值。因此，需要将 tb_push_record_history 的主键约束去掉
			delete from tb_push_record where push_id = old_record.push_id;
			raise notice 'delete the old record!';
		else
			raise notice 'More new record already exists, Cancel the insert operation!';
			RETURN NULL;
		end if;
	end if;

end if;

RETURN new;
end;
$$;


ALTER FUNCTION public.insert_trigger_for_sync_tb_push_record() OWNER TO admin;

--
-- Name: insert_trigger_for_sync_tb_push_record_sync_temp(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION insert_trigger_for_sync_tb_push_record_sync_temp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
trigger_when text default null;
trigger_level text default null;
trigger_op text default null;
trigger_table_name text default null;
trigger_table_schema text default null;
old_record record;

begin
trigger_when := TG_WHEN;
trigger_level := TG_LEVEL;
trigger_op := TG_OP;
trigger_table_name := TG_TABLE_NAME;
trigger_table_schema := TG_TABLE_SCHEMA;

--因BEFORE触发的行级别触发器可以返回一个NULL， 告诉触发器管理器忽略对该行剩下的操作，也就是说，随后的触发器将不再执行， 并且不会对该行产生INSERT/UPDATE/DELETE动作)。 如果返回了一个非NULL的行，那么将继续对该行数值进行处理。
if trigger_when = 'BEFORE' and trigger_level = 'ROW' and trigger_op = 'INSERT' and trigger_table_name = 'tb_push_record_sync_temp' then

	select * into old_record from tb_push_record_sync_temp where push_id = new.push_id;
	if found then
		if new.record_write_time > old_record.record_write_time then
			--tb_push_record 上面有一个 delete 触发器，会将删除的记录插入到 tb_push_record_history 表中，存在 tb_push_record_history 表中主键冲突的可能，此情况下会导致本触发器抛出异常。此外，tb_push_record 还有一个 update 触发器，用于在 update 时修改 record_write_time 和 record_former_db_id ，因此此处也不能使用 update 去修改原记录的值。因此，需要将 tb_push_record_history 的主键约束去掉
			delete from tb_push_record_sync_temp where push_id = old_record.push_id;
			raise notice 'delete the old record!';
		else
			raise notice 'More new record already exists, Cancel the insert operation!';
			RETURN NULL;
		end if;
	end if;

end if;

RETURN new;
end;
$$;


ALTER FUNCTION public.insert_trigger_for_sync_tb_push_record_sync_temp() OWNER TO admin;

--
-- Name: save_record_history(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION save_record_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
history_record tb_push_record_history%ROWTYPE;

begin

select * into history_record from tb_push_record_history where push_id = old.push_id;
if found then
		if old.record_write_time > history_record.record_write_time then
			--tb_push_record 上面有一个 delete 触发器，会将删除的记录插入到 tb_push_record_history 表中，存在 tb_push_record_history 表中主键冲突的可能，此情况下会导致本触发器抛出异常。此外，tb_push_record 还有一个 update 触发器，用于在 update 时修改 record_write_time 和 record_former_db_id ，因此此处也不能使用 update 去修改原记录的值。因此，需要将 tb_push_record_history 的主键约束去掉
			delete from tb_push_record_history where push_id = history_record.push_id;
			raise notice 'delete the old record in tb_push_record_history table! push_id = ''%''', history_record.push_id::text;
		else
			raise notice 'More new record already exists in tb_push_record_history table, Cancel the insert operation! push_id = ''%''', history_record.push_id::text;
			RETURN NULL;
		end if;
end if;

INSERT INTO tb_push_record_history select OLD.*;

return NULL;
end
$$;


ALTER FUNCTION public.save_record_history() OWNER TO admin;

--
-- Name: FUNCTION save_record_history(); Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON FUNCTION save_record_history() IS '删除记录时，自动保存到 tb_push_record_history';


--
-- Name: update_trigger_for_sync_tb_push_record(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION update_trigger_for_sync_tb_push_record() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
trigger_when text default null;
trigger_level text default null;
trigger_op text default null;
trigger_table_name text default null;
trigger_table_schema text default null;
update_record_former_db_id text default null;
update_record_former_db_id_uuid uuid default null;

begin
trigger_when := TG_WHEN;
trigger_level := TG_LEVEL;
trigger_op := TG_OP;
trigger_table_name := TG_TABLE_NAME;
trigger_table_schema := TG_TABLE_SCHEMA;

--因BEFORE触发的行级别触发器可以返回一个NULL， 告诉触发器管理器忽略对该行剩下的操作，也就是说，随后的触发器将不再执行， 并且不会对该行产生INSERT/UPDATE/DELETE动作)。 如果返回了一个非NULL的行，那么将继续对该行数值进行处理。为了修改行存储，可以用一个值直接代替NEW里的某个数值并且返回之， 或者也可以构建一个全新的记录/行再返回。
if trigger_when = 'BEFORE' and trigger_level = 'ROW' and trigger_op = 'UPDATE' and trigger_table_name = 'tb_push_record' and trigger_table_schema = 'public' then

	--查询 record_former_db_id 字段的默认值，这样就添加新的需要同步的数据库时，就少一个修改的地方
	select column_default into update_record_former_db_id from information_schema.columns where table_schema = 'public' AND table_name = 'tb_push_record' and column_name = 'record_former_db_id';

	select * into update_record_former_db_id_uuid from substr(update_record_former_db_id, 2, 36); 

	new.record_write_time := now();
	new.record_former_db_id := update_record_former_db_id_uuid;
	--raise notice 'new: %', new;
end if;

RETURN new;
end;
$$;


ALTER FUNCTION public.update_trigger_for_sync_tb_push_record() OWNER TO admin;

--
-- Name: ddddd_tb_push_record_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW ddddd_tb_push_record_view AS
 SELECT tb_push_record.push_id,
    tb_push_record.pull_id,
    tb_push_record.push_content,
    tb_push_record.push_start_time,
    tb_push_record.push_finish_time,
    tb_push_record.push_type,
    tb_push_record.record_write_time
   FROM dblink('test_dblink'::text, 'select * from tb_push_record'::text) tb_push_record(push_id uuid, pull_id uuid, push_content bytea, push_start_time timestamp without time zone, push_finish_time timestamp without time zone, push_type smallint, record_write_time timestamp with time zone);


ALTER TABLE ddddd_tb_push_record_view OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: tb_apple_message_badge_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_apple_message_badge_info (
    userid uuid NOT NULL,
    badge integer,
    CONSTRAINT tb_apple_message_badge_info_userid_check CHECK ((userid <> '00000000-0000-0000-0000-000000000000'::uuid))
);


ALTER TABLE tb_apple_message_badge_info OWNER TO admin;

--
-- Name: COLUMN tb_apple_message_badge_info.badge; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_apple_message_badge_info.badge IS '消息计数';


--
-- Name: tb_area_server; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_area_server (
    area_type smallint DEFAULT 1 NOT NULL,
    server_id uuid NOT NULL
);


ALTER TABLE tb_area_server OWNER TO admin;

--
-- Name: TABLE tb_area_server; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_area_server IS '区域服务关系映射表';


--
-- Name: COLUMN tb_area_server.server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_area_server.server_id IS '服务id';


--
-- Name: tb_ip_area_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_ip_area_info (
    ip_start_point inet NOT NULL,
    ip_end_point inet NOT NULL,
    ip_area_type smallint DEFAULT 1 NOT NULL,
    ip_area_name text NOT NULL
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
-- Name: tb_network_sync_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_network_sync_info (
    db_tb_id uuid NOT NULL,
    host inet NOT NULL,
    port integer NOT NULL,
    db_name text NOT NULL,
    db_user text NOT NULL,
    db_password text,
    table_name text NOT NULL,
    last_sync_time timestamp with time zone,
    last_read_time timestamp with time zone
);


ALTER TABLE tb_network_sync_info OWNER TO admin;

--
-- Name: TABLE tb_network_sync_info; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_network_sync_info IS '记录需要同步的各数据库表的信息';


--
-- Name: COLUMN tb_network_sync_info.host; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.host IS '数据库所在主机的IP地址';


--
-- Name: COLUMN tb_network_sync_info.port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.port IS '数据库服务监听的端口';


--
-- Name: COLUMN tb_network_sync_info.db_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.db_name IS '数据库库名';


--
-- Name: COLUMN tb_network_sync_info.db_user; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.db_user IS '用户名，用于dblink连接';


--
-- Name: COLUMN tb_network_sync_info.db_password; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.db_password IS '密码，用于创建dblink连接';


--
-- Name: COLUMN tb_network_sync_info.table_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.table_name IS '要同步的表名';


--
-- Name: COLUMN tb_network_sync_info.last_sync_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.last_sync_time IS '该表最近更新时间';


--
-- Name: COLUMN tb_network_sync_info.last_read_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_network_sync_info.last_read_time IS '记录最近一次发送数据到同步中心的时间';


--
-- Name: tb_pull_id; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_pull_id (
    pull_id uuid NOT NULL,
    pull_generate_time timestamp without time zone,
    pull_access_time timestamp without time zone,
    pull_system_name text DEFAULT 'unkown'::text NOT NULL
);


ALTER TABLE tb_pull_id OWNER TO admin;

--
-- Name: TABLE tb_pull_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_pull_id IS '允许的pull id';


--
-- Name: COLUMN tb_pull_id.pull_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_pull_id.pull_id IS '允许的id';


--
-- Name: COLUMN tb_pull_id.pull_generate_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_pull_id.pull_generate_time IS '生成时间';


--
-- Name: COLUMN tb_pull_id.pull_access_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_pull_id.pull_access_time IS '最后访问时间';


--
-- Name: COLUMN tb_pull_id.pull_system_name; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_pull_id.pull_system_name IS '外部系统名';


--
-- Name: tb_push_record; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_push_record (
    push_id uuid NOT NULL,
    pull_id uuid NOT NULL,
    push_content bytea,
    push_start_time timestamp without time zone,
    push_finish_time timestamp without time zone,
    push_type smallint DEFAULT 3 NOT NULL,
    record_write_time timestamp with time zone DEFAULT now() NOT NULL,
    record_former_db_id uuid DEFAULT '0c9517a4-6066-45b6-83e4-38ff07cfeaf0'::uuid NOT NULL,
    push_msg_type integer DEFAULT 0 NOT NULL,
    push_alone_type integer DEFAULT 1 NOT NULL
);


ALTER TABLE tb_push_record OWNER TO admin;

--
-- Name: TABLE tb_push_record; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_push_record IS '推送记录表';


--
-- Name: COLUMN tb_push_record.push_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_id IS '推送ID';


--
-- Name: COLUMN tb_push_record.pull_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.pull_id IS '推给的id';


--
-- Name: COLUMN tb_push_record.push_content; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_content IS '推送消息';


--
-- Name: COLUMN tb_push_record.push_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_start_time IS '开始推送时间';


--
-- Name: COLUMN tb_push_record.push_finish_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_finish_time IS '推送完成时间';


--
-- Name: COLUMN tb_push_record.push_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_type IS 'ios 2, android 3';


--
-- Name: COLUMN tb_push_record.record_write_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.record_write_time IS '记录写入时间，该时间类型带时区，精度为 1/14 毫秒';


--
-- Name: COLUMN tb_push_record.record_former_db_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.record_former_db_id IS '记录本条数据最开始是记录在哪个数据库的，用于集群同步，该数据库的信息可以查看 主数据库的 tb_network_sync_info 表';


--
-- Name: COLUMN tb_push_record.push_msg_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_msg_type IS '业务服务与app协商类型，推送服务只存储用数类型消息计数';


--
-- Name: COLUMN tb_push_record.push_alone_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record.push_alone_type IS '1代表可被计数
2代表不可计数，必须单独推送';


--
-- Name: tb_push_record_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_push_record_history (
    push_id uuid NOT NULL,
    pull_id uuid NOT NULL,
    push_content bytea,
    push_start_time timestamp without time zone,
    push_finish_time timestamp without time zone,
    push_type smallint DEFAULT 3 NOT NULL,
    record_write_time timestamp with time zone DEFAULT now() NOT NULL,
    record_former_db_id uuid DEFAULT '0c9517a4-6066-45b6-83e4-38ff07cfeaf0'::uuid NOT NULL,
    push_msg_type integer DEFAULT 0 NOT NULL,
    push_alone_type integer DEFAULT 1 NOT NULL
);


ALTER TABLE tb_push_record_history OWNER TO admin;

--
-- Name: TABLE tb_push_record_history; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_push_record_history IS '推送记录表';


--
-- Name: COLUMN tb_push_record_history.push_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_id IS '推送ID';


--
-- Name: COLUMN tb_push_record_history.pull_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.pull_id IS '推给的id';


--
-- Name: COLUMN tb_push_record_history.push_content; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_content IS '推送消息';


--
-- Name: COLUMN tb_push_record_history.push_start_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_start_time IS '开始推送时间';


--
-- Name: COLUMN tb_push_record_history.push_finish_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_finish_time IS '推送完成时间';


--
-- Name: COLUMN tb_push_record_history.push_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_type IS 'ios:2  android:3';


--
-- Name: COLUMN tb_push_record_history.record_write_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.record_write_time IS '记录写入时间，该时间类型带时区，精度为 1/14 毫秒';


--
-- Name: COLUMN tb_push_record_history.record_former_db_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.record_former_db_id IS '记录本条数据最开始是记录在哪个数据库的，用于集群同步，该数据库的信息可以查看 主数据库的 tb_network_sync_info 表';


--
-- Name: COLUMN tb_push_record_history.push_msg_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_msg_type IS '业务服务与app协商类型，推送服务只存储用数类型消息计数';


--
-- Name: COLUMN tb_push_record_history.push_alone_type; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_record_history.push_alone_type IS '1代表可被计数
2代表不可计数，必须单独推送';


--
-- Name: tb_push_server; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_push_server (
    server_id uuid NOT NULL,
    wan_server_ip text NOT NULL,
    wan_server_port integer NOT NULL,
    conn_num integer DEFAULT 0 NOT NULL,
    last_update_time timestamp without time zone NOT NULL,
    lan_server_ip text NOT NULL,
    lan_server_port integer NOT NULL
);


ALTER TABLE tb_push_server OWNER TO admin;

--
-- Name: TABLE tb_push_server; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON TABLE tb_push_server IS '推送服务信息';


--
-- Name: COLUMN tb_push_server.server_id; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.server_id IS '服务器id';


--
-- Name: COLUMN tb_push_server.wan_server_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.wan_server_ip IS '服务器公网ip';


--
-- Name: COLUMN tb_push_server.wan_server_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.wan_server_port IS '服务公网端口';


--
-- Name: COLUMN tb_push_server.conn_num; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.conn_num IS '连接数';


--
-- Name: COLUMN tb_push_server.last_update_time; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.last_update_time IS '最后更新时间';


--
-- Name: COLUMN tb_push_server.lan_server_ip; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.lan_server_ip IS '服务内网ip';


--
-- Name: COLUMN tb_push_server.lan_server_port; Type: COMMENT; Schema: public; Owner: admin
--

COMMENT ON COLUMN tb_push_server.lan_server_port IS '服务内网port';


--
-- Name: tb_test; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_test (
    pull_id uuid NOT NULL,
    pull_generate_time timestamp without time zone,
    pull_access_time timestamp without time zone,
    pull_ip inet NOT NULL,
    pull_ip1 inet,
    version bigint NOT NULL,
    record_write_time timestamp with time zone,
    record_former_db_id uuid DEFAULT '4edbcb10-1ccb-4724-96e0-873447bf82ab'::uuid
);


ALTER TABLE tb_test OWNER TO admin;

--
-- Name: tb_test_dblink; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE tb_test_dblink (
    t_str text NOT NULL
);


ALTER TABLE tb_test_dblink OWNER TO admin;

--
-- Name: tb_apple_message_badge_info tb_apple_message_badge_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_apple_message_badge_info
    ADD CONSTRAINT tb_apple_message_badge_info_pkey PRIMARY KEY (userid);


--
-- Name: tb_ip_area_info tb_ip_area_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_ip_area_info
    ADD CONSTRAINT tb_ip_area_info_pkey PRIMARY KEY (ip_start_point);


--
-- Name: tb_network_sync_info tb_network_sync_info_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_network_sync_info
    ADD CONSTRAINT tb_network_sync_info_pkey PRIMARY KEY (db_tb_id);


--
-- Name: tb_pull_id tb_pull_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_pull_id
    ADD CONSTRAINT tb_pull_ids_pkey PRIMARY KEY (pull_id);


--
-- Name: tb_push_record_history tb_push_record_history_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_push_record_history
    ADD CONSTRAINT tb_push_record_history_pkey PRIMARY KEY (push_id);


--
-- Name: tb_push_record tb_push_records_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_push_record
    ADD CONSTRAINT tb_push_records_pkey PRIMARY KEY (push_id);


--
-- Name: tb_push_server tb_push_servers_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_push_server
    ADD CONSTRAINT tb_push_servers_pkey PRIMARY KEY (server_id);


--
-- Name: tb_test_dblink tb_test_dblink_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_test_dblink
    ADD CONSTRAINT tb_test_dblink_pkey PRIMARY KEY (t_str);


--
-- Name: tb_test tb_test_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_test
    ADD CONSTRAINT tb_test_pkey PRIMARY KEY (pull_id);


--
-- Name: fki_tb_push_record_pull_id_fkey; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX fki_tb_push_record_pull_id_fkey ON tb_push_record USING btree (pull_id);


--
-- Name: tb_push_record anticollision_insert; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER anticollision_insert BEFORE INSERT ON tb_push_record FOR EACH ROW EXECUTE PROCEDURE insert_trigger_for_sync_tb_push_record();


--
-- Name: tb_push_record for_sync_update; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER for_sync_update BEFORE UPDATE ON tb_push_record FOR EACH ROW EXECUTE PROCEDURE update_trigger_for_sync_tb_push_record();


--
-- Name: tb_push_record record_delete; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER record_delete AFTER DELETE ON tb_push_record FOR EACH ROW EXECUTE PROCEDURE save_record_history();


--
-- Name: tb_area_server tb_area_server_server_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY tb_area_server
    ADD CONSTRAINT tb_area_server_server_id_fkey FOREIGN KEY (server_id) REFERENCES tb_push_server(server_id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: tb_push_record; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_push_record FROM PUBLIC;
REVOKE ALL ON TABLE tb_push_record FROM admin;
GRANT ALL ON TABLE tb_push_record TO admin;


--
-- Name: tb_push_record_history; Type: ACL; Schema: public; Owner: admin
--

REVOKE ALL ON TABLE tb_push_record_history FROM PUBLIC;
REVOKE ALL ON TABLE tb_push_record_history FROM admin;
GRANT ALL ON TABLE tb_push_record_history TO admin;


--
-- PostgreSQL database dump complete
--

