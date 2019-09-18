# dell_ipmi_fan_control

Dell服务器风扇控制脚本, 基于impi协议控制
* 测试硬件：DELL R720xd
* 测试环境：
  - CentOS 7
  - Ubuntu 16.04, Ubuntu 18.04

主要有以下几个特点：
1. 自动添加到 systemd 服务，自动启动，自动开机启动，守护进程，实时控制
2. 自动添加 cron 任务作为备用，两者不冲突，当服务启动失败时cron任务生效，每分钟检测一次
3. 单脚本执行，一劳永逸，不小心清空 crontab，不小心删掉自启动服务，只需重新执行一遍
4. 只支持使用 systemd 的发行版
