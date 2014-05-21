#!/bin/bash

## TESTED ON UBUNTU 12.04 ONLY
## Will probably fail on other distributions (thanks for that, Ruby!!)

# Define packages
PKG_GLOBAL_DEPENDENCIES="build-essential libxml2-dev libxslt-dev libssl-dev"
PKG_AMQP="rabbitmq-server"
PKG_RUBY="ruby1.9.1-full"

DEBUG=0

# Internal vars
_OMF_RC_AUTOSTART=1
_SOURCES_UPDATED=0
_DEPS_INSTALLED=0
_INSTALL_AMQP=0
_INSTALL_OMFEC=0
_INSTALL_OMFRC=0
_OMFRC_DEBUG="false"
_OMFRC_AMQPURL=""
_OMFRC_ENVIRONMENT="development"

function usage () {
cat << EOF

  usage: $0 [--help|-h] [--omfec|-e] [--omfrc|-r] [--amqp[=url] |-q[url]] [--all|-a]
  
  OPTIONS
    --help, -h             Show this message
    --all, -a              Install all OMF components (implies -e -r -q)
    --omfec, -e            Install OMF Experiment Controller
    --omfrc, -r            Install OMF Resource Controller
    --noauto, -n           Do not automatically start the OMF Resource Controller on system boot
    --amqp[=URL], -q[URL]  Install AMQP server. In case the oprional <URL> argument is provided

EOF
}

function read_args () {
    args=`getopt -q -l help,omfec,omfrc,amqp::,all -o herq::a -- "$@"`
    if [ $? != 0 ] || [ $# == 0 ]; then
        usage
        exit 1
    fi
        eval set -- "$args"
        while true; do
            case $1 in
                -h|--help)
                    usage
                    exit
                    ;;
                -e|--omfec)
                    _INSTALL_OMFEC=1;
                    shift
                    ;;
                -r|--omfrc)
                    _INSTALL_OMFRC=1;
                    shift
                    ;;
                -n|--noauto)
                    _OMF_RC_AUTOSTART=0
                    shift
                    ;;
                -q|--amqp)
                    case $2 in
                        "")
                            _INSTALL_AMQP=1
                            _OMFRC_AMQPURL='localhost'
                            ;;
                        *)
                            _OMFRC_AMQPURL=$2
                            ;;
                    esac
                    shift 2
                    ;;
                -a|--all)
                    _INSTALL_OMFEC=1;
                    _INSTALL_OMFRC=1;
                    _INSTALL_AMQP=1;
                    shift
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    usage
                    exit 1
                    ;;
            esac
        done
#    fi
}

function fail () {
    echo "FATAL: $1"
    exit 1
}

function info () {
    echo "INFO : $1"
}

function update_apt_sources () {
    if [ $_SOURCES_UPDATED -eq 0 ]; then
        apt-get update
        _SOURCES_UPDATED=1
    fi
}

function install_pkg () {
    if [ -n "$1" ]; then
        update_apt_sources
        apt-get -y install $1
        if [ $? -ne 0 ]; then
            fail "Failed to install $2."
        else
            info "  Installed $2"
        fi
    else
        fail "At least one package name must be provided with install_pkg"
    fi
}

function install_deps () {
    if [ $_DEPS_INSTALLED -eq 0 ]; then
        install_pkg "$PKG_GLOBAL_DEPENDENCIES" "the basic dependencies."
        install_pkg "$PKG_RUBY" "Ruby."
    fi
}

function install_amqp () {
    echo "* Installing the AMQP server..."
    install_pkg "$PKG_AMQP" "the AMQP server."
    echo "  Successfully installed the AMQP server"
}

function install_omfec () {
    echo "* Installing the OMF Experiment Controller..."
    install_deps
    gem install omf_ec --no-ri --no-rdoc
    if [ $? == 0]; then
        echo "  Successfully installed the OMF Experiment Controller"
    else
        fail "Failed to instal OMF Experiment Controller"
    fi
}

function install_omfrc () {
    echo "* Installing the OMF Resource Controller..."
    install_deps
    gem install omf_rc --no-ri --no-rdoc
    if [ $? == 0 ]; then
        echo "  Successfully installed the OMF Resource Controller"
    else
        fail "Failed to instal OMF Resource Controller"
    fi
    if [ $_OMF_RC_AUTOSTART -eq 1 ]; then
        install_omf_rc -i -c
        if [ $? -ne 0 ]; then
            echo "  !! FAILED to configure the OMF Resource Controller to start on system boot"
        elif [ -n "$_OMFRC_AMQPURL" ] ; then
            echo '---' > /etc/omf_rc/config.yml
            echo ':uid: <%= Socket.gethostname %>' >> /etc/omf_rc/config.yml
            echo ":uri: $_OMFRC_AMQPURL" >> /etc/omf_rc/config.yml
            echo ":environment: $_OMFRC_OMFRC_ENVIRONMENT" >> /etc/omf_rc/config.yml
            echo ":debug:  $_OMFRC_DEBUG" >> /etc/omf_rc/config.yml
        fi
    fi
}

if [ $DEBUG == 0 ]; then
    read_args $*;
    if [ $UID -ne 0 ]; then
        fail "This script must be run as root"
    fi
    if [ $_INSTALL_AMQP -eq 1 ]; then
        install_amqp
    fi

    if [ $_INSTALL_OMFEC -eq 1 ]; then
        install_omfec
    fi

    if [ $_INSTALL_OMFRC -eq 1 ]; then
        install_omfrc
    fi
else
    echo $_OMF_RC_AUTOSTART
    echo $_SOURCES_UPDATED
    echo $_DEPS_INSTALLED
    echo $_INSTALL_AMQP
    echo $_INSTALL_OMFEC
    echo $_INSTALL_OMFRC
    echo $_OMFEC_AMQPADDRESS
fi