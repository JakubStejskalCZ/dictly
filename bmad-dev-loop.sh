#!/usr/bin/env bash
# =============================================================================
# bmad-dev-loop.sh — Automated BMAD v6.2.x Development Loop
# =============================================================================
# Reads sprint-status.yaml and drives stories through:
#   create-story → commit → dev-story → commit → code-review (yolo) → commit
# At end of each epic: runs e2e test generation.
#
# Resumes gracefully — skips done stories, picks up in-progress ones.
# Cancellable with Ctrl+C at any time (waits for current Claude call).
#
# Usage:
#   ./bmad-dev-loop.sh                  # process all epics
#   ./bmad-dev-loop.sh epic-2           # process only epic-2
#   ./bmad-dev-loop.sh epic-1 epic-3    # process specific epics
#   ./bmad-dev-loop.sh --dry-run        # preview what would be done
#   ./bmad-dev-loop.sh --dry-run epic-1 # preview specific epic
#
# Environment overrides:
#   PROJECT_ROOT=/path/to/project ./bmad-dev-loop.sh
#   ON_LIMIT_SCRIPT=./notify.sh ./bmad-dev-loop.sh
#   MAX_BUDGET_PER_CALL=5 ./bmad-dev-loop.sh
#
# Requirements:
#   - Claude CLI (`claude`) installed and authenticated
#   - BMAD v6.2.x installed in project (`npx bmad-method install`)
#   - sprint-status.yaml in _bmad-output/implementation-artifacts/
#   - yq v4+ (https://github.com/mikefarah/yq) for YAML parsing
# =============================================================================

set -euo pipefail

# ─── Argument parsing ────────────────────────────────────────────────────────

DRY_RUN=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            sed -n '2,/^# =====/p' "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]+"${POSITIONAL_ARGS[@]}"}"

# ─── Ctrl+C / signal handling ────────────────────────────────────────────────

CANCELLED=false
CLAUDE_PID=""

cleanup() {
    CANCELLED=true
    echo ""
    echo -e "\033[1;33m⚠ Ctrl+C received — stopping after current step.\033[0m"

    # Kill running Claude process if any
    if [[ -n "$CLAUDE_PID" ]] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
        echo -e "\033[1;33m  Terminating running Claude process (PID: ${CLAUDE_PID})...\033[0m"
        kill "$CLAUDE_PID" 2>/dev/null
        wait "$CLAUDE_PID" 2>/dev/null || true
    fi

    echo -e "\033[1;33m  Re-run the script to resume from where it left off.\033[0m"

    if [[ -n "${ON_LIMIT_SCRIPT:-}" && -x "${ON_LIMIT_SCRIPT:-}" ]]; then
        "$ON_LIMIT_SCRIPT" "cancelled" "user_interrupt" || true
    fi

    exit 130
}

trap cleanup INT TERM

# Check if user cancelled between steps
check_cancelled() {
    if $CANCELLED; then
        echo -e "\033[1;33m  Stopping — cancelled by user.\033[0m"
        exit 130
    fi
}

# ─── Project root detection ──────────────────────────────────────────────────

detect_project_root() {
    if [[ -n "${PROJECT_ROOT:-}" && -d "$PROJECT_ROOT" ]]; then
        return
    fi

    # Try git root first
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        PROJECT_ROOT="$(git rev-parse --show-toplevel)"
        return
    fi

    # Fallback: walk up looking for _bmad-output or _bmad
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/_bmad-output" ]] || [[ -d "$dir/_bmad" ]]; then
            PROJECT_ROOT="$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done

    PROJECT_ROOT="$PWD"
}

detect_project_root

# ─── Configuration ───────────────────────────────────────────────────────────

# Sprint status location (BMAD v6.2.x default)
SPRINT_STATUS="${SPRINT_STATUS:-${PROJECT_ROOT}/_bmad-output/implementation-artifacts/sprint-status.yaml}"

# Claude CLI binary
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# ─── Per-step model selection ────────────────────────────────────────────────
# Opus for planning/e2e, Sonnet for dev+review, Haiku for commits

MODEL_CREATE_STORY="${MODEL_CREATE_STORY:-opus}"
MODEL_DEV_STORY="${MODEL_DEV_STORY:-sonnet}"
MODEL_CODE_REVIEW="${MODEL_CODE_REVIEW:-sonnet}"
MODEL_E2E_TESTS="${MODEL_E2E_TESTS:-opus}"
MODEL_COMMIT="${MODEL_COMMIT:-haiku}"

# Max budget per Claude invocation in USD (0 = unlimited)
MAX_BUDGET_PER_CALL="${MAX_BUDGET_PER_CALL:-0}"

# Script to call on rate limit / stop (receives: $1=reason, $2=context)
ON_LIMIT_SCRIPT="${ON_LIMIT_SCRIPT:-}"

# Log file
LOG_DIR="${LOG_DIR:-${PROJECT_ROOT}/.scripts/bmad-auto/logs}"
LOG_FILE="${LOG_DIR}/bmad-dev-loop-$(date +%Y%m%d-%H%M%S).log"

# Rate limit detection patterns (in Claude CLI output / stderr)
RATE_LIMIT_PATTERNS=(
    "Rate limit reached"
    "rate_limit_error"
    "overloaded_error"
    "Too many requests"
    "HTTP 429"
    "usage limit"
)

# Retry config for transient errors (not rate limits)
MAX_RETRIES=2
RETRY_DELAY_SEC=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helper functions ────────────────────────────────────────────────────────

log() {
    local level="$1"; shift
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${timestamp} [${level}] $*" | tee -a "$LOG_FILE"
}

info()  { log "${BLUE}INFO${NC} " "$@"; }
ok()    { log "${GREEN}OK${NC}   " "$@"; }
warn()  { log "${YELLOW}WARN${NC} " "$@"; }
err()   { log "${RED}ERROR${NC}" "$@"; }
step()  { echo -e "\n${BOLD}${CYAN}▶ $*${NC}" | tee -a "$LOG_FILE"; }

die() {
    err "$@"
    exit 1
}

# ─── Dependency checks ──────────────────────────────────────────────────────

check_deps() {
    command -v "$CLAUDE_BIN" >/dev/null 2>&1 || die "Claude CLI not found. Install: https://github.com/anthropics/claude-code"
    command -v yq >/dev/null 2>&1 || die "yq (mikefarah) not found. Install: https://github.com/mikefarah/yq"
    command -v git >/dev/null 2>&1 || die "git not found."

    # Validate yq is mikefarah version (not pip yq)
    if ! yq --version 2>&1 | grep -q "mikefarah\|version v4\|version (.*) v"; then
        warn "yq detected but may not be mikefarah/yq v4+. YAML parsing may fail."
    fi
}

# ─── Sprint status discovery ────────────────────────────────────────────────

find_sprint_status() {
    if [[ -f "$SPRINT_STATUS" ]]; then
        return
    fi

    # Try common BMAD locations relative to project root
    local candidates=(
        "${PROJECT_ROOT}/_bmad-output/implementation-artifacts/sprint-status.yaml"
        "${PROJECT_ROOT}/_bmad/bmm/sprint-status.yaml"
        "${PROJECT_ROOT}/_bmad/sprint-status.yaml"
        "${PROJECT_ROOT}/sprint-status.yaml"
    )

    for f in "${candidates[@]}"; do
        if [[ -f "$f" ]]; then
            SPRINT_STATUS="$f"
            return
        fi
    done

    # Fallback: find it anywhere in the project
    local found
    found="$(find "$PROJECT_ROOT" -name 'sprint-status.yaml' -not -path '*/.git/*' -not -path '*/node_modules/*' | head -1)"
    if [[ -n "$found" ]]; then
        SPRINT_STATUS="$found"
        return
    fi

    die "sprint-status.yaml not found in ${PROJECT_ROOT}. Run bmad-sprint-planning first."
}

# ─── YAML parsing helpers ───────────────────────────────────────────────────

get_all_keys() {
    yq '.development_status | keys | .[]' "$SPRINT_STATUS" 2>/dev/null
}

get_status() {
    local key="$1"
    yq ".development_status.\"${key}\"" "$SPRINT_STATUS" 2>/dev/null
}

set_status() {
    local key="$1" new_status="$2"
    if $DRY_RUN; then
        info "${YELLOW}[DRY RUN]${NC} Would update ${key} → ${new_status}"
        return 0
    fi
    yq -i "
        .development_status.\"${key}\" = \"${new_status}\" |
        .last_updated = \"$(date '+%Y-%m-%d %H:%M')\"
    " "$SPRINT_STATUS"
    info "Updated ${key} → ${new_status}"
}

# Extract epic ID from story key (e.g., "1-2-user-auth" → "epic-1")
epic_of() {
    local story_key="$1"
    echo "epic-${story_key%%-*}"
}

# Check if key is a story (matches N-Na-name, N-Nb-name, N-N-name patterns)
is_story() {
    [[ "$1" =~ ^[0-9]+-[0-9]+[a-z]*-.+ ]]
}

# Check if key is an epic header
is_epic() {
    [[ "$1" =~ ^epic-[0-9]+$ ]]
}

# Check if key is a retrospective
is_retro() {
    [[ "$1" =~ -retrospective$ ]]
}

# ─── Claude CLI wrapper ─────────────────────────────────────────────────────

# Runs claude in print mode, captures output, detects rate limits.
# Args: $1=prompt, $2=description, $3=model, $4=session-name
# Returns: 0 = success, 1 = error, 2 = rate limit hit
run_claude() {
    local prompt="$1"
    local description="${2:-claude task}"
    local model="${3:-}"
    local session_name="${4:-}"

    check_cancelled

    if $DRY_RUN; then
        info "${YELLOW}[DRY RUN]${NC} Would run: ${description} [model: ${model:-default}]"
        return 0
    fi

    local attempt=0
    local exit_code
    local output_file
    output_file="$(mktemp)"

    local cmd=("$CLAUDE_BIN" -p --dangerously-skip-permissions --output-format json)

    if [[ -n "$session_name" ]]; then
        cmd+=(--name "$session_name")
    fi

    if [[ -n "$model" ]]; then
        cmd+=(--model "$model")
    fi

    if [[ "$MAX_BUDGET_PER_CALL" != "0" ]]; then
        cmd+=(--max-budget-usd "$MAX_BUDGET_PER_CALL")
    fi

    while (( attempt <= MAX_RETRIES )); do
        check_cancelled

        info "Running: ${description} [model: ${model:-default}] (attempt $((attempt + 1)))"
        info "Prompt: ${prompt:0:150}..."

        # Run Claude from project root, capture output
        # Run in background so we can track the PID for Ctrl+C
        set +e
        (cd "$PROJECT_ROOT" && "${cmd[@]}" "$prompt") > "$output_file" 2>&1 &
        CLAUDE_PID=$!
        wait "$CLAUDE_PID"
        exit_code=$?
        CLAUDE_PID=""
        set -e

        # If cancelled during wait, bail out
        check_cancelled

        local output
        output="$(cat "$output_file")"

        # Log the output (truncate if huge)
        {
            echo "--- Claude output for: ${description} [model: ${model:-default}] ---"
            echo "$output" | head -200
            local lines
            lines="$(echo "$output" | wc -l)"
            if (( lines > 200 )); then
                echo "... (truncated, ${lines} total lines)"
            fi
            echo "--- end output (exit: ${exit_code}) ---"
        } >> "$LOG_FILE"

        # Check for rate limit patterns
        for pattern in "${RATE_LIMIT_PATTERNS[@]}"; do
            if echo "$output" | grep -qi "$pattern"; then
                warn "Rate limit detected (pattern: '${pattern}') during: ${description}"
                rm -f "$output_file"
                handle_rate_limit "$description"
                return 2
            fi
        done

        # Success
        if [[ $exit_code -eq 0 ]]; then
            rm -f "$output_file"
            return 0
        fi

        # Non-rate-limit error — retry for transient failures
        attempt=$((attempt + 1))
        if (( attempt <= MAX_RETRIES )); then
            warn "Claude exited with code ${exit_code}. Retrying in ${RETRY_DELAY_SEC}s..."
            sleep "$RETRY_DELAY_SEC"
        fi
    done

    err "Claude failed after $((MAX_RETRIES + 1)) attempts for: ${description}"
    err "Last output: $(tail -5 "$output_file" 2>/dev/null)"
    rm -f "$output_file"
    return 1
}

handle_rate_limit() {
    local context="$1"
    err "═══════════════════════════════════════════════════════════"
    err "  RATE LIMIT HIT during: ${context}"
    err "  Stopping the dev loop. Re-run to resume from this point."
    err "═══════════════════════════════════════════════════════════"

    if [[ -n "$ON_LIMIT_SCRIPT" && -x "$ON_LIMIT_SCRIPT" ]]; then
        info "Calling notification script: ${ON_LIMIT_SCRIPT}"
        "$ON_LIMIT_SCRIPT" "rate_limit" "$context" || true
    fi

    exit 10
}

# ─── Workflow step functions ─────────────────────────────────────────────────
# Skills are invoked by name: bmad-create-story, bmad-dev-story, etc.
# Claude Code resolves these from .claude/skills/<name>/SKILL.md

do_create_story() {
    local story_key="$1"
    step "Creating story: ${story_key} [opus]"

    run_claude \
        "bmad-create-story - Create story: ${story_key}. Do not ask questions. Do not halt. Complete the full story creation autonomously." \
        "create-story ${story_key}" \
        "$MODEL_CREATE_STORY" \
        "bmad-create-story-${story_key}" \
        || return $?

    ok "Story created: ${story_key}"
}

do_commit() {
    local story_key="$1"
    local phase="$2"
    step "Committing (${phase}): ${story_key} [haiku]"

    # Check if there are changes to commit (skip check in dry-run)
    if ! $DRY_RUN; then
        if (cd "$PROJECT_ROOT" && git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]); then
            info "No changes to commit for ${story_key} (${phase}), skipping."
            return 0
        fi
    fi

    run_claude \
        "Stage all relevant changes and commit using conventional commits format. Context: BMAD story ${story_key}, phase: ${phase}. Write a clear, descriptive commit message following conventional commits (e.g., feat:, fix:, docs:, chore:). Do not ask questions, do not push." \
        "commit ${story_key} (${phase})" \
        "$MODEL_COMMIT" \
        "bmad-commit-${story_key}-${phase}" \
        || return $?

    ok "Committed: ${story_key} (${phase})"
}

do_dev_story() {
    local story_key="$1"
    step "Developing story: ${story_key} [sonnet]"

    run_claude \
        "bmad-dev-story - Work on story: ${story_key}. Complete ALL tasks. Run tests after each implementation. Do not ask clarifying questions - use best judgment based on existing patterns. Do not halt for milestones or session boundaries. Continue until story is COMPLETE." \
        "dev-story ${story_key}" \
        "$MODEL_DEV_STORY" \
        "bmad-dev-story-${story_key}" \
        || return $?

    ok "Development complete: ${story_key}"
}

do_code_review() {
    local story_key="$1"
    step "Code review (YOLO): ${story_key} [sonnet]"

    run_claude \
        "bmad-code-review ${story_key} - Use YOLO mode - automatically fix ALL found issues without asking. For decision-needed findings, use best judgment and fix them. For patch findings, batch-apply all fixes automatically. Do not halt, do not wait for user input at any point. At the end run full test suites to test project as whole." \
        "code-review ${story_key}" \
        "$MODEL_CODE_REVIEW" \
        "bmad-code-review-${story_key}" \
        || return $?

    ok "Code review complete: ${story_key}"
}

do_e2e_tests() {
    local epic_id="$1"
    step "Generating E2E tests for: ${epic_id} [opus]"

    # Collect all story keys for this epic to give context
    local stories
    stories="$(get_all_keys | while read -r k; do
        if is_story "$k" && [[ "$(epic_of "$k")" == "$epic_id" ]]; then
            echo "$k"
        fi
    done | tr '\n' ', ')"

    run_claude \
        "bmad-qa-generate-e2e-tests - Generate end-to-end automated tests for all features implemented in ${epic_id}. Stories covered: ${stories}. Do not ask questions. Generate comprehensive e2e tests covering all acceptance criteria from these stories." \
        "e2e-tests ${epic_id}" \
        "$MODEL_E2E_TESTS" \
        "bmad-e2e-tests-${epic_id}" \
        || return $?

    ok "E2E tests generated for: ${epic_id}"
}

# ─── Story lifecycle ─────────────────────────────────────────────────────────

# Phase chain: create → dev → review → done
# Each phase runs its own step then calls the next phase.

_phase_create() {
    local story_key="$1"
    do_create_story "$story_key" || return $?
    do_commit "$story_key" "story-created" || return $?
    set_status "$story_key" "ready-for-dev"
    _phase_dev "$story_key"
}

_phase_dev() {
    local story_key="$1"
    set_status "$story_key" "in-progress"
    do_dev_story "$story_key" || return $?
    do_commit "$story_key" "dev-complete" || return $?
    set_status "$story_key" "review"
    _phase_review "$story_key"
}

_phase_review() {
    local story_key="$1"
    do_code_review "$story_key" || return $?
    do_commit "$story_key" "review-fixes" || return $?
    set_status "$story_key" "done"
    ok "Story DONE: ${story_key}"
}

# Drives a single story from its current status to done.
# Resumes from wherever it left off (reads current status from YAML).
process_story() {
    local story_key="$1"
    local status
    status="$(get_status "$story_key")"

    info "Processing ${story_key} (status: ${status})"

    case "$status" in
        backlog)       _phase_create "$story_key" ;;
        ready-for-dev) _phase_dev "$story_key" ;;
        in-progress)   _phase_dev "$story_key" ;;
        review)        _phase_review "$story_key" ;;
        done)
            info "Story already done: ${story_key}, skipping."
            ;;
        *)
            warn "Unknown status '${status}' for ${story_key}, skipping."
            ;;
    esac
}

# ─── Epic lifecycle ──────────────────────────────────────────────────────────

process_epic() {
    local epic_id="$1"
    local epic_status
    epic_status="$(get_status "$epic_id")"

    step "════ Processing ${epic_id} (status: ${epic_status}) ════"

    if [[ "$epic_status" == "done" ]]; then
        info "Epic already done: ${epic_id}, skipping."
        return 0
    fi

    # Mark epic as in-progress
    if [[ "$epic_status" == "backlog" ]]; then
        set_status "$epic_id" "in-progress"
    fi

    # Collect stories for this epic (preserving order from YAML)
    local stories=()
    while IFS= read -r key; do
        if is_story "$key" && [[ "$(epic_of "$key")" == "$epic_id" ]]; then
            stories+=("$key")
        fi
    done < <(get_all_keys)

    if [[ ${#stories[@]} -eq 0 ]]; then
        warn "No stories found for ${epic_id}"
        return 0
    fi

    info "Stories in ${epic_id}: ${stories[*]}"

    # Show skip summary for already-done stories
    local pending=0
    local done_count=0
    for s in "${stories[@]}"; do
        local st
        st="$(get_status "$s")"
        if [[ "$st" == "done" ]]; then
            done_count=$((done_count + 1))
        else
            pending=$((pending + 1))
        fi
    done
    if (( done_count > 0 )); then
        info "${done_count} stories already done, ${pending} remaining"
    fi

    # Process each story
    local all_done=true
    for story_key in "${stories[@]}"; do
        check_cancelled
        process_story "$story_key"
        local rc=$?

        if [[ $rc -eq 2 ]]; then
            return 2
        elif [[ $rc -ne 0 ]]; then
            err "Story ${story_key} failed (exit: ${rc}). Stopping epic."
            all_done=false
            break
        fi
    done

    # Check if all stories are done → run e2e tests
    if $all_done; then
        local truly_done=true
        for story_key in "${stories[@]}"; do
            if [[ "$(get_status "$story_key")" != "done" ]]; then
                truly_done=false
                break
            fi
        done

        if $truly_done; then
            do_e2e_tests "$epic_id" || {
                local rc=$?
                if [[ $rc -eq 2 ]]; then return 2; fi
                warn "E2E test generation failed for ${epic_id}, but all stories are done."
            }
            do_commit "$epic_id" "e2e-tests" || true

            set_status "$epic_id" "done"
            ok "════ Epic DONE: ${epic_id} ════"
        fi
    fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    check_deps
    find_sprint_status

    mkdir -p "$LOG_DIR"

    if $DRY_RUN; then
        step "BMAD Dev Loop — DRY RUN (no changes will be made)"
    else
        step "BMAD Dev Loop Starting"
    fi
    info "Project root:  ${PROJECT_ROOT}"
    info "Sprint status: ${SPRINT_STATUS}"
    info "Log file:      ${LOG_FILE}"
    info "Claude binary:  ${CLAUDE_BIN}"
    info "Models:         create=${MODEL_CREATE_STORY} dev=${MODEL_DEV_STORY} review=${MODEL_CODE_REVIEW} e2e=${MODEL_E2E_TESTS} commit=${MODEL_COMMIT}"
    [[ -n "$ON_LIMIT_SCRIPT" ]] && info "On-limit script: ${ON_LIMIT_SCRIPT}"
    [[ "$MAX_BUDGET_PER_CALL" != "0" ]] && info "Max budget/call: \$${MAX_BUDGET_PER_CALL}"
    echo ""

    # Determine which epics to process
    local target_epics=()

    if [[ $# -gt 0 ]]; then
        target_epics=("$@")
        info "Target epics: ${target_epics[*]}"
    else
        while IFS= read -r key; do
            if is_epic "$key"; then
                target_epics+=("$key")
            fi
        done < <(get_all_keys)
        info "All epics: ${target_epics[*]}"
    fi

    if [[ ${#target_epics[@]} -eq 0 ]]; then
        die "No epics found to process."
    fi

    # Process each epic
    local processed=0
    local failed=0
    local start_time
    start_time="$(date +%s)"

    for epic_id in "${target_epics[@]}"; do
        check_cancelled
        process_epic "$epic_id"
        local rc=$?

        if [[ $rc -eq 2 ]]; then
            break
        elif [[ $rc -ne 0 ]]; then
            failed=$((failed + 1))
            warn "Epic ${epic_id} had errors."
        else
            processed=$((processed + 1))
        fi
    done

    local elapsed=$(( $(date +%s) - start_time ))
    local hours=$(( elapsed / 3600 ))
    local mins=$(( (elapsed % 3600) / 60 ))
    local secs=$(( elapsed % 60 ))

    echo ""
    step "════ Dev Loop Summary ════"
    info "Epics processed: ${processed} / ${#target_epics[@]}"
    info "Failed: ${failed}"
    info "Duration: ${hours}h ${mins}m ${secs}s"
    info "Log: ${LOG_FILE}"

    if [[ $failed -gt 0 ]]; then
        if [[ -n "$ON_LIMIT_SCRIPT" && -x "$ON_LIMIT_SCRIPT" ]]; then
            "$ON_LIMIT_SCRIPT" "completed_with_errors" "epics_failed=${failed}" || true
        fi
        exit 1
    fi

    if [[ -n "$ON_LIMIT_SCRIPT" && -x "$ON_LIMIT_SCRIPT" ]]; then
        "$ON_LIMIT_SCRIPT" "completed_success" "epics=${processed}" || true
    fi
}

main "$@"
