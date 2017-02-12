# Docker swarm demo

## Prerequire

- [vagrant](https://www.vagrantup.com/)

## Vagrant command

- Create: `vagrant up`
- Destroy: `vagrant destroy`
- Status: `vagrat status`
- Connect: `vagrant ssh core-01`

## Virtual Box Info

- core-01(manager) / 172.17.8.101 / 1 cpu / 1G memory
- core-02(worker) / 172.17.8.102 / 1 cpu / 1G memory
- core-03(worker) / 172.17.8.103 / 1 cpu / 1G memory

## Create swarm cluster

- 1 manager & 2 workers

**manager**

```sh
docker swarm init --advertise-addr 172.17.8.101
```

**workers**

```sh
docker swarm join \
    --token xxxx \
    172.17.8.101:2377
```

**manager**

```sh
docker node ls
```

output:

```
ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
4ld9enwqy44akwon8pxgipwhj    core-03   Ready   Active
kc59j9oq87b0go6zc5didbgzg    core-02   Ready   Active
wzbde2rgmunh78fnr1m5u64hj *  core-01   Ready   Active        Leader
```

**config files**

/var/lib/docker/swarm

## Demo

### Basic Web Application

- Simple standalone web application
- Ingress network / Route mesh
- Scale up
- HEALTHCHECK (subicura/whoami:1 - no healthcheck, subicura/whoami:2 - healthcheck)

**run**

```sh
# run
docker service create --name whoami \
  -p 4567:4567 \
  subicura/whoami:1

# test
while true; do
  curl 172.17.8.101:4567
  echo "\n---"
  sleep 1
done

# check
docker service ls
docker service ps whoami
docker service logs -f whoami

# scale up
docker service scale whoami=5

# update image
docker service update --update-parallelism 3 --image subicura/whoami:2 whoami
docker service scale whoami=1
docker service scale whoami=5
```

**cleanup**

```sh
docker service rm whoami
```

### Visit Count Web Application

- Run web application with redis
- Overlay network
- Replication
- DNS
- Mount option in service

**network**

```sh
docker network create --attachable --driver overlay backend
docker network ls
```

output:

```
NETWORK ID          NAME                DRIVER              SCOPE
uv96b2uo19p5        backend             overlay             swarm
df65301199f1        bridge              bridge              local
baf918b16109        docker_gwbridge     bridge              local
97d4f5826494        host                host                local
u7dt1gxv9d8g        ingress             overlay             swarm
b19c267a6bdc        none                null                local
```

**redis**

```sh
# run
docker service create --name redis \
  --network=backend \
  --mount "type=bind,source=/shared/redis,target=/data" \
  redis \
  redis-server --appendonly yes

# test
docker run --rm -it \
  --network=backend \
  alpine \
  telnet redis 6379

KEYS *
SET hello world
GET hello
DEL hello

# check
docker service ls
docker service ps redis
docker service logs -f redis
```

**counter web**

```sh
# run
docker service create --name counter \
  --network=backend \
  --replicas 3 \
  -e REDIS_HOST=redis \
  -p 4568:4567 \
  subicura/counter

# test
docker run --rm -it \
  --network=backend \
  alpine \
  /bin/sh

ping counter
ping tasks.counter
apk add --update bind-tools
dig counter
dig tasks.counter

while true; do
  curl 172.17.8.101:4568
  echo "\n---"
  sleep 1
done

# check
docker service ls
docker service ps counter
docker service logs -f counter
```

**cleanup**

```sh
docker service rm redis
docker service rm counter
```

### Secret Web Application

- use secret

**secret**

```sh
echo "this is my password!" | docker secret create my-password -
```

**secret web**

```sh
# run
docker service create --name secret \
  --secret my-password \
  -p 4569:4567 \
  -e SECRET_PATH=/run/secrets/my-password \
  subicura/secret

# test
curl 172.17.8.101:4569

# check
docker service ls
docker service ps secret
docker service logs -f secret
```

**cleanup**

```sh
docker service rm secret
```

### Web Application Discovery by Traefik

- service create constraint
- portainer app

**/etc/hosts**

```
172.17.8.101 portainer.local.dev counter.local.dev
```

**network**

```sh
docker network create --attachable --driver overlay frontend
```

**traefic**

```sh
#run
docker service create --name traefik \
  --constraint 'node.role == manager' \
  -p 80:80 \
  -p 8080:8080 \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --network frontend \
  traefik \
  --docker \
  --docker.swarmmode \
  --docker.domain=local.dev \
  --docker.watch \
  --web

# test
open http://172.17.8.101:8080/

# check
docker service ls
docker service ps traefik
docker service logs -f traefik
```

**portainer**

```sh
# run
docker service create --name portainer \
  --network=frontend \
  --label traefik.port=9000 \
  --constraint 'node.role == manager' \
  --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
  portainer/portainer

# check
docker service ls
docker service ps portainer
docker service logs -f portainer
```

**counter**

> Replicate bug not yet resolved! Do not use in production.

- Add network=frontend
- Add label traefik.port=4567
- Remove -p

```sh
docker service rm counter

docker service create --name counter \
  --network=frontend \
  --network=backend \
  --replicas 3 \
  --label traefik.port=4567 \
  -e REDIS_HOST=redis \
  subicura/counter
```

**cleanup**

```sh
# remove
docker service rm traefik
# remove
docker service rm portainer
```

### Monitoring

- docker stack

```sh
docker stack deploy --compose-file ./docker-compose.yml prometheus-stack
```
