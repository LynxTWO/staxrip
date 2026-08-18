#!/usr/bin/env bash

if [[ "${STAXRIP_LINUX_GATE_CLEAN_ENV:-}" != "1" ]]; then
    readonly initial_script_path="${BASH_SOURCE[0]}"
    [[ "$initial_script_path" == /* ]] || {
        printf 'FAIL port-linux-sandbox criterion=environment detail=absolute-script-required exit=2 evidence=none\n' >&2
        exit 2
    }
    readonly clean_uid="$(/usr/bin/id -u)"
    exec /usr/bin/env -i \
        PATH=/usr/bin:/bin \
        HOME=/nonexistent \
        XDG_RUNTIME_DIR="/run/user/$clean_uid" \
        LANG=C.UTF-8 \
        LC_ALL=C.UTF-8 \
        TZ=UTC \
        STAXRIP_LINUX_GATE_CLEAN_ENV=1 \
        /usr/bin/bash --noprofile --norc "$initial_script_path" "$@"
fi

set -Eeuo pipefail
IFS=$'\n\t'

readonly GATE_ID="port-linux-sandbox"
readonly MANIFEST_NAME="artifact-linux-x64.tsv"

MODE="outer"
CURRENT_CRITERION="bootstrap"
CHECKS=0
FAIL_EMITTED=0
SANDBOX_ROOT=""
SYSTEMD_UNIT_NAME=""
SYSTEMD_UNIT_STARTED=0
APP_PID=""
APP_START_TICKS=""
APP_EXECUTABLE_PATH=""
APP_OWNERSHIP_REGISTERED=0
declare -a APP_EXPECTED_ARGV=()
MONITOR_PID=""
EVIDENCE_ROOT=""
CROSS_PLATFORM_ROOT=""
PERSISTENT_EVIDENCE_ROOT=""
FAILURE_ROOT=""
FAILURE_EVIDENCE="none"
FAILURE_PACKET_REQUIRED=0
FAILURE_PACKET_PUBLISHED=0
ARTIFACT_DIGEST="unknown"
HOST_DOTNET_COMMAND="unknown"
HOST_PLATFORM="unknown"
HOST_ARCHITECTURE="unknown"
HOST_PRIVILEGE="unknown"
HOST_VIRT="unknown"
HOST_CONTAINER="unknown"
HOST_KERNEL_RELEASE="unknown"
HOST_OS_ID="unknown"
HOST_OS_VERSION_ID="unknown"
HOST_MACHINE_ID_SHA256=""
HOST_WSL_INTEROP="false"
EVIDENCE_LEASE_PATH=""
EVIDENCE_LEASE_NONCE=""
EVIDENCE_LEASE_ACQUIRED=0
EVIDENCE_LEASE_RECEIPT_VALIDATED=0
EVIDENCE_PASS_PAIR_INVALIDATED=0

pass_check() {
    CHECKS=$((CHECKS + 1))
}

safe_word() {
    local value="${1:-unknown}"
    local lower_value="${value,,}"

    if [[ "$lower_value" =~ ^.{0,32}(authorization|proxy-authorization|cookie|set-cookie)[[:space:]]*[:=] ]] ||
       [[ "$lower_value" =~ (https?|wss?)://[^/[:space:]:@]+:[^@[:space:]/]+@ ]] ||
       [[ "$lower_value" =~ (access_token|refresh_token|id_token|api_key|client_secret|token|secret)[[:space:]]*[:=] ]]; then
        printf 'redacted'
        return
    fi

    if [[ "$value" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]]; then
        printf '%s' "$value"
    else
        printf 'unknown'
    fi
}

die() {
    local criterion
    local detail
    local exit_code="${3:-1}"

    trap - ERR
    criterion="$(safe_word "${1:-unknown}")"
    detail="$(safe_word "${2:-failed}")"

    if [[ "$MODE" == "unit" ]]; then
        if [[ -n "$EVIDENCE_ROOT" && -d "$EVIDENCE_ROOT" && ! -L "$EVIDENCE_ROOT" ]]; then
            printf '%s\n' "$criterion-$detail" >"$EVIDENCE_ROOT/unit-failure" 2>/dev/null || true
        fi

        printf 'UNIT_FAIL criterion=%s detail=%s\n' "$criterion" "$detail" >&2
    elif (( FAIL_EMITTED == 0 )); then
        FAIL_EMITTED=1
        FAILURE_PACKET_REQUIRED=1
        write_failure_packet "$criterion" "$detail" "$exit_code"
        printf 'FAIL %s criterion=%s detail=%s exit=%s evidence=%s\n' \
            "$GATE_ID" "$criterion" "$detail" "$exit_code" "$FAILURE_EVIDENCE" >&2
    fi

    exit "$exit_code"
}

unexpected_error() {
    local exit_code="$?"
    die "$CURRENT_CRITERION" "unexpected-command" "$exit_code"
}

is_valid_sandbox_root() {
    local candidate="${1:-}"
    [[ "$candidate" =~ ^/tmp/staxrip-linux-gate\.[A-Za-z0-9]{6}$ ]]
}

is_valid_unit_name() {
    local candidate="${1:-}"
    [[ "$candidate" =~ ^staxrip-linux-gate-[0-9a-f]{32}$ ]]
}

cleanup_outer_resources() {
    local cleanup_failed=0
    local resolved_sandbox

    if (( SYSTEMD_UNIT_STARTED == 1 )); then
        if ! is_valid_unit_name "$SYSTEMD_UNIT_NAME"; then
            cleanup_failed=1
        elif systemctl --user stop "$SYSTEMD_UNIT_NAME.service" >/dev/null 2>&1; then
            SYSTEMD_UNIT_STARTED=0
        else
            cleanup_failed=1
        fi
    fi

    if [[ -n "$SANDBOX_ROOT" ]]; then
        if [[ -d "$SANDBOX_ROOT" && ! -L "$SANDBOX_ROOT" ]]; then
            resolved_sandbox="$(realpath -e -- "$SANDBOX_ROOT" 2>/dev/null)"
            if is_valid_sandbox_root "$resolved_sandbox" &&
               rm -rf -- "$resolved_sandbox" &&
               [[ ! -e "$resolved_sandbox" && ! -L "$resolved_sandbox" ]]; then
                SANDBOX_ROOT=""
            else
                cleanup_failed=1
            fi
        elif [[ -e "$SANDBOX_ROOT" || -L "$SANDBOX_ROOT" ]]; then
            cleanup_failed=1
        else
            SANDBOX_ROOT=""
        fi
    fi

    (( cleanup_failed == 0 ))
}

cleanup() {
    local exit_code="$?"
    local app_signaled=0
    trap - EXIT ERR
    set +e

    if [[ "$MODE" == "unit" ]]; then
        if [[ -n "$MONITOR_PID" && "$MONITOR_PID" =~ ^[0-9]+$ ]]; then
            # The sampler is bounded to four seconds. Waiting on Bash's child-job
            # receipt avoids signaling a numeric PID that the kernel could reuse.
            wait "$MONITOR_PID" 2>/dev/null
            MONITOR_PID=""
        fi

        if [[ -n "$APP_PID" && "$APP_PID" =~ ^[0-9]+$ ]]; then
            if app_process_ownership_matches; then
                kill -TERM "$APP_PID" 2>/dev/null
                app_signaled=1
                /usr/bin/sleep 0.2

                if [[ -d "/proc/$APP_PID" ]]; then
                    if app_process_ownership_matches; then
                        kill -KILL "$APP_PID" 2>/dev/null
                    else
                        exit_code=1
                    fi
                fi
            elif [[ -d "/proc/$APP_PID" ]]; then
                # A live numeric PID without the complete receipt is not ours to signal.
                exit_code=1
            fi

            if (( app_signaled == 1 )) || [[ ! -d "/proc/$APP_PID" ]]; then
                wait "$APP_PID" 2>/dev/null
            fi
            reset_app_process_ownership
        fi
    else
        if ! cleanup_outer_resources; then
            exit_code=1
        fi
    fi

    if (( EVIDENCE_LEASE_ACQUIRED == 1 )); then
        if (( FAILURE_PACKET_REQUIRED == 1 && FAILURE_PACKET_PUBLISHED == 0 )); then
            exit_code=1
        elif ! exit_evidence_writer_lease; then
            exit_code=1
        fi
    elif (( EVIDENCE_LEASE_RECEIPT_VALIDATED != 0 ||
            EVIDENCE_PASS_PAIR_INVALIDATED != 0 )); then
        exit_code=1
    fi

    exit "$exit_code"
}

trap unexpected_error ERR
trap cleanup EXIT

require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 || die "preflight" "missing-command"
}

reset_evidence_writer_lease_state() {
    EVIDENCE_LEASE_PATH=""
    EVIDENCE_LEASE_NONCE=""
    EVIDENCE_LEASE_ACQUIRED=0
    EVIDENCE_LEASE_RECEIPT_VALIDATED=0
    EVIDENCE_PASS_PAIR_INVALIDATED=0
}

evidence_lease_receipt_matches() {
    local resolved_root
    local resolved_lease
    local receipt_size
    local receipt_text

    (( EVIDENCE_LEASE_ACQUIRED == 1 )) || return 1
    [[ "$EVIDENCE_LEASE_NONCE" =~ ^[0-9a-f]{32}$ ]] || return 1
    [[ -n "$PERSISTENT_EVIDENCE_ROOT" &&
       "$EVIDENCE_LEASE_PATH" == "$PERSISTENT_EVIDENCE_ROOT/.evidence-writer.lock" ]] || \
        return 1
    [[ -d "$PERSISTENT_EVIDENCE_ROOT" && ! -L "$PERSISTENT_EVIDENCE_ROOT" ]] || return 1
    resolved_root="$(realpath -e -- "$PERSISTENT_EVIDENCE_ROOT" 2>/dev/null)" || return 1
    [[ "$resolved_root" == "$CROSS_PLATFORM_ROOT/artifacts/evidence" ]] || return 1
    [[ -f "$EVIDENCE_LEASE_PATH" && ! -L "$EVIDENCE_LEASE_PATH" ]] || return 1
    resolved_lease="$(realpath -e -- "$EVIDENCE_LEASE_PATH" 2>/dev/null)" || return 1
    [[ "$resolved_lease" == "$EVIDENCE_LEASE_PATH" ]] || return 1
    receipt_size="$(stat -c '%s' -- "$EVIDENCE_LEASE_PATH" 2>/dev/null)" || return 1
    [[ "$receipt_size" == "33" ]] || return 1
    receipt_text="$(<"$EVIDENCE_LEASE_PATH")" || return 1
    [[ "$receipt_text" == "$EVIDENCE_LEASE_NONCE" ]]
}

evidence_pass_pair_absent() {
    local prior_path

    for prior_path in \
        "$PERSISTENT_EVIDENCE_ROOT/evidence-audit.json.sha256" \
        "$PERSISTENT_EVIDENCE_ROOT/evidence-audit.json"; do
        [[ ! -e "$prior_path" && ! -L "$prior_path" ]] || return 1
    done
}

evidence_writer_publication_authority() {
    (( EVIDENCE_LEASE_ACQUIRED == 1 &&
       EVIDENCE_LEASE_RECEIPT_VALIDATED == 1 &&
       EVIDENCE_PASS_PAIR_INVALIDATED == 1 )) || return 1
    evidence_lease_receipt_matches || return 1
    evidence_pass_pair_absent
}

release_exact_evidence_writer_lease() {
    (( EVIDENCE_LEASE_ACQUIRED == 1 )) || return 1
    evidence_lease_receipt_matches || return 1
    rm -- "$EVIDENCE_LEASE_PATH" || return 1
    [[ ! -e "$EVIDENCE_LEASE_PATH" && ! -L "$EVIDENCE_LEASE_PATH" ]] || return 1
    reset_evidence_writer_lease_state
}

cleanup_partial_evidence_writer_lease() {
    if (( EVIDENCE_LEASE_ACQUIRED == 1 )) && evidence_lease_receipt_matches; then
        release_exact_evidence_writer_lease
        return
    fi

    # Leave an ambiguous receipt in place for manual recovery. Never steal it.
    reset_evidence_writer_lease_state
    return 1
}

exit_evidence_writer_lease() {
    if (( EVIDENCE_LEASE_ACQUIRED == 0 )); then
        (( EVIDENCE_LEASE_RECEIPT_VALIDATED == 0 &&
           EVIDENCE_PASS_PAIR_INVALIDATED == 0 ))
        return
    fi
    evidence_writer_publication_authority || return 1
    release_exact_evidence_writer_lease
}

enter_evidence_writer_lease() {
    local resolved_root
    local lease_path
    local nonce
    local prior_path

    if (( EVIDENCE_LEASE_ACQUIRED == 1 )); then
        evidence_writer_publication_authority
        return
    fi
    (( EVIDENCE_LEASE_RECEIPT_VALIDATED == 0 &&
       EVIDENCE_PASS_PAIR_INVALIDATED == 0 )) || return 1
    [[ -z "$EVIDENCE_LEASE_PATH" && -z "$EVIDENCE_LEASE_NONCE" ]] || return 1
    [[ -n "$CROSS_PLATFORM_ROOT" && -d "$CROSS_PLATFORM_ROOT/artifacts" &&
       ! -L "$CROSS_PLATFORM_ROOT/artifacts" ]] || return 1
    command -v mkdir >/dev/null 2>&1 || return 1
    command -v realpath >/dev/null 2>&1 || return 1
    command -v rm >/dev/null 2>&1 || return 1
    command -v stat >/dev/null 2>&1 || return 1

    PERSISTENT_EVIDENCE_ROOT="$CROSS_PLATFORM_ROOT/artifacts/evidence"
    mkdir -p -- "$PERSISTENT_EVIDENCE_ROOT" >/dev/null 2>&1 || return 1
    [[ -d "$PERSISTENT_EVIDENCE_ROOT" && ! -L "$PERSISTENT_EVIDENCE_ROOT" ]] || return 1
    resolved_root="$(realpath -e -- "$PERSISTENT_EVIDENCE_ROOT" 2>/dev/null)" || return 1
    [[ "$resolved_root" == "$CROSS_PLATFORM_ROOT/artifacts/evidence" ]] || return 1

    lease_path="$resolved_root/.evidence-writer.lock"
    [[ ! -e "$lease_path" && ! -L "$lease_path" ]] || return 1
    [[ -r /proc/sys/kernel/random/uuid ]] || return 1
    nonce="$(</proc/sys/kernel/random/uuid)"
    nonce="${nonce//-/}"
    [[ "$nonce" =~ ^[0-9a-f]{32}$ ]] || return 1

    if ! (
        umask 077
        set -o noclobber
        printf '%s\n' "$nonce" >"$lease_path"
    ) 2>/dev/null; then
        return 1
    fi
    EVIDENCE_LEASE_PATH="$lease_path"
    EVIDENCE_LEASE_NONCE="$nonce"
    EVIDENCE_LEASE_ACQUIRED=1
    if ! evidence_lease_receipt_matches; then
        cleanup_partial_evidence_writer_lease >/dev/null 2>&1 || true
        return 1
    fi
    EVIDENCE_LEASE_RECEIPT_VALIDATED=1

    # Validate both leaves before deleting either one, so partial validation cannot
    # leave a stale PASS pair alongside a lease state that appears publishable.
    for prior_path in \
        "$resolved_root/evidence-audit.json.sha256" \
        "$resolved_root/evidence-audit.json"; do
        if [[ ! -e "$prior_path" && ! -L "$prior_path" ]]; then
            continue
        fi
        if [[ ! -f "$prior_path" || -L "$prior_path" ||
              "$(realpath -e -- "$prior_path" 2>/dev/null)" != "$prior_path" ]]; then
            cleanup_partial_evidence_writer_lease >/dev/null 2>&1 || true
            return 1
        fi
    done
    evidence_lease_receipt_matches || {
        cleanup_partial_evidence_writer_lease >/dev/null 2>&1 || true
        return 1
    }
    for prior_path in \
        "$resolved_root/evidence-audit.json.sha256" \
        "$resolved_root/evidence-audit.json"; do
        if [[ -e "$prior_path" || -L "$prior_path" ]]; then
            if ! rm -- "$prior_path" || [[ -e "$prior_path" || -L "$prior_path" ]]; then
                cleanup_partial_evidence_writer_lease >/dev/null 2>&1 || true
                return 1
            fi
        fi
    done
    if ! evidence_lease_receipt_matches || ! evidence_pass_pair_absent; then
        cleanup_partial_evidence_writer_lease >/dev/null 2>&1 || true
        return 1
    fi
    EVIDENCE_PASS_PAIR_INVALIDATED=1
    evidence_writer_publication_authority || {
        cleanup_partial_evidence_writer_lease >/dev/null 2>&1 || true
        return 1
    }
}

run_bounded_command() {
    local timeout_seconds="$1"
    local stdout_limit="$2"
    local stderr_limit="$3"
    local combined_limit="$4"
    local stdout_path="$5"
    local stderr_path="$6"
    shift 6

    python3 -I - \
        "$timeout_seconds" \
        "$stdout_limit" \
        "$stderr_limit" \
        "$combined_limit" \
        "$stdout_path" \
        "$stderr_path" \
        "$@" <<'PY'
import os
import selectors
import signal
import subprocess
import sys
import time


def fail(code: int) -> None:
    raise SystemExit(code)


if len(sys.argv) < 8:
    fail(126)

try:
    timeout_seconds = int(sys.argv[1])
    stdout_limit = int(sys.argv[2])
    stderr_limit = int(sys.argv[3])
    combined_limit = int(sys.argv[4])
except ValueError:
    fail(126)

stdout_path = sys.argv[5]
stderr_path = sys.argv[6]
command = sys.argv[7:]
if (
    not command
    or timeout_seconds < 1
    or stdout_limit < 1
    or stderr_limit < 1
    or combined_limit < stdout_limit
    or combined_limit < stderr_limit
    or os.path.lexists(stdout_path)
    or os.path.lexists(stderr_path)
):
    fail(126)

process = subprocess.Popen(
    command,
    stdin=subprocess.DEVNULL,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    close_fds=True,
    start_new_session=True,
)
if process.stdout is None or process.stderr is None:
    fail(126)

selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ, "stdout")
selector.register(process.stderr, selectors.EVENT_READ, "stderr")
buffers = {"stdout": bytearray(), "stderr": bytearray()}
limits = {"stdout": stdout_limit, "stderr": stderr_limit}
deadline = time.monotonic() + timeout_seconds
termination_deadline = None
reason = None
kill_sent = False


def terminate_group(sig: int) -> None:
    try:
        os.killpg(process.pid, sig)
    except ProcessLookupError:
        pass


while selector.get_map() or process.poll() is None:
    now = time.monotonic()
    if reason is None and now >= deadline:
        reason = "timeout"
        termination_deadline = now + 5.0
        terminate_group(signal.SIGTERM)
    if reason is not None and termination_deadline is not None and now >= termination_deadline:
        if not kill_sent:
            terminate_group(signal.SIGKILL)
            kill_sent = True
            termination_deadline = now + 5.0
        else:
            break

    for key, _ in selector.select(0.05):
        chunk = os.read(key.fileobj.fileno(), 4096)
        if not chunk:
            selector.unregister(key.fileobj)
            continue
        stream_name = key.data
        prospective_stream = len(buffers[stream_name]) + len(chunk)
        prospective_combined = len(buffers["stdout"]) + len(buffers["stderr"]) + len(chunk)
        if prospective_stream > limits[stream_name] or prospective_combined > combined_limit:
            if reason is None:
                reason = "overflow"
                termination_deadline = time.monotonic() + 5.0
                terminate_group(signal.SIGTERM)
            continue
        buffers[stream_name].extend(chunk)

if process.poll() is None:
    terminate_group(signal.SIGKILL)
try:
    return_code = process.wait(timeout=5.0)
except subprocess.TimeoutExpired:
    return_code = None

selector.close()
process.stdout.close()
process.stderr.close()

for path, stream_name in ((stdout_path, "stdout"), (stderr_path, "stderr")):
    with open(path, "xb") as output:
        output.write(buffers[stream_name])
        output.flush()
        os.fsync(output.fileno())

if return_code is None:
    fail(126)
if reason == "timeout":
    fail(124)
if reason == "overflow":
    fail(125)
if return_code < 0:
    fail(min(255, 128 - return_code))
fail(return_code)
PY
}

write_failure_packet_body() {
    local criterion="$1"
    local detail="$2"
    local exit_code="$3"
    local packet_path
    local temporary_path
    local resolved_root
    local digest="$ARTIFACT_DIGEST"
    local dotnet_state="$HOST_DOTNET_COMMAND"
    local host_platform="$HOST_PLATFORM"
    local host_architecture="$HOST_ARCHITECTURE"
    local host_privilege="$HOST_PRIVILEGE"

    evidence_writer_publication_authority || return 1
    FAILURE_ROOT="$CROSS_PLATFORM_ROOT/artifacts/failures"
    mkdir -p -- "$FAILURE_ROOT" >/dev/null 2>&1 || return 1
    [[ -d "$FAILURE_ROOT" && ! -L "$FAILURE_ROOT" ]] || return 1
    resolved_root="$(realpath -e -- "$FAILURE_ROOT" 2>/dev/null)" || return 1
    [[ "$resolved_root" == "$CROSS_PLATFORM_ROOT/artifacts/failures" ]] || return 1

    [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || digest="unknown"
    [[ "$dotnet_state" == "absent" || "$dotnet_state" == "present" ]] || dotnet_state="unknown"
    [[ "$host_platform" == "linux" ]] || host_platform="unknown"
    [[ "$host_architecture" == "x64" ]] || host_architecture="unknown"
    [[ "$host_privilege" == "non-root" || "$host_privilege" == "root" ]] || \
        host_privilege="unknown"
    packet_path="$resolved_root/port-linux-sandbox.txt"
    [[ ( ! -e "$packet_path" && ! -L "$packet_path" ) ||
       ( -f "$packet_path" && ! -L "$packet_path" ) ]] || return 1
    umask 077
    temporary_path="$(mktemp "$resolved_root/.port-linux-sandbox.XXXXXX")" || return 1

    {
        printf 'schema=staxrip-port-failure-v1\n'
        printf 'gate=%s\n' "$GATE_ID"
        printf 'criterion=%s\n' "$criterion"
        printf 'detail=%s\n' "$detail"
        printf 'exit=%s\n' "$exit_code"
        printf 'replay=wsl.exe -d Ubuntu -- /usr/bin/bash --noprofile --norc <absolute-repo>/CrossPlatform/eng/verify-linux.sh <absolute-publish-dir> <absolute-manifest-path>\n'
        printf 'artifact_sha256=%s\n' "$digest"
        printf 'host_tuple=%s-%s\n' "$host_platform" "$host_architecture"
        printf 'host_privilege=%s\n' "$host_privilege"
        printf 'host_dotnet_command=%s\n' "$dotnet_state"
        printf 'raw_logs=not-retained\n'
    } >"$temporary_path" 2>/dev/null || {
        rm -f -- "$temporary_path"
        return 1
    }
    [[ ( ! -e "$packet_path" && ! -L "$packet_path" ) ||
       ( -f "$packet_path" && ! -L "$packet_path" ) ]] || {
        rm -f -- "$temporary_path"
        return 1
    }
    evidence_writer_publication_authority || {
        rm -f -- "$temporary_path"
        return 1
    }
    mv -fT -- "$temporary_path" "$packet_path" 2>/dev/null || {
        rm -f -- "$temporary_path"
        return 1
    }
    evidence_writer_publication_authority || return 1

    FAILURE_EVIDENCE="CrossPlatform/artifacts/failures/port-linux-sandbox.txt"
}

write_failure_packet() {
    local criterion="$1"
    local detail="$2"
    local exit_code="$3"
    local packet_written=0
    local lease_was_acquired="$EVIDENCE_LEASE_ACQUIRED"

    FAILURE_EVIDENCE="none"
    [[ -n "$CROSS_PLATFORM_ROOT" && -d "$CROSS_PLATFORM_ROOT/artifacts" ]] || return 0
    [[ ! -L "$CROSS_PLATFORM_ROOT/artifacts" ]] || return 0
    command -v mkdir >/dev/null 2>&1 || return 0
    command -v mktemp >/dev/null 2>&1 || return 0
    command -v mv >/dev/null 2>&1 || return 0
    command -v realpath >/dev/null 2>&1 || return 0

    enter_evidence_writer_lease || return 0
    evidence_writer_publication_authority || return 0
    if write_failure_packet_body "$criterion" "$detail" "$exit_code"; then
        packet_written=1
        FAILURE_PACKET_PUBLISHED=1
    fi
    if (( lease_was_acquired == 0 )); then
        if (( packet_written == 1 )) && ! exit_evidence_writer_lease; then
            FAILURE_EVIDENCE="none"
            return 0
        fi
    fi
    if (( packet_written == 0 )); then
        FAILURE_EVIDENCE="none"
    fi
}

remove_own_failure_packet() {
    local failure_root="$CROSS_PLATFORM_ROOT/artifacts/failures"
    local packet_path="$failure_root/port-linux-sandbox.txt"
    local resolved_root

    evidence_writer_publication_authority || return 1
    if [[ ! -e "$failure_root" && ! -L "$failure_root" ]]; then
        return 0
    fi
    [[ -d "$failure_root" && ! -L "$failure_root" ]] || return 1
    resolved_root="$(realpath -e -- "$failure_root")" || return 1
    [[ "$resolved_root" == "$CROSS_PLATFORM_ROOT/artifacts/failures" ]] || return 1
    if [[ ! -e "$packet_path" && ! -L "$packet_path" ]]; then
        return 0
    fi
    [[ -f "$packet_path" && ! -L "$packet_path" ]] || return 1
    evidence_writer_publication_authority || return 1
    rm -f -- "$packet_path" || return 1
    [[ ! -e "$packet_path" && ! -L "$packet_path" ]] || return 1
    evidence_writer_publication_authority
}

write_success_record() {
    local output_path="$1"
    local artifact_digest="$2"
    local check_count="$3"
    local runtime_writes="$4"
    local temporary_path
    local app_before="$PERSISTENT_EVIDENCE_ROOT/linux-runtime-app-before.tsv"
    local app_after="$PERSISTENT_EVIDENCE_ROOT/linux-runtime-app-after.tsv"
    local state_before="$PERSISTENT_EVIDENCE_ROOT/linux-runtime-state-before.tsv"
    local state_after="$PERSISTENT_EVIDENCE_ROOT/linux-runtime-state-after.tsv"
    local app_snapshot_sha256
    local state_snapshot_sha256
    local source_record="$PERSISTENT_EVIDENCE_ROOT/static-gate.json"
    local source_record_resolved
    local source_record_sha256

    evidence_writer_publication_authority || return 1
    [[ "$output_path" == "$PERSISTENT_EVIDENCE_ROOT/linux-runtime.json" ]] || return 1
    [[ "$artifact_digest" =~ ^[0-9a-f]{64}$ ]] || return 1
    [[ "$check_count" =~ ^[0-9]+$ && "$runtime_writes" == "0" ]] || return 1
    [[ "$HOST_DOTNET_COMMAND" == "absent" || "$HOST_DOTNET_COMMAND" == "present" ]] || return 1
    [[ "$HOST_VIRT" =~ ^[a-z0-9-]{1,32}$ && "$HOST_CONTAINER" =~ ^[a-z0-9-]{1,32}$ ]] || return 1
    [[ "$HOST_KERNEL_RELEASE" =~ ^[A-Za-z0-9._+-]{1,64}$ ]] || return 1
    [[ "$HOST_OS_ID" =~ ^[a-z0-9._-]{1,32}$ && "$HOST_OS_VERSION_ID" =~ ^[A-Za-z0-9._-]{1,32}$ ]] || return 1
    [[ "$HOST_MACHINE_ID_SHA256" =~ ^[0-9a-f]{64}$ ]] || return 1
    [[ "$HOST_WSL_INTEROP" == "true" || "$HOST_WSL_INTEROP" == "false" ]] || return 1

    [[ -d "$PERSISTENT_EVIDENCE_ROOT" && ! -L "$PERSISTENT_EVIDENCE_ROOT" ]] || return 1
    [[ "$(realpath -e -- "$PERSISTENT_EVIDENCE_ROOT")" == "$CROSS_PLATFORM_ROOT/artifacts/evidence" ]] || \
        return 1
    [[ -f "$app_before" && ! -L "$app_before" &&
       -f "$app_after" && ! -L "$app_after" &&
       -f "$state_before" && ! -L "$state_before" &&
       -f "$state_after" && ! -L "$state_after" ]] || \
        return 1
    [[ ( ! -e "$output_path" && ! -L "$output_path" ) ||
       ( -f "$output_path" && ! -L "$output_path" ) ]] || return 1
    cmp -s "$app_before" "$app_after" || return 1
    cmp -s "$state_before" "$state_after" || return 1
    app_snapshot_sha256="$(sha256sum -- "$app_before")" || return 1
    app_snapshot_sha256="${app_snapshot_sha256%% *}"
    state_snapshot_sha256="$(sha256sum -- "$state_before")" || return 1
    state_snapshot_sha256="${state_snapshot_sha256%% *}"
    [[ "$app_snapshot_sha256" =~ ^[0-9a-f]{64}$ ]] || return 1
    [[ "$state_snapshot_sha256" =~ ^[0-9a-f]{64}$ ]] || return 1

    [[ -f "$source_record" && ! -L "$source_record" ]] || return 1
    source_record_resolved="$(realpath -e -- "$source_record")" || return 1
    [[ "$source_record_resolved" == "$CROSS_PLATFORM_ROOT/artifacts/evidence/static-gate.json" ]] || \
        return 1
    source_record_sha256="$(sha256sum -- "$source_record")" || return 1
    source_record_sha256="${source_record_sha256%% *}"
    [[ "$source_record_sha256" =~ ^[0-9a-f]{64}$ ]] || return 1
    [[ -f "$source_record" && ! -L "$source_record" &&
       "$(realpath -e -- "$source_record")" == "$source_record_resolved" ]] || return 1

    umask 077
    temporary_path="$(mktemp "$PERSISTENT_EVIDENCE_ROOT/.linux-runtime.XXXXXX")" || return 1
    {
        printf '{\n'
        printf '  "schema": "staxrip-linux-runtime-v1",\n'
        printf '  "gate": "port-linux-sandbox",\n'
        printf '  "result": "pass",\n'
        printf '  "sourceRecordSha256": "%s",\n' "$source_record_sha256"
        printf '  "host": {"platformId": "linux", "architectureId": "x64", "privilege": "non-root", "dotnetCommand": "%s"},\n' "$HOST_DOTNET_COMMAND"
        printf '  "artifact": {"manifest": "CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv", "sha256": "%s", "modeSource": "wsl:Ubuntu"},\n' "$artifact_digest"
        printf '  "selfContainedProof": {"invalidPath": true, "invalidDotnetRoot": true, "localHostFxr": true, "localCoreClr": true, "executed": true},\n'
        printf '  "sandbox": {"privateNetwork": true, "protectSystem": "strict", "noNewPrivileges": true, "applicationTreeChanged": false},\n'
        printf '  "filesystemEvidence": {"applicationBefore": "CrossPlatform/artifacts/evidence/linux-runtime-app-before.tsv", "applicationAfter": "CrossPlatform/artifacts/evidence/linux-runtime-app-after.tsv", "applicationSha256": "%s", "stateBefore": "CrossPlatform/artifacts/evidence/linux-runtime-state-before.tsv", "stateAfter": "CrossPlatform/artifacts/evidence/linux-runtime-state-after.tsv", "stateSha256": "%s"},\n' "$app_snapshot_sha256" "$state_snapshot_sha256"
        printf '  "httpRoutes": ["/", "/healthz", "/api/v1/capabilities"],\n'
        printf '  "childObservation": {"samples": 200, "observed": 0},\n'
        printf '  "runtimeStateWrites": %s,\n' "$runtime_writes"
        printf '  "shutdown": {"exitCode": 0, "stoppedMarker": true, "portReleased": true, "unitCollected": true, "cgroupEmpty": true},\n'
        printf '  "hostIdentity": {"virt": "%s", "container": "%s", "kernelRelease": "%s", "osId": "%s", "osVersionId": "%s", "machineIdSha256": "%s", "wslInterop": %s},\n' \
            "$HOST_VIRT" "$HOST_CONTAINER" "$HOST_KERNEL_RELEASE" \
            "$HOST_OS_ID" "$HOST_OS_VERSION_ID" "$HOST_MACHINE_ID_SHA256" "$HOST_WSL_INTEROP"
        printf '  "checks": %s\n' "$check_count"
        printf '}\n'
    } >"$temporary_path" || {
        rm -f -- "$temporary_path"
        return 1
    }

    [[ ( ! -e "$output_path" && ! -L "$output_path" ) ||
       ( -f "$output_path" && ! -L "$output_path" ) ]] || {
        rm -f -- "$temporary_path"
        return 1
    }
    evidence_writer_publication_authority || {
        rm -f -- "$temporary_path"
        return 1
    }
    mv -fT -- "$temporary_path" "$output_path" || {
        rm -f -- "$temporary_path"
        return 1
    }
    evidence_writer_publication_authority
}

persist_success_snapshots() {
    local transient_root="$1"
    local persistent_root="$2"
    local source_path
    local target_path
    local temporary_path
    local name

    evidence_writer_publication_authority || return 1
    [[ -d "$transient_root" && ! -L "$transient_root" ]] || return 1
    [[ "$persistent_root" == "$PERSISTENT_EVIDENCE_ROOT" ]] || return 1
    [[ -d "$persistent_root" && ! -L "$persistent_root" ]] || return 1

    for name in app-before app-after state-before state-after; do
        source_path="$transient_root/$name.tsv"
        target_path="$persistent_root/linux-runtime-$name.tsv"
        [[ -f "$source_path" && ! -L "$source_path" ]] || return 1
        [[ ( ! -e "$target_path" && ! -L "$target_path" ) ||
           ( -f "$target_path" && ! -L "$target_path" ) ]] || return 1
        temporary_path="$(mktemp "$persistent_root/.linux-runtime-$name.XXXXXX")" || return 1
        cp -- "$source_path" "$temporary_path" || {
            rm -f -- "$temporary_path"
            return 1
        }
        [[ ( ! -e "$target_path" && ! -L "$target_path" ) ||
           ( -f "$target_path" && ! -L "$target_path" ) ]] || {
            rm -f -- "$temporary_path"
            return 1
        }
        evidence_writer_publication_authority || {
            rm -f -- "$temporary_path"
            return 1
        }
        mv -fT -- "$temporary_path" "$target_path" || {
            rm -f -- "$temporary_path"
            return 1
        }
        evidence_writer_publication_authority || return 1
    done
}

verify_artifact_manifest() {
    local publish_root="$1"
    local manifest_path="$2"
    local companion_path="$3"

    python3 -I - "$publish_root" "$manifest_path" "$companion_path" <<'PY'
import hashlib
import os
import re
import stat
import sys

EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
PREAMBLE = "# staxrip-artifact-manifest-v1"
MODE_SOURCE = "# mode-source=wsl:Ubuntu"
HEADER = "path\ttype\tlength\tsha256\tmode"
PATH_PATTERN = re.compile(r"^[\x20-\x7e]+$")
SHA_PATTERN = re.compile(r"^[0-9a-f]{64}$")
MODE_PATTERN = re.compile(r"^[0-7]{4}$")


def reject() -> None:
    raise ValueError("invalid artifact manifest")


def validate_path(value: str) -> None:
    if not PATH_PATTERN.fullmatch(value):
        reject()
    if "\\" in value or value.startswith("/") or value.endswith("/"):
        reject()
    parts = value.split("/")
    if any(part in ("", ".", "..") for part in parts):
        reject()


def file_sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def enumerate_tree(root: str):
    rows = []

    def visit(relative: str) -> None:
        absolute = os.path.join(root, *relative.split("/"))
        metadata = os.lstat(absolute)
        mode = format(stat.S_IMODE(metadata.st_mode), "04o")

        if stat.S_ISLNK(metadata.st_mode):
            reject()
        if stat.S_ISDIR(metadata.st_mode):
            rows.append((relative, "directory", "0", EMPTY_SHA256, mode))
            with os.scandir(absolute) as entries:
                children = [entry.name for entry in entries]
            for child in sorted(children, key=lambda item: item.encode("utf-8")):
                validate_path(child)
                visit(f"{relative}/{child}")
            return
        if stat.S_ISREG(metadata.st_mode):
            rows.append(
                (relative, "file", str(metadata.st_size), file_sha256(absolute), mode)
            )
            return
        reject()

    with os.scandir(root) as entries:
        top_level = [entry.name for entry in entries]

    for name in sorted(top_level, key=lambda item: item.encode("utf-8")):
        validate_path(name)
        visit(name)

    rows.sort(key=lambda row: row[0].encode("utf-8"))
    return rows


try:
    root = os.path.realpath(sys.argv[1])
    manifest = os.path.realpath(sys.argv[2])
    companion = os.path.realpath(sys.argv[3])

    if os.path.commonpath((root, manifest)) == root:
        reject()
    if os.path.commonpath((root, companion)) == root:
        reject()

    with open(manifest, "rb") as stream:
        raw = stream.read(10 * 1024 * 1024 + 1)
    if len(raw) > 10 * 1024 * 1024 or not raw.endswith(b"\n") or b"\r" in raw:
        reject()

    text = raw.decode("ascii", errors="strict")
    lines = text[:-1].split("\n")
    if len(lines) < 4:
        reject()
    if lines[:3] != [PREAMBLE, MODE_SOURCE, HEADER]:
        reject()

    manifest_rows = []
    paths = []

    for line in lines[3:]:
        fields = line.split("\t")
        if len(fields) != 5:
            reject()
        path, entry_type, length, sha256, mode = fields
        validate_path(path)
        if entry_type not in ("file", "directory"):
            reject()
        if not re.fullmatch(r"0|[1-9][0-9]*", length):
            reject()
        if not SHA_PATTERN.fullmatch(sha256) or not MODE_PATTERN.fullmatch(mode):
            reject()
        if entry_type == "directory" and (length != "0" or sha256 != EMPTY_SHA256):
            reject()
        manifest_rows.append((path, entry_type, length, sha256, mode))
        paths.append(path)

    if len(paths) != len(set(paths)):
        reject()
    if paths != sorted(paths, key=lambda item: item.encode("utf-8")):
        reject()

    actual_rows = enumerate_tree(root)
    if manifest_rows != actual_rows:
        reject()

    launchers = [row for row in manifest_rows if row[0] == "StaxRip.Server"]
    if len(launchers) != 1 or launchers[0][1] != "file":
        reject()
    if int(launchers[0][4], 8) & 0o111 == 0:
        reject()

    manifest_digest = hashlib.sha256(raw).hexdigest()
    expected_companion = f"{manifest_digest}  {os.path.basename(manifest)}\n".encode("ascii")
    with open(companion, "rb") as stream:
        if stream.read() != expected_companion:
            reject()

    print(manifest_digest)
except Exception:
    sys.exit(1)
PY
}

write_tree_snapshot() {
    local tree_root="$1"
    local output_path="$2"
    local policy="$3"

    python3 -I - "$tree_root" "$output_path" "$policy" <<'PY'
import hashlib
import os
import stat
import sys


def digest_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def safe_relative(path: str) -> None:
    if not path or "\t" in path or "\r" in path or "\n" in path or "\0" in path:
        raise ValueError("unsafe path")
    path.encode("ascii", errors="strict")


try:
    root = os.path.realpath(sys.argv[1])
    output = sys.argv[2]
    policy = sys.argv[3]
    if policy not in ("application", "runtime-state"):
        raise ValueError("unknown snapshot policy")

    rows = []

    def add_entry(relative: str, absolute: str) -> None:
        safe_relative(relative)
        metadata = os.lstat(absolute)
        mode = format(stat.S_IMODE(metadata.st_mode), "04o")
        modified_ns = str(metadata.st_mtime_ns)

        if stat.S_ISREG(metadata.st_mode):
            rows.append(
                (relative, "file", str(metadata.st_size), digest_file(absolute), mode, modified_ns)
            )
        elif stat.S_ISDIR(metadata.st_mode):
            rows.append(
                (
                    relative,
                    "directory",
                    "0",
                    hashlib.sha256(b"").hexdigest(),
                    mode,
                    modified_ns,
                )
            )
        elif policy == "application":
            raise ValueError("special application entry")
        elif stat.S_ISLNK(metadata.st_mode):
            rows.append((relative, "symlink", str(metadata.st_size), "-", mode, modified_ns))
        elif stat.S_ISSOCK(metadata.st_mode):
            rows.append((relative, "socket", "0", "-", mode, modified_ns))
        elif stat.S_ISFIFO(metadata.st_mode):
            rows.append((relative, "fifo", "0", "-", mode, modified_ns))
        elif stat.S_ISCHR(metadata.st_mode):
            rows.append((relative, "character", "0", "-", mode, modified_ns))
        elif stat.S_ISBLK(metadata.st_mode):
            rows.append((relative, "block", "0", "-", mode, modified_ns))
        else:
            rows.append((relative, "other", str(metadata.st_size), "-", mode, modified_ns))

    add_entry(".", root)

    def visit(directory: str, relative_directory: str) -> None:
        with os.scandir(directory) as entries:
            children = list(entries)
        children.sort(key=lambda entry: entry.name.encode("utf-8"))

        for entry in children:
            relative = entry.name if not relative_directory else f"{relative_directory}/{entry.name}"
            safe_relative(relative)
            add_entry(relative, entry.path)
            if entry.is_dir(follow_symlinks=False):
                visit(entry.path, relative)

    visit(root, "")
    rows.sort(key=lambda row: row[0].encode("utf-8"))

    with open(output, "w", encoding="ascii", newline="\n") as stream:
        stream.write("path\ttype\tlength\tsha256\tmode\tmodified_ns\n")
        for row in rows:
            stream.write("\t".join(row) + "\n")
except Exception:
    sys.exit(1)
PY
}

count_snapshot_delta() {
    local before_path="$1"
    local after_path="$2"

    python3 -I - "$before_path" "$after_path" <<'PY'
import sys


def load(path: str):
    with open(path, "r", encoding="ascii", newline="") as stream:
        lines = stream.read().splitlines()
    if not lines or lines[0] != "path\ttype\tlength\tsha256\tmode\tmodified_ns":
        raise ValueError("invalid snapshot")
    result = {}
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != 6 or fields[0] in result:
            raise ValueError("invalid snapshot row")
        result[fields[0]] = tuple(fields[1:])
    return result


try:
    before = load(sys.argv[1])
    after = load(sys.argv[2])
    changed = sum(1 for key in set(before) | set(after) if before.get(key) != after.get(key))
    print(changed)
except Exception:
    sys.exit(1)
PY
}

validate_json_responses() {
    local health_path="$1"
    local capabilities_path="$2"

    python3 -I - "$health_path" "$capabilities_path" <<'PY'
import json
import re
import sys


def load(path: str):
    with open(path, "rb") as stream:
        raw = stream.read(256 * 1024 + 1)
    if len(raw) > 256 * 1024:
        raise ValueError("response too large")
    return json.loads(raw.decode("utf-8"))


try:
    health = load(sys.argv[1])
    if health != {
        "schemaVersion": "1",
        "apiVersion": "v1",
        "engineVersion": "0.1.0-bootstrap",
        "status": "ready",
    }:
        raise ValueError("health contract")

    capabilities = load(sys.argv[2])
    if set(capabilities) != {
        "schemaVersion", "apiVersion", "engineVersion", "host", "features", "tools"
    }:
        raise ValueError("capability keys")
    if capabilities["schemaVersion"] != "1" or capabilities["apiVersion"] != "v1":
        raise ValueError("capability version")
    if capabilities["engineVersion"] != "0.1.0-bootstrap":
        raise ValueError("engine version")

    host = capabilities["host"]
    if set(host) != {
        "platformId", "architectureId", "runtimeVersion", "logicalProcessorCount"
    }:
        raise ValueError("host keys")
    if host["platformId"] != "linux" or host["architectureId"] != "x64":
        raise ValueError("host tuple")
    if not isinstance(host["runtimeVersion"], str) or not re.fullmatch(
        r"[A-Za-z0-9._-]{1,32}", host["runtimeVersion"]
    ):
        raise ValueError("runtime version")
    processor_count = host["logicalProcessorCount"]
    if isinstance(processor_count, bool) or not isinstance(processor_count, int):
        raise ValueError("processor count type")
    if not 1 <= processor_count <= 4096:
        raise ValueError("processor count range")

    expected_features = [
        ("local-engine", "Local engine", "available", "bootstrap-ready"),
        ("web-shell", "Web shell", "available", "bootstrap-ready"),
        ("media-inspection", "Media inspection", "unavailable", "bootstrap-unavailable"),
        ("encoding", "Encoding", "unavailable", "bootstrap-unavailable"),
        ("persistence", "Persistence", "unavailable", "bootstrap-unavailable"),
        ("remote-access", "Remote access", "unavailable", "bootstrap-unavailable"),
        ("plugins", "Plugins", "unavailable", "bootstrap-unavailable"),
        ("project-import", "Project import", "unavailable", "bootstrap-unavailable"),
    ]
    actual_features = []
    for feature in capabilities["features"]:
        if set(feature) != {"id", "displayName", "availability", "reasonCode"}:
            raise ValueError("feature keys")
        actual_features.append(
            (feature["id"], feature["displayName"], feature["availability"], feature["reasonCode"])
        )
    if actual_features != expected_features:
        raise ValueError("feature catalog")

    expected_tools = [
        ("ffmpeg", "FFmpeg"),
        ("ffprobe", "ffprobe"),
        ("vapoursynth", "VapourSynth"),
        ("avisynth-plus", "AviSynth+"),
        ("mkvtoolnix", "MKVToolNix"),
        ("nvenc", "NVEnc"),
    ]
    actual_tools = []
    for tool in capabilities["tools"]:
        if set(tool) != {"id", "displayName", "compatibility", "reasonCode"}:
            raise ValueError("tool keys")
        if tool["compatibility"] != "unverified":
            raise ValueError("tool compatibility")
        if tool["reasonCode"] != "compatibility-not-tested":
            raise ValueError("tool reason")
        actual_tools.append((tool["id"], tool["displayName"]))
    if actual_tools != expected_tools:
        raise ValueError("tool catalog")
except Exception:
    sys.exit(1)
PY
}

validate_cookie_jar() {
    local cookie_jar="$1"

    python3 -I - "$cookie_jar" <<'PY'
import re
import sys

try:
    with open(sys.argv[1], "r", encoding="ascii", newline="") as stream:
        lines = stream.read().splitlines()

    rows = [line for line in lines if line and (not line.startswith("#") or line.startswith("#HttpOnly_"))]
    if len(rows) != 1:
        raise ValueError("cookie count")
    fields = rows[0].split("\t")
    if len(fields) != 7:
        raise ValueError("cookie fields")
    domain, include_subdomains, path, secure, expires, name, value = fields
    if domain != "#HttpOnly_127.0.0.1" or include_subdomains != "FALSE":
        raise ValueError("cookie domain")
    if path != "/api/v1" or secure != "FALSE" or expires != "0":
        raise ValueError("cookie attributes")
    if not re.fullmatch(r"staxrip_session_[0-9A-F]{24}", name):
        raise ValueError("cookie name")
    if not re.fullmatch(r"[0-9A-F]{64}", value):
        raise ValueError("cookie value shape")
except Exception:
    sys.exit(1)
PY
}

reset_app_process_ownership() {
    APP_PID=""
    APP_START_TICKS=""
    APP_EXECUTABLE_PATH=""
    APP_OWNERSHIP_REGISTERED=0
    APP_EXPECTED_ARGV=()
}

read_proc_start_ticks() {
    local process_id="$1"

    python3 -I - "$process_id" <<'PY'
import re
import sys

try:
    pid = int(sys.argv[1])
    if pid <= 0:
        raise ValueError("pid")
    with open(f"/proc/{pid}/stat", "r", encoding="ascii") as stream:
        value = stream.read()
    close = value.rfind(") ")
    if close < 0:
        raise ValueError("stat shape")
    fields = value[close + 2:].split()
    if len(fields) < 20 or not re.fullmatch(r"[0-9]+", fields[19]):
        raise ValueError("start ticks")
    print(fields[19])
except Exception:
    sys.exit(1)
PY
}

app_process_receipt_matches() {
    [[ "$APP_PID" =~ ^[0-9]+$ && "$APP_PID" != "0" ]] || return 1
    [[ "$APP_START_TICKS" =~ ^[0-9]+$ && "$APP_START_TICKS" != "0" ]] || return 1
    [[ -n "$APP_EXECUTABLE_PATH" && -x "$APP_EXECUTABLE_PATH" &&
       -f "$APP_EXECUTABLE_PATH" && ! -L "$APP_EXECUTABLE_PATH" ]] || return 1
    (( ${#APP_EXPECTED_ARGV[@]} > 0 )) || return 1

    python3 -I - \
        "$APP_PID" \
        "$APP_START_TICKS" \
        "$APP_EXECUTABLE_PATH" \
        "${APP_EXPECTED_ARGV[@]}" <<'PY'
import os
import re
import sys

try:
    pid = int(sys.argv[1])
    expected_start = sys.argv[2]
    expected_executable = sys.argv[3]
    expected_argv = sys.argv[4:]
    if pid <= 0 or not re.fullmatch(r"[0-9]+", expected_start) or not expected_argv:
        raise ValueError("receipt")

    with open(f"/proc/{pid}/stat", "r", encoding="ascii") as stream:
        stat_value = stream.read()
    close = stat_value.rfind(") ")
    if close < 0:
        raise ValueError("stat shape")
    stat_fields = stat_value[close + 2:].split()
    if len(stat_fields) < 20 or stat_fields[19] != expected_start:
        raise ValueError("start ticks")

    if os.path.realpath(f"/proc/{pid}/exe") != expected_executable:
        raise ValueError("executable")
    with open(f"/proc/{pid}/cmdline", "rb") as stream:
        actual_argv = stream.read()
    encoded_argv = []
    for argument in expected_argv:
        encoded = os.fsencode(argument)
        if b"\0" in encoded:
            raise ValueError("argv nul")
        encoded_argv.append(encoded + b"\0")
    if actual_argv != b"".join(encoded_argv):
        raise ValueError("argv")
except Exception:
    sys.exit(1)
PY
}

app_process_ownership_matches() {
    (( APP_OWNERSHIP_REGISTERED == 1 )) || return 1
    app_process_receipt_matches
}

register_app_process_ownership() {
    local process_id="$1"
    local executable_path="$2"
    shift 2
    local initial_start_ticks
    local current_start_ticks
    local sample

    reset_app_process_ownership
    [[ "$process_id" =~ ^[0-9]+$ && "$process_id" != "0" ]] || return 1
    [[ -x "$executable_path" && -f "$executable_path" && ! -L "$executable_path" ]] || return 1
    (( $# > 0 )) || return 1

    initial_start_ticks="$(read_proc_start_ticks "$process_id")" || return 1
    [[ "$initial_start_ticks" =~ ^[0-9]+$ && "$initial_start_ticks" != "0" ]] || return 1
    APP_PID="$process_id"
    APP_START_TICKS="$initial_start_ticks"
    APP_EXECUTABLE_PATH="$executable_path"
    APP_EXPECTED_ARGV=("$@")

    # The short-lived Python launcher execs the app in place. Keep the original
    # start-time receipt fixed while waiting for the exact exe and NUL argv.
    for ((sample = 0; sample < 100; sample++)); do
        if app_process_receipt_matches; then
            APP_OWNERSHIP_REGISTERED=1
            return 0
        fi
        current_start_ticks="$(read_proc_start_ticks "$process_id" 2>/dev/null)" || return 1
        [[ "$current_start_ticks" == "$APP_START_TICKS" ]] || return 1
        /usr/bin/sleep 0.01
    done
    return 1
}

bounded_regular_file_below() {
    local path="$1"
    local limit="$2"
    local size

    [[ "$limit" =~ ^[1-9][0-9]*$ && -f "$path" && ! -L "$path" ]] || return 1
    size="$(stat -c '%s' -- "$path" 2>/dev/null)" || return 1
    [[ "$size" =~ ^[0-9]+$ ]] || return 1
    (( size < limit ))
}

bounded_regular_file_at_most() {
    local path="$1"
    local limit="$2"
    local size

    [[ "$limit" =~ ^[1-9][0-9]*$ && -f "$path" && ! -L "$path" ]] || return 1
    size="$(stat -c '%s' -- "$path" 2>/dev/null)" || return 1
    [[ "$size" =~ ^[0-9]+$ ]] || return 1
    (( size <= limit ))
}

run_capped_curl() {
    local output_limit="$1"
    shift

    [[ "$output_limit" =~ ^[1-9][0-9]*$ && "${1:-}" == "/usr/bin/curl" ]] || return 2
    /usr/bin/python3 -I - "$output_limit" "$@" <<'PY'
import os
import resource
import sys

limit = int(sys.argv[1])
argv = sys.argv[2:]
if limit <= 0 or not argv or argv[0] != "/usr/bin/curl":
    sys.exit(2)
resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))
os.execv(argv[0], argv)
PY
}

verify_listener_ownership() {
    local process_id="$1"
    local expected_port="$2"

    python3 -I - "$process_id" "$expected_port" <<'PY'
import os
import re
import sys

try:
    pid = int(sys.argv[1])
    port = int(sys.argv[2])
    if not 1 <= port <= 65535:
        raise ValueError("port")

    owned = set()
    for name in os.listdir(f"/proc/{pid}/fd"):
        try:
            target = os.readlink(f"/proc/{pid}/fd/{name}")
        except FileNotFoundError:
            continue
        match = re.fullmatch(r"socket:\[([0-9]+)\]", target)
        if match:
            owned.add(match.group(1))

    listeners = []
    for family, path in (("tcp", "/proc/net/tcp"), ("tcp6", "/proc/net/tcp6")):
        with open(path, "r", encoding="ascii") as stream:
            next(stream)
            for line in stream:
                fields = line.split()
                if len(fields) < 10 or fields[3] != "0A":
                    continue
                listeners.append((family, fields[1], fields[9]))

    expected_address = f"0100007F:{port:04X}"
    if len(listeners) != 1:
        raise ValueError("listener count")
    family, address, inode = listeners[0]
    if family != "tcp" or address != expected_address or inode not in owned:
        raise ValueError("listener identity")
except Exception:
    sys.exit(1)
PY
}

verify_port_released_and_rebind() {
    local released_port="$1"

    python3 -I - "$released_port" <<'PY'
import socket
import sys

try:
    port = int(sys.argv[1])
    for path in ("/proc/net/tcp", "/proc/net/tcp6"):
        with open(path, "r", encoding="ascii") as stream:
            next(stream)
            for line in stream:
                fields = line.split()
                if len(fields) >= 4 and fields[3] == "0A":
                    if int(fields[1].rsplit(":", 1)[1], 16) == port:
                        raise ValueError("port remains bound")

    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        probe.bind(("127.0.0.1", port))
    finally:
        probe.close()
except Exception:
    sys.exit(1)
PY
}

sample_app_children() {
    local process_id="$1"
    local stdout_path="$2"
    local stderr_path="$3"
    local output_limit="$4"
    local sample
    local children

    # R-S2-037. Removing the process-wide file-size limit fixed a runtime that could not
    # start, but it left the output cap enforced only by polls at readiness and at
    # shutdown, with this roughly four-second observation window uncovered in between.
    # Polling here closes that gap, so an overflow is detected while it happens rather
    # than after the fact. Distinct return codes keep the reasons separable: the caller
    # previously collapsed every non-zero result into one detail, which is the
    # diagnosis-destroying pattern this slice has hit repeatedly.
    for ((sample = 0; sample < 200; sample++)); do
        [[ -r "/proc/$process_id/task/$process_id/children" ]] || return 2
        children="$(<"/proc/$process_id/task/$process_id/children")"
        [[ -z "${children//[[:space:]]/}" ]] || return 3
        # The size helper returns one status for every failure it can hit, including a
        # missing or replaced file, so mapping its status straight to "overflow" would
        # misreport those. Distinguish file validity from size here. The meanings are
        # near single, not absolute: 5 is gone or not a regular file at the validity
        # check, 4 is too large, and a file deleted in the roughly twenty milliseconds
        # between the two checks still reports 4. The window is one sample iteration
        # and the gate fails either way.
        [[ -f "$stdout_path" && ! -L "$stdout_path" && -f "$stderr_path" && ! -L "$stderr_path" ]] || return 5
        bounded_regular_file_below "$stdout_path" "$output_limit" || return 4
        bounded_regular_file_below "$stderr_path" "$output_limit" || return 4
        /usr/bin/sleep 0.02
    done
}

unit_main() {
    MODE="unit"
    CURRENT_CRITERION="unit-input"

    [[ "$#" -eq 5 ]] || die "unit-input" "argument-count"

    local app_root="$1"
    local runtime_root="$2"
    local harness_root="$3"
    EVIDENCE_ROOT="$4"
    local unit_name="$5"
    local writable_root
    local sandbox_root
    local launcher
    local runtime_home
    local runtime_config
    local runtime_cache
    local runtime_data
    local runtime_tmp
    local server_stdout
    local server_stderr
    local cookie_jar
    local root_body
    local health_body
    local capabilities_body
    local status_code
    local ready_line
    local port
    local monitor_exit
    local app_exit
    local sample
    local process_state
    local state_delta
    local cgroup_line
    local cgroup_path
    local cgroup_processes
    local server_output_limit=524288
    local root_body_limit=262144
    local json_body_limit=65536
    local cookie_jar_limit=65536

    app_root="$(realpath -e -- "$app_root")"
    runtime_root="$(realpath -e -- "$runtime_root")"
    harness_root="$(realpath -e -- "$harness_root")"
    EVIDENCE_ROOT="$(realpath -e -- "$EVIDENCE_ROOT")"
    writable_root="$(dirname -- "$runtime_root")"
    sandbox_root="$(dirname -- "$app_root")"

    is_valid_sandbox_root "$sandbox_root" || die "unit-input" "sandbox-path"
    is_valid_unit_name "$unit_name" || die "unit-input" "unit-name"
    [[ "$app_root" == "$sandbox_root/app" ]] || die "unit-input" "app-path"
    [[ "$runtime_root" == "$sandbox_root/writable/runtime" ]] || die "unit-input" "runtime-path"
    [[ "$harness_root" == "$sandbox_root/writable/harness" ]] || die "unit-input" "harness-path"
    [[ "$EVIDENCE_ROOT" == "$sandbox_root/writable/evidence" ]] || die "unit-input" "evidence-path"
    [[ "$writable_root" == "$sandbox_root/writable" ]] || die "unit-input" "writable-path"
    pass_check

    launcher="$app_root/StaxRip.Server"
    runtime_home="$runtime_root/home"
    runtime_config="$runtime_root/xdg-config"
    runtime_cache="$runtime_root/xdg-cache"
    runtime_data="$runtime_root/xdg-data"
    runtime_tmp="$runtime_root/tmp"
    server_stdout="$harness_root/server.stdout"
    server_stderr="$harness_root/server.stderr"
    cookie_jar="$harness_root/session.cookies"
    root_body="$harness_root/root.body"
    health_body="$harness_root/health.body"
    capabilities_body="$harness_root/capabilities.body"

    [[ -x "$launcher" && -f "$launcher" && ! -L "$launcher" ]] || \
        die "unit-input" "launcher-invalid"
    [[ -d "$runtime_home" && -d "$runtime_config" && -d "$runtime_cache" ]] || \
        die "unit-input" "state-root-missing"
    [[ -d "$runtime_data" && -d "$runtime_tmp" ]] || \
        die "unit-input" "state-root-missing"
    pass_check

    CURRENT_CRITERION="sandbox-activation"
    mapfile -t network_interfaces < <(
        find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort
    )
    [[ "${#network_interfaces[@]}" -eq 1 && "${network_interfaces[0]}" == "lo" ]] || \
        die "sandbox-activation" "network-not-private"

    [[ "$(awk '$1 == "NoNewPrivs:" { print $2 }' /proc/self/status)" == "1" ]] || \
        die "sandbox-activation" "new-privileges-enabled"

    local blocked_probe="/tmp/staxrip-unit-write-probe-$$"
    if ( : >"$blocked_probe" ) 2>/dev/null; then
        rm -f -- "$blocked_probe"
        die "sandbox-activation" "filesystem-not-readonly"
    fi

    if ( : >"$app_root/.write-probe" ) 2>/dev/null; then
        rm -f -- "$app_root/.write-probe"
        die "sandbox-activation" "app-tree-writable"
    fi

    if ( : >"$runtime_tmp/.write-probe" ) 2>/dev/null; then
        rm -f -- "$runtime_tmp/.write-probe"
        die "sandbox-activation" "runtime-state-writable"
    fi

    printf 'probe\n' >"$harness_root/.write-probe"
    rm -f -- "$harness_root/.write-probe"

    # R-S2-046 closed by removal, not by a probe. The home property was recorded as a fixed
    # literal with nothing behind it, so the first repair added a write probe against the
    # home roots. Execution showed that probe was itself vacuous: on the supported runtime
    # /home is root-owned 755 and /root is root-owned 700, so the unprivileged account the
    # gate requires is denied on both with no sandboxing at all, and the probe returns the
    # same answer whether the property applies or not. Its untestable escape could not fire
    # either, because the directory exists.
    #
    # No write probe can do better here. ProtectSystem=strict already mounts the whole
    # hierarchy read-only except the declared writable paths, so every candidate target is
    # unwritable for that reason alone and none can isolate this property's contribution.
    # The honest conclusion is that the property is subsumed by the strict system protection
    # and is not independently observable from inside this unit, so the record no longer
    # claims it. Recording a value that cannot be checked is what created the finding.
    # Do not reintroduce this field without a probe that can actually fail.
    pass_check

    CURRENT_CRITERION="runtime-start"
    /usr/bin/python3 -I - \
        "$launcher" \
        "$server_output_limit" \
        "$runtime_home" \
        "$runtime_config" \
        "$runtime_cache" \
        "$runtime_data" \
        "$runtime_tmp" \
        >"$server_stdout" 2>"$server_stderr" <<'PY' &
import os
import resource
import sys

launcher = sys.argv[1]
output_limit = int(sys.argv[2])
environment = {
    "HOME": sys.argv[3],
    "XDG_CONFIG_HOME": sys.argv[4],
    "XDG_CACHE_HOME": sys.argv[5],
    "XDG_DATA_HOME": sys.argv[6],
    "TMPDIR": sys.argv[7],
    "TMP": sys.argv[7],
    "TEMP": sys.argv[7],
    "PATH": "/staxrip-no-host-tools",
    "DOTNET_ROOT": "/staxrip-no-host-dotnet",
    "DOTNET_MULTILEVEL_LOOKUP": "0",
    "DOTNET_EnableDiagnostics": "0",
    "COMPlus_EnableDiagnostics": "0",
    "DOTNET_CLI_TELEMETRY_OPTOUT": "1",
    "DOTNET_NOLOGO": "1",
    "ASPNETCORE_ENVIRONMENT": "Production",
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "TZ": "UTC",
}
# Do not bound server output with RLIMIT_FSIZE. That limit applies to every file the
# process creates or extends, not just the redirected stdout and stderr. The .NET
# write-xor-execute double mapping backs executable memory with a file, and
# System.Private.CoreLib.dll is far larger than this limit, so the runtime failed to
# start with "Failed to load System.Private.CoreLib.dll ... Out Of Memory" and the gate
# reported it as a process-ownership failure. Redirected output stays bounded by the
# existing bounded_regular_file_below poll against server_output_limit in the readiness
# and observation loops, which is the mechanism that actually enforces the cap.
# Tracked in Docs/Review/SLICE-002-Remediation-Backlog.md as R-S2-037.
_ = output_limit
os.execve(launcher, [launcher], environment)
PY
    APP_PID="$!"

    [[ "$APP_PID" =~ ^[0-9]+$ ]] || die "runtime-start" "pid-invalid"
    register_app_process_ownership "$APP_PID" "$launcher" "$launcher" || \
        die "runtime-start" "ownership-registration"

    ready_line=""
    for ((sample = 0; sample < 300; sample++)); do
        bounded_regular_file_below "$server_stdout" "$server_output_limit" || \
            die "runtime-start" "stdout-overflow"
        bounded_regular_file_below "$server_stderr" "$server_output_limit" || \
            die "runtime-start" "stderr-overflow"
        if [[ -s "$server_stdout" ]]; then
            mapfile -t -n 2 ready_lines < <(grep -m 2 '^READY ' "$server_stdout" || true)
            if (( ${#ready_lines[@]} > 0 )); then
                [[ "${#ready_lines[@]}" -eq 1 ]] || die "runtime-start" "ready-count"
                ready_line="${ready_lines[0]}"
                break
            fi
        fi

        [[ -d "/proc/$APP_PID" ]] || die "runtime-start" "process-exited"
        /usr/bin/sleep 0.05
    done

    [[ -n "$ready_line" ]] || die "runtime-start" "ready-timeout"
    [[ "$ready_line" =~ ^READY\ http://127\.0\.0\.1:([1-9][0-9]{0,4})/$ ]] || \
        die "runtime-start" "ready-authority"
    port="${BASH_REMATCH[1]}"
    (( port <= 65535 )) || die "runtime-start" "ready-port"

    app_process_ownership_matches || die "runtime-start" "ownership-current"
    pass_check

    CURRENT_CRITERION="runtime-cgroup"
    cgroup_line="$(<"/proc/$$/cgroup")"
    [[ "$cgroup_line" =~ ^0::(/[^[:space:]]+)$ ]] || die "runtime-cgroup" "runner-cgroup"
    cgroup_path="${BASH_REMATCH[1]}"
    [[ "$(<"/proc/$APP_PID/cgroup")" == "0::$cgroup_path" ]] || \
        die "runtime-cgroup" "app-cgroup"
    printf '%s\n' "$cgroup_path" >"$EVIDENCE_ROOT/unit-cgroup"
    pass_check

    CURRENT_CRITERION="listener"
    verify_listener_ownership "$APP_PID" "$port" >/dev/null 2>&1 || \
        die "listener" "ownership"
    pass_check

    CURRENT_CRITERION="child-observation"
    sample_app_children "$APP_PID" "$server_stdout" "$server_stderr" "$server_output_limit" &
    MONITOR_PID="$!"

    CURRENT_CRITERION="http-root"
    if ! status_code="$(
        run_capped_curl "$root_body_limit" \
            /usr/bin/curl --disable --silent --show-error --http1.1 --noproxy '*' \
            --connect-timeout 2 --max-time 8 --request GET \
            --max-filesize "$root_body_limit" \
            --header "Host: 127.0.0.1:$port" \
            --cookie-jar "$cookie_jar" --output "$root_body" \
            --write-out '%{http_code}' "http://127.0.0.1:$port/"
    )"; then
        die "http-root" "curl-failed"
    fi
    [[ "$status_code" == "200" ]] || die "http-root" "status"
    bounded_regular_file_at_most "$root_body" "$root_body_limit" || \
        die "http-root" "body-size"
    bounded_regular_file_at_most "$cookie_jar" "$cookie_jar_limit" || \
        die "http-root" "cookie-size"
    [[ -s "$root_body" ]] || die "http-root" "empty-body"
    grep -Fq 'id="engine-shell"' "$root_body" || die "http-root" "shell-marker"
    validate_cookie_jar "$cookie_jar" >/dev/null 2>&1 || die "http-root" "cookie-contract"
    pass_check

    CURRENT_CRITERION="http-health"
    if ! status_code="$(
        run_capped_curl "$json_body_limit" \
            /usr/bin/curl --disable --silent --show-error --http1.1 --noproxy '*' \
            --connect-timeout 2 --max-time 8 --request GET \
            --max-filesize "$json_body_limit" \
            --header "Host: 127.0.0.1:$port" \
            --output "$health_body" --write-out '%{http_code}' \
            "http://127.0.0.1:$port/healthz"
    )"; then
        die "http-health" "curl-failed"
    fi
    [[ "$status_code" == "200" ]] || die "http-health" "status"
    bounded_regular_file_at_most "$health_body" "$json_body_limit" || \
        die "http-health" "body-size"
    pass_check

    CURRENT_CRITERION="http-capabilities"
    if ! status_code="$(
        run_capped_curl "$json_body_limit" \
            /usr/bin/curl --disable --silent --show-error --http1.1 --noproxy '*' \
            --connect-timeout 2 --max-time 8 --request GET \
            --max-filesize "$json_body_limit" \
            --header "Host: 127.0.0.1:$port" \
            --header "X-StaxRip-Client: web" \
            --cookie "$cookie_jar" --output "$capabilities_body" \
            --write-out '%{http_code}' "http://127.0.0.1:$port/api/v1/capabilities"
    )"; then
        die "http-capabilities" "curl-failed"
    fi
    [[ "$status_code" == "200" ]] || die "http-capabilities" "status"
    bounded_regular_file_at_most "$capabilities_body" "$json_body_limit" || \
        die "http-capabilities" "body-size"
    validate_json_responses "$health_body" "$capabilities_body" >/dev/null 2>&1 || \
        die "http-capabilities" "contract"
    rm -f -- "$cookie_jar"
    pass_check

    CURRENT_CRITERION="listener"
    verify_listener_ownership "$APP_PID" "$port" >/dev/null 2>&1 || \
        die "listener" "post-request-ownership"
    pass_check

    CURRENT_CRITERION="child-observation"
    # A non-zero monitor wait is an expected outcome that the check below reports.
    # "set +e" does not reach it on its own: with "set -E" the inherited ERR trap fires
    # regardless of errexit. Same repair as R-S2-035; tracked as R-S2-041.
    set +e
    trap - ERR
    wait "$MONITOR_PID"
    monitor_exit="$?"
    trap unexpected_error ERR
    set -e
    MONITOR_PID=""
    # Report which observation failed. Collapsing these into one detail was the same
    # diagnosis-destroying pattern as R-S2-035: the verdict was right and the reason was
    # not recoverable.
    case "$monitor_exit" in
        0) ;;
        2) die "child-observation" "children-unreadable" ;;
        3) die "child-observation" "child-observed" ;;
        4) die "child-observation" "output-overflow" ;;
        5) die "child-observation" "output-file-invalid" ;;
        *) die "child-observation" "monitor-failed" ;;
    esac
    pass_check

    CURRENT_CRITERION="shutdown"
    app_process_ownership_matches || die "shutdown" "ownership-current"
    kill -TERM "$APP_PID" || die "shutdown" "signal-failed"

    for ((sample = 0; sample < 120; sample++)); do
        if [[ ! -r "/proc/$APP_PID/stat" ]]; then
            break
        fi
        process_state="$(awk '{ print $3 }' "/proc/$APP_PID/stat" 2>/dev/null || true)"
        [[ "$process_state" == "Z" ]] && break
        /usr/bin/sleep 0.05
    done

    if [[ -r "/proc/$APP_PID/stat" ]]; then
        process_state="$(awk '{ print $3 }' "/proc/$APP_PID/stat" 2>/dev/null || true)"
        [[ "$process_state" == "Z" ]] || die "shutdown" "timeout"
    fi

    # A non-zero application exit is an expected outcome that the check below reports.
    # Same ERR-trap suspension as R-S2-035; tracked as R-S2-041.
    set +e
    trap - ERR
    wait "$APP_PID"
    app_exit="$?"
    trap unexpected_error ERR
    set -e
    reset_app_process_ownership
    [[ "$app_exit" -eq 0 ]] || die "shutdown" "exit-code"

    bounded_regular_file_below "$server_stdout" "$server_output_limit" || \
        die "shutdown" "stdout-overflow"
    bounded_regular_file_below "$server_stderr" "$server_output_limit" || \
        die "shutdown" "stderr-overflow"
    mapfile -t -n 3 server_lines <"$server_stdout"
    [[ "${#server_lines[@]}" -eq 2 ]] || die "shutdown" "stdout-shape"
    [[ "${server_lines[0]}" == "$ready_line" && "${server_lines[1]}" == "STOPPED" ]] || \
        die "shutdown" "stdout-contract"
    [[ ! -s "$server_stderr" ]] || die "shutdown" "stderr-not-empty"

    verify_port_released_and_rebind "$port" >/dev/null 2>&1 || \
        die "shutdown" "port-not-released"
    pass_check

    CURRENT_CRITERION="filesystem"
    write_tree_snapshot "$app_root" "$EVIDENCE_ROOT/app-after.tsv" "application" \
        >/dev/null 2>&1 || die "filesystem" "app-snapshot"
    cmp -s "$EVIDENCE_ROOT/app-before.tsv" "$EVIDENCE_ROOT/app-after.tsv" || \
        die "filesystem" "app-tree-changed"

    write_tree_snapshot "$runtime_root" "$EVIDENCE_ROOT/state-after.tsv" "runtime-state" \
        >/dev/null 2>&1 || die "filesystem" "state-snapshot"
    state_delta="$(
        count_snapshot_delta "$EVIDENCE_ROOT/state-before.tsv" "$EVIDENCE_ROOT/state-after.tsv"
    )" || die "filesystem" "state-delta"
    [[ "$state_delta" =~ ^[0-9]+$ ]] || die "filesystem" "state-delta"
    [[ "$state_delta" == "0" ]] || die "filesystem" "runtime-state-write"
    printf '%s\n' "$state_delta" >"$EVIDENCE_ROOT/runtime-write-count"
    pass_check

    CURRENT_CRITERION="runtime-cgroup"
    cgroup_processes="$(<"/sys/fs/cgroup$cgroup_path/cgroup.procs")"
    [[ "${cgroup_processes//[[:space:]]/}" == "$$" ]] || \
        die "runtime-cgroup" "processes-remain"
    pass_check

    printf '%s\n' "$CHECKS" >"$EVIDENCE_ROOT/unit-check-count"
    printf 'UNIT_PASS checks=%s runtime_writes=%s\n' "$CHECKS" "$state_delta"
}

outer_main() {
    MODE="outer"
    local started_at
    local finished_at
    local elapsed_ms
    local publish_input
    local manifest_input
    local publish_root
    local manifest_path
    local companion_path
    local expected_manifest
    local manifest_digest
    local copied_digest
    local native_fs
    local app_root
    local writable_root
    local runtime_root
    local harness_root
    local evidence_root
    local launcher
    local file_result
    local readelf_result
    local ldd_result
    local user_systemd_state
    local systemd_exit
    local unit_failure
    local unit_checks
    local runtime_writes
    local cgroup_path
    local cgroup_directory
    local load_state
    local sample
    local command_name
    local script_path
    local script_directory
    local publish_parent
    local success_record
    local -a required_commands
    local -a systemd_command

    script_path="$(realpath -e -- "${BASH_SOURCE[0]}")"
    script_directory="$(dirname -- "$script_path")"
    CROSS_PLATFORM_ROOT="$(dirname -- "$script_directory")"
    [[ "$script_path" == "$CROSS_PLATFORM_ROOT/eng/verify-linux.sh" ]] || \
        die "preflight" "script-path"
    [[ "$CROSS_PLATFORM_ROOT" == */CrossPlatform && -d "$CROSS_PLATFORM_ROOT/artifacts" ]] || \
        die "preflight" "cross-platform-root"
    [[ ! -L "$CROSS_PLATFORM_ROOT/artifacts" ]] || die "preflight" "artifacts-link"
    PERSISTENT_EVIDENCE_ROOT="$CROSS_PLATFORM_ROOT/artifacts/evidence"

    started_at="$(date +%s%3N)"

    CURRENT_CRITERION="preflight"
    [[ "$#" -eq 2 ]] || die "preflight" "argument-count"
    [[ "$(uname -s)" == "Linux" ]] || die "preflight" "platform"
    HOST_PLATFORM="linux"
    if [[ "$(id -u)" =~ ^[0-9]+$ && "$(id -u)" -ne 0 ]]; then
        HOST_PRIVILEGE="non-root"
    else
        HOST_PRIVILEGE="root"
        die "preflight" "root-user"
    fi
    [[ "$(uname -m)" == "x86_64" ]] || die "preflight" "architecture"
    HOST_ARCHITECTURE="x64"

    required_commands=(
        awk cmp cp curl date dirname env file find grep id ldd mkdir mktemp mv
        python3 readelf readlink realpath rm sha256sum sleep sort stat systemctl
        systemd-detect-virt systemd-run uname
    )
    for command_name in "${required_commands[@]}"; do
        require_command "$command_name"
    done

    user_systemd_state="$(systemctl --user is-system-running 2>/dev/null || true)"
    [[ "$user_systemd_state" == "running" || "$user_systemd_state" == "degraded" ]] || \
        die "preflight" "user-systemd"
    pass_check

    # Measured host identity for the evidence record. The prior schema hardcoded
    # "independentHost": "not-run" while the auditor required exactly that value, so a
    # genuine independent-host run was unrecordable (R-S2-040). These are objective
    # facts; the auditor derives the host role from them instead of trusting a claim.
    # systemd-detect-virt exits nonzero when it prints "none", so tolerate the status
    # and validate the text instead.
    CURRENT_CRITERION="host-identity"
    HOST_VIRT="$(systemd-detect-virt 2>/dev/null || true)"
    [[ "$HOST_VIRT" =~ ^[a-z0-9-]{1,32}$ ]] || die "host-identity" "virt-grammar"
    HOST_CONTAINER="$(systemd-detect-virt --container 2>/dev/null || true)"
    [[ "$HOST_CONTAINER" =~ ^[a-z0-9-]{1,32}$ ]] || die "host-identity" "container-grammar"
    HOST_KERNEL_RELEASE="$(uname -r)"
    [[ "$HOST_KERNEL_RELEASE" =~ ^[A-Za-z0-9._+-]{1,64}$ ]] || die "host-identity" "kernel-grammar"
    if [[ -r /etc/os-release ]]; then
        HOST_OS_ID="$(. /etc/os-release && printf '%s' "${ID:-unknown}")"
        HOST_OS_VERSION_ID="$(. /etc/os-release && printf '%s' "${VERSION_ID:-unknown}")"
    fi
    [[ "$HOST_OS_ID" =~ ^[a-z0-9._-]{1,32}$ ]] || die "host-identity" "os-id-grammar"
    [[ "$HOST_OS_VERSION_ID" =~ ^[A-Za-z0-9._-]{1,32}$ ]] || die "host-identity" "os-version-grammar"
    [[ -r /etc/machine-id ]] || die "host-identity" "machine-id-unreadable"
    HOST_MACHINE_ID_SHA256="$(sha256sum -- /etc/machine-id)" || die "host-identity" "machine-id-hash"
    HOST_MACHINE_ID_SHA256="${HOST_MACHINE_ID_SHA256%% *}"
    [[ "$HOST_MACHINE_ID_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "host-identity" "machine-id-grammar"
    if [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        HOST_WSL_INTEROP="true"
    else
        HOST_WSL_INTEROP="false"
    fi
    CURRENT_CRITERION="preflight"

    if command -v dotnet >/dev/null 2>&1; then
        HOST_DOTNET_COMMAND="present"
    else
        HOST_DOTNET_COMMAND="absent"
    fi
    pass_check

    publish_input="$1"
    manifest_input="$2"
    [[ -d "$publish_input" && ! -L "$publish_input" ]] || die "paths" "publish-root"
    [[ -f "$manifest_input" && ! -L "$manifest_input" ]] || die "paths" "manifest"

    publish_root="$(realpath -e -- "$publish_input")"
    manifest_path="$(realpath -e -- "$manifest_input")"
    publish_parent="$CROSS_PLATFORM_ROOT/artifacts/publish"
    [[ -d "$publish_parent" && ! -L "$publish_parent" ]] || die "paths" "publish-parent"
    publish_parent="$(realpath -e -- "$publish_parent")"
    [[ "$publish_root" == "$publish_parent/"* && "$publish_root" != "$publish_parent" ]] || \
        die "paths" "publish-contract"

    expected_manifest="$PERSISTENT_EVIDENCE_ROOT/$MANIFEST_NAME"
    [[ "$manifest_path" == "$expected_manifest" ]] || die "paths" "manifest-contract"

    companion_path="$manifest_path.sha256"
    [[ -f "$companion_path" && ! -L "$companion_path" ]] || \
        die "paths" "manifest-digest"
    companion_path="$(realpath -e -- "$companion_path")"
    [[ "$companion_path" == "$expected_manifest.sha256" ]] || \
        die "paths" "manifest-digest-contract"
    pass_check

    CURRENT_CRITERION="evidence"
    enter_evidence_writer_lease || die "evidence" "lease-unavailable"
    evidence_writer_publication_authority || die "evidence" "lease-authority"

    CURRENT_CRITERION="sandbox-copy"
    SANDBOX_ROOT="$(mktemp -d /tmp/staxrip-linux-gate.XXXXXX)"
    SANDBOX_ROOT="$(realpath -e -- "$SANDBOX_ROOT")"
    is_valid_sandbox_root "$SANDBOX_ROOT" || die "sandbox-copy" "temp-path"
    [[ ! -L "$SANDBOX_ROOT" && "$(stat -c '%u' -- "$SANDBOX_ROOT")" == "$(id -u)" ]] || \
        die "sandbox-copy" "temp-owner"

    native_fs="$(stat -f -c '%T' -- "$SANDBOX_ROOT")"
    case "$native_fs" in
        9p|cifs|drvfs|fuseblk|nfs|nfs4)
            die "sandbox-copy" "non-native-filesystem"
            ;;
    esac
    pass_check

    app_root="$SANDBOX_ROOT/app"
    writable_root="$SANDBOX_ROOT/writable"
    runtime_root="$writable_root/runtime"
    harness_root="$writable_root/harness"
    evidence_root="$writable_root/evidence"
    mkdir -p -- \
        "$app_root" \
        "$runtime_root/home" \
        "$runtime_root/xdg-config" \
        "$runtime_root/xdg-cache" \
        "$runtime_root/xdg-data" \
        "$runtime_root/tmp" \
        "$harness_root" \
        "$evidence_root"

    CURRENT_CRITERION="artifact-manifest"
    if ! manifest_digest="$(
        verify_artifact_manifest "$publish_root" "$manifest_path" "$companion_path" \
            2>"$harness_root/manifest-source.error"
    )"; then
        die "artifact-manifest" "source-mismatch"
    fi
    [[ "$manifest_digest" =~ ^[0-9a-f]{64}$ ]] || die "artifact-manifest" "digest-shape"
    ARTIFACT_DIGEST="$manifest_digest"
    pass_check

    cp -a -- "$publish_root/." "$app_root/" 2>"$harness_root/copy.error" || \
        die "sandbox-copy" "copy-failed"
    if ! copied_digest="$(
        verify_artifact_manifest "$app_root" "$manifest_path" "$companion_path" \
            2>"$harness_root/manifest-copy.error"
    )"; then
        die "artifact-manifest" "copy-mismatch"
    fi
    [[ "$copied_digest" == "$manifest_digest" ]] || die "artifact-manifest" "copy-digest"
    pass_check

    launcher="$app_root/StaxRip.Server"
    [[ -x "$launcher" && -f "$launcher" && ! -L "$launcher" ]] || \
        die "binary" "launcher-invalid"

    CURRENT_CRITERION="binary"
    run_bounded_command \
        10 65536 65536 131072 \
        "$harness_root/file.stdout" \
        "$harness_root/file.error" \
        file -b -- "$launcher" || die "binary" "file-failed"
    file_result="$(<"$harness_root/file.stdout")"
    [[ "$file_result" == *"ELF 64-bit LSB"* && "$file_result" == *"x86-64"* ]] || \
        die "binary" "elf-identity"

    run_bounded_command \
        10 65536 65536 131072 \
        "$harness_root/readelf.stdout" \
        "$harness_root/readelf.error" \
        readelf -h -- "$launcher" || die "binary" "readelf-failed"
    readelf_result="$(<"$harness_root/readelf.stdout")"
    grep -Eq 'Class:[[:space:]]+ELF64' <<<"$readelf_result" || die "binary" "elf-class"
    grep -Eq 'Machine:[[:space:]]+Advanced Micro Devices X86-64' <<<"$readelf_result" || \
        die "binary" "elf-machine"
    pass_check

    run_bounded_command \
        30 262144 65536 327680 \
        "$harness_root/ldd.stdout" \
        "$harness_root/ldd.error" \
        ldd -- "$launcher" || die "binary" "ldd-failed"
    ldd_result="$(<"$harness_root/ldd.stdout")"
    ! grep -Fqi 'not found' <<<"$ldd_result" || die "binary" "dependency-missing"
    [[ -f "$app_root/libhostfxr.so" && -f "$app_root/libhostpolicy.so" ]] || \
        die "binary" "self-contained-host"
    [[ -f "$app_root/libcoreclr.so" ]] || die "binary" "self-contained-runtime"
    pass_check

    CURRENT_CRITERION="filesystem"
    write_tree_snapshot "$app_root" "$evidence_root/app-before.tsv" "application" \
        >/dev/null 2>"$harness_root/app-snapshot.error" || \
        die "filesystem" "app-baseline"
    write_tree_snapshot "$runtime_root" "$evidence_root/state-before.tsv" "runtime-state" \
        >/dev/null 2>"$harness_root/state-snapshot.error" || \
        die "filesystem" "state-baseline"
    pass_check

    CURRENT_CRITERION="systemd-run"
    SYSTEMD_UNIT_NAME="$(</proc/sys/kernel/random/uuid)"
    SYSTEMD_UNIT_NAME="staxrip-linux-gate-${SYSTEMD_UNIT_NAME//-/}"
    is_valid_unit_name "$SYSTEMD_UNIT_NAME" || die "systemd-run" "unit-name"
    load_state="$(systemctl --user show "$SYSTEMD_UNIT_NAME.service" --property=LoadState --value 2>/dev/null || true)"
    [[ -z "$load_state" || "$load_state" == "not-found" ]] || \
        die "systemd-run" "unit-name-collision"

    systemd_command=(
        systemd-run
        --user
        --wait
        --pipe
        --collect
        --quiet
        --no-ask-password
        --expand-environment=no
        "--unit=$SYSTEMD_UNIT_NAME"
        --service-type=exec
        --property=PrivateNetwork=yes
        --property=ProtectSystem=strict
        --property=ProtectHome=read-only
        --property=NoNewPrivileges=yes
        --property=KillMode=control-group
        --property=KillSignal=SIGTERM
        --property=SendSIGKILL=yes
        --property=TimeoutStopSec=10s
        --property=UMask=0077
        "--property=ReadOnlyPaths=$app_root $runtime_root"
        "--property=ReadWritePaths=$harness_root $evidence_root"
        "--working-directory=$app_root"
        /usr/bin/env
        -i
        PATH=/usr/bin:/bin
        HOME="$runtime_root/home"
        XDG_CONFIG_HOME="$runtime_root/xdg-config"
        XDG_CACHE_HOME="$runtime_root/xdg-cache"
        XDG_DATA_HOME="$runtime_root/xdg-data"
        TMPDIR="$runtime_root/tmp"
        TMP="$runtime_root/tmp"
        TEMP="$runtime_root/tmp"
        LANG=C.UTF-8
        LC_ALL=C.UTF-8
        TZ=UTC
        /usr/bin/bash
        "$(realpath -e -- "${BASH_SOURCE[0]}")"
        --unit-runner-v1
        "$app_root"
        "$runtime_root"
        "$harness_root"
        "$evidence_root"
        "$SYSTEMD_UNIT_NAME"
    )

    SYSTEMD_UNIT_STARTED=1
    # The unit is expected to fail sometimes, and the handler below reports why by
    # reading "$evidence_root/unit-failure". "set +e" alone does not reach that handler:
    # bash runs an ERR trap on the same conditions that trigger errexit, and disabling
    # errexit does not disable the trap. With "set -E" the trap is inherited into
    # run_bounded_command, so unexpected_error fired on the bounded runner before
    # systemd_exit was ever assigned, and every unit failure was reported as
    # "unexpected-command" while the real reason was deleted with the sandbox.
    # Suspend the trap for exactly this call. Tracked in
    # Docs/Review/SLICE-002-Remediation-Backlog.md as R-S2-035.
    set +e
    trap - ERR
    run_bounded_command \
        120 \
        1048576 \
        262144 \
        1179648 \
        "$harness_root/unit.stdout" \
        "$harness_root/unit.stderr" \
        "${systemd_command[@]}"
    systemd_exit="$?"
    trap unexpected_error ERR
    set -e

    if [[ "$systemd_exit" -ne 0 ]]; then
        unit_failure="unit-exit"
        if [[ -f "$evidence_root/unit-failure" ]]; then
            unit_failure="$(<"$evidence_root/unit-failure")"
        fi
        die "systemd-run" "$unit_failure" "$systemd_exit"
    fi
    pass_check

    CURRENT_CRITERION="unit-result"
    [[ "$(grep -c '^UNIT_PASS checks=[0-9][0-9]* runtime_writes=[0-9][0-9]*$' \
        "$harness_root/unit.stdout")" -eq 1 ]] || die "unit-result" "success-marker"
    [[ -f "$evidence_root/unit-check-count" && -f "$evidence_root/runtime-write-count" ]] || \
        die "unit-result" "result-files"
    unit_checks="$(<"$evidence_root/unit-check-count")"
    runtime_writes="$(<"$evidence_root/runtime-write-count")"
    [[ "$unit_checks" =~ ^[0-9]+$ && "$runtime_writes" =~ ^[0-9]+$ ]] || \
        die "unit-result" "result-shape"
    CHECKS=$((CHECKS + unit_checks))
    pass_check

    CURRENT_CRITERION="unit-cleanup"
    [[ -f "$evidence_root/unit-cgroup" ]] || die "unit-cleanup" "cgroup-evidence"
    cgroup_path="$(<"$evidence_root/unit-cgroup")"
    [[ "$cgroup_path" =~ ^/[A-Za-z0-9_.@:/-]+$ && "$cgroup_path" != *".."* ]] || \
        die "unit-cleanup" "cgroup-path"
    cgroup_directory="/sys/fs/cgroup$cgroup_path"

    for ((sample = 0; sample < 80; sample++)); do
        load_state="$(
            systemctl --user show "$SYSTEMD_UNIT_NAME.service" \
                --property=LoadState --value 2>/dev/null || true
        )"

        if [[ "$load_state" == "not-found" || -z "$load_state" ]]; then
            if [[ ! -e "$cgroup_directory" ]]; then
                break
            fi

            if [[ -f "$cgroup_directory/cgroup.procs" && \
                  -z "$(<"$cgroup_directory/cgroup.procs")" ]]; then
                break
            fi
        fi

        /usr/bin/sleep 0.05
    done

    if systemctl --user is-active --quiet "$SYSTEMD_UNIT_NAME.service" 2>/dev/null; then
        die "unit-cleanup" "unit-active"
    fi
    load_state="$(
        systemctl --user show "$SYSTEMD_UNIT_NAME.service" \
            --property=LoadState --value 2>/dev/null || true
    )"
    [[ "$load_state" == "not-found" || -z "$load_state" ]] || \
        die "unit-cleanup" "unit-retained"
    if [[ -e "$cgroup_directory" ]]; then
        [[ -f "$cgroup_directory/cgroup.procs" ]] || die "unit-cleanup" "cgroup-shape"
        [[ -z "$(<"$cgroup_directory/cgroup.procs")" ]] || \
            die "unit-cleanup" "cgroup-not-empty"
    fi
    SYSTEMD_UNIT_STARTED=0
    pass_check

    CURRENT_CRITERION="evidence"
    success_record="$PERSISTENT_EVIDENCE_ROOT/linux-runtime.json"
    evidence_writer_publication_authority || die "evidence" "lease-authority"
    persist_success_snapshots "$evidence_root" "$PERSISTENT_EVIDENCE_ROOT" || \
        die "evidence" "snapshot-persist-failed"
    # This count sits after the snapshot persist rather than before it. It previously sat
    # directly after the string assignment above, where the only statement it covered was
    # that assignment, so it was a counted check no execution could fail and the reported
    # total carried one phantom. Counting after the persist keeps the historical total of
    # 27 while making the evidence criterion count work that can actually fail.
    pass_check

    CURRENT_CRITERION="unit-cleanup"
    cleanup_outer_resources || die "unit-cleanup" "sandbox-remove"

    CURRENT_CRITERION="evidence"
    evidence_writer_publication_authority || die "evidence" "lease-authority"
    write_success_record "$success_record" "$manifest_digest" "$CHECKS" "$runtime_writes" || \
        die "evidence" "write-failed"
    remove_own_failure_packet || die "evidence" "failure-state-unsafe"
    evidence_writer_publication_authority || die "evidence" "lease-authority"
    exit_evidence_writer_lease || die "evidence" "lease-release-failed"

    finished_at="$(date +%s%3N)"
    elapsed_ms=$((finished_at - started_at))
    printf 'PASS %s checks=%s elapsed_ms=%s evidence=CrossPlatform/artifacts/evidence/linux-runtime.json runtime_writes=%s artifact_sha256=%s\n' \
        "$GATE_ID" "$CHECKS" "$elapsed_ms" "$runtime_writes" "$manifest_digest"
}

if [[ "${1:-}" == "--unit-runner-v1" ]]; then
    shift
    unit_main "$@"
else
    outer_main "$@"
fi
