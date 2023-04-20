#!/bin/bash
# 检测目标端口连接数
# 隔离服务
# 实例下线

# 目标实例端口
dst_port=6300
# 隔离时间
ticket=30
# 抓包临时路径
packet_file="/tmp/packet_${dst_port}.cap"

packet_capture() {
    echo "Starting Tcpdump Captured"
    timeout ${ticket} tcpdump -v -W 1 -G ${ticket} -i any dst port ${dst_port} > ${packet_file} 2>1
    # 统计连接数
    conn_count=$(grep ${dst_port} -c ${packet_file})
    echo "${conn_count}"
    grep "${dst_port}" ${packet_file} |awk '{print $1}'|sed 's/\./:/4'
}

packet_capture