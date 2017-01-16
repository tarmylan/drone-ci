
## Gogs + Drone + docker + registry 自动构建镜像并推送到镜像仓库

#新建用户
```text
Gogs 默认以 git 用户运行（你应该也不会想一个能修改 ssh 配置的程序以 root 用户运行吧？）。
运行 sudo adduser git 新建好 git 用户。
su git 以 git 用户登录，到 git 用户的主目录中新建好 .ssh 文件夹。
```

## Gogs
[gos on github](https://github.com/gogits/gogs)

[Run in docker](https://github.com/gogits/gogs/tree/master/docker)

```text
# Pull image from Docker Hub.
$ docker pull gogs/gogs

# Create local directory for volume.
$ mkdir -p /data/gogs

# Use `docker run` for the first time.
$ docker run --name=gogs -d -p 10022:22 -p 80:3000 -v /data/gogs:/data gogs/gogs

# Use `docker start` if you have stopped it.
$ docker start gogs
```
容器启动后可以访问 http://serverIp 访问，先安装数据库，再执行页面安装

Install MySQL

```text
sudo apt-get update

sudo apt-get -y install mysql-server
```

```text
$ mysql -u root -p
> # （输入密码）
> create user 'gogs'@'%' identified by 'password';
> grant all privileges on gogs.* to 'gogs'@'%';
> flush privileges;
> exit;
```
如果出现远程无法访问，修改my.cnf注释 bind_address

Paste the following contents into the file, and save and close it.
vim gogs.sql
```text
DROP DATABASE IF EXISTS gogs;
CREATE DATABASE IF NOT EXISTS gogs CHARACTER SET utf8 COLLATE utf8_general_ci;
```

Finally, execute gogs.sql with MySQL to create the Gogs database. Replace your_password with the root password you chose earlier in this step.
```text
mysql -u gogs -pyour_password < gogs.sql
```

安装页面[参考](http://blog.hypriot.com/post/run-your-own-github-like-service-with-docker/)

## drone

使用MySQL做存储，先创建用户和数据库!

使用docker运行
```text
docker run -d \
    -e DRONE_GOGS=true \
    -e DRONE_GOGS_URL=http://serverIp \
    -e DRONE_SECRET=drone_secret \
    -e DRONE_OPEN=true \
    -e DATABASE_DRIVER=mysql \
    -e DRONE_DATABASE_DATASOURCE="git:passwd@tcp(serverIp:3306)/drone?parseTime=true" \
    -v /var/lib/drone:/var/lib/drone \
    -p 8000:8000 \
    --restart=always \
    --name=drone \
    drone/drone:0.5
```
启动后可以访问 http://serverIp:8000 使用gogs用户登陆,如果gogs 有仓库，即可在Account下查看

启动drone agent
```text
docker run -d \
    -e DRONE_SERVER=ws://172.17.0.1:8000/ws/broker \
    -e DRONE_SECRET=drone_secret \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart=always \
    --name=drone-agent \
    drone/drone:0.5 agent
```

## registry

启动registry
```text
docker run -d --name registry -e SETTINGS_FLAVOR=dev -e STORAGE_PATH=/tmp/registry -v /data/registry:/tmp/registry  -p 5000:5000 registry
```

## Test workspace
登陆gogs创建仓库 test

```text
test
    -- Dockerfile
    -- .drone.yml
    -- main.go
```

Dockerfile
```text
FROM local_registry_url/gliderlabs/alpine
COPY hello /usr/bin/
ENTRYPOINT /usr/bin/hello
EXPOSE 1234 
```

.drone.yml
```text
debug: true

workspace:
    base: /go 
        path: src/test

pipeline:    
    build:
        image: golang:1.8
        environment:
            - GOOS=linux
            - GOARCH=amd64
            - CGO_ENABLED=0
        commands:
            - go build -o hello .
    publish:
        image: plugins/docker
        registry: local_registry_url
        repo: local_registry_url/test/hello
        tag: latest
        file: Dockerfile
        insecure: true
        when:
            branch: master
```

main.go
```go
package main

import "fmt"

func main() {
    fmt.Println("Hello world")
}
```

把几个文件push 到gogs，drone 开始自动构建，并且把镜像push到本地的registry仓库
