#!/bin/sh

NAMESPACE="ilya-mongodb"

MONGOS_PORT=27017
MONGOS_SERVICE="mongos"

K="kubectl --namespace ${NAMESPACE}"
M="mongo"

# Get mongos cluster IP
mongos_ip=`${K} get service ${MONGOS_SERVICE} -o jsonpath='{.spec.clusterIP}'`

echo "mongos:port=${mongos_ip}:${MONGOS_PORT}"

# Set sharding strategy for myDB.posts
${M} -host ${mongos_ip} -port ${MONGOS_PORT} myDB --eval \
	"db.posts.getShardDistribution()"





