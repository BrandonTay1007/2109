#!/usr/bin/env bash
set -u
set -o pipefail

# Print the command list
print_help() {
cat <<'EOF'
Commands:
    --help
        Show this help message

    summary <log_dir>
        Print summary counts for the log directory

    services <log_dir>
        Print counts by service

    failed-logins <log_dir>
        Print failed login counts by user

    report <log_dir> <output_file>
        Generate a consolidated plain-text report

    top-users <log_dir> [N]
        Print the N most frequent usernames (default 3)
EOF
    exit 0
}

# Write a usage error to stderr and exit 1
usage_error(){
    echo "Error: $1" >&2
    echo "Usage: $0 <command> [options]" >&2
    echo "Try '$0 --help' for more information." >&2
    exit 1
}

# Extract valid log lines from a directory
valid_lines(){
    # -type f skips a directory named *.log, drop blanks and # comments
    find "$1" -type f -name '*.log' -exec grep -h -v -E '^[[:space:]]*$' {} + | grep -v -E '^[[:space:]]*#' || true
}

# Count lines with a specific level
count_level(){
    # cut drops msg="..." so later grep only sees key=value fields
    valid_lines "$2" | cut -d'"' -f1 | grep -c -E "(^|[[:space:]])level=$1([[:space:]]|\$)" || true
}

# Extract service= values from valid lines
service_names(){
    # cut drops msg="..." so later grep only sees key=value fields
    valid_lines "$1" | cut -d'"' -f1 | grep -Eo 'service=[^[:space:]]+' | cut -d'=' -f2- || true
}

# Print file, line, and level totals
summary(){
    log_dir="$1"

    if [ ! -d "$log_dir" ]; then
        usage_error "not a directory: $log_dir"
    fi

    echo "FILES_SCANNED=$(find "$log_dir" -type f -name '*.log' | grep -c '^' || true)"
    echo "LINES_PROCESSED=$(valid_lines "$log_dir" | grep -c '^' || true)"
    echo "ERROR=$(count_level ERROR "$log_dir")"
    echo "WARN=$(count_level WARN "$log_dir")"
    echo "INFO=$(count_level INFO "$log_dir")"
}

# Count valid lines by service, most frequent first
services(){
    log_dir="$1"

    if [ ! -d "$log_dir" ]; then
        usage_error "not a directory: $log_dir"
    fi

    names=$(service_names "$log_dir")
    # sort by count descending, then name ascending
    for svc in $(echo "$names" | sort -u); do
        echo "$svc $(echo "$names" | grep -c "^${svc}\$" || true)"
    done | sort -k2,2nr -k1,1
}

# Usernames on FAILED_LOGIN lines (user=- ignored)
failed_login_users(){
    # cut drops msg="..." so later grep only sees key=value fields
    valid_lines "$1" | cut -d'"' -f1 \
        | grep -E '(^|[[:space:]])event=FAILED_LOGIN([[:space:]]|$)' \
        | grep -Eo 'user=[^[:space:]]+' \
        | cut -d'=' -f2- \
        | grep -v '^-$' \
        || true
}

# Count failed logins by user, most frequent first
failed_logins(){
    log_dir="$1"
    if [ ! -d "$log_dir" ]; then
        usage_error "not a directory: $log_dir"
    fi
    names=$(failed_login_users "$log_dir")
    # sort by count descending, then name ascending
    for user in $(echo "$names" | sort -u); do
        echo "$user $(echo "$names" | grep -c "^${user}\$" || true)"
    done | sort -k2,2nr -k1,1
}

# Write a labelled file by reusing summary, services, and failed_logins
report(){
    log_dir="$1"
    output_file="$2"

    if [ ! -d "$log_dir" ]; then
        usage_error "not a directory: $log_dir"
    fi

    if [ -d "$output_file" ]; then
        usage_error "not a file: $output_file"
    fi

    sum=$(summary "$log_dir")
    files=$(echo "$sum" | grep '^FILES_SCANNED=' | cut -d'=' -f2)
    lines=$(echo "$sum" | grep '^LINES_PROCESSED=' | cut -d'=' -f2)
    error=$(echo "$sum" | grep '^ERROR=' | cut -d'=' -f2)
    warn=$(echo "$sum" | grep '^WARN=' | cut -d'=' -f2)
    info=$(echo "$sum" | grep '^INFO=' | cut -d'=' -f2)

    echo -n "" > "$output_file"
    echo "=== LOG REPORT ===" >> "$output_file"
    echo "[OVERVIEW]" >> "$output_file"
    echo "Files scanned: $files" >> "$output_file"
    echo "Lines processed: $lines" >> "$output_file"

    echo "[COUNTS BY LEVEL]" >> "$output_file"
    echo "ERROR $error" >> "$output_file"
    echo "WARN $warn" >> "$output_file"
    echo "INFO $info" >> "$output_file"

    echo "[COUNTS BY SERVICE]" >> "$output_file"
    services "$log_dir" >> "$output_file"

    echo "[FAILED LOGIN USERS]" >> "$output_file"
    failed_logins "$log_dir" >> "$output_file"
}

# All usernames on valid lines (user=- ignored)
all_users(){
    # cut drops msg="..." so later grep only sees key=value fields
    valid_lines "$1" | cut -d'"' -f1 \
        | grep -Eo 'user=[^[:space:]]+' \
        | cut -d'=' -f2- \
        | grep -v '^-$' \
        || true
}

# Print the N most frequent usernames
top_users(){
    log_dir="$1"
    n="$2"
    if [ ! -d "$log_dir" ]; then
        usage_error "not a directory: $log_dir"
    fi
    echo "$n" | grep -E -q '^[0-9]+$' || usage_error "N must be a non-negative integer: $n"
    names=$(all_users "$log_dir")
    # sort by count descending, then name ascending
    for user in $(echo "$names" | sort -u); do
        echo "$user $(echo "$names" | grep -c "^${user}\$")"
    done | sort -k2,2nr -k1,1 | head -"$n"
}

if [ "$#" -eq 0 ]; then
    usage_error "missing command"
elif [ "$1" = "--help" ]; then
    print_help
elif [ "$1" = "summary" ]; then
    if [ "$#" -ne 2 ]; then
        usage_error "summary requires exactly one argument: <log_dir>"
    fi
    summary "$2"
elif [ "$1" = "services" ]; then
    if [ "$#" -ne 2 ]; then
        usage_error "services requires exactly one argument: <log_dir>"
    fi
    services "$2"
elif [ "$1" = "failed-logins" ]; then
    if [ "$#" -ne 2 ]; then
        usage_error "failed-logins requires exactly one argument: <log_dir>"
    fi
    failed_logins "$2"
elif [ "$1" = "report" ]; then
    if [ "$#" -ne 3 ]; then
        usage_error "report requires exactly two arguments: <log_dir> <output_file>"
    fi
    report "$2" "$3"
elif [ "$1" = "top-users" ]; then
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        usage_error "top-users requires <log_dir> [N]"
    fi
    # N defaults to 3 when omitted
    top_users "$2" "${3:-3}"
else
    usage_error "unknown command: $1"
fi
