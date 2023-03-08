How to use Docker to deploy Serverless PostgreSQL

1. Deploy storage broker (see file `docker-storagebroker.sh`)

```
docker run -d -t --name storagebroker --net=host --entrypoint "storage_broker"  perconalab/neon:pg14-1.0.0  -l 0.0.0.0:50051
```

2. Deploy safekeeper (or multiple), file `docker-safekeeper.sh`

```
docker run -d -t --name safekeeper1 --net=host --entrypoint "safekeeper" perconalab/neon:pg14-1.0.0 --id=1 -D /data --broker-endpoint=http://172.16.0.9:50051  -l 172.16.0.9:5454 --listen-http=0.0.0.0:7676  
```
where 172.16.0.9 is IP address of the server that is reachable by network
