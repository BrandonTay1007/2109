#!/usr/bin/env bash
set -u
set -o pipefail

# Run from the directory that contains logtool.sh
if [ -f ../logtool.sh ]; then
    cd .. || exit 1
fi

pass=0
fail=0

mkdir -p tests/out

# One argument: ./logtool.sh "$a"
check1() {
    local desc="$1"
    local expected="$2"
    local a="$3"
    if diff -q "$expected" <(./logtool.sh "$a") >/dev/null 2>&1; then
        echo "PASS: $desc"
        ((pass++))
    else
        echo "FAIL: $desc"
        diff -u "$expected" <(./logtool.sh "$a")
        ((fail++))
    fi
}

# Two arguments: ./logtool.sh "$a" "$b"
check2() {
    local desc="$1"
    local expected="$2"
    local a="$3"
    local b="$4"
    if diff -q "$expected" <(./logtool.sh "$a" "$b") >/dev/null 2>&1; then
        echo "PASS: $desc"
        ((pass++))
    else
        echo "FAIL: $desc"
        diff -u "$expected" <(./logtool.sh "$a" "$b")
        ((fail++))
    fi
}

check_report() {
    local desc="$1"
    local expected="$2"
    local log_dir="$3"
    local out="tests/out/actual_report.txt"
    local captured
    captured=$(./logtool.sh report "$log_dir" "$out")
    if diff -q "$expected" "$out" >/dev/null 2>&1; then
        if [ -z "$captured" ]; then
            echo "PASS: $desc"
            ((pass++))
        else
            echo "FAIL: $desc"
            ((fail++))
        fi
    else
        echo "FAIL: $desc"
        diff -u "$expected" "$out"
        ((fail++))
    fi
}

check_error() {
    local desc="$1"
    local a="${2:-}"
    local b="${3:-}"
    local c="${4:-}"
    local d="${5:-}"
    local out
    local status
    if [ -n "$d" ]; then
        out=$(./logtool.sh "$a" "$b" "$c" "$d" 2>/dev/null)
        status=$?
    elif [ -n "$c" ]; then
        out=$(./logtool.sh "$a" "$b" "$c" 2>/dev/null)
        status=$?
    elif [ -n "$b" ]; then
        out=$(./logtool.sh "$a" "$b" 2>/dev/null)
        status=$?
    elif [ -n "$a" ]; then
        out=$(./logtool.sh "$a" 2>/dev/null)
        status=$?
    else
        out=$(./logtool.sh 2>/dev/null)
        status=$?
    fi
    if [ "$status" -ne 0 ]; then
        if [ -z "$out" ]; then
            echo "PASS: $desc"
            ((pass++))
        else
            echo "FAIL: $desc"
            ((fail++))
        fi
    else
        echo "FAIL: $desc"
        ((fail++))
    fi
}

check1 "help"                    tests/expected/help.txt                --help
check2 "summary logs"            tests/expected/summary_logs.txt        summary logs
check2 "summary mixed"           tests/expected/summary_mixed.txt       summary tests/fixtures/mixed
check2 "summary messy"           tests/expected/summary_messy.txt       summary tests/fixtures/messy
check2 "summary nologs"          tests/expected/summary_nologs.txt      summary tests/fixtures/nologs
check2 "services logs"           tests/expected/services_logs.txt       services logs
check2 "services mixed"          tests/expected/services_mixed.txt      services tests/fixtures/mixed
check2 "services messy"          tests/expected/services_messy.txt      services tests/fixtures/messy
check2 "services nologs"         tests/expected/services_nologs.txt     services tests/fixtures/nologs
check2 "failed-logins logs"      tests/expected/failed_logins_logs.txt  failed-logins logs
check2 "failed-logins mixed"     tests/expected/failed_logins_mixed.txt failed-logins tests/fixtures/mixed
check2 "failed-logins messy"     tests/expected/failed_logins_messy.txt failed-logins tests/fixtures/messy
check2 "failed-logins nologs"    tests/expected/failed_logins_nologs.txt failed-logins tests/fixtures/nologs
check2 "top-users logs"          tests/expected/top_users_logs.txt      top-users logs
check2 "top-users mixed"         tests/expected/top_users_mixed.txt     top-users tests/fixtures/mixed
check2 "top-users messy"         tests/expected/top_users_messy.txt     top-users tests/fixtures/messy
check2 "top-users nologs"        tests/expected/top_users_nologs.txt    top-users tests/fixtures/nologs

check_report "report logs"       tests/expected/report_logs.txt         logs
check_report "report mixed"      tests/expected/report_mixed.txt        tests/fixtures/mixed

check_error "no arguments"
check_error "unknown command"          bogus
check_error "summary missing dir"      summary
check_error "summary extra arg"        summary logs extra
check_error "summary bad dir"          summary does-not-exist
check_error "services missing dir"     services
check_error "services extra arg"       services logs extra
check_error "services bad dir"         services does-not-exist
check_error "failed-logins missing dir" failed-logins
check_error "failed-logins extra arg"  failed-logins logs extra
check_error "failed-logins bad dir"    failed-logins does-not-exist
check_error "report missing args"      report
check_error "report one arg"           report logs
check_error "report extra arg"         report logs tests/out/x extra
check_error "report bad dir"           report does-not-exist tests/out/x
check_error "top-users missing dir"    top-users
check_error "top-users extra args"     top-users logs 3 extra
check_error "top-users bad dir"        top-users does-not-exist
check_error "top-users bad N"          top-users logs abc

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
