#!/bin/bash

THREESCALE_PROJECT="${1}"

SINGLE="${2}"

CURRENT_DIR=$(dirname "$0")

# Avoid fetching information about any pod that is not a 3scale one
THREEESCALE_PODS=("apicast-production" "apicast-staging" "apicast-wildcard-router" "backend-cron" "backend-listener" "backend-redis" "backend-worker" "system-app" "system-memcache" "system-mysql" "system-redis" "system-resque" "system-sidekiq" "system-sphinx" "zync" "zync-database")

DUMP_FILE="${CURRENT_DIR}/3scale-dump.tar"

DUMP_DIR="${CURRENT_DIR}/3scale-dump"

# Validate: 3scale Project Argument
if [[ -z ${THREESCALE_PROJECT} ]]; then
    echo -e "\nUsage: 3scale_dump.sh <3SCALE PROJECT> single (optional)\n"
    exit 1

else
    if [[ "${SINGLE,,}" == "single" ]]; then
        SINGLE=1

    else
        SINGLE=0
    fi

    # Validate the existance of the project
    OC_PROJECT=$(oc get project | awk '{print $1}' | grep "${THREESCALE_PROJECT}")

    if [[ ! "${OC_PROJECT}" == "${THREESCALE_PROJECT}" ]]; then
        echo -e "\nProject not found: ${THREESCALE_PROJECT}. Ensure that you are logged in and specified the correct project.\n"
        exit 1

    else
        # Change to the 3scale project
        oc project ${THREESCALE_PROJECT}
    fi
fi


echo -e "\nNOTE: A temporary directory will be created in order to store the information about the 3scale dump: ${DUMP_DIR}\n\nPress any key to continue or <Ctrl + C> to abort...\n"
read FOO

# Create Dump Directory if it does not exist:
if [[ ! -d ${DUMP_DIR} ]]; then
    mkdir -pv ${DUMP_DIR}

    if [[ ! -d ${DUMP_DIR} ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}.\n"
        exit 1
    fi
fi


# 1. Fetch the status from all the pods and events #

echo -e "\n1. Fetch: All pods and Events\n"

oc get pod -o wide > ${DUMP_DIR}/pods.txt 2>&1

oc get event > ${DUMP_DIR}/events.txt 2>&1


# 2. DeploymentConfig objects #

echo -e "\n2. Fetch: DeploymentConfig\n"

# Cleanup any previous DeploymentConfig data
if [[ ${SINGLE} == 0 ]] && [[ ! -d ${DUMP_DIR}/dc ]]; then
    mkdir -pv ${DUMP_DIR}/dc

    if [[ ! -d ${DUMP_DIR}/dc ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/dc.\n"
        exit 1
    fi

elif [[ ${SINGLE} == 1 ]] && [[ -f ${DUMP_DIR}/dc.txt ]]; then
    /bin/rm -fv ${DUMP_DIR}/dc.txt
fi

oc get dc | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

# Browse through the DeploymentConfig objects:
while read DC; do
    FOUND=0
    for POD in "${THREEESCALE_PODS[@]}"; do
        if [[ "${POD}" == "${DC}" ]]; then
            FOUND=1
        fi
    done  

    if [[ ! ${FOUND} == 1 ]]; then
        echo -e "Skipping DC: ${DC}"

    elif [[ ${SINGLE} == 1 ]]; then
        oc get dc/${DC} -o yaml >> ${DUMP_DIR}/dc.txt 2>&1

    else
        oc get dc/${DC} -o yaml > ${DUMP_DIR}/dc/dc-${DC}.txt 2>&1
    fi

done < ${DUMP_DIR}/temp.txt


# 3. Fetch and compress the logs #

echo -e "\n3. Fetch: Logs\n"

cat ${DUMP_DIR}/pods.txt | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

mkdir -pv ${DUMP_DIR}/logs

if [[ ! -d ${DUMP_DIR}/logs ]]; then
    echo -e "\nUnable to create: ${DUMP_DIR}/logs.\n"
    exit 1
fi

while read OBJ; do
    FOUND=0
    for POD in "${THREEESCALE_PODS[@]}"; do
        if [[ "${OBJ}" == *"${POD}"* ]]; then
            FOUND=1
        fi
    done  

    if [[ ! ${FOUND} == 1 ]]; then
        echo -e "Skipping POD: ${OBJ}"

    else
        echo -e "\nLogs: ${OBJ}"
        oc logs --all-containers ${OBJ} > ${DUMP_DIR}/logs/${OBJ}.txt 2>&1
        gzip -f ${DUMP_DIR}/logs/${OBJ}.txt
    fi

done < ${DUMP_DIR}/temp.txt


# 4. Secrets #

echo -e "\n4. Fetch: Secrets\n"

if [[ ${SINGLE} == 0 ]] && [[ ! -d ${DUMP_DIR}/secrets ]]; then
    mkdir -pv ${DUMP_DIR}/secrets

    if [[ ! -d ${DUMP_DIR}/secrets ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/secrets.\n"
        exit 1
    fi
fi


if [[ ${SINGLE} == 1 ]]; then
    oc get secret -o yaml > ${DUMP_DIR}/secrets.txt 2>&1

else
    oc get secret | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

    while read SECRET; do
        oc get secret ${SECRET} -o yaml > ${DUMP_DIR}/secrets/${SECRET}.txt 2>&1

    done < ${DUMP_DIR}/temp.txt
fi


# 5. Routes #

echo -e "\n5. Fetch: Routes\n"

if [[ ${SINGLE} == 0 ]] && [[ ! -d ${DUMP_DIR}/routes ]]; then
    mkdir -pv ${DUMP_DIR}/routes

    if [[ ! -d ${DUMP_DIR}/routes ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/routes.\n"
        exit 1
    fi
fi


if [[ ${SINGLE} == 1 ]]; then
    oc get route -o yaml > ${DUMP_DIR}/routes.txt 2>&1

else
    oc get route | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

    while read ROUTE; do
        oc get route ${ROUTE} -o yaml > ${DUMP_DIR}/routes/${ROUTE}.txt 2>&1

    done < ${DUMP_DIR}/temp.txt
fi


# 6. Services #

echo -e "\n6. Fetch: Services\n"

if [[ ${SINGLE} == 0 ]] && [[ ! -d ${DUMP_DIR}/services ]]; then
    mkdir -pv ${DUMP_DIR}/services

    if [[ ! -d ${DUMP_DIR}/services ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/services.\n"
        exit 1
    fi
fi


if [[ ${SINGLE} == 1 ]]; then
    oc get service -o yaml > ${DUMP_DIR}/services.txt 2>&1

else
    oc get service | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

    while read SERVICE; do
        oc get service ${SERVICE} -o yaml > ${DUMP_DIR}/services/${SERVICE}.txt 2>&1

    done < ${DUMP_DIR}/temp.txt
fi


# 7. Image Streams #

echo -e "\n7. Fetch: Image Streams\n"

if [[ ${SINGLE} == 0 ]] && [[ ! -d ${DUMP_DIR}/images ]]; then
    mkdir -pv ${DUMP_DIR}/images

    if [[ ! -d ${DUMP_DIR}/images ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/images.\n"
        exit 1
    fi
fi


if [[ ${SINGLE} == 1 ]]; then
    oc get imagestream -o yaml > ${DUMP_DIR}/images.txt 2>&1

else
    oc get imagestream | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

    while read IMAGE; do
        oc get imagestream ${IMAGE} -o yaml > ${DUMP_DIR}/images/${IMAGE}.txt

    done < ${DUMP_DIR}/temp.txt
fi


# 8. ConfigMaps #

echo -e "\n8. Fetch: ConfigMaps\n"

if [[ ${SINGLE} == 0 ]] && [[ ! -d ${DUMP_DIR}/configmaps ]]; then
    mkdir -pv ${DUMP_DIR}/configmaps

    if [[ ! -d ${DUMP_DIR}/configmaps ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/configmaps.\n"
        exit 1
    fi
fi


if [[ ${SINGLE} == 1 ]]; then
    oc get configmap -o yaml > ${DUMP_DIR}/configmaps.txt 2>&1

else
    oc get configmap | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

    while read CONFIGMAP ; do
        oc get configmap ${CONFIGMAP} -o yaml > ${DUMP_DIR}/configmaps/${CONFIGMAP}.txt

    done < ${DUMP_DIR}/temp.txt
fi


# Compress the Directory

/bin/rm -f ${DUMP_DIR}/temp.txt

if [[ -f ${DUMP_FILE} ]]; then
    /bin/rm -f ${DUMP_FILE}
fi

tar cpf ${DUMP_FILE} ${DUMP_DIR}

if [[ ! -f ${DUMP_FILE} ]]; then
    echo -e "\nThere was an error creating ${DUMP_FILE}"
    exit 1

else
    echo -e "\nFile created: ${DUMP_FILE}\n\nPlease remove manually the temporary directory: ${DUMP_DIR}\n"
    exit 0
fi
