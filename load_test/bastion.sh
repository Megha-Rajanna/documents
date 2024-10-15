#!/usr/bin/env bash
# Bastion Test Control Script

# Variables
PROFILE=small
TRIGGER_FILE="${HOME}/trigger_file"
EXPORT_INTERVAL=300
RETRY_INTERVAL=10

# Loop looking for test file
while [ 1 ]
do
    # Check if the file exists 
    if [ -f ${TRIGGER_FILE} ]
    then
        echo "${TRIGGER_FILE} found, reading arguments from the file"
        HOSTS=$(cut -f1 -d, ${TRIGGER_FILE})
        SPANS=$(cut -f2 -d, ${TRIGGER_FILE})
        DURATION=$(cut -f3 -d, ${TRIGGER_FILE})
        ID=$(cut -f4 -d, ${TRIGGER_FILE})

        # Calculate time-frame
        START_TIME=$(TZ="Asia/Kolkata" date +"%Y-%m-%d %H:%M")
        END_TIME=$(TZ="Asia/Kolkata" date +"%Y-%m-%d %H:%M" -d "+${DURATION} hour")
        EXPORT_END_TIME=$(TZ="Asia/Kolkata" date +"%Y-%m-%d %H:%M" -d "+${DURATION} hour 5 minutes")

        # Compute name of the test
        TEST_NAME="s390x_${PROFILE}_${HOSTS}H${SPANS}S_${ID}"

        # Log test details
        echo "${TEST_NAME} -> ${START_TIME} <---> ${END_TIME}" >> test.log

        echo "Deleting ${TRIGGER_FILE}"
        rm ${TRIGGER_FILE}

        echo "Triggering pod failure monitor..."
        echo fail_test.sh -l "${TEST_NAME}_failtest" -t true -b true -e "${END_TIME}" -i "instana-cassandra-default-sts-0"
        ./fail_test.sh -l "${TEST_NAME}_failtest" -t true -b true -e "${END_TIME}" -i "instana-cassandra-default-sts-0"

        echo "Sleeping for ${EXPORT_INTERVAL} seconds before exporting..."
        sleep ${EXPORT_INTERVAL} 

        # Export metrics collected from the test
        echo "Exporting metrics..."
        echo export_metrics.sh -a "instana-core instana-units instana-operator instana-clickhouse instana-kafka instana-cassandra instana-postgres instana-elastic instana-zookeeper beeinstana" -f "${TEST_NAME}_metrics" -s "${START_TIME}" -e "${EXPORT_END_TIME}"
        ./export_metrics.sh \
            -a "instana-core instana-units \
            instana-operator \
            instana-clickhouse \
            instana-kafka \
            instana-cassandra \
            instana-postgres \
            instana-elastic \
            instana-zookeeper \
            beeinstana" \
            -f "${TEST_NAME}_metrics" \
            -s "${START_TIME}" \
            -e "${EXPORT_END_TIME}"
        
        # Print couple of newlines to separate new output
        printf "\n\n"

	echo "Running IOPS Tests..."
	sleep 60
	oc exec -it fio-pod -n dbench -- "/root/docker-entrypoint.sh" &> ${TEST_NAME}.iops
    fi

    echo "Retrying for ${TRIGGER_FILE} in ${RETRY_INTERVAL} seconds..."
    sleep ${RETRY_INTERVAL} 
done
