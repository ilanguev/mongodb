PROJECT = proj-mongodb
ZONE = us-west1-a
CLUSTER = mongodb
MACHINE_TYPE = f1-micro
NUM_NODES = 4
NAMESPACE = lvi123

DISK_PREFIX = pd-ssd-disk-k8s-${CLUSTER}-${NAMESPACE}

DISK_10G_SUFFIXES = 1 2
DISKS_10G = $(addprefix ${DISK_PREFIX}-10g-, ${DISK_10G_SUFFIXES})
DISK_5G_SUFFIXES = 1
DISKS_5G = $(addprefix ${DISK_PREFIX}-5g-, ${DISK_5G_SUFFIXES})
DISKS_ALL = ${DISKS_10G} ${DISKS_5G}

all: config \
     namespace \
     storage-class

namespace: config
	sed s/NAMESPACE/${NAMESPACE}/g namespace.yaml|kubectl apply -f -
	kubectl get ns

storage-class: namespace
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

disks: config \
       disks-10G \
       disks-5G
	gcloud compute disks list

define create_disk
	gcloud compute disks create --size $(1) --type pd-ssd $(2)
endef

disks-10G:
	for d in ${DISKS_10G}; do \
		$(call create_disk,10G, $$d); \
	done

disks-5G:
	for d in ${DISKS_5G}; do \
		$(call create_disk,5G, $$d); \
	done

disks-delete:
	for d in ${DISKS_ALL}; do \
		gcloud -q compute disks delete $$d; \
	done
	gcloud compute disks list
