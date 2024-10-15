#!/usr/bin/env bash
# Client Test Control Script

# Variables
COOL_OFF_INTERVAL=1800
TEST_FILE="tests.txt"
TRIGGER_FILE="trigger_file"
PROFILE="small"
CLUSTER=""
AGENT_KEY=""
BASTION_NODE="root@api.${CLUSTER}"

# Read list of tests into an TEST_ARRAY 
readarray -t TEST_ARRAY < ${TEST_FILE}

# Loop through each test in the array
for TEST in "${TEST_ARRAY[@]}"
do
    # Get number of hosts, spans and timing for each test
    HOSTS=$(echo ${TEST} | cut -f1 -d,)
    SPANS=$(echo ${TEST} | cut -f2 -d,)
    ID=$(TZ="Asia/Kolkata" date +"%Y%m%d%H%M")
    DURATION_HOUR=$(echo ${TEST} | cut -f3 -d,)
    let DURATION_MINS=${DURATION_HOUR#0}*60

    # Compute name of the test
    TEST_NAME="s390x_${PROFILE}_${HOSTS}H${SPANS}S_${ID}"

    echo "Writing ${TRIGGER_FILE} with contents ${HOSTS},${SPANS},${DURATION_HOUR} to ${BASTION_NODE}" 
    ssh ${BASTION_NODE} "echo ${HOSTS},${SPANS},${DURATION_HOUR},${ID} > ${TRIGGER_FILE}"

    # Decide whether to enable metrics/traces 
    METRICS=false
    TRACES=false

    if [ "${HOSTS}" -gt 0 ];
    then
        METRICS=true
    fi

    if [ "${SPANS}" -gt 0 ];
    then
        TRACES=true
    fi

    # Print useful info
    echo "Starting load test -> ${TEST_NAME}"
    echo "Target Cluster -> ${CLUSTER}"
    echo "Metrics enabled -> ${METRICS}"
    echo "Traces enabled -> ${TRACES}"

    # Start the actual test
    ./start_test.sh -a agent.instana.apps.${CLUSTER} -k "${AGENT_KEY}" -f "${TEST_NAME}_load" -e off -m ${METRICS} -s ${TRACES} -t "${DURATION_MINS}" -r 10 -o "${HOSTS}" -n "${SPANS}" -c 11

    echo "Sleeping for ${COOL_OFF_INTERVAL} seconds before next run..."
    sleep ${COOL_OFF_INTERVAL}

    # Do couple of newlines before starting the next test
    printf "\n\n"
done

