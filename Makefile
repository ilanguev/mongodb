PROJECT=proj-mongodb
ZONE=us-west1-a
CLUSTER=mongodb
MACHINE_TYPE=f1-micro
NUM_NODES=4
NAMESPACE=lvi123

DISK_PREFIX=pd-ssd-disk-k8s-${CLUSTER}-${NAMESPACE}

define make_disk_names
	$(addprefix ${DISK_PREFIX}-${1}-, ${2})
endef

DATA_DISK_SIZE=10g
DATA_PV_CAPACITY=10Gi
DATA_DISK_SUFFIXES=1 2
CONFIG_DISK_SIZE=5g
CONFIG_PV_CAPACITY=5Gi
CONFIG_DISK_SUFFIXES=1

DATA_DISKS=$(call make_disk_names,${DATA_DISK_SIZE},${DATA_DISK_SUFFIXES})
CONFIG_DISKS=$(call make_disk_names,${CONFIG_DISK_SIZE},${CONFIG_DISK_SUFFIXES})
DISKS_ALL=${DATA_DISKS} ${CONFIG_DISKS}

all: config \
     namespace \
     storage-class \
     pvs

namespace: config
	sed "s/NAMESPACE/${NAMESPACE}/g" namespace.yaml|kubectl apply -f -
	kubectl get ns

storage-class: config
	kubectl apply -f gce-ssd-storageclass.yaml
	kubectl get sc

config:
	gcloud config set project ${PROJECT}
	gcloud config set compute/zone ${ZONE}

delete: cluster-delete \
       disks-delete

create: cluster \
	disks

cluster: config
	gcloud container clusters create ${CLUSTER} --machine-type ${MACHINE_TYPE} --num-nodes=${NUM_NODES}
	gcloud container clusters get-credentials ${CLUSTER}

cluster-delete: config
	gcloud -q container clusters delete ${CLUSTER}

disks: data-disks \
       config-disks
	gcloud compute disks list

define create_disks
	for d in ${1}; do \
		gcloud compute disks create --size $(2) --type pd-ssd $$d; \
	done
endef

data-disks: config
	$(call create_disks,${DATA_DISKS},${DATA_DISK_SIZE})

config-disks: config
	$(call create_disks,${CONFIG_DISKS},${CONFIG_DISK_SIZE})

define delete_disks
	for d in ${1}; do \
		gcloud -q compute disks delete $$d; \
	done
endef

disks-delete: data-disks-delete \
              config-disks-delete
	gcloud compute disks list

data-disks-delete: config
	$(call delete_disks,${DATA_DISKS})

config-disks-delete: config
	$(call delete_disks,${CONFIG_DISKS})

define apply_pvs
	for d in ${1}; do \
		sed "s/CLUSTER/${CLUSTER}/g; s/NAMESPACE/${NAMESPACE}/g; s/CAPACITY/${2}/g; s/SIZE/${3}/g; s/DISK/$$d/g" ${4}|kubectl apply -f -; \
	done
endef

pvs: data-pvs \
     config-pvs
	kubectl get pv -o wide

data-pvs: config
	$(call apply_pvs,${DATA_DISK_SUFFIXES},${DATA_PV_CAPACITY},${DATA_DISK_SIZE},data-persistentvolume.yaml)

config-pvs: config
	$(call apply_pvs,${CONFIG_DISK_SUFFIXES},${CONFIG_PV_CAPACITY},${CONFIG_DISK_SIZE},config-persistentvolume.yaml)
