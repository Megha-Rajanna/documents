#/bin/bash
print_red() {
  echo -e "\e[31m$1\e[0m"
}

print_green() {
  echo -e "\e[32m$1\e[0m"
}

print_green "Instana Fail test\n===================="

if [ "$1" = "-h" ]; then
  echo "
This script help you to check the pod failures and spandrops in instana on ocp.

Usage:
  sh fail_test.sh [flags]

flags:
      -l    Specify filename for saving reports (required).

      -r    Polling Interval (in sec) (default 1s)
      -m    Maximum no.of pod crashes to be recorded (default 100 / 0 for unlimited)
      -d    Enable Instana Datastore API datastores Count (default false)
      -t    Enable Third-Party Datastores Count (default false)
      -b    Enable beeinstana Datastore Count (default false)
      -e    End time in IST (yyyy-mm-dd hh:mm:ss format)
      -i    Pods that can be ignored
      -s    Enable Span Drops check (default false)"
  exit 0
fi
TP="false"
DP="false"
NOOFCRASH=0
PODCOUNT=0
LOCATION=""
RATE=1
SPANDROPS="false"
ENDTIME=""
TIMEZONE="Asia/Kolkata"
BEE="false"
IGNORE=""
while getopts 'n:l:r:m:t:d:e:b:i:s:' OPTION; do
  case "$OPTION" in
  s)
    SPANDROPS="$OPTARG"
    ;;
  i)
    IGNORE="$OPTARG"
    ;;
  b)
    BEE="$OPTARG"
    ;;
  e)
    ENDTIME="$OPTARG"
    ;;
  d)
    DP="$OPTARG"
    ;;
  t)
    TP="$OPTARG"
    ;;
  m)
    NOOFCRASH="$OPTARG"
    ;;
  l)
    LOCATION="$OPTARG"
    ;;
  r)
    RATE="$OPTARG"
    ;;
  ?)
    print_red "Try 'sh fail_test.sh -h' for more information."
    exit 0
    ;;
  esac
done
shift "$(($OPTIND - 1))"
if [ "$LOCATION" = "" ]; then
  print_red "\nplease specify file name..!"
  print_red "Try 'sh fail_test.sh -h' for more information."
  exit 0
fi
ignore_list=()
if [ "$IGNORE" != "" ]; then
  IFS=' ' read -ra elements <<<"$IGNORE"
  for element in "${elements[@]}"; do
    ignore_list+=("$element")
  done
fi
TMP_CNT=$(($(oc get po -n instana-core | wc -l) - 1))
PODCOUNT=$((PODCOUNT + TMP_CNT))
print_green "available instana-core pods : $TMP_CNT"
TMP_CNT=$(($(oc get po -n instana-units | wc -l) - 1))
PODCOUNT=$((PODCOUNT + TMP_CNT))
print_green "\navailable instana-units pods : $TMP_CNT"
TMP_CNT=$(($(oc get po -n instana-operator | wc -l) - 1))
PODCOUNT=$((PODCOUNT + TMP_CNT))
print_green "\navailable instana-operator pods : $TMP_CNT"
if [ "$TP" = "true" ]; then
  TMP_CNT=$(($(oc get po -n instana-clickhouse | wc -l) - 1))
  CLICKHOUSE_SHARDS=
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-clickhouse pods : $TMP_CNT"
  TMP_CNT=$(($(oc get po -n instana-postgres | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-postgres pods : $TMP_CNT"
  TMP_CNT=$(($(oc get po -n instana-cassandra | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-cassandra pods : $TMP_CNT"
  TMP_CNT=$(($(oc get po -n instana-zookeeper | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-zookeeper pods : $TMP_CNT"
  TMP_CNT=$(($(oc get po -n instana-elastic | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-elastic pods : $TMP_CNT"
  TMP_CNT=$(($(oc get po -n instana-kafka | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-kafka pods : $TMP_CNT"
fi
if [ "$DP" = "true" ]; then
  TMP_CNT=$(($(oc get po -n instana-db | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable instana-db pods : $TMP_CNT"
fi
if [ "$BEE" = "true" ]; then
  TMP_CNT=$(($(oc get po -n beeinstana | wc -l) - 1))
  PODCOUNT=$((PODCOUNT + TMP_CNT))
  print_green "\navailable beeinstana pods : $TMP_CNT"
fi
print_green "\nTotal Pod Count : $PODCOUNT"
print_green "Starting Fail Test..."
COUNT=0
rm -fr $LOCATION
mkdir $LOCATION
echo -e "Instana Pod Failure Report\n==========================" >"${LOCATION}/report.txt"
START_TIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
START_TIME_IST=$(TZ="$TIMEZONE" date -d "$START_TIME" "+%Y-%m-%d %H:%M:%S %Z")
END_TIME_FORMATED=""
if [ "$ENDTIME" != "" ]; then
  END_TIME_FORMATED=$(date -d "$ENDTIME IST" -u "+%Y%m%d%H%M%S")
fi
while true; do
  echo "=================INSTANA POD FAIL TEST=================="
  echo -e "====FAILED PODS====\n"
  NO_OF_PODS=0
  function process_pods() {
    local NAMESPACE="$1"
    KINDS=()
    if [ "$2" = "0" ]; then
      KINDS=("deployments")
    fi
    if [ "$2" = "1" ]; then
      KINDS=("statefulsets")
    fi
    if [ "$2" = "2" ]; then
      KINDS=("deployments" "statefulsets")
    fi
    if [ "$2" = "3" ]; then
      KINDS=("deployments" "strimzipodsets")
    fi
    for KIND in "${KINDS[@]}"; do
      local PODS="$(oc get $KIND -n $NAMESPACE)"
      if [ "$KIND" != "strimzipodsets" ]; then
        while read line; do
          line=$(echo "$line" | tr -s ' ')
          local STATUS=$(echo "$line" | cut -d " " -f 2)
          local RUNNING=$(echo "$line" | cut -d " " -f 4)
          local ST1=$(echo "$STATUS" | cut -d "/" -f 1)
          local ST2=$(echo "$STATUS" | cut -d "/" -f 2)
          if [ "$RUNNING" != "AVAILABLE" ]; then
            NO_OF_PODS=$((NO_OF_PODS + ST1))
          fi
          if [ "$ST1" != "$ST2" ] && [ "$RUNNING" != "AVAILABLE" ]; then
            local DEPNAME=$(echo "$line" | cut -d " " -f 1)
            local PODNAMES=$(oc get po -n "$NAMESPACE" | grep "^$DEPNAME" | tr -s ' ')
            local PODNAME=""
            while read p; do
              local R=$(echo "$p" | cut -d " " -f 2)
              local R1=$(echo "$R" | cut -d "/" -f 1)
              local R2=$(echo "$R" | cut -d "/" -f 2)
              if [ "$R1" != "$R2" ]; then
                PODNAME=$(echo "$p" | cut -d " " -f 1)
              fi
            done <<<"$PODNAMES"
            local NOTIN=true
            for pod in "${ignore_list[@]}"; do
              if echo "$PODNAME" | grep -q "$pod"; then
                NOTIN=false
              fi
            done
            if $NOTIN; then
              COUNT=$((COUNT + 1))
              local NODENAME=$(kubectl get pod "$PODNAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
              echo -e "\nCURRENT LOG\n=============\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              oc logs "$PODNAME" -n "$NAMESPACE" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nPREVIOUS LOG\n=============\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              oc logs --previous "$PODNAME" -n "$NAMESPACE" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nPOD_DETAILS\n===========\npodname : $PODNAME \nnode at which pod is running : $NODENAME \n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nCPU_AND_MEMORY_USAGE_OF_POD\n==============================\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              kubectl top pod "$PODNAME" -n "$NAMESPACE" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nCPU_AND_MEMORY_USAGE_OF_NODE\n=============================\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              kubectl top node "$NODENAME" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nCPU_AND_MEMORY_USAGE_OF_ALL_NODES\n==============================\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              kubectl top node &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo "$line"
              echo "${COUNT}_${PODNAME}.txt -> $(TZ="$TIMEZONE" date) ===>  $line" >>"${LOCATION}/report.txt"
            fi
          fi
        done <<<"$PODS"
      fi
      if [ "$KIND" == "strimzipodsets" ]; then
        while read line; do
          line=$(echo "$line" | tr -s ' ')
          local ST1=$(echo "$line" | cut -d " " -f 2)
          local ST2=$(echo "$line" | cut -d " " -f 3)
          if [ "$ST1" != "PODS" ]; then
            NO_OF_PODS=$((NO_OF_PODS + ST1))
          fi
          if [ "$ST1" != "$ST2" ] && [ "$ST1" != "PODS" ]; then
            local DEPNAME=$(echo "$line" | cut -d " " -f 1)
            local PODNAMES=$(oc get po -n "$NAMESPACE" | grep "^$DEPNAME" | tr -s ' ')
            local PODNAME=""
            while read p; do
              local R=$(echo "$p" | cut -d " " -f 2)
              local R1=$(echo "$R" | cut -d "/" -f 1)
              local R2=$(echo "$R" | cut -d "/" -f 2)
              if [ "$R1" != "$R2" ]; then
                PODNAME=$(echo "$p" | cut -d " " -f 1)
              fi
            done <<<"$PODNAMES"
            local NOTIN=true
            for pod in "${ignore_list[@]}"; do
              if echo "$PODNAME" | grep -q "$pod"; then
                NOTIN=false
              fi
            done
            if $NOTIN; then
              COUNT=$((COUNT + 1))
              local NODENAME=$(kubectl get pod "$PODNAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
              echo -e "\nCURRENT LOG\n=============\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              oc logs "$PODNAME" -n "$NAMESPACE" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nPREVIOUS LOG\n=============\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              oc logs --previous "$PODNAME" -n "$NAMESPACE" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nPOD_DETAILS\n===========\npodname : $PODNAME \nnode at which pod is running : $NODENAME \n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nCPU_AND_MEMORY_USAGE_OF_POD\n==============================\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              kubectl top pod "$PODNAME" -n "$NAMESPACE" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nCPU_AND_MEMORY_USAGE_OF_NODE\n=============================\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              kubectl top node "$NODENAME" &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo -e "\nCPU_AND_MEMORY_USAGE_OF_ALL_NODES\n==============================\n" >>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              kubectl top node &>>"${LOCATION}/${COUNT}_${PODNAME}.txt"
              echo "$line"
              echo "${COUNT}_${PODNAME}.txt -> $(TZ="$TIMEZONE" date) ===>  $line" >>"${LOCATION}/report.txt"
            fi
          fi
        done <<<"$PODS"
      fi
    done
  }
  process_pods "instana-operator" "0"
  if [ "$TP" = "true" ]; then
    process_pods "instana-clickhouse" "2"
    process_pods "instana-postgres" "2"
    process_pods "instana-cassandra" "2"
    process_pods "instana-zookeeper" "0"
    process_pods "instana-elastic" "1"
    process_pods "instana-kafka" "3"
  fi
  if [ "$DP" = "true" ]; then
    process_pods "instana-db" "1"
  fi
  if [ "$BEE" = "true" ]; then
    process_pods "beeinstana" "2"
  fi
  process_pods "instana-core" "0"
  process_pods "instana-units" "0"
  if ((NO_OF_PODS >= PODCOUNT)); then
    echo "NO PODS WERE FAILED"
  else
    echo -e " \nTHESE PODS ARE NOT READY..!"
  fi
  echo "No of Pods = $NO_OF_PODS / $PODCOUNT"
  echo "========================================================"
  sleep $RATE

  if (($COUNT > $NOOFCRASH)) && ((NOOFCRASH != 0)); then
    break
  fi
  if [ "$END_TIME_FORMATED" != "" ]; then
    CURR_TIME=$(date -u "+%Y%m%d%H%M%S")
    if ((END_TIME_FORMATED < CURR_TIME)); then
      break
    fi
  fi
  clear
done

END_TIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
END_TIME_IST=$(TZ="$TIMEZONE" date -d "$END_TIME" "+%Y-%m-%d %H:%M:%S %Z")

cat >${LOCATION}/test.txt <<EOF
TESTNAME: $LOCATION
TIMEZONE: $TIMEZONE
START_TIME:$START_TIME_IST
END_TIME:$END_TIME_IST
MONITORED POD DETAILS
=====================
EOF
TMP_CNT=$(($(oc get po -n instana-core | wc -l) - 1))
echo -e "\n$(oc get po -n instana-core)" >>${LOCATION}/test.txt
echo -e "\navailable instana-core pods : $TMP_CNT" >>${LOCATION}/test.txt
TMP_CNT=$(($(oc get po -n instana-units | wc -l) - 1))
echo -e "\n$(oc get po -n instana-units)" >>${LOCATION}/test.txt
echo -e "\navailable instana-units pods : $TMP_CNT" >>${LOCATION}/test.txt
TMP_CNT=$(($(oc get po -n instana-operator | wc -l) - 1))
echo -e "\n$(oc get po -n instana-operator)" >>${LOCATION}/test.txt
echo -e "\navailable instana-operator pods : $TMP_CNT" >>${LOCATION}/test.txt
if [ "$TP" = "true" ]; then
  TMP_CNT=$(($(oc get po -n instana-clickhouse | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-clickhouse)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-clickhouse pods : $TMP_CNT" >>${LOCATION}/test.txt
  TMP_CNT=$(($(oc get po -n instana-postgres | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-postgres)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-postgres pods : $TMP_CNT" >>${LOCATION}/test.txt
  TMP_CNT=$(($(oc get po -n instana-cassandra | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-cassandra)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-cassandra pods : $TMP_CNT" >>${LOCATION}/test.txt
  TMP_CNT=$(($(oc get po -n instana-zookeeper | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-zookeeper)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-zookeeper pods : $TMP_CNT" >>${LOCATION}/test.txt
  TMP_CNT=$(($(oc get po -n instana-elastic | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-elastic)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-elastic pods : $TMP_CNT" >>${LOCATION}/test.txt
  TMP_CNT=$(($(oc get po -n instana-kafka | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-kafka)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-kafka pods : $TMP_CNT" >>${LOCATION}/test.txt
fi
if [ "$DP" = "true" ]; then
  TMP_CNT=$(($(oc get po -n instana-db | wc -l) - 1))
  echo -e "\n$(oc get po -n instana-db)" >>${LOCATION}/test.txt
  echo -e "\navailable instana-db pods : $TMP_CNT" >>${LOCATION}/test.txt
fi
if [ "$BEE" = "true" ]; then
  TMP_CNT=$(($(oc get po -n beeinstana | wc -l) - 1))
  echo -e "\n$(oc get po -n beeinstana)" >>${LOCATION}/test.txt
  echo -e "\navailable beeinstana pods : $TMP_CNT" >>${LOCATION}/test.txt
fi
echo -e "\nTotal Pod Count : $PODCOUNT" >>${LOCATION}/test.txt
if [ "$SPANDROPS" = "true" ]; then
  rm -fr ${LOCATION}/spandrops.txt
  UTC_START_TIME=$(date -d "$START_TIME_IST" -u "+%Y-%m-%d %H:%M:%S %Z")
  UTC_END_TIME=$(date -d "$END_TIME_IST" -u "+%Y-%m-%d %H:%M:%S %Z")
  FORMATTED_UTC_START_TIME=$(date -u -d "$UTC_START_TIME" "+%Y-%m-%d %H:%M:%S")
  FORMATTED_UTC_END_TIME=$(date -u -d "$UTC_END_TIME" "+%Y-%m-%d %H:%M:%S")
  echo -e "\nSPAN_DROPS\n============\n" >> ${LOCATION}/spandrops.txt
  S=0
  E=0
  CLICKHOUSE_SHARDS=$(oc get po -n instana-clickhouse | grep '^chi' | wc -l)
  for NO in $(seq 0 $((CLICKHOUSE_SHARDS - 1))); do
    DT=$(kubectl exec -n instana-clickhouse chi-instana-local-$NO-0-0 -- clickhouse-client -q "SELECT sum(ProfileEvent_InsertQuery) AS inserts, sum(ProfileEvent_FailedInsertQuery) AS \"f inserts\" FROM system.metric_log WHERE (event_time >= '$FORMATTED_UTC_START_TIME') AND (event_time <= '$FORMATTED_UTC_END_TIME')")
    T=$(echo $DT | cut -d " " -f 1)
    D=$(echo $DT | cut -d " " -f 2)
    S=$(echo "$S + $(printf "%.0f" $T)" | bc)
    E=$(echo "$E + $(printf "%.0f" $D)" | bc)  
  done
  PER=$(echo "($E / $S) * 100" | bc -l)
  echo -e "$(printf "%.2f" $PER) %" >> ${LOCATION}/spandrops.txt
fi
tar -czvf $LOCATION.tar ./$LOCATION/*
rm -fr ./$LOCATION
print_green "TEST START TIME : $START_TIME_IST"
print_green "TEST END TIME : $END_TIME_IST"
print_green "\nexported data to $LOCATION.tar"
print_green "\n=============================="
print_green "\n Pod Failure Test Completed..!"
print_green "\n=============================="
