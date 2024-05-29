log() {
    local level color message
    level=$1
    message=$2

    case "$level" in
        INFO)
            color=$'\e[36m'
            ;;
        WARNING)
            color=$'\e[35m'
            ;;
        ERROR)
            color=$'\e[31m'
            ;;
        *)
            color=$'\e[39m'
            ;;
    esac

    reset=$'\e[39m'
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    if [[ -t 1 || -n $CONTENT_TYPE ]]; then
        echo -e "${color}-${level:0:1}|${timestamp}|${message}${reset}"
    else
        echo "-${level:0:1}|${timestamp}|${message}"
    fi

    logger -t SCRIPT_NAME -p user.${level,,} "${timestamp} - ${level} - ${message}"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARNING" "$1"
}

log_error() {
    log "ERROR" "$1"
}
