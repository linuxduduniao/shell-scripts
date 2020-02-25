#!/bin/bash

### 参数处理
OPTIONS(){
    # 开始处理module参数
    if [[ $1 =~ ^(port|cmd|pull|push|ping|mount|cpu)$ ]];then
        MODULE=$(echo $1 | tr 'a-z' 'A-Z') ; shift
    else
        USAGE ; exit
    fi

    # 开始处理IP地址参数
    if [[ $1 == "-i" && -f $2 ]];then
        IP_LIST=$2 ; shift ; shift
    elif [[ $1 != "-i" && $1 != "-h" && -f $1 ]];then
        IP_LIST=$1 ; shift
    elif [[ $1 == "-h" && $2 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]];then
        shift ; IP_LIST=".$$.ip.list"; [ -f $IP_LIST ] && rm -f $IP_LIST
        while :
        do
            echo $1 >> $IP_LIST ; shift
            [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || break
        done
    else
        USAGE;exit
    fi
    
    # 开始处理Options;为了避免脚本使用过多的选项和降低脚本的复杂性，此处不采用 getopts 和 getopt.
    if [[ $1 == "-f" && $2 =~ ^[0-9]+$ ]];then
        FORK_NUM=$2 ; shift ; shift
    elif [[ $1 == "-u" && ! -z $2 ]];then
        SSH_USER=$2 ; shift ; shift 
    fi

    if [[ $1 == "-u" && ! -z $2 ]];then
        SSH_USER=$2 ; shift ; shift 
    elif [[ $1 == "-f" && $2 =~ ^[0-9]+$ ]];then
        FORK_NUM=$2 ; shift ; shift
    fi

    [ -z $FORK_NUM ] && FORK_NUM=5
    [ -z $SSH_USER ] && SSH_USER=$USER

    # 开始执行脚本，如果需要的话，可以考虑加 trap 捕捉kill命令，用于删除可能存在的临时文件 .$$.ip.list
    FORK
    $MODULE $@
    exec 996>&-
    [ -f .$$.ip.list ] && rm -f .$$.ip.list
}

FORK(){
    # 控制并发数，默认为5
    mkfifo /tmp/$$.fifo
    exec 996<>/tmp/$$.fifo
    rm -f /tmp/$$.fifo
    for i in $(seq $FORK_NUM); do echo >&996 ;done
}

PING(){
    # ping模块，使用ping命令实现，如果失败返回 DOWN，否则UPPER
    echo "IP  status"|tr " " "\t"
    for i in $(cat $IP_LIST|grep -v '#')
    do
        read -u 996
        {
            ping -c 1 -w 2 $i >/dev/null 2>&1 && echo -e "$i\tUPPER" || echo -e "\e[47;31m$i\tDOWN\e[0m"
            echo >&996
        } &
    done
    wait
}

# CPU 信息
CPU(){
    echo -e "IP_Address \tCPU(s)   load average(total)         R/Total        usr     sys     iowait  irq     soft    idle"
    for i in $(cat $IP_LIST|grep -v '#')
    do
        read -u 996
        {
            ping -c 1 -w 2 $i >/dev/null 2>&1 
            [ $? -ne 0 ] && echo -e "\e[47;31m$i\tDOWN\e[0m" && echo >&996 && continue
            ssh -o "StrictHostKeyChecking no" ${SSH_USER}@$i "echo -ne \"$i\t\";awk '/processor/{sum+=1}END{printf \"%-9s\",sum}' /proc/cpuinfo; top -b -d 1 -n 2|grep -E '^(top|Task|%?Cpu)'|tail -n 3|sed 's/%/ /g;s/%/ /g;s/,/ /g'|awk '{if(NR==1) printf \"%7-s %7-s %12-s\",\$(NF-2),\$(NF-1),\$NF;if(NR==2) printf \"%-15s\",\$4\"/\"\$2;if(NR==3) printf \"%-7s %-7s %-7s %-7s %-7s %-7s\n\",\$2,\$4,\$10,\$12,\$14,\$8}'" 2>&1 | grep -v 'Authorized'
            echo >&996
        } &
    done
    wait
}

# 推文件
PUSH(){
    ## 确认本地文件和远程主机目录
    [ $# -lt 2 ] && USAGE && exit || FILES=''
    for file in $@
    do
        [ $# -ge 2 ] && FILES="$FILES $1" && shift || REMOTE_DIR=$1
    done
    ###
    for i in $(cat $IP_LIST|grep -v '#')
    do
        read -u 996
        {
            ping -c 1 -w 2 $i >/dev/null 2>&1 
            [ $? -ne 0 ] && echo -e "\e[47;31m$i\tDOWN\e[0m" && echo >&996 && continue
            scp -o "StrictHostKeyChecking no" -r $FILES ${SSH_USER}@$i:$REMOTE_DIR >/dev/null 2>&1 && echo -e "$i\t $FILES --> $REMOTE_DIR Y" || echo -e "\e[47;31m$i\t $FILES --> $REMOTE_DIR N\e[0m"|tr " " "\t"
            echo >&996
        } &
    done
    wait
}

# 拉文件
PULL(){
    [ $# -lt 2 ] && USAGE && exit
    for file in $@
    do
        [[ $# -ge 2 && -z $FILES ]] && FILES="$1" && shift && continue
        [[ $# -ge 2 ]] && FILES="$FILES,$1" && shift && continue
        LOCAL_DIR=$1
        [[ -e $LOCAL_DIR && ! -d $LOCAL_DIR ]] && echo "$LOCAL_DIR isn't a directory!" && USAGE && exit
        [[ ! -e $LOCAL_DIR ]] && mkdir -p $LOCAL_DIR
        
        REMOTE_FILES=$(echo $FILES|tr ',' '\n'|awk -F'/' '{print $NF}'|xargs )
        REMOTE_FILES_COUNTS=$(echo $FILES|tr ',' '\n'|wc -l)
    done
    for i in $(cat $IP_LIST|grep -v '#')
    do
        read -u 996
        {
            ping -c 1 -w 2 $i >/dev/null 2>&1 
            [ $? -ne 0 ] && echo -e "\e[47;31m$i\tDOWN\e[0m" && echo >&996 && continue
            [ -e $LOCAL_DIR/$i/ ] || mkdir $LOCAL_DIR/$i/
            if [ $REMOTE_FILES_COUNTS -eq 1 ];then
                scp -r -o "StrictHostKeyChecking no" ${SSH_USER}@$i:$FILES $LOCAL_DIR/$i/ >/dev/null 2>&1 && echo -e "$i\t $REMOTE_FILES --> $LOCAL_DIR SUCCESS" || echo -e "$i\t $REMOTE_FILES --> $LOCAL_DIR \e[47;31mFAILED\e[0m"
            else
                scp -r -o "StrictHostKeyChecking no" ${SSH_USER}@$i:{$FILES} $LOCAL_DIR/$i/ >/dev/null 2>&1 && echo -e "$i\t $REMOTE_FILES --> $LOCAL_DIR SUCCESS" || echo -e "$i\t $REMOTE_FILES --> $LOCAL_DIR \e[47;31mFAILED\e[0m"
            fi
            echo >&996
        } &
    done
    wait
}

# 远程执行命令
CMD(){
    CMDS=$@
    for i in $(cat $IP_LIST|grep -v '#')
    do
        read -u 996
        {
            ping -c 1 -w 2 $i >/dev/null 2>&1 
            [ $? -ne 0 ] && echo -e "\e[47;31m$i\tDOWN\e[0m" && echo >&996 && continue
            ssh -o "StrictHostKeyChecking no" ${SSH_USER}@$i "echo $i >/tmp/$$.log;chmod 666 /tmp/$$.log ; ($CMDS) >>/tmp/$$.log 2>&1 ; cat /tmp/$$.log ; rm -f /tmp/$$.log " 2>&1 | grep -v 'Authorized'
            echo >&996
        } &
    done
    wait
}

# 扫描端口
PORT(){
    :
}

# 扫描挂载信息
MOUNT(){
    :
}

USAGE(){
cat << EOF
该脚本是基于ssh通道完成命令的批量执行，批量推文件和拉文件。可以根据自己的业务需求编写模块，提高批处理效率。
当前脚本没有提供输入密码的选项，适合在打通了ssh通道的跳板机操作
Usage: 
    scan_host.sh module ([-i] ip_list_file|-h ip1 ip2 ...) [-u ssh_user] [-i fork_num] [args]
    module: 模块函数名称，默认支持: cmd,ping,push,pull
    -i: 指定ip地址列表文件，脚本会自动剔除包含 # 的行
    -h: 指定IP地址列表，可指定多个
    -u: 指定ssh远程登陆的用户
    -i: 指定并发数，默认为5
    args: 参数
Example:
    scan_host.sh ping ip.list  # 从ip.list中取出非注释行的IP地址，执行ping模块
    scan_host.sh cmd -h ip1 ip2 ip3 "commands"  # 批量执行命令
    scan_host.sh cmd ip.txt -f 1 "commands"  # 串行执行执行命令
    scan_host.sh push ip.list local_dir|local_file [local_dir|local_file] [local_dir|local_file] remote_dir # 推文件
    scan_host.sh pull ip.list remote_dir|remote_file  [remote_dir|remote_file] [remote_dir|remote_file] local_dir # 拉文件，Local_dir不存在会自动创建
EOF
}

OPTIONS $@
