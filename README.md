# shell-scripts

```
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
```

# 案例
`[root@elk-7-41 src]# echo 10.4.7.4{0..5} 10.4.7.10{0..5} | xargs -n 1 > ip.txt`
## Ping模块
`[root@elk-7-41 src]# scan_host.sh ping ip.txt -f 10  # 以10个并发进程镜像探测`

## push模块，推文件或者目录
```
[root@elk-7-41 src]# scan_host.sh push -h 10.4.7.42 10.4.7.101 10.4.7.103 jdk-1.8.tar.gz apollo-* /tmp/ # 推文件
10.4.7.42	  jdk-1.8.tar.gz apollo-adminservice-1.5.1-github.zip apollo-configservice-1.5.1-github.zip apollo-portal-1.5.1-github.zip --> /tmp/ Y
10.4.7.101	  jdk-1.8.tar.gz apollo-adminservice-1.5.1-github.zip apollo-configservice-1.5.1-github.zip apollo-portal-1.5.1-github.zip --> /tmp/ Y
10.4.7.103	  jdk-1.8.tar.gz apollo-adminservice-1.5.1-github.zip apollo-configservice-1.5.1-github.zip apollo-portal-1.5.1-github.zip --> /tmp/ Y
```
## pull模块，拉文件
```
[root@elk-7-41 src]# echo '10.4.7.42 10.4.7.101 10.4.7.103 #10.4.7.43' | xargs -n 1 > ip.list
[root@elk-7-41 src]# scan_host.sh pull ip.list /etc/yum.repos.d /etc/passwd xxx  # 拖文件
10.4.7.101	 yum.repos.d passwd --> xxx SUCCESS
10.4.7.103	 yum.repos.d passwd --> xxx SUCCESS
10.4.7.42	 yum.repos.d passwd --> xxx SUCCESS
```

## cpu模块，扫描CPU信息
```
[root@elk-7-41 src]# scan_host.sh cpu ip.list  # CPU信息
IP_Address 	CPU(s)   load average(total)         R/Total        usr     sys     iowait  irq     soft    idle
10.4.7.101	2        0.00    0.01    0.05        1/97           0.0     0.0     0.0     0.0     0.0     100.0  
10.4.7.103	2        0.00    0.01    0.05        1/97           0.0     0.0     0.0     0.0     0.0     100.0  
10.4.7.42	1        0.00    0.02    0.05        1/92           0.0     0.0     0.0     0.0     0.0     100.0
```

## cmd模块，执行命令
```
[root@elk-7-41 src]# scan_host.sh cmd ip.list "yum install -q -y httpd && systemctl start httpd && systemctl enable httpd"
10.4.7.103
Created symlink from /etc/systemd/system/multi-user.target.wants/httpd.service to /usr/lib/systemd/system/httpd.service.
10.4.7.42
Created symlink from /etc/systemd/system/multi-user.target.wants/httpd.service to /usr/lib/systemd/system/httpd.service.
10.4.7.101
Created symlink from /etc/systemd/system/multi-user.target.wants/httpd.service to /usr/lib/systemd/system/httpd.service.
[root@elk-7-41 src]# scan_host.sh cmd ip.list "netstat -lntp|grep 80"
10.4.7.42
tcp6       0      0 :::80                   :::*                    LISTEN      10339/httpd         
10.4.7.101
tcp6       0      0 :::80                   :::*                    LISTEN      2050/httpd          
10.4.7.103
tcp6       0      0 :::80                   :::*                    LISTEN      1903/httpd          
```
