#!/bin/bash -e

# This script will run on workload VM to setup Riemann server.
# It will install nvm, node, rvm, ruby, riemaan-dash, riemann-tools, riemaan-client.
# It will also run node program to collect UDP logs from various servers and forward it
# to riemann server.
# TODO: WORK_DIR should be something inside /opt/pg ...
# TODO: expose interface "nirvana install" to
WORK_DIR="/home/$USER"
riemann_version="0.2.10"
LOGSTASH_VERSION="1.5"
IDE="true"
LOGSTASH="true"
LOGSTASH_CONF_DIR="/etc/logstash/conf.d/"
STEP_ST=1
STEP_ED=8

function show_setup_help() {
  cat << HELP

Prepare your machine to run Nirvana

USAGE: setup_riemann_infra.sh -w <work-dir> -i <no-ide> -l <no-logstash>

Optional Arguments:
  -w, --work-dir      Directory where packages (like riemann, intellijIDE) will be downloaded.
                      Default is "/home/$USER".
  -i, --no-ide        Do NOT setup the ide (you are perhaps on ssh machine).
                      Default is setup the IDE.
  -l, --no-logstash   Do NOT setup Riemann logstash client.
                      Default is to setup it.
  -h, --help          Well... It will show help.
HELP
}

#Show help
if [[ $1 == "--help" || $1 == "-h" ]]; then
  show_setup_help
  exit 1
fi

TEMP=`getopt -o w:ilR:E:h --long work-dir:,no-ide,no-logstash,step_st:,step_ed:,help -n 'setup.sh' -- "$@"`
eval set -- "$TEMP"
while true ; do
  case "$1" in
    -w| --work-dir ) WORK_DIR="$2"; shift 2 ;;
    -i| --no-ide ) IDE="false"; shift ;;
    -l| --no-logstash ) LOGSTASH="false"; shift ;;

    -R| --step_st ) STEP_ST="$2"; shift 2 ;;
    -E| --step_ed ) STEP_ED="$2"; shift 2 ;;
    -h| --help ) show_setup_help; exit 0; shift;;
    --) shift ; break ;;
    *) exit 1 ;;
  esac
done

function setup() {
  local step=$1
  case "$step" in

  1)
    echo "Update repositories"
    sudo apt-get update || true
    echo "Install JRE and build-essential"
    sudo apt-get -y install wget default-jre build-essential stress || true
    ;;

  2)
    echo "Download Riemann"
    pushd $WORK_DIR
    wget https://aphyr.com/riemann/riemann-${riemann_version}.tar.bz2
    tar xvfj riemann-${riemann_version}.tar.bz2
    popd
    ;;

  3)
    echo "Add node/reimann path"
    sudo cp nirvana.bashrc /home/$USER/.nirvana.bashrc
    # TODO: Make it idempotent.
    sudo bash -c "echo 'source /home/$USER/.nirvana.bashrc' >> /home/$USER/.bashrc"
    source /home/$USER/.bashrc
    ;;

  4)
    echo "Rate limit settings of rsyslog"
    # $SystemLogRateLimitInterval and $SystemLogRateLimitBurst are two parameters which define rate-limiting of
    # rsyslog. There default values are
    # => $SystemLogRateLimitInterval 5
    # => $SystemLogRateLimitBurst 200
    # which means that by default, rate limiting will only work, if a process sends more than 200 messages in 5 seconds.
    # We will make these setting in compliance with our trace collector settings.
    sudo bash -c "echo '\$SystemLogRateLimitInterval 1' >> /etc/rsyslog.conf"
    sudo bash -c "echo '\$SystemLogRateLimitBurst 10000' >> /etc/rsyslog.conf"
    ;;

  5)
    echo "Add rsyslog configuration file (to forward ps syslogs to reimann). Restart"
    sudo cp 00-pg.conf /etc/rsyslog.d/.
    sudo service rsyslog  restart
    ;;

  6)
    if [[ ${LOGSTASH} == "true" ]]; then
      echo "Install logstash"
      sudo apt-get install -y openjdk-7-jdk
      sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D5495F657635B973
      sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D27D666CD88E42B4
      echo "deb http://packages.elasticsearch.org/logstash/${LOGSTASH_VERSION}/debian stable main" | sudo tee /etc/apt/sources.list.d/elk.list
      echo "update the packages"
      sudo apt-get update || true
      echo "install logstash"
      sudo apt-get install -y logstash
    fi
    ;;

  7)
    if [[ ${LOGSTASH} == "true" ]]; then
      echo "Install logstash output Riemann plugin"
      sudo /opt/logstash/bin/plugin install logstash-output-riemann
      echo "Add logstash configuration"
      sudo cp logstash.conf ${LOGSTASH_CONF_DIR}/logstash.conf
      # sudo service rsyslog  restart
    fi
    ;;

  8)
    if [[ ${IDE} == "true" ]]; then
      echo "Install IntelliJ IDEA IDE"
      pushd $WORK_DIR
      wget https://download.jetbrains.com/idea/ideaIC-14.1.5.tar.gz --no-check-certificate
      tar xvf ideaIC-14.1.5.tar.gz
      popd
    fi
    ;;

  *)
    echo "NOP - $step"
  ;;
  esac
}

for STEP in `seq ${STEP_ST} ${STEP_ED}`; do
  printf "\n    === Starting Nirvana STEP $STEP === \n"
  setup $STEP
done
