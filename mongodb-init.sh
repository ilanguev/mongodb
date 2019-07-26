#!/bin/sh

NAMESPACE="ilya-mongodb"

CONFIGDB_POD="configdb-0"
CONFIGDB_SERVICE="configdb"
CONFIGDB_PORT=27019

MAINDB_SHARDS="shard1 shard2"
MAINDB_SHARD_POD_NAME_FORMAT="maindb-%s-0"
MAINDB_SHARD_SERVICE_NAME_FORMAT="service-maindb-%s"
MAINDB_PORT=27017

MONGOS_PORT=27017
MONGOS_SERVICE="mongos"

K="kubectl --namespace ${NAMESPACE}"
M="mongo"

echo ${K}

# Init config DB
configdb_fqdn="${CONFIGDB_POD}.${CONFIGDB_SERVICE}.${NAMESPACE}.svc.cluster.local"
${K} exec ${CONFIGDB_POD} -- ${M} --port ${CONFIGDB_PORT} --eval \
     "rs.initiate( { _id: \"configdb\", version: 1, members: [ {_id: 0, host: \"${configdb_fqdn}:${CONFIGDB_PORT}\"}]});"

# Init mainDB shards
for shard in ${MAINDB_SHARDS}
do
    shard_pod=`printf ${MAINDB_SHARD_POD_NAME_FORMAT} ${shard}`
    shard_service=`printf ${MAINDB_SHARD_SERVICE_NAME_FORMAT} ${shard}`
    shard_fqdn="${shard_pod}.${shard_service}.${NAMESPACE}.svc.cluster.local"
    ${K} exec ${shard_pod} -- ${M} --port ${MAINDB_PORT} --eval \
         "rs.initiate({_id: \"${shard}\", version: 1, members: [ {_id: 0, host:\"${shard_fqdn}:${MAINDB_PORT}\"} ] });"
done

# Sleep for a bit to let shards init
sleep 10

# Init mongos shard router
mongos_pod=`${K} get pod -l tier=routers -o jsonpath='{.items[0].metadata.name}')`
for shard in ${MAINDB_SHARDS}
do
    shard_pod=`printf ${MAINDB_SHARD_POD_NAME_FORMAT} ${shard}`
    shard_service=`printf ${MAINDB_SHARD_SERVICE_NAME_FORMAT} ${shard}`
    shard_fqdn="${shard_pod}.${shard_service}.${NAMESPACE}.svc.cluster.local"
    ${K} exec ${mongos_pod} -- ${M} --port ${MONGOS_PORT} --eval \
	 "sh.addShard(\"${shard}/${shard_fqdn}:${MAINDB_PORT}\");"
done


# Get mongos cluster IP
mongos_ip=`${K} get service ${MONGOS_SERVICE} -o jsonpath='{.spec.clusterIP}'`

echo "mongos:port=${mongos_ip}:${MONGOS_PORT}"

# Enable sharding
${M} -host ${mongos_ip} -port ${MONGOS_PORT} --eval \
     "sh.enableSharding(\"myDB\");\
      sh.status();"

# Do stuff
${M} -host ${mongos_ip} -port ${MONGOS_PORT} admin --eval \
      "db.admin.runCommand(\"getShardMap\");"
