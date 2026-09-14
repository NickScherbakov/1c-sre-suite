#!/usr/bin/env bash
# ==============================================================================
# 1C:SRE-Suite — Production Health Check & Diagnostic Tool (v1.1)
# Subsystem: Linux Kernel ↔ PostgreSQL/Patroni ↔ 1C:Enterprise Cluster
# License: MIT (NickScherbakov/1c-sre-suite)
# ==============================================================================

set -eo pipefail

# --- Color Definitions ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

GENERATE_FIX=false
FIX_FILE="/tmp/sre-healthcheck-fix.sh"

if [[ "${1:-}" == "--generate-fix" ]]; then
    GENERATE_FIX=true
    echo "#!/usr/bin/env bash" > "$FIX_FILE"
    echo "# 1C:SRE-Suite Auto-Generated Fix Script" >> "$FIX_FILE"
    echo "# Created at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$FIX_FILE"
    echo "set -euo pipefail" >> "$FIX_FILE"
    chmod +x "$FIX_FILE"
fi

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

log_ok() {
    echo -e " [${GREEN}OK${NC}]   $1"
    ((OK_COUNT++)) || true
}

log_info() {
    echo -e " [${BLUE}INFO${NC}] $1"
}

log_warn() {
    echo -e " [${YELLOW}WARN${NC}] $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "        ${CYAN}--> RECOMMENDATION:${NC} $2"
    fi
    ((WARN_COUNT++)) || true
}

log_fail() {
    echo -e " [${RED}FAIL${NC}] $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "        ${CYAN}--> FIX ACTION:${NC} $2"
    fi
    if $GENERATE_FIX && [[ -n "${3:-}" ]]; then
        echo "$3" >> "$FIX_FILE"
    fi
    ((FAIL_COUNT++)) || true
}

header() {
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo -e "${BOLD}${CYAN} 1C:SRE-Suite — System & Database Health Check (v1.1)${NC}"
    echo -e " Host: ${BOLD}$(hostname)${NC} | Kernel: $(uname -r) | Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo ""
}

check_kernel_and_vm() {
    echo -e "${BOLD}[1. LINUX KERNEL & VIRTUAL MEMORY (OS HEALTH)]${NC}"

    # 1. Transparent Huge Pages
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        THP_STATUS=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
        if [[ "$THP_STATUS" == *"[never]"* ]]; then
            log_ok "Transparent Huge Pages (THP): disabled (never)"
        else
            log_fail "Transparent Huge Pages: $THP_STATUS" \
                     "Set transparent_hugepage=never in GRUB_CMDLINE_LINUX" \
                     "echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag"
        fi
    else
        log_warn "THP status file not found (/sys/kernel/mm/transparent_hugepage/enabled)"
    fi

    # 2. vm.swappiness
    SWAPPINESS=$(sysctl -n vm.swappiness 2>/dev/null || echo "60")
    if [[ "$SWAPPINESS" -le 10 ]]; then
        log_ok "vm.swappiness = $SWAPPINESS (Optimal for PostgreSQL & 1C)"
    else
        log_warn "vm.swappiness = $SWAPPINESS (Recommended <= 10 to prevent premature swapping)" \
                 "Set vm.swappiness=10 in /etc/sysctl.d/99-1c-postgresql.conf"
        if $GENERATE_FIX; then
            echo "sysctl -w vm.swappiness=10" >> "$FIX_FILE"
        fi
    fi

    # 3. Dirty Pages configuration (Bytes or Ratios)
    DIRTY_BYTES=$(sysctl -n vm.dirty_bytes 2>/dev/null || echo "0")
    DIRTY_BG_BYTES=$(sysctl -n vm.dirty_background_bytes 2>/dev/null || echo "0")

    if [[ "$DIRTY_BYTES" -gt 0 && "$DIRTY_BG_BYTES" -gt 0 ]]; then
        BG_MB=$((DIRTY_BG_BYTES / 1024 / 1024))
        RATIO_MB=$((DIRTY_BYTES / 1024 / 1024))
        log_ok "Dirty memory (absolute): background=${BG_MB}MB, limit=${RATIO_MB}MB (Smooth I/O flushes)"
    else
        DIRTY_BG=$(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo "10")
        DIRTY_RATIO=$(sysctl -n vm.dirty_ratio 2>/dev/null || echo "20")
        if [[ "$DIRTY_BG" -le 10 && "$DIRTY_RATIO" -le 20 ]]; then
            log_ok "Dirty page ratios: background=$DIRTY_BG%, ratio=$DIRTY_RATIO% (Acceptable)"
        else
            log_warn "Dirty page ratios high (bg=$DIRTY_BG%, ratio=$DIRTY_RATIO%)" \
                     "Configure absolute limits: vm.dirty_background_bytes=1073741824 and vm.dirty_bytes=4294967296"
            if $GENERATE_FIX; then
                echo "sysctl -w vm.dirty_background_bytes=1073741824" >> "$FIX_FILE"
                echo "sysctl -w vm.dirty_bytes=4294967296" >> "$FIX_FILE"
            fi
        fi
    fi

    # 4. vm.overcommit_memory
    OVERCOMMIT=$(sysctl -n vm.overcommit_memory 2>/dev/null || echo "0")
    if [[ "$OVERCOMMIT" -eq 2 ]]; then
        log_ok "vm.overcommit_memory = 2 (Strict Don't Overcommit — Safe for dedicated DB)"
    else
        log_info "vm.overcommit_memory = $OVERCOMMIT (Heuristic overcommit — Verify swap size if running 1C)"
    fi

    # 5. net.ipv4.ip_nonlocal_bind (Critical for vip-manager)
    NONLOCAL_BIND=$(sysctl -n net.ipv4.ip_nonlocal_bind 2>/dev/null || echo "0")
    if [[ "$NONLOCAL_BIND" -eq 1 ]]; then
        log_ok "net.ipv4.ip_nonlocal_bind = 1 (vip-manager ready)"
    else
        log_fail "net.ipv4.ip_nonlocal_bind = $NONLOCAL_BIND (vip-manager cannot bind Virtual IP!)" \
                 "Execute sysctl -w net.ipv4.ip_nonlocal_bind=1" \
                 "sysctl -w net.ipv4.ip_nonlocal_bind=1"
    fi

    # 6. Socket backlog & SOMAXCONN
    SOMAXCONN=$(sysctl -n net.core.somaxconn 2>/dev/null || echo "128")
    if [[ "$SOMAXCONN" -ge 4096 ]]; then
        log_ok "net.core.somaxconn = $SOMAXCONN (High-concurrency sockets ready)"
    else
        log_warn "net.core.somaxconn = $SOMAXCONN (Recommended >= 4096 for heavy 1C client pools)" \
                 "Set net.core.somaxconn=4096 in sysctl"
        if $GENERATE_FIX; then
            echo "sysctl -w net.core.somaxconn=4096" >> "$FIX_FILE"
        fi
    fi

    echo ""
}

check_postgres_patroni() {
    echo -e "${BOLD}[2. POSTGRESQL & PATRONI HIGH-AVAILABILITY CLUSTER]${NC}"

    # Patroni REST API check
    if command -v curl &>/dev/null; then
        PATRONI_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/cluster 2>/dev/null || echo "000")
        if [[ "$PATRONI_HTTP" -eq 200 ]]; then
            ROLE=$(curl -s http://localhost:8008/patroni 2>/dev/null | grep -o '"role":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            log_ok "Patroni REST API responsive (200 OK) | Node Role: ${BOLD}${ROLE^^}${NC}"
        else
            log_warn "Patroni REST API unreachable on http://localhost:8008/cluster (HTTP $PATRONI_HTTP)" \
                     "Verify Patroni daemon service: systemctl status patroni"
        fi
    else
        log_warn "curl not installed; skipping Patroni REST API check"
    fi

    # PostgreSQL configuration checks via psql
    if command -v psql &>/dev/null; then
        LOCKS=$(psql -U postgres -t -A -c "SHOW max_locks_per_transaction;" 2>/dev/null || echo "0")
        if [[ "$LOCKS" -ge 256 ]]; then
            log_ok "max_locks_per_transaction = $LOCKS"
            
            # Проверка текущей утилизации блокировок
            ACTIVE_LOCKS=$(psql -U postgres -t -A -c "SELECT count(*) FROM pg_locks;" 2>/dev/null || echo "0")
            if [[ "$ACTIVE_LOCKS" -gt 0 ]]; then
                UTILIZATION=$(( ACTIVE_LOCKS * 100 / LOCKS ))
                if [[ "$UTILIZATION" -ge 70 ]]; then
                    log_warn "Active locks count: $ACTIVE_LOCKS / $LOCKS ($UTILIZATION% utilized)" \
                             "High lock density detected; consider increasing max_locks_per_transaction"
                else
                    log_ok "Active locks count: $ACTIVE_LOCKS / $LOCKS ($UTILIZATION% utilized)"
                fi
            fi
        elif [[ "$LOCKS" -gt 0 ]]; then
            log_fail "max_locks_per_transaction = $LOCKS (Dangerous for 1C! Recommended >= 256)" \
                     "Update patroni.yml / postgresql.conf with max_locks_per_transaction: 256"
        fi

        MAX_CONN=$(psql -U postgres -t -A -c "SHOW max_connections;" 2>/dev/null || echo "0")
        if [[ "$MAX_CONN" -ge 250 ]]; then
            log_ok "max_connections = $MAX_CONN (Ready for high background task volume)"
        elif [[ "$MAX_CONN" -gt 0 ]]; then
            log_warn "max_connections = $MAX_CONN (Recommended >= 250)"
        fi
    else
        log_warn "psql utility not in PATH; skipping direct SQL parameter checks"
    fi

    echo ""
}

check_1c_cluster() {
    echo -e "${BOLD}[3. 1C:ENTERPRISE CLUSTER & RPHOST PROCESS ANALYSIS]${NC}"

    RPHOST_PIDS=$(pgrep -f "rphost" || true)

    if [[ -z "$RPHOST_PIDS" ]]; then
        log_info "No active 'rphost' processes found on this host (Normal if dedicated DB node)"
    else
        RPHOST_COUNT=$(echo "$RPHOST_PIDS" | wc -w)
        log_ok "Active rphost worker processes detected: $RPHOST_COUNT"

        for pid in $RPHOST_PIDS; do
            if [[ -f "/proc/$pid/status" ]]; then
                RSS_KB=$(awk '/VmRSS:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo "0")
                SWAP_KB=$(awk '/VmSwap:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo "0")
                
                RSS_GB=$(( RSS_KB / 1024 / 1024 ))
                SWAP_GB=$(( SWAP_KB / 1024 / 1024 ))

                # Порог алерта утечки в swap: > 1 ГБ (1048576 KB)
                if (( SWAP_KB > 1048576 )); then
                    log_warn "PID $pid (rphost): RSS = ~${RSS_GB} GB, SWAP = ~${SWAP_GB} GB (Leaking to swap!)" \
                             "Candidate for soft rotation via admincluster_run.sh / RAS API"
                else
                    log_ok "PID $pid (rphost): RSS = ~${RSS_GB} GB, SWAP = ~${SWAP_GB} GB (Healthy RAM allocation)"
                fi
            fi
        done
    fi

    echo ""
}

summary() {
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo -e "${BOLD} SUMMARY:${NC} ${GREEN}${OK_COUNT} OK${NC} | ${YELLOW}${WARN_COUNT} WARNINGS${NC} | ${RED}${FAIL_COUNT} FAILURES${NC}"
    
    if $GENERATE_FIX; then
        echo -e "${BOLD}${GREEN} Auto-fix script generated:${NC} $FIX_FILE"
        echo -e " Run '${BOLD}sudo bash $FIX_FILE${NC}' to apply kernel recommendations."
    else
        echo -e " Tip: Run '${BOLD}$0 --generate-fix${NC}' to generate an automated remediation script."
    fi
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
}

main() {
    header
    check_kernel_and_vm
    check_postgres_patroni
    check_1c_cluster
    summary
}

main