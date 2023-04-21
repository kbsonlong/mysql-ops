#!/bin/bash

init() {
    port=$1
    # 初始化目录结构
    mkdir -p /data/services/mysql-${port}/{base,data,log,binlog,conf}

    # 在MySQL官方镜像中用户mysql的uid和gid是999,要对目录授权，不然没有权限写入
    chown 999.999 /data/services/mysql-${port} -R

    cat <<EOF >/data/services/mysql-${port}/docker-compose.yaml
version: "3.8"
services:
  mysql-${port}:
    container_name: mysql-${port}
    image: mysql:5.7
    restart: unless-stopped
    network_mode: "host"
    environment:
      - MYSQL_ROOT_PASSWORD=123456
    volumes:
      - /data/services/mysql-${port}/base:/data/services/mysql-${port}/base
      - /data/services/mysql-${port}/data:/data/services/mysql-${port}/data
      - /data/services/mysql-${port}/log:/data/services/mysql-${port}/log
      - /data/services/mysql-${port}/binlog:/data/services/mysql-${port}/binlog
      - /data/services/mysql-${port}/conf/my.cnf:/etc/mysql/my.cnf
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 10G
EOF

    cat <<EOF >/data/services/mysql-630${port}/conf/my.cnf
[client]
port = ${port}
socket = /data/services/mysql-${port}/base/mysql_${port}.sock
default-character-set = utf8mb4

[mysqld]
open_files_limit = 65535
sql_mode = NO_ENGINE_SUBSTITUTION
port = ${port}
#basedir = /data/services/mysql-${port}/base
socket = /data/services/mysql-${port}/base/mysql_${port}.sock
pid-file = /data/services/mysql-${port}/base/mysql_${port}.pid
datadir = /data/services/mysql-${port}/data
tmpdir = /data/services/mysql-${port}/data
show_compatibility_56 = ON
binlog_rows_query_log_events = 1
slave_exec_mode = IDEMPOTENT
default_time_zone = +8:00
log_timestamps = SYSTEM
character-set-server = utf8mb4
key_buffer_size = 8M
max_allowed_packet = 128M
table_open_cache = 800
table_open_cache_instances = 4
innodb_buffer_pool_instances = 8
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
myisam_sort_buffer_size = 128M
thread_cache_size = 2000
query_cache_size = 0M
query_cache_type = 0
max_heap_table_size = 128M
bulk_insert_buffer_size = 64M
myisam_max_sort_file_size = 2G
#myisam_repair_threads = 1
user = mysql
max_connections = 500
max_connect_errors = 999999
slow_launch_time = 1
skip-name-resolve
init-connect = "insert into auditdb.accesslog values(null,connection_id(),now(),user(),current_user());"
log-error = /data/services/mysql-${port}/log/error.log
general_log_file = /data/services/mysql-${port}/log/general_log.log
binlog_format = row
max_binlog_cache_size = 512M
log_bin = /data/services/mysql-${port}/binlog/mysql-bin.log
relay_log = /data/services/mysql-${port}/binlog/mysql-relay-bin.log
max_binlog_size = 100M
log_slave_updates
expire_logs_days = 7
slow_query_log_file = /data/services/mysql-${port}/log/slow.log
slow_query_log = on
long_query_time = 1
server-id = 16280${port}
replicate_ignore_db = mysql
replicate_wild_ignore_table = mysql.%
slave_compressed_protocol = 1
binlog_ignore_db = auditdb
master_info_repository = TABLE
relay_log_info_repository = TABLE
transaction_isolation = READ-COMMITTED
core-file
innodb_data_home_dir = /data/services/mysql-${port}/data
innodb_data_file_path = ibdata1:100M:autoextend
innodb_log_group_home_dir = /data/services/mysql-${port}/data
innodb_buffer_pool_size = 3G
innodb_log_file_size = 256M
innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_files_in_group = 4
innodb_max_dirty_pages_pct = 90
innodb_open_files = 2000
innodb_doublewrite = 1
innodb_file_per_table
innodb_purge_batch_size = 1000
innodb_file_format = Barracuda
innodb_file_format_max = Barracuda
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_thread_concurrency = 16
innodb_purge_threads = 4
innodb_flush_method = O_DIRECT
innodb_undo_tablespaces = 4
innodb_undo_directory = /data/services/mysql-${port}/data
innodb_undo_log_truncate = 1
log_bin_trust_function_creators = 1
slave_skip_errors = 1062,1032
innodb_autoinc_lock_mode = 2
sync_binlog = 0
loose_secure_file_priv = 
loose_group_concat_max_len = 1M
loose_innodb_stats_on_metadata = 0
slave_rows_search_algorithms = INDEX_SCAN,HASH_SCAN

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
auto-rehash

[myisamchk]
key_buffer_size = 256M
sort_buffer_size = 256M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout
EOF
}

for port in {0..3}; do

    echo -e "\n-----630${port}------\n"
    init ${port}
    docker-compose -f /data/services/mysql-630${port}/docker-compose.yaml down

    rm -rf /data/services/mysql-630${port}/{base,binlog,data,log}/*

    docker-compose -f /data/services/mysql-630${port}/docker-compose.yaml up -d

    sleep 30

    mysql -p123456 -h127.0.0.1 -P630${port} -e "show master status;"

    mysql -p123456 -h127.0.0.1 -P630${port} -e "CREATE USER 'slave' IDENTIFIED BY '123456';"

    mysql -p123456 -h127.0.0.1 -P630${port} -e "GRANT SELECT, RELOAD, SUPER, REPLICATION SLAVE, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'slave'@'%';"

    mysql -p123456 -h127.0.0.1 -P630${port} -e "select user,host from mysql.user;"
    echo -e "\n-----------\n\n"

done

mysql -p123456 -h127.0.0.1 -P${port} -e "change master to master_host='10.90.208.190',master_user='slave',master_port=6301,master_password='123456',master_log_file='mysql-bin.000003',master_log_pos=154 for channel '6301'; start slave; show slave status\G;"
mysql -p123456 -h127.0.0.1 -P6302 -e "change master to master_host='10.90.208.190',master_user='slave',master_port=6301,master_password='123456',master_log_file='mysql-bin.000003',master_log_pos=154 for channel '6301'; start slave; show slave status\G;"

mysql -p123456 -h127.0.0.1 -P6301 -e "change master to master_host='10.90.208.190',master_user='slave',master_port=${port},master_password='123456',master_log_file='mysql-bin.000003',master_log_pos=154 for channel '${port}'; start slave; show slave status\G;"
mysql -p123456 -h127.0.0.1 -P6303 -e "change master to master_host='10.90.208.190',master_user='slave',master_port=${port},master_password='123456',master_log_file='mysql-bin.000003',master_log_pos=154 for channel '${port}'; start slave; show slave status\G;"

for port in {0..3}; do
    echo -e "\n-----630${port}------\n"
    mysql -p123456 -h127.0.0.1 -P630${port} -e " show slave status\G;"
    #mysql -p123456 -h127.0.0.1 -P630${port} -e "stop slave; reset slave;"
    echo -e "\n-----------\n\n"
done
