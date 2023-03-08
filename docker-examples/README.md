How to use Docker to deploy Serverless PostgreSQL

1. Deploy storage broker (see file `docker-storagebroker.sh`)

```
docker run -d -t --name storagebroker --net=host \
  --entrypoint "storage_broker"  \
  perconalab/neon:pg14-1.0.0  -l 0.0.0.0:50051
```

2. Deploy safekeeper (or multiple), file `docker-safekeeper.sh`

```
docker run -d -t --name safekeeper1 --net=host \
  --entrypoint "safekeeper" \
  perconalab/neon:pg14-1.0.0 \
  --id=1 -D /data --broker-endpoint=http://172.16.0.9:50051  \
  -l 172.16.0.9:5454 --listen-http=0.0.0.0:7676  
```
where 172.16.0.9 is IP address of the server that is reachable by network

3. Deploy pageserver, file `docker-pageserver.sh`

```
docker run -d -t --name pageserver --net=host \
  --entrypoint "pageserver" \
  perconalab/neon:pg14-1.0.0 \
  -D /data -c "id=1" -c "broker_endpoint='http://172.16.0.9:50051'" \
  -c "listen_pg_addr='0.0.0.0:6400'" -c "listen_http_addr='0.0.0.0:9898'" \
  -c "pg_distrib_dir='/opt/neondatabase-neon/pg_install'"
```

4. Deploy computnode

There are several possibilities:

a. we want to create new tenant and timeline
```
docker run -d -t --name compute --entrypoint "/compute.sh" -p55432:55432 -e PAGESERVER=172.16.0.9 -e SAFEKEEPERS=172.16.0.9:5454 perconalab/neon:pg14-1.0.0
```

b. we want to start a compute node on existing tenant and timeline

```
docker run -d -t --name compute1 --entrypoint "/compute.sh" -p55433:55432 -e PAGESERVER=172.16.0.9 -e SAFEKEEPERS=172.16.0.9:5454 -e TENANT=51021f53054316c6533d371c9d7e273c -e TIMELINE=e08a6f1526b3ad6249a7b08fc5585e0b perconalab/neon:pg14-1.0.0
```

c. we want to fork existing tenant and timeline
```
docker run -d -t --name compute3 --entrypoint "/compute.sh" -p55435:55432 -e PAGESERVER=172.16.0.9 -e SAFEKEEPERS=172.16.0.9:5454 -e TENANT=6c92c037a54c0e3a005cdd4a69d6e997 -e TIMELINE=4b4541ad75370114cd7956e457cc875f -e "CREATE_BRANCH=1" perconalab/neon:pg14-1.0.0
```

