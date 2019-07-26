NAMESPACE=ilya-mongodb

KUBECTL=kubectl
K=${KUBECTL} --namespace ${NAMESPACE}

all: namespace \
     storage-class \
     configdb \
     maindb \
     mongos

namespace:
	${KUBECTL} apply -f namespace.yaml

storage-class:
	${KUBECTL} apply -f sc-vmware-vsan.yaml

configdb:
	${K} apply -f service-configdb.yaml

maindb:
	${K} apply -f service-maindb-shard1.yaml
	${K} apply -f service-maindb-shard2.yaml

mongos:
	${K} apply -f service-mongos.yaml


delete: clean

clean: delete-mongos \
       delete-maindb \
       delete-configdb \
       delete-storage-class \
       delete-namespace

delete-mongos:
	-${K} delete service mongos
	-${K} delete deployment mongos

delete-maindb:
	-${K} delete service service-maindb-shard1
	-${K} delete statefulset maindb-shard1
	-${K} delete service service-maindb-shard2
	-${K} delete statefulset maindb-shard2

delete-configdb:
	-${K} delete service configdb
	-${K} delete statefulset configdb

delete-storage-class:
	-${KUBECTL} delete storageclass sc-mongodb

delete-namespace:
	-${KUBECTL} delete namespace ilya-mongodb

init:
	./mongodb-init.sh
