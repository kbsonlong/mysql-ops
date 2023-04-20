#!/bin/bash

ADMIN_USER=root
ADMIN_PASSWD=123456
REPLICE_USER=slave
REPLICE_PASSWD=slavepass

MASTER_HOST=10.90.208.190
MASTER_PORT=6300
SLAVE_HOST=10.90.208.190
SLAVE_PORT=6302

# 检测实例是否正常启动
check_liveness() {
    if ! mysqladmin -u${ADMIN_USER} -p${ADMIN_PASSWD}  -h "$1" -P "$2" ping|grep 'mysqld is alive' >/dev/null 2>&1; then
        # if [ "$?" != 0 ]; then
        echo "MySQL isn't live!!"
        exit 1
    fi
}

# 创建主从同步用户
create_replice_user() {
    GRANT_SQL="GRANT SELECT, RELOAD, SUPER, REPLICATION SLAVE, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'slave'@'%';"
    CREATE_USER_SQL="CREATE USER \"${REPLICE_USER}\" IDENTIFIED BY \"${REPLICE_PASSWD}\";"
    tmpuser=$(mysql -u${ADMIN_USER} -p${ADMIN_PASSWD}  -h "$1" -P "$2" -N <<EOT
select user from mysql.user where user="$REPLICE_USER" and host="%" limit  1;
EOT
)

    if [[ $tmpuser != "${REPLICE_USER}" ]]; then
        if ! mysql -u${ADMIN_USER} -p${ADMIN_PASSWD} -e "${CREATE_USER_SQL}" -h "$1" -P "$2" >/dev/null 2>&1; then
            # if [ "$?" != 0 ]; then
            echo "Master Create Replice User failed with error: ${CREATE_USER_SQL}"
            exit 1
        fi

        if ! mysql -u"${ADMIN_USER}" -p"${ADMIN_PASSWD}" -e "${GRANT_SQL}" -h "$1" -P "$2" >/dev/null 2>&1; then
            # if [ "$?" != 0 ]; then
            echo "Master Grant Replice User failed with error: ${GRANT_SQL}"
            exit 1
        fi
    else
        echo "${REPLICE_USER}" already exists
    fi

}

# 创建主从同步
create_replice() {
    # 获取 Master 信息
    if ! mysql -u${ADMIN_USER} -p${ADMIN_PASSWD} -h ${MASTER_HOST} -P ${MASTER_PORT} -e "SHOW MASTER STATUS\G" >master.info; then
        # if [ "$?" != 0 ]; then
        echo "SHOW MASTER STATUS Failed!!"
        exit 1
    fi

    MASTER_LOG_FILE=$(grep File master.info | awk -F ':' '{print $2}' | sed 's/[ \t]*$//g' | sed 's/^[ \t]*//g')
    MASTER_LOG_POS=$(grep Position master.info | awk -F ':' '{print $2}' | sed 's/[ \t]*$//g' | sed 's/^[ \t]*//g')

    read -r -d '' REPLICATION_SQL <<-EOF
    CHANGE MASTER TO MASTER_HOST="${MASTER_HOST}",
    MASTER_PORT=${MASTER_PORT},
    MASTER_USER="${REPLICE_USER}",
    MASTER_PASSWORD="${REPLICE_PASSWD}",
    MASTER_LOG_FILE="${MASTER_LOG_FILE}",
    MASTER_LOG_POS=${MASTER_LOG_POS};
EOF

    echo "${REPLICATION_SQL}"
    mysql -u${ADMIN_USER} -p${ADMIN_PASSWD} -h ${SLAVE_HOST} -P ${SLAVE_PORT} -e "${REPLICATION_SQL}"
    mysql -u${ADMIN_USER} -p${ADMIN_PASSWD} -h ${SLAVE_HOST} -P ${SLAVE_PORT} -e "start slave;"
    mysql -u${ADMIN_USER} -p${ADMIN_PASSWD} -h ${SLAVE_HOST} -P ${SLAVE_PORT} -e "show slave status\G" >slave.info
    cat slave.info

}

check_liveness ${MASTER_HOST} ${MASTER_PORT}

check_liveness ${SLAVE_HOST} ${SLAVE_PORT}

create_replice_user ${MASTER_HOST} ${MASTER_PORT}

create_replice


#!/bin/bash

echo original parameters=[$@]

#-o或--options选项后面是可接受的短选项，如ab:c::，表示可接受的短选项为-a -b -c，
#其中-a选项不接参数，-b选项后必须接参数，-c选项的参数为可选的
#-l或--long选项后面是可接受的长选项，用逗号分开，冒号的意义同短选项。
#-n选项后接选项解析错误时提示的脚本名字
ARGS=$(getopt -o h,p,u,P --long master_host:,master_port:,master_user:,master_password:,slave_host:,slave_port:,--help -n "$0" -- "$@")
if [ $? != 0 ]; then
    echo "Terminating..."
    exit 1
fi

echo ARGS=[$ARGS]
#将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"
echo formatted parameters=[$@]

while true
do
    case "$1" in
        -h | --master_host)
            MASTER_HOST="$2"
            shift 2
            ;;
        -p | --master_port)
            echo "Option master_port, argument $2";

            shift 2
            ;;
        -u | --master_user)
            echo "Option master_user, argument $2";
            ADMIN_USER="$2"
            shift 2
            ;;
        -P | --master_password)
            echo "Option master_passwordb argument $2";
            shift 2
            ;;
        --replice_user)
            echo "Option replice_user, argument $2";
            shift 2
            ;;
        --replice_password)
            echo "Option replice_password argument $2";
            shift 2
            ;;
        --slave_host)
            echo "Option slave_host, argument $2";
            shift 2
            ;;
        --slave_port)
            echo "Option slave_host, argument $2";
            shift 2
            ;;
        --)
            help
            shift
            break
            ;;
        *)
            help
            exit 1
            ;;
    esac
done


help() {
    echo -e "Usage: $0 [OPTION]"
    echo -e "Options:"
    echo -e "-h localhost, --master_host=localhost, Master主节点地址"
    echo -e "-p 3306, --master_port=3306, Master主节点端口"
    echo -e "--master_user=root, Master节点管理用户,创建同步用户使用"
    echo -e "--master_password=123456, Master节点管理用户密码,创建同步用户使用"
    echo -e "--replice_user=slave, Master节点同步用户使用"
    echo -e "--replice_password=slavepass, Master节点同步用户密码"
    echo -e "--slave_host=127.0.0.1, Slave节点地址"
    echo -e "--slave_port=3307, Slave节点地址"
    echo -e " --help [OPTION]"
}

ADMIN_USER=root
ADMIN_PASSWD=123456
REPLICE_USER=slave
REPLICE_PASSWD=slavepass

MASTER_HOST=10.90.208.190
MASTER_PORT=6300
SLAVE_HOST=10.90.208.190
SLAVE_PORT=6302