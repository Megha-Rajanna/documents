#!/usr/bin/env bash

HOSTS=$1
SPANS=$2
DURATION_HOUR=$3

let DURATION_MINS=${DURATION_HOUR#0}*60

TEST_NAME="s390x_small_${HOSTS}H${SPANS}S"

./start_test.sh -a ingress.instana.apps.instanaons390x.cp.fyre.ibm.com -k <agent_key> -f ${TEST_NAME}_load -m true -s true -t ${DURATION_MINS} -r 10 -o ${HOSTS} -n ${SPANS} -c 11
