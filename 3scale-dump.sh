#!/bin/bash

THREESCALE_PROJECT="${1}"

COMPRESS_UTIL="${2,,}"

CURRENT_DIR=$(dirname "$0")

# Avoid fetching information about any pod that is not a 3scale one
THREEESCALE_PODS=("apicast-production" "apicast-staging" "apicast-wildcard-router" "backend-cron" "backend-listener" "backend-redis" "backend-worker" "system-app" "system-memcache" "system-mysql" "system-redis" "system-resque" "system-sidekiq" "system-sphinx" "zync" "zync-database")

DUMP_FILE="${CURRENT_DIR}/3scale-dump.tar"

DUMP_DIR="${CURRENT_DIR}/3scale-dump"

# Functions #

print_error() {
    if [[ -z ${MSG} ]]; then
        echo -e "\n# Unknown Error #\n"
        exit 1

    else
        echo -e "\n# [Error] ${MSG} #\n"
        exit 1        
    fi

    unset MSG
}

create_dir() {
    if [[ -z ${NEWDIR} ]]; then
        MSG="Variable Not Found: NEWDIR"
        print_error

    elif [[ -z ${SINGLE_FILE} ]]; then
        MSG="Variable Not Found: SINGLE_FILE"
        print_error

    else
        if [[ ! -d ${DUMP_DIR}/${NEWDIR} ]]; then
            MKDIR=$(mkdir -pv ${DUMP_DIR}/${NEWDIR} 2>&1)
            echo -e "\t${MKDIR}"
        fi

        if [[ ! -d ${DUMP_DIR}/${NEWDIR} ]]; then
            MSG="Unable to create: ${DUMP_DIR}/${NEWDIR}"
            print_error

        elif [[ -f ${DUMP_DIR}/${SINGLE_FILE} ]]; then
            REMOVE=$(/bin/rm -fv ${DUMP_DIR}/${SINGLE_FILE} 2>&1)
            echo -e "\t${REMOVE}"

            if [[ -f ${SINGLE_FILE} ]]; then
                MSG="Unable to delete: ${DUMP_DIR}/${SINGLE_FILE}"
                print_error
            fi
        fi
    fi
}

execute_command() {
    if [[ -z ${COMMAND} ]]; then
        MSG="Variable Not Found: COMMAND"
        print_error

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

    while read OBJ; do
        if [[ ! ${VALIDATE_PODS} == 1 ]]; then
            FOUND=1

        else
            FOUND=0

            for POD in "${THREEESCALE_PODS[@]}"; do
                if ( [[ ${SUBSTRING} == 1 ]] && [[ "${OBJ}" == *"${POD}"* ]] ) || ( [[ "${OBJ}" == "${POD}" ]] ); then
                    FOUND=1
                fi
            done           
        fi

        if [[ ! ${FOUND} == 1 ]]; then
            echo -e "\tSkipping: ${OBJ}"

        else
            if [[ ${VERBOSE} == 1 ]]; then
                echo -e "\n\tProcess: ${OBJ}"
            fi

            if [[ ${COMPRESS} == 1 ]]; then
                ${COMMAND} ${OBJ} ${YAML} 2>&1 | ${COMPRESS_UTIL} -f - > ${DUMP_DIR}/${NEWDIR}/${OBJ}.${COMPRESS_FORMAT}

            else
                ${COMMAND} ${OBJ} ${YAML} >> ${DUMP_DIR}/${SINGLE_FILE} 2>&1
                ${COMMAND} ${OBJ} ${YAML} > ${DUMP_DIR}/${NEWDIR}/${OBJ}.yaml 2>&1
            fi

        fi

    done < ${DUMP_DIR}/temp.txt
            
    /bin/rm -f ${DUMP_DIR}/temp.txt
}

mgmt_api() {
    if [[ -z ${OUTPUT} ]]; then
        MSG="Variable Not Found: OUTPUT"
        print_error

    elif [[ -z ${APICAST_POD} ]]; then
        MSG="Variable Not Found: APICAST_POD"
        print_error
    fi

    if [[ ${MGMT_API,,} == "debug" ]]; then
        OUTPUT="${OUTPUT}-debug"

        timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -X GET -H 'Accept: application/json' http://localhost:8090/config" > ${OUTPUT}.json 2> ${OUTPUT}-stderr.txt < /dev/null
    fi
        

    if [[ ${MGMT_API,,} == "debug" ]] || [[ ${MGMT_API,,} == "status" ]]; then
        OUTPUT="${OUTPUT}-status"     

        timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -X GET http://localhost:8090/status/live" > ${OUTPUT}-live.txt 2>&1 < /dev/null
        timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -X GET http://localhost:8090/status/ready" > ${OUTPUT}-ready.txt 2>&1 < /dev/null
        timeout 10 oc rsh ${APICAST_POD} /bin/bash -c "curl -X GET http://localhost:8090/status/info" > ${OUTPUT}-info.txt 2>&1 < /dev/null
    fi


    unset OUTPUT APICAST_POD MGMT_API
}

cleanup() {
    unset COMMAND COMPRESS NEWDIR NOYAML SINGLE_FILE SUBSTRING VALIDATE_PODS VERBOSE
}

cleanup_dir() {
    if [[ -z ${TARGET_DIR} ]]; then
        MSG="Variable Not Found: TARGET_DIR"
        print_error

    else
        if [[ ${TARGET_DIR,,} == "dump_dir" ]]; then
            TARGET_DIR="${DUMP_DIR}"
        else
            TARGET_DIR="${DUMP_DIR}/${TARGET_DIR}"
        fi

        if [[ ${COMPRESS} == 1 ]]; then
            REMOVE=$(/bin/rm -fv ${TARGET_DIR}/*.${COMPRESS_FORMAT} 2>&1)

            while read ITEM; do
                echo -e "\t\t${ITEM}"
            done <<< "${REMOVE}"

        else   
            REMOVE=$(/bin/rm -fv ${TARGET_DIR}/{*.txt,*.json,*.yml,*.yaml} 2>&1)

            while read ITEM; do
                echo -e "\t\t${ITEM}"
            done <<< "${REMOVE}"  
        fi

        RMDIR=$(rmdir -v ${TARGET_DIR} 2>&1)

        echo -e "\n\t${RMDIR}\n"
    fi

    unset TARGET_DIR COMPRESS
}


########
# MAIN #
########


# Validate Argument: 3scale project #

if [[ -z ${THREESCALE_PROJECT} ]]; then
    MSG="Usage: 3scale_dump.sh [3SCALE PROJECT] [COMPRESS UTIL (Optional)]"
    print_error

else

    # Validate the existance of the project
    OC_PROJECT=$(oc get project | awk '{print $1}' | grep "${THREESCALE_PROJECT}")

    if [[ ! "${OC_PROJECT}" == "${THREESCALE_PROJECT}" ]]; then
        MSG="Project not found: ${THREESCALE_PROJECT}. Ensure that you are logged in and specified the correct project."
        print_error

    else
        # Change to the 3scale project
        echo
        oc project ${THREESCALE_PROJECT}
    fi
fi


# Validate Argument: Compress Util #

# Attempt to auto-detect the COMPRESS_UTIL if not specified
if [[ -z ${COMPRESS_UTIL} ]] || [[ "${COMPRESS_UTIL}" == "auto" ]]; then
    XZ_COMMAND=$(command -v xz 2>&1)

    XZ_VERSION=$(xz --version 2>&1)

    if [[ -n ${XZ_COMMAND} ]] && [[ "${XZ_VERSION,,}" == *"xz utils"* ]]; then
        echo -e "\nXZ util found:\n\n~~~\n${XZ_VERSION}\n~~~\n"
        COMPRESS_UTIL="xz"
        COMPRESS_FORMAT="${COMPRESS_UTIL}"

    else
        echo -e "\nXZ util not found: using gzip\n"
        COMPRESS_UTIL="gzip"
        COMPRESS_FORMAT="gz"
    fi

elif [[ ${COMPRESS_UTIL} == "gz" ]]; then
    COMPRESS_UTIL="gzip"
    COMPRESS_FORMAT="gz"

elif [[ ${COMPRESS_UTIL} == "gzip" ]]; then
    COMPRESS_FORMAT="gz"

elif [[ ${COMPRESS_UTIL} == "xz" ]]; then
    COMPRESS_FORMAT="${COMPRESS_UTIL}"

else
    MSG="Invalid Compress Util: ${COMPRESS_UTIL} (Values: gzip, xz)"
    print_error
fi


echo -e "\nNOTE: A temporary directory will be created in order to store the information about the 3scale dump: ${DUMP_DIR}\n\nPress [ENTER] to continue or <Ctrl + C> to abort...\n"
read TEMP


# Create the Dump Directory if it does not exist:

if [[ ! -d ${DUMP_DIR}/status/apicast-staging ]] || [[ ! -d ${DUMP_DIR}/status/apicast-production ]]; then
    MKDIR=$(mkdir -pv ${DUMP_DIR}/status/{apicast-staging,apicast-production} 2>&1)

    while read ITEM; do
        echo -e "\t${ITEM}"
    done <<< "${MKDIR}"

    if [[ ! -d ${DUMP_DIR}/status/apicast-staging ]] || [[ ! -d ${DUMP_DIR}/status/apicast-production ]]; then
        MSG="Unable to create: ${DUMP_DIR}/status"
        print_error
    fi
fi


# 1. Fetch the status from all the pods and events #

echo -e "\n1. Fetch: All pods and Events\n"

oc get pod -o wide > ${DUMP_DIR}/status/pods-all.txt 2>&1

oc get pod -o wide | grep -iv "deploy" > ${DUMP_DIR}/status/pods.txt 2>&1

oc get event > ${DUMP_DIR}/status/events.txt 2>&1


# 2. DeploymentConfig objects #

echo -e "\n2. Fetch: DeploymentConfig\n"

NEWDIR="dc"
SINGLE_FILE="dc.yaml"
COMMAND="oc get dc"

VALIDATE_PODS=1

create_dir
execute_command
read_obj
cleanup


# 3. Fetch and compress the logs #

echo -e "\n3. Fetch: Logs\n"

NEWDIR="logs"
SINGLE_FILE="logs.txt"
COMMAND="oc logs --all-containers"

VALIDATE_PODS=1
SUBSTRING=1
COMPRESS=1
VERBOSE=1
NOYAML=1

cat ${DUMP_DIR}/status/pods.txt | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

create_dir
read_obj
cleanup

if [[ ${COMPRESS_UTIL} == "xz" ]]; then
    echo -e '#!/bin/bash\n\nfor FILE in *.xz; do\n\txz -d ${FILE}\n\ndone' > ${DUMP_DIR}/logs/uncompress-logs.sh

else
    echo -e '#!/bin/bash\n\nfor FILE in *.gz; do\n\tgunzip ${FILE}\n\ndone' > ${DUMP_DIR}/logs/uncompress-logs.sh
fi

chmod +x ${DUMP_DIR}/logs/uncompress-logs.sh


# 4. Secrets #

echo -e "\n4. Fetch: Secrets\n"

NEWDIR="secrets"
SINGLE_FILE="secrets.yaml"
COMMAND="oc get secret"

create_dir
execute_command
read_obj
cleanup


# 5. Routes #

echo -e "\n5. Fetch: Routes\n"

NEWDIR="routes"
SINGLE_FILE="routes.yaml"
COMMAND="oc get route"

create_dir
execute_command
read_obj
cleanup


# 6. Services #

echo -e "\n6. Fetch: Services\n"

NEWDIR="services"
SINGLE_FILE="services.yaml"
COMMAND="oc get service"

create_dir
execute_command
read_obj
cleanup


# 7. Image Streams #

echo -e "\n7. Fetch: Image Streams\n"

NEWDIR="images"
SINGLE_FILE="images.yaml"
COMMAND="oc get imagestream"

create_dir
execute_command
read_obj
cleanup


# 8. ConfigMaps #

echo -e "\n8. Fetch: ConfigMaps\n"

NEWDIR="configmaps"
SINGLE_FILE="configmaps.yaml"
COMMAND="oc get configmap"

create_dir
execute_command
read_obj
cleanup


# 9. PV #

echo -e "\n9. Fetch: PV\n"

NEWDIR="pv"
SINGLE_FILE="pv.yaml"
COMMAND="oc get pv"

${COMMAND} > ${DUMP_DIR}/status/pv.txt 2>&1

create_dir
execute_command
read_obj
cleanup

NEWDIR="pv/describe"
SINGLE_FILE="pv/describe.txt"
COMMAND="oc get pv"

create_dir
execute_command
cleanup

while read PV; do
    DESCRIBE=$(oc describe pv ${PV} 2>&1)

    echo -e "${DESCRIBE}" > ${DUMP_DIR}/pv/describe/${PV}.txt
    echo -e "${DESCRIBE}\n" >> ${DUMP_DIR}/pv/describe.txt
done < ${DUMP_DIR}/temp.txt


# 10. PVC #

echo -e "\n10. Fetch: PVC\n"

NEWDIR="pvc"
SINGLE_FILE="pvc.yaml"
COMMAND="oc get pvc"

${COMMAND} > ${DUMP_DIR}/status/pvc.txt 2>&1

create_dir
execute_command
read_obj
cleanup

NEWDIR="pvc/describe"
SINGLE_FILE="pvc/describe.txt"
COMMAND="oc get pvc"

create_dir
execute_command
cleanup

while read PVC; do
    DESCRIBE=$(oc describe pvc ${PVC} 2>&1)

    echo -e "${DESCRIBE}" > ${DUMP_DIR}/pvc/describe/${PVC}.txt
    echo -e "${DESCRIBE}\n" >> ${DUMP_DIR}/pvc/describe.txt
done < ${DUMP_DIR}/temp.txt


# 11. ServiceAccounts #

echo -e "\n11. Fetch: ServiceAccounts\n"

NEWDIR="serviceaccounts"
SINGLE_FILE="serviceaccounts.yaml"
COMMAND="oc get serviceaccount"

create_dir
execute_command
read_obj
cleanup


# 12. Status: Node #

echo -e "\n12. Status: Node"

oc describe node > ${DUMP_DIR}/status/node.txt 2>&1


# Variables used on 13+ #

APICAST_POD_STG=$(oc get pod | grep -i "apicast-staging" | grep -iv "deploy" | head -n 1 | awk '{print $1}')

if [[ -n ${APICAST_POD_STG} ]]; then
    MGMT_API_STG=$(oc rsh ${APICAST_POD_STG} /bin/bash -c "env | grep 'APICAST_MANAGEMENT_API=' | head -n 1 | cut -d '=' -f 2" < /dev/null)
    APICAST_ROUTE_STG=$(oc get route | grep -i "apicast-staging" | grep -v NAME | head -n 1 | awk '{print $2}')
fi

APICAST_POD_PRD=$(oc get pod | grep -i "apicast-production" | grep -iv "deploy" | head -n 1 | awk '{print $1}')

if [[ -n ${APICAST_POD_PRD} ]]; then
    MGMT_API_PRD=$(oc rsh ${APICAST_POD_PRD} /bin/bash -c "env | grep 'APICAST_MANAGEMENT_API=' | head -n 1 | cut -d '=' -f 2" < /dev/null)
    APICAST_ROUTE_PRD=$(oc get route | grep -i "apicast-production" | grep -v NAME | head -n 1 | awk '{print $2}')
fi

WILDCARD_POD=$(oc get pod | grep -i "apicast-wildcard-router" | grep -iv "deploy" | grep -v NAME | head -n 1 | awk '{print $1}')

if [[ -n ${APICAST_POD_STG} ]]; then
    THREESCALE_PORTAL_ENDPOINT=$(oc rsh ${APICAST_POD_STG} /bin/bash -c "env | grep 'THREESCALE_PORTAL_ENDPOINT=' | head -n 1 | cut -d '=' -f 2" < /dev/null)
fi

echo -e "\n\tAPICAST_POD_PRD: ${APICAST_POD_PRD}\n\tAPICAST_POD_STG: ${APICAST_POD_STG}\n\tMGMT_API_PRD: ${MGMT_API_PRD}\n\tMGMT_API_STG: ${MGMT_API_STG}\n\tAPICAST_ROUTE_PRD: ${APICAST_ROUTE_PRD}\n\tAPICAST_ROUTE_STG: ${APICAST_ROUTE_STG}\n\tWILDCARD POD: ${WILDCARD_POD}\n\tTHREESCALE_PORTAL_ENDPOINT: ${THREESCALE_PORTAL_ENDPOINT}"
sleep 3

echo -e '#!/bin/bash\n\nfor FILE in *.json; do\n\tpython -m json.tool ${FILE} > ${FILE}.filtered ; sleep 0.5 ; mv -f ${FILE}.filtered ${FILE}\n\ndone' > ${DUMP_DIR}/status/apicast-staging/python-json.sh
chmod +x ${DUMP_DIR}/status/apicast-staging/python-json.sh

echo -e '#!/bin/bash\n\nfor FILE in *.json; do\n\tpython -m json.tool ${FILE} > ${FILE}.filtered ; sleep 0.5 ; mv -f ${FILE}.filtered ${FILE}\n\ndone' > ${DUMP_DIR}/status/apicast-production/python-json.sh
chmod +x ${DUMP_DIR}/status/apicast-production/python-json.sh


# 13. Status: 3scale Echo API #

echo -e "\n13. Status: 3scale Echo API"

if [[ -n ${APICAST_POD_STG} ]]; then
    timeout 10 oc rsh ${APICAST_POD_STG} /bin/bash -c "curl -k -vvv https://echo-api.3scale.net" > ${DUMP_DIR}/status/apicast-staging/3scale-echo-api-staging.txt 2>&1 < /dev/null
fi

if [[ -n ${APICAST_POD_PRD} ]]; then
    timeout 10 oc rsh ${APICAST_POD_PRD} /bin/bash -c "curl -k -vvv https://echo-api.3scale.net" > ${DUMP_DIR}/status/apicast-production/3scale-echo-api-production.txt 2>&1 < /dev/null
fi


# 14. Status: Staging/Production Backend JSON #

echo -e "\n14. Status: Staging/Production Backend JSON"

if [[ -n ${APICAST_POD_STG} ]]; then
    timeout 10 oc rsh ${APICAST_POD_STG} /bin/bash -c "curl -X GET -H 'Accept: application/json' -k ${THREESCALE_PORTAL_ENDPOINT}/staging.json" > ${DUMP_DIR}/status/apicast-staging/apicast-staging.json 2> ${DUMP_DIR}/status/apicast-staging/apicast-staging-json-debug.txt < /dev/null

    timeout 10 oc rsh ${APICAST_POD_STG} /bin/bash -c "curl -X GET -H 'Accept: application/json' -k ${THREESCALE_PORTAL_ENDPOINT}/production.json" > ${DUMP_DIR}/status/apicast-staging/apicast-production.json 2> ${DUMP_DIR}/status/apicast-staging/apicast-production-json-debug.txt < /dev/null
fi

if [[ -n ${APICAST_POD_PRD} ]]; then
    timeout 10 oc rsh ${APICAST_POD_PRD} /bin/bash -c "curl -X GET -H 'Accept: application/json' -k ${THREESCALE_PORTAL_ENDPOINT}/staging.json" > ${DUMP_DIR}/status/apicast-production/apicast-staging.json 2> ${DUMP_DIR}/status/apicast-production/apicast-staging-json-debug.txt < /dev/null

    timeout 10 oc rsh ${APICAST_POD_PRD} /bin/bash -c "curl -X GET -H 'Accept: application/json' -k ${THREESCALE_PORTAL_ENDPOINT}/production.json" > ${DUMP_DIR}/status/apicast-production/apicast-production.json 2> ${DUMP_DIR}/status/apicast-production/apicast-production-json-debug.txt < /dev/null
fi


# 15. Status: Management API #

echo -e "\n15. Status: Management API"

if [[ -n ${APICAST_POD_STG} ]]; then
    OUTPUT="${DUMP_DIR}/status/apicast-staging/mgmt-api"
    APICAST_POD="${APICAST_POD_STG}"
    MGMT_API="${MGMT_API_STG}"

    mgmt_api
fi

if [[ -n ${APICAST_POD_PRD} ]]; then
    OUTPUT="${DUMP_DIR}/status/apicast-production/mgmt-api"
    APICAST_POD="${APICAST_POD_PRD}"
    MGMT_API="${MGMT_API_PRD}"

    mgmt_api
fi


# 16. APIcast Status: APIcast Certificates #

echo -e "\n16. Status: APIcast Certificates"

if [[ -n ${APICAST_POD_STG} ]]; then
    timeout 10 oc rsh ${WILDCARD_POD} /bin/bash -c "echo | openssl s_client -connect ${APICAST_ROUTE_STG}:443" > ${DUMP_DIR}/status/apicast-staging/certificate.txt 2>&1 < /dev/null
fi

if [[ -n ${APICAST_POD_PRD} ]]; then
    timeout 10 oc rsh ${WILDCARD_POD} /bin/bash -c "echo | openssl s_client -connect ${APICAST_ROUTE_PRD}:443" > ${DUMP_DIR}/status/apicast-production/certificate.txt 2>&1 < /dev/null
fi


# 17. Status: Project and Pods 'runAsUser' (Database RW issues) #

echo -e "\n17. Status: Status: Project and Pods 'runAsUser'"

oc get project ${THREESCALE_PROJECT} -o yaml > ${DUMP_DIR}/status/project.txt

cat ${DUMP_DIR}/status/pods.txt | awk '{print $1}' | tail -n +2 > ${DUMP_DIR}/temp.txt

while read POD; do
    RUNASUSER=$(oc get pod ${POD} -o yaml | grep "runAsUser" | head -n 1 | cut -d ":" -f 2 | sed "s@ @@g")

    echo -e "Pod: ${POD} | RunAsUser: ${RUNASUSER}\n" >> ${DUMP_DIR}/status/pods-run-as-user.txt

done < ${DUMP_DIR}/temp.txt


# Compact the Directory

echo -e "\n# Compacting... #\n"

if [[ -f ${DUMP_FILE} ]]; then
    /bin/rm -f ${DUMP_FILE}

    if [[ -f ${DUMP_FILE} ]]; then
        MSG="There was an error deleting ${DUMP_FILE}"
        print_error
    fi
fi

/bin/rm -f ${DUMP_DIR}/temp.txt

tar cpf ${DUMP_FILE} --xform s:'./':: ${DUMP_DIR}

if [[ ! -f ${DUMP_FILE} ]]; then
    MSG="There was an error creating ${DUMP_FILE}"
    print_error

else
    # Cleanup (less aggressive than "rm -fr ...") #

    echo -e "\n# Cleanup... #\n"

    sleep 3

    REMOVE=$(/bin/rm -fv ${DUMP_DIR}/status/apicast-staging/python-json.sh 2>&1)
    echo -e "\t\t${REMOVE}"
    
    TARGET_DIR="status/apicast-staging"
    cleanup_dir

    REMOVE=$(/bin/rm -fv ${DUMP_DIR}/status/apicast-production/python-json.sh 2>&1)
    echo -e "\t\t${REMOVE}"   

    TARGET_DIR="status/apicast-production"
    cleanup_dir

    TARGET_DIR="status"
    cleanup_dir

    TARGET_DIR="dc"
    cleanup_dir

    REMOVE=$(/bin/rm -fv ${DUMP_DIR}/logs/uncompress-logs.sh 2>&1)
    echo -e "\t\t${REMOVE}"   

    TARGET_DIR="logs"
    COMPRESS=1
    cleanup_dir

    TARGET_DIR="secrets"
    cleanup_dir

    TARGET_DIR="routes"
    cleanup_dir

    TARGET_DIR="services"
    cleanup_dir

    TARGET_DIR="images"
    cleanup_dir

    TARGET_DIR="configmaps"
    cleanup_dir

    TARGET_DIR="pv/describe"
    cleanup_dir

    TARGET_DIR="pv"
    cleanup_dir

    TARGET_DIR="pvc/describe"
    cleanup_dir

    TARGET_DIR="pvc"
    cleanup_dir

    TARGET_DIR="serviceaccounts"
    cleanup_dir

    TARGET_DIR="dump_dir"
    cleanup_dir

    echo -e "\nFile created: ${DUMP_FILE}\n"

    if [[ -d ${DUMP_DIR} ]]; then
        echo -e "\nPlease remove manually the temporary directory: ${DUMP_DIR}\n"
    fi
    
    exit 0
fi
