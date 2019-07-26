NAMESPACE=ilya-mongodb

KUBECTL=kubectl
K=${KUBECTL} --namespace ${NAMESPACE}
APPLY=${K} apply -f
GET=${K} get -o wide
DELETE=${K} delete
EXEC=${K} exec

DISK_PREFIX=pd-ssd-disk-k8s-${CLUSTER}-${NAMESPACE}

define make_disk_names
	$(addprefix ${DISK_PREFIX}-${1}-, ${2})
endef

STORAGECLASS=gp2

DATA_DISK_SIZE=10g
DATA_PV_CAPACITY=10Gi
DATA_DISK_SUFFIXES=1 2
CONFIG_DISK_SIZE=5g
CONFIG_PV_CAPACITY=5Gi
CONFIG_DISK_SUFFIXES=1

DATA_DISKS=$(call make_disk_names,${DATA_DISK_SIZE},${DATA_DISK_SUFFIXES})
CONFIG_DISKS=$(call make_disk_names,${CONFIG_DISK_SIZE},${CONFIG_DISK_SUFFIXES})
DISKS_ALL=${DATA_DISKS} ${CONFIG_DISKS}

DATA_SHARDS=shard1 shard2

all: config \
     namespace \
     storage-class \
     pv \
     pvc \
     configdb \
     maindb \
     mongos

namespace: config
	sed "s/NAMESPACE/${NAMESPACE}/g" namespace.yaml|${KUBECTL} apply -f -
	${GET} ns

storage-class: config
#	${APPLY} ebs-gp2-storageclass.yaml
#	${GET} sc

config:
#	${GC} config set project ${PROJECT}
#	${GC} config set compute/zone ${ZONE}

delete: cluster-delete \
       disks-delete

create: cluster \
	disks

cluster: config
	${GC} container clusters create ${CLUSTER} --machine-type ${MACHINE_TYPE} --num-nodes=${NUM_NODES}
	${GC} container clusters get-credentials ${CLUSTER}

cluster-delete: config
	${GC} -q container clusters delete ${CLUSTER}

disks: data-disks \
       config-disks
	${GC} compute disks list

define create_disks
	for d in ${1}; do \
		${GC} compute disks create --size $(2) --type pd-ssd $$d; \
	done
endef

data-disks: config
	$(call create_disks,${DATA_DISKS},${DATA_DISK_SIZE})

config-disks: config
	$(call create_disks,${CONFIG_DISKS},${CONFIG_DISK_SIZE})

define delete_disks
	for d in ${1}; do \
		${GC} -q compute disks delete $$d; \
	done
endef

disks-delete: data-disks-delete \
              config-disks-delete
	${GC} compute disks list

data-disks-delete: config
	$(call delete_disks,${DATA_DISKS})

config-disks-delete: config
	$(call delete_disks,${CONFIG_DISKS})

pv: data-pv \
    config-pv
	${GET} pv

define apply_pv
	for d in ${1}; do \
		sed "s/CLUSTER/${CLUSTER}/g; s/NAMESPACE/${NAMESPACE}/g; s/CAPACITY/${2}/g; s/SIZE/${3}/g; s/DISK/$$d/g" ${4}|\
			${APPLY} -; \
	done
endef

data-pv: config
	$(call apply_pv,${DATA_DISK_SUFFIXES},${DATA_PV_CAPACITY},${DATA_DISK_SIZE},data-pv.yaml)

config-pv: config
	$(call apply_pv,${CONFIG_DISK_SUFFIXES},${CONFIG_PV_CAPACITY},${CONFIG_DISK_SIZE},config-pv.yaml)

delete-pv: delete-data-pv \
	   delete-config-pv

define delete_pv
	for d in ${1}; do \
		-${DELETE} pv k8s-mongodb-${NAMESPACE}-data-$$d; \
	done
endef

delete-data-pv: config
	$(call delete_pv,${DATA_DISK_SUFFIXES})

delete-config-pv: config
	$(call delete_pv,${CONFIG_DISK_SUFFIXES})

configdb: namespace \
          storage-class
	sed "s/NAMESPACE/${NAMESPACE}/g; s/CAPACITY/${CONFIG_PV_CAPACITY}/g" \
		mongodb-configdb-service-stateful.yaml|${APPLY} -

pvc: data-pvc
	${GET} pvc

data-pvc: data-pv
	for s in ${DATA_SHARDS}; do \
		sed "s/NAMESPACE/${NAMESPACE}/g; s/CAPACITY/${DATA_PV_CAPACITY}/g; s/SHARD/$$s/g; s/REPLICA/0/g" \
			data-pvc.yaml|${APPLY} -;\
	done

delete-pvc: delete-data-pvc

delete-data-pvc: config
	for s in ${DATA_SHARDS}; do \
		-${DELETE} pvc mongo-$$s-persistent-storage-claim-mongodb-$$s-0; \
	done

maindb: namespace \
          pvc
	for s in ${DATA_SHARDS}; do \
		sed "s/NAMESPACE/${NAMESPACE}/g; s/CAPACITY/${CONFIG_PV_CAPACITY}/g; s/SHARD/$$s/g" \
			mongodb-maindb-service-stateful.yaml|${APPLY} -; \
	done

mongos: namespace
	sed "s/NAMESPACE/${NAMESPACE}/g" mongodb-mongos-deployment-service.yaml|${APPLY} -

delete-mongos: config
	-${DELETE} service mongos-service
	-${DELETE} deployment mongos

init: init-configdb \
      init-maindb \
      init-mongos

init-configdb: config
	 ${EXEC} mongodb-configdb-0 -- mongo --port 27019 --eval \
	"rs.initiate( { _id: \"configdb\", version: 1, members: [ {_id: 0, host: \"mongodb-configdb-0.mongodb-configdb-headless-service.${NAMESPACE}.svc.cluster.local:27019\"}]});"

init-maindb: config
	for s in ${DATA_SHARDS}; do \
		${EXEC} mongodb-$$s-0 -- mongo --port 27017 --eval \
		"rs.initiate({_id: \"$$s\", version: 1, members: [ {_id: 0, host: \"mongodb-$$s-0.mongodb-$$s-headless-service.${NAMESPACE}.svc.cluster.local:27017\"} ] });"; \
	done

MONGOS=$(shell ${GET} pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}')

init-mongos: config
	for s in ${DATA_SHARDS}; do \
		${EXEC} ${MONGOS} -- mongo --port 27017 --eval \
			"sh.addShard(\"$$s/mongodb-$$s-0.mongodb-$$s-headless-service.${NAMESPACE}.svc.cluster.local:27017\");"; \
	done


MONGOS_EXTERNAL_IP=$(shell ${GET} service mongos-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

test: config
	mongo -host ${MONGOS_EXTERNAL_IP} < test.js
