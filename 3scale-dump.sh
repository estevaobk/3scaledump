#!/bin/bash

THREESCALE_PROJECT="${1}"

SINGLE="${2}"

CURRENT_DIR=$(dirname "$0")

# Avoid fetching information about any pod that is not a 3scale one
THREEESCALE_PODS=("apicast-production" "apicast-staging" "apicast-wildcard-router" "backend-cron" "backend-listener" "backend-redis" "backend-worker" "system-app" "system-memcache" "system-mysql" "system-redis" "system-resque" "system-sidekiq" "system-sphinx" "zync" "zync-database")

DUMP_FILE="${CURRENT_DIR}/3scale-dump.tar"

DUMP_DIR="${CURRENT_DIR}/3scale-dump"

# Functions #

create_dir() {
    if [[ -z ${NEWDIR} ]]; then
        echo -e "\n# [Error] Variable Not Found: NEWDIR #\n"
        exit 1

    elif [[ ${SINGLE} == 0 ]]; then
        mkdir -pv ${DUMP_DIR}/${NEWDIR}

        if [[ ! -d ${DUMP_DIR}/${NEWDIR} ]]; then
            echo -e "\n# [Error] Unable to create: ${DUMP_DIR}/${NEWDIR} #\n"
            exit 1
        fi
    fi

    if [[ -z ${SINGLE_FILE} ]]; then
        echo -e "\n# [Error] Variable Not Found: SINGLE_FILE #\n"
        exit 1

    elif [[ -f ${DUMP_DIR}/${SINGLE_FILE} ]]; then
        /bin/rm -fv ${DUMP_DIR}/${SINGLE_FILE}

        if [[ -f ${SINGLE_FILE} ]]; then
            echo -e "# [Error] Unable to delete: ${DUMP_DIR}/${SINGLE_FILE} #\n"
            exit 1
        fi
    fi
}

execute_command() {
    if [[ -z ${COMMAND} ]]; then
        echo -e "\n# [Error] Variable Not Found: COMMAND #\n"
        exit 1

    else
        ${COMMAND} | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt
    fi
}


read_obj() {
    if [[ -z ${NOYAML} ]]; then
        YAML="-o yaml"

    else
        unset YAML
    fi

    if [[ ${VALIDATE_PODS} == 1 ]]; then
        while read OBJ; do
            FOUND=0
            for POD in "${THREEESCALE_PODS[@]}"; do
                if ( [[ ${SUBSTRING} == 1 ]] && [[ "${OBJ}" == *"${POD}"* ]] ) || ( [[ "${OBJ}" == "${POD}" ]] ); then
                    FOUND=1
                fi
            done  

            if [[ ! ${FOUND} == 1 ]]; then
                echo -e "Skipping: ${OBJ}"

            else

                if [[ ${VERBOSE} == 1 ]]; then
                    echo -e "\nProcess: ${OBJ}"
                fi

                if [[ ${SINGLE} == 1 ]] && [[ ! ${COMPRESS} == 1 ]]; then
                    ${COMMAND} ${OBJ} ${YAML} >> ${DUMP_DIR}/${SINGLE_FILE} 2>&1

                else
                    ${COMMAND} ${OBJ} ${YAML} > ${DUMP_DIR}/${NEWDIR}/${OBJ}.txt 2>&1

                    if [[ ${COMPRESS} == 1 ]]; then
                        gzip -f ${DUMP_DIR}/${NEWDIR}/${OBJ}.txt
                    fi
                fi
            fi
        
        done < ${DUMP_DIR}/temp.txt

    else
        while read OBJ; do
            if [[ ${VERBOSE} == 1 ]]; then
                echo -e "\nProcess: ${OBJ}"
            fi

            if [[ ${SINGLE} == 1 ]] && [[ ! ${COMPRESS} == 1 ]]; then
                ${COMMAND} ${OBJ} ${YAML} >> ${DUMP_DIR}/${SINGLE_FILE} 2>&1

            else
                ${COMMAND} ${OBJ} ${YAML} > ${DUMP_DIR}/${NEWDIR}/${OBJ}.txt 2>&1

                if [[ ${COMPRESS} == 1 ]]; then
                    gzip -f ${DUMP_DIR}/${NEWDIR}/${OBJ}.txt
                fi
            fi
        
        done < ${DUMP_DIR}/temp.txt

    fi

    /bin/rm -f ${DUMP_DIR}/temp.txt
}

cleanup() {
    unset COMMAND COMPRESS NEWDIR NOYAML SINGLE_FILE SUBSTRING VALIDATE_PODS VERBOSE
}


########
# MAIN #
########


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

# Create the Dump Directory if it does not exist:

if [[ ! -d ${DUMP_DIR}/status ]]; then
    mkdir -pv ${DUMP_DIR}/status

    if [[ ! -d ${DUMP_DIR}/status ]]; then
        echo -e "\nUnable to create: ${DUMP_DIR}/status.\n"
        exit 1
    fi
fi


# 1. Fetch the status from all the pods and events #

echo -e "\n1. Fetch: All pods and Events\n"

oc get pod -o wide > ${DUMP_DIR}/pods.txt 2>&1

oc get event > ${DUMP_DIR}/events.txt 2>&1


# 2. DeploymentConfig objects #

echo -e "\n2. Fetch: DeploymentConfig\n"

NEWDIR="dc"
SINGLE_FILE="dc.txt"
COMMAND="oc get dc"

VALIDATE_PODS=1

create_dir
execute_command
read_obj
cleanup


# 3. Fetch and compress the logs #

echo -e "\n3. Fetch: Logs\n"

SINGLE_OLD=${SINGLE}

SINGLE=0

NEWDIR="logs"
SINGLE_FILE="logs.txt"
COMMAND="oc logs --all-containers"

VALIDATE_PODS=1
SUBSTRING=1
COMPRESS=1
VERBOSE=1
NOYAML=1

cat ${DUMP_DIR}/pods.txt | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

create_dir
read_obj
cleanup

SINGLE=${SINGLE_OLD}


# 4. Secrets #

echo -e "\n4. Fetch: Secrets\n"

NEWDIR="secrets"
SINGLE_FILE="secrets.txt"
COMMAND="oc get secret"

create_dir
execute_command
read_obj
cleanup


# 5. Routes #

echo -e "\n5. Fetch: Routes\n"

NEWDIR="routes"
SINGLE_FILE="routes.txt"
COMMAND="oc get route"

create_dir
execute_command
read_obj
cleanup


# 6. Services #

echo -e "\n6. Fetch: Services\n"

NEWDIR="services"
SINGLE_FILE="services.txt"
COMMAND="oc get service"

create_dir
execute_command
read_obj
cleanup


# 7. Image Streams #

echo -e "\n7. Fetch: Image Streams\n"

NEWDIR="images"
SINGLE_FILE="images.txt"
COMMAND="oc get imagestream"

create_dir
execute_command
read_obj
cleanup


# 8. ConfigMaps #

echo -e "\n8. Fetch: ConfigMaps\n"

NEWDIR="configmaps"
SINGLE_FILE="configmaps.txt"
COMMAND="oc get configmap"

create_dir
execute_command
read_obj
cleanup


# 9. PV #

echo -e "\n9. Fetch: PV\n"

NEWDIR="pv"
SINGLE_FILE="pv.txt"
COMMAND="oc get pv"

${COMMAND} > ${DUMP_DIR}/status/pv.txt 2>&1

create_dir
execute_command
read_obj
cleanup


# 10. PVC #

echo -e "\n10. Fetch: PVC\n"

NEWDIR="pvc"
SINGLE_FILE="pvc.txt"
COMMAND="oc get pvc"

${COMMAND} > ${DUMP_DIR}/status/pvc.txt 2>&1

create_dir
execute_command
read_obj
cleanup


APICAST_POD=$(oc get pod | grep -i "apicast-production" | head -n 1 | awk '{print $1}')

APICAST_ROUTE=$(oc get route | grep -i "apicast-production" | grep -v NAME | head -n 1 | awk '{print $2}')

WILDCARD_POD=$(oc get pod | grep -i "apicast-wildcard-router" | grep -v NAME | head -n 1 | awk '{print $1}')

THREESCALE_PORTAL_ENDPOINT=$(oc rsh ${APICAST_POD} /bin/bash -c "env | grep 'THREESCALE_PORTAL_ENDPOINT=' | head -n 1 | cut -d '=' -f 2" < /dev/null)

echo -e "\nAPICAST POD: ${APICAST_POD}\nAPICAST ROUTE: ${APICAST_ROUTE}\nWILDCARD POD: ${WILDCARD_POD}\nTHREESCALE_PORTAL_ENDPOINT: ${THREESCALE_PORTAL_ENDPOINT}\n"
sleep 3


# 11. Status: Node #

echo -e "\n11. Status: Node"

oc describe node > ${DUMP_DIR}/status/node.txt 2>&1


# 12. Status: 3scale Echo API #

echo -e "\n12. Status: 3scale Echo API"

timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -k -v https://echo-api.3scale.net" > ${DUMP_DIR}/status/3scale-echo-api.txt 2>&1 < /dev/null


# 13. Status: Staging/Production Backend JSON #

echo -e "\n13. Status: Staging/Production Backend JSON"

timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -X GET -H 'Accept: application/json' -k ${THREESCALE_PORTAL_ENDPOINT}/staging.json" > ${DUMP_DIR}/status/apicast-staging.json 2> ${DUMP_DIR}/status/apicast-staging-json-debug.txt < /dev/null

timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -X GET -H 'Accept: application/json' -k ${THREESCALE_PORTAL_ENDPOINT}/production.json" > ${DUMP_DIR}/status/apicast-production.json 2> ${DUMP_DIR}/status/apicast-production-json-debug.txt < /dev/null


# 14. Status: Certificate #

echo -e "\n14. Status: Certificate"

timeout 10 oc rsh ${WILDCARD_POD} /bin/bash -c "echo | openssl s_client -connect ${APICAST_ROUTE}:443" > ${DUMP_DIR}/status/apicast-production-certificate.txt 2>&1 < /dev/null



# Compact the Directory

echo -e "\n# Compacting... #\n"

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
