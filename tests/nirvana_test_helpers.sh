#!/bin/bash -e

# *****************************************************************************
# Test helpers script in Nirvana
# *****************************************************************************

source /home/plumgrid/work/workspace2/nirvana/build/tests/nirvana_tests.conf

declare -A summary

function test_cleanup() {
  echo "*** Going to call test cleanup **** "
  pkill -f riemann
  if [[ ${RIEMANN_CLIENT} = "node" ]]; then
    pkill -f riemann_node_client
  else
    sudo service logstash stop
  fi
}

# Function to initialize testing environment
# *****************************************************************************
# Function: test_env_init
# Purpose : Makes nirvana test logs directory if not created already
#           Cleans up existing nirvana output info/warning/error logs
#           Starts riemann server and client
# Usage   : test_env_init
# *****************************************************************************
function test_env_init() {
  rm -rf $TEST_LOGS_DIR/*
  retryexec mkdir -p $TEST_LOGS_DIR
  log "Cleaning up nirvana output logs"
  cat /dev/null > $NIRVANA_INFO_LOG
  cat /dev/null > $NIRVANA_WARN_LOG
  cat /dev/null > $NIRVANA_ERROR_LOG

  # Start Riemann server
  start_riemann_server
  # Start Riemann node client
  start_riemann_client
}

. /opt/pg/test/scripts/test_helpers.sh || retval=$?
. /home/plumgrid/work/workspace2/nirvana/build/tests/expected_messages.sh

# Function to start riemann server
# *****************************************************************************
# Function: start_riemann_server
# Purpose : Starts riemann server on locahost (port 15555)
# Usage   : start_riemann_server
# *****************************************************************************
function start_riemann_server() {
  echo -e "\n*****Starting Riemann Server*****"
  pushd /home/plumgrid/work/workspace2/nirvana/build > /dev/null
  source /home/$USER/.nirvana.bashrc
  riemann riemann.config >& $RIEMANN_SERVER_LOG &
  popd > /dev/null
  check_listening_on_port $LOCALHOST $RIEMANN_PORT
  result=$?
  assert_eq 0 $result $LINENO "Riemann server failed to start. Logs present in $BASE_LOG_DIR"
  echo "Riemann server started successfully"
}

# *************************************************************************************
# Function: start_riemann_node_client
# Purpose : Starts riemann node client on locahost (will open udp port 6000 to listen)
# Usage   : start_riemann_node_client
# *************************************************************************************
function start_riemann_node_client() {
  echo " --> Node Client"
  pushd /home/plumgrid/work/workspace2/nirvana/build/setup > /dev/null
  node riemann_node_client.js >& "$RIEMANN_CLIENT_LOG" &
  popd > /dev/null
  check_listening_on_port "0.0.0.0" "$LOGSTASH_PORT"
  result=$?
  assert_eq 0 $result $LINENO "Riemann node client failed to start. Logs present in $BASE_LOG_DIR"
  echo "Riemann node client has been started successfully"
}

# *****************************************************************************************
# Function: start_riemann_logstash_client
# Purpose : Starts riemann logstash client on locahost (will open udp port 6000 to listen)
# Usage   : start_riemann_client
# *****************************************************************************************
function start_riemann_logstash_client () {
  echo " --> Logstash Client"
  sudo service logstash restart >& "$RIEMANN_CLIENT_LOG" &
  check_listening_on_port "0.0.0.0" "$LOGSTASH_PORT"
  result=$?
  assert_eq 0 $result $LINENO "Riemann logstash client failed to start. Logs present in $BASE_LOG_DIR"
  echo "Riemann logstash client has been started successfully"
}

# *************************************************************************************
# Function: start_riemann_client
# Purpose : Starts riemann client on locahost
# Usage   : start_riemann_client
# *************************************************************************************
function start_riemann_client () {
  echo -e "***** Starting Riemann Client *****"
  if [[ ${RIEMANN_CLIENT} = "node" ]]; then
    start_riemann_node_client
  else
    start_riemann_logstash_client
  fi
}

# *****************************************************************************
# Function: check_listening_on_port
# Purpose : Test if process is listening on a port using netstat
# Usage   : check_listening_on_port $IP $port $log_file
# *****************************************************************************
function check_listening_on_port() {
  IP=$1
  port=$2
  retryexec_no_assert "sudo netstat -nlp | grep -w $IP:$port" || return $?
}

#usage: wait_for_string "command to run" expected_string num_iter
# TODO: Add LINENO stuff here.
function nrv_wait_for_string() {
  cmd=$1
  expected=$2
  i=$3
  comparison_oper=${4:-eq}
  final_status=1
  while [ $i -ne 0 ]; do
    DO_NOT_TAR="yes" # ignore failures in a subshell
    result=$(eval "$cmd")
    unset DO_NOT_TAR
    if [[ "$comparison_oper" == "ge" ]]; then
      if [[ "$result" -ge "$expected" ]]; then
        final_status=0
        break; fi
    elif [[ "$comparison_oper" == "eq" ]]; then
      if [[ "$result" -eq "$expected" ]]; then
        final_status=0
        break; fi
    else
      echo "Invalid comparison operator($4) in nrv_wait_for_string"
      break
    fi
    sleep $SLEEP_INTERVAL
    i=$[$i-1]
  done

  if [[ $final_status != 0 ]]; then
    echo "expected=$comparison_oper$expected result=$result"
    return $final_status
  else
    return $final_status
  fi
}

# Function to check if plugin output is as expected
# *****************************************************************************
# Function: check_plugin_output
# Purpose : Tests if plugin outputs the expected info/warning/error statements
#           Tests if the number of occurences of the log statements is as expected
# Usage   : check_plugin_output $grep_cmd $expected_output $iterations $comparison
# *****************************************************************************
function check_plugin_output() {
  grep_str=$1
  grep_file=$2
  num_grep_occurence=$3
  iterations=$4
  comparison=$5
  grep_cmd='egrep "'${grep_str}'" '${grep_file}' | wc -l'
  nrv_wait_for_string "$grep_cmd" "$num_grep_occurence" "$iterations" "$comparison"
  result=$?
  if [[ $result != 0 ]]; then
    echo -e "\nExpected output in $grep_file:\n$grep_str"
    echo -e "\n***************** Nirvana Output ($grep_file)******************"
    cat $grep_file
    echo -e "*******************************************************************"
  fi
  return $result
}

# *****************************************************************************
# Function: print_summary
# Purpose: Print summary of all scnerios in a test run
# Usage   : print_summary
# *****************************************************************************
function print_summary() {
  echo -e "\n***************** Test Summary ********************************"
  for test in "${!summary[@]}"; do
    if [[ ${summary["$test"]} == 0 ]]; then
      summary["$test"]="Passed"
    else
      summary["$test"]="Failed"
    fi
    echo "$test - ${summary["$test"]}"; done
  echo -e "*******************************************************************\n"
}

# *****************************************************************************
# Function: write_to_syslog
# Purpose : Write specified file contents to syslog
# Usage   : write_to_syslog <file>
# *****************************************************************************
function write_to_syslog() {
  file=$1
  echo "Writing $file to syslog"
  retryexec python $WRITE_TO_SYSLOG_FILE -f $file > /dev/null
}

# *****************************************************************************
# Function: copy_test_logs
# Purpose : Collect test logs at end of each test case in /opt/pg/log
#           ** /opt/pg/log/nirvana_test_logs will contain:
#           1) Riemann server/client run logs
#           2) syslog
#           3) logstash logs (if logstash is being used as Riemann client)
#           ** /opt/pg/log/nirvana will contain Nirvana info/error/warning logs
#           ** /opt/pg/log will contain trace collector
# Usage   : copy_test_logs
# *****************************************************************************
function copy_test_logs() {
  echo "Collecting logs .."
  retryexec_no_assert "cp /var/log/syslog* $TEST_LOGS_DIR"
  if [[ ${RIEMANN_CLIENT} = "logstash" ]]; then
    retryexec_no_assert "cp /var/log/logstash/* $TEST_LOGS_DIR"
  fi
}

# *****************************************************************************
# Function: retryexec
# Purpose : Try to execute a command. If the command returns success, this
#           function returns 0. Otherwise, the script retries for a while. If
#           it still fails, the test case fails with assert
# Usage   : retryexec <command>
# *****************************************************************************
function retryexec() {
  retries=10
  try=1
  until [[ $try == ${retries} ]]
  do
    local retval=0;
    "$@" || retval=$?
    if [[ $retval == "0" ]]; then
      break
    fi
    let try++
    if [[ $try == ${retries} ]]; then
      assert_eq 0 $retval $LINENO "Command $@ failed with status $retval"
    fi
    sleep 3
  done
}

# *****************************************************************************
# Function: retryexec_no_assert
# Purpose : Try to execute a command. If the command returns success, this
#           function returns 0. Otherwise, the script retries for a while. If
#           it still fails, its then aborted with the status code of the failed
#           command.
# Usage   : retryexec_no_assert <command>
# *****************************************************************************
function retryexec_no_assert() {
  cmd=$1
  retries=10
  try=1
  until [[ $try == ${retries} ]]
  do
    local retval=0;
    eval $cmd || retval=$?
    if [[ $retval == "0" ]]; then
      break
    fi
    let try++
    if [[ $try == ${retries} ]]; then
      echo "Command $cmd failed with status $retval"
      return $retval
    fi
    sleep 3
  done
}

# Evaluate a floating point number expression.
function float_eval()
{
    local float_scale=2
    local stat=0
    local result=0.0
    if [[ $# -gt 0 ]]; then
        result=$(echo "scale=$float_scale; $*" | bc -q 2>/dev/null)
        stat=$?
        if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
    fi
    echo $result
    return $stat
}
