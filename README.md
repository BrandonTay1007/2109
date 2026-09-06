# **FIT2109 Computer Science Workshop - 2026-Assignment 1**

## logtool.sh - Shell-Based Log Analysis Script

FIT2109 Assignment 1 — wtay0015

## What problem it solves

Support and developer teams accumulate Linux-style log files across many directories. `logtool.sh` analyses a set of Linux-style system log files and produces useful summary outputs for them. `logtool.sh` recursively search one or more directories in a given directory for relevant files (`.log` files)  and reads every `.log` file it finds, and reports aggregate counts so a human can see the shape of the logs without reading them line by line.

Each log line is assumed to follow:

```
<TIMESTAMP> host=<HOST> service=<SERVICE> level=<LEVEL> event=<EVENT> user=<USER> ip=<IP> msg="<MESSAGE>"
```

`Blank lines (including whitespace-only) and comment lines (optional leading whitespace, then #) are ignored. Fields may be separated by whitespace, and a line may have trailing whitespace or a Windows (CRLF) ending. Non-.log files are not read. LINES_PROCESSED counts every remaining line; ERROR, WARN, and INFO count only lines whose level= field is exactly that value.`

## How to run

### Installation
1. Clone the GitLab repository and `cd` to the directory that contains `logtool.sh`.
2. If the script is not executable, set the permission once:

```
chmod u+x logtool.sh
```

3. Run a command:

```
./logtool.sh <command> [options]
```

| Command | Arguments | Notes |
|---|---|---|
| `--help` | none | usage text, exit 0 |
| `summary` | `<log_dir>` | key=value counts |
| `services` | `<log_dir>` | `<service> <count>` |
| `failed-logins` | `<log_dir>` | `<user> <count>` |
| `report` | `<log_dir> <output_file>` | writes a file; overwrites if it exists |
| `top-users` | `<log_dir> [N]` | default N=3 |

Print the command list with:

```
./logtool.sh --help
```

Invalid usage writes to stderr and exits non-zero, leaving stdout empty.

## Example commands and expected output

Examples below use the bundled `logs/` directory.

### `--help`

Prints a concise usage summary that shows the available commands and their expected arguments.

```
$ ./logtool.sh --help
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
```



### `summary <log_dir>`

Scan the target directory recursively and read every regular `.log` file (a directory named `notafile.log` is not a file). Blank lines and comment lines are ignored:

- **Blank:** empty, or only spaces/tabs (and a Windows `\r` if the file uses CRLF)
- **Comment:** optional leading whitespace, then `#` (so `# note` and    `# note` are both comments)

`LINES_PROCESSED` is every remaining line. `ERROR`, `WARN`, and `INFO` count only lines whose `level=` field is exactly that value (`level=ERRORX` and `level=DEBUG` do not count). Fields may be separated by spaces or tabs; trailing whitespace after `msg="..."` is allowed.

```
$ ./logtool.sh summary logs
FILES_SCANNED=3
LINES_PROCESSED=54
ERROR=19
WARN=11
INFO=24
```



### `services <log_dir>`

Counts valid lines by `service=` and prints `<service> <count>`, sorted by count descending then name ascending.

```
$ ./logtool.sh services logs
sshd 14
nginx 10
backup 9
cron 9
kernel 7
authd 5
```



### `failed-logins <log_dir>`

Counts `event=FAILED_LOGIN` lines by username (`user=-` is ignored).

```
$ ./logtool.sh failed-logins logs
alice 3
dave 2
bob 1
erin 1
```



### `report <log_dir> <output_file>`

Writes a consolidated report to  (stdout stays empty). The file is created if it does not exist, and overwritte if it does.

```
$ ./logtool.sh report logs report.txt
```

`report.txt` then contains:

```
=== LOG REPORT ===
[OVERVIEW]
Files scanned: 3
Lines processed: 54
[COUNTS BY LEVEL]
ERROR 19
WARN 11
INFO 24
[COUNTS BY SERVICE]
sshd 14
nginx 10
backup 9
cron 9
kernel 7
authd 5
[FAILED LOGIN USERS]
alice 3
dave 2
bob 1
erin 1
```



### `top-users <log_dir> [N]`

Prints the N most frequent usernames (user=- is ignored). N defaults to 3. If N is larger than the number of distinct usernames, max username will be printed is all.

```
$ ./logtool.sh top-users logs
alice 9
carol 8
erin 7
```

```
$ ./logtool.sh top-users logs 2
alice 9
carol 8
```



### Invalid usage

```
$ ./logtool.sh services no-such-directory
Error: not a directory: no-such-directory
Usage: ./logtool.sh <command> [options]
Try './logtool.sh --help' for more information.
```

