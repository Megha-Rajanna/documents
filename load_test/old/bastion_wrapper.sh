#!/usr/bin/env bash

HOSTS=$1
SPANS=$2
DURATION=$3

TEST_NAME="s390x_small_${HOSTS}H${SPANS}S"

START_TIME=$(TZ="Asia/Kolkata" date +"%Y-%m-%d %H:%M")
END_TIME=$(TZ="Asia/Kolkata" date +"%Y-%m-%d %H:%M" -d "+1 hour")
EXPORT_END_TIME=$(TZ="Asia/Kolkata" date +"%Y-%m-%d %H:%M" -d "+1 hour 5 minutes")

echo "--------------------------------------------------"
echo "Start Time -> ${START_TIME}"
echo "End Time -> ${END_TIME}"
echo "Export End Time -> ${EXPORT_END_TIME}"
echo "--------------------------------------------------"

./fail_test.sh -l ${TEST_NAME}_failtest -t true -b true -e "${END_TIME}" -i "instana-cassandra-default-sts-0"
sleep 300
./export_metrics.sh -a "instana-core instana-units instana-operator instana-clickhouse instana-kafka instana-cassandra instana-postgres instana-elastic instana-zookeeper beeinstana" -f ${TEST_NAME}_metrics -s "${START_TIME}" -e "${EXPORT_END_TIME}"