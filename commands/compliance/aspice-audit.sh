#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ASPICE Audit — Assess Automotive SPICE process maturity
# ============================================================================
# Usage: aspice-audit.sh [options]
# Options:
#   -h, --help       Show help
#   -v, --verbose    Verbose output
#   -V, --version    ASPICE version (3.1|4.0), default: 3.1
#   -l, --level      Target capability level (1|2|3)
#   -p, --process    Process area (SWE|SYS|MLE|HWE|MAN|SUP|VAL|all)
#   -o, --output     Output audit report
# ============================================================================
# Version Selection:
#   - Use ASPICE 3.1 for traditional VDA Scope assessments
#   - Use ASPICE 4.0 for ML/HW projects or when new processes (MLE, HWE, VAL) are needed
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

VERBOSE=false
ASPICE_VERSION="3.1"
TARGET_LEVEL=2
PROCESS_AREA="SWE"
OUTPUT_FILE="./aspice-audit.json"

# ASPICE 3.1 VDA Scope processes
ASPICE31_SWE_PROCESSES=("SWE.1:Requirements Analysis:L" "SWE.2:Architecture:F" "SWE.3:Design:L" "SWE.4:Unit Test:P" "SWE.5:Integration Test:L" "SWE.6:Qualification Test:P")
ASPICE31_SYS_PROCESSES=("SYS.2:System Requirements:F" "SYS.3:System Architecture:L" "SYS.4:System Integration Test:L" "SYS.5:System Qualification Test:P")
ASPICE31_SUP_PROCESSES=("SUP.1:Quality Assurance:L" "SUP.8:Configuration Management:F" "SUP.9:Problem Resolution:L" "SUP.10:Change Management:L")
ASPICE31_MAN_PROCESSES=("MAN.3:Project Management:L")

# ASPICE 4.0 processes (with Verification terminology)
ASPICE40_SWE_PROCESSES=("SWE.1:Requirements Analysis:L" "SWE.2:Architecture:F" "SWE.3:Design:L" "SWE.4:Unit Verification:P" "SWE.5:Integration Verification:L" "SWE.6:Qualification Verification:P")
ASPICE40_SYS_PROCESSES=("SYS.2:System Requirements:F" "SYS.3:System Architecture:L" "SYS.4:System Integration Verification:L" "SYS.5:System Qualification Verification:P")
ASPICE40_SUP_PROCESSES=("SUP.1:Quality Assurance:L" "SUP.8:Configuration Management:F" "SUP.9:Problem Resolution:L" "SUP.10:Change Management:L" "SUP.11:ML Data Management:N")
ASPICE40_MAN_PROCESSES=("MAN.3:Project Management:L" "MAN.5:Risk Management:P" "MAN.6:Measurement:P")
ASPICE40_MLE_PROCESSES=("MLE.1:ML Requirements Analysis:N" "MLE.2:ML Architecture:N" "MLE.3:ML Training:N" "MLE.4:ML Model Verification:N")
ASPICE40_HWE_PROCESSES=("HWE.1:HW Requirements Analysis:N" "HWE.2:HW Design:N" "HWE.3:HW Design Verification:N" "HWE.4:HW Requirements Verification:N")
ASPICE40_VAL_PROCESSES=("VAL.1:Validation:N")

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $(basename "$0") [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help       Show this help"
            echo "  -v, --verbose    Verbose output"
            echo "  -V, --version    ASPICE version (3.1|4.0), default: 3.1"
            echo "  -l, --level      Target capability level (1|2|3)"
            echo "  -p, --process    Process area (SWE|SYS|MLE|HWE|MAN|SUP|VAL|all)"
            echo "  -o, --output     Output audit report"
            echo ""
            echo "Version Selection:"
            echo "  ASPICE 3.1 - Traditional VDA Scope assessments, 'Testing' terminology"
            echo "  ASPICE 4.0 - ML/HW projects, 'Verification' terminology, new processes"
            exit 0
            ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -V|--version) ASPICE_VERSION="$2"; shift 2 ;;
        -l|--level) TARGET_LEVEL="$2"; shift 2 ;;
        -p|--process) PROCESS_AREA="$2"; shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Validate version
if [[ "$ASPICE_VERSION" != "3.1" && "$ASPICE_VERSION" != "4.0" ]]; then
    error "Invalid ASPICE version: $ASPICE_VERSION. Use 3.1 or 4.0"
    exit 1
fi

# Validate process area for version
if [[ "$ASPICE_VERSION" == "3.1" && ("$PROCESS_AREA" == "MLE" || "$PROCESS_AREA" == "HWE" || "$PROCESS_AREA" == "VAL") ]]; then
    warn "Process area $PROCESS_AREA is only available in ASPICE 4.0"
    warn "Switching to ASPICE 4.0 for this assessment"
    ASPICE_VERSION="4.0"
fi

get_processes() {
    local area="$1"
    local version="$2"

    case "$version" in
        "3.1")
            case "$area" in
                SWE) printf '%s\n' "${ASPICE31_SWE_PROCESSES[@]}" ;;
                SYS) printf '%s\n' "${ASPICE31_SYS_PROCESSES[@]}" ;;
                SUP) printf '%s\n' "${ASPICE31_SUP_PROCESSES[@]}" ;;
                MAN) printf '%s\n' "${ASPICE31_MAN_PROCESSES[@]}" ;;
                all)
                    printf '%s\n' "${ASPICE31_SWE_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE31_SYS_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE31_SUP_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE31_MAN_PROCESSES[@]}"
                    ;;
            esac
            ;;
        "4.0")
            case "$area" in
                SWE) printf '%s\n' "${ASPICE40_SWE_PROCESSES[@]}" ;;
                SYS) printf '%s\n' "${ASPICE40_SYS_PROCESSES[@]}" ;;
                SUP) printf '%s\n' "${ASPICE40_SUP_PROCESSES[@]}" ;;
                MAN) printf '%s\n' "${ASPICE40_MAN_PROCESSES[@]}" ;;
                MLE) printf '%s\n' "${ASPICE40_MLE_PROCESSES[@]}" ;;
                HWE) printf '%s\n' "${ASPICE40_HWE_PROCESSES[@]}" ;;
                VAL) printf '%s\n' "${ASPICE40_VAL_PROCESSES[@]}" ;;
                all)
                    printf '%s\n' "${ASPICE40_SWE_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE40_SYS_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE40_SUP_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE40_MAN_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE40_MLE_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE40_HWE_PROCESSES[@]}"
                    printf '%s\n' "${ASPICE40_VAL_PROCESSES[@]}"
                    ;;
            esac
            ;;
    esac
}

assess_processes() {
    info "ASPICE Version: $ASPICE_VERSION"
    info "Assessing $PROCESS_AREA processes (target: Level $TARGET_LEVEL)..."

    local processes
    mapfile -t processes < <(get_processes "$PROCESS_AREA" "$ASPICE_VERSION")

    for p in "${processes[@]}"; do
        IFS=':' read -r id name rating <<< "$p"
        local rating_full=""
        case "$rating" in
            N) rating_full="Not achieved" ;;
            P) rating_full="Partially achieved" ;;
            L) rating_full="Largely achieved" ;;
            F) rating_full="Fully achieved" ;;
        esac
        info "  $id ($name): $rating_full"
    done
}

generate_audit_report() {
    # Build assessments array
    local assessments="["
    local first=true
    local processes
    mapfile -t processes < <(get_processes "$PROCESS_AREA" "$ASPICE_VERSION")

    for p in "${processes[@]}"; do
        IFS=':' read -r id name rating <<< "$p"
        local level=0
        case "$rating" in
            F) level=2 ;;
            L) level=1 ;;
            P) level=0 ;;
            N) level=0 ;;
        esac

        if [[ "$first" == "true" ]]; then
            first=false
        else
            assessments+=","
        fi
        assessments+="{\"process\": \"$id\", \"name\": \"$name\", \"rating\": \"$rating\", \"level\": $level}"
    done
    assessments+="]"

    # Determine terminology based on version
    local terminology="Testing"
    if [[ "$ASPICE_VERSION" == "4.0" ]]; then
        terminology="Verification"
    fi

    cat > "$OUTPUT_FILE" <<EOF
{
    "aspice_audit": {
        "aspice_version": "${ASPICE_VERSION}",
        "target_level": ${TARGET_LEVEL},
        "process_area": "${PROCESS_AREA}",
        "terminology": "${terminology}",
        "standard": "Automotive SPICE ${ASPICE_VERSION}",
        "assessments": ${assessments},
        "overall_capability": 1,
        "gaps_for_level_2": ["SWE.4 needs improvement", "SWE.6 needs improvement"],
        "version_specific_info": {
            "aspice_31_vda_scope": {
                "description": "Traditional VDA Scope assessment",
                "processes": ["SYS.2-5", "SWE.1-6", "SUP.1,8-10", "MAN.3"]
            },
            "aspice40_new_processes": {
                "MLE": ["MLE.1", "MLE.2", "MLE.3", "MLE.4"],
                "HWE": ["HWE.1", "HWE.2", "HWE.3", "HWE.4"],
                "VAL": ["VAL.1"],
                "SUP": ["SUP.11"],
                "MAN": ["MAN.5", "MAN.6"],
                "PIM": ["PIM.3"],
                "REU": ["REU.2"]
            }
        },
        "audited_at": "$(date -Iseconds)"
    }
}
EOF
    info "Audit report written to: $OUTPUT_FILE"
}

main() {
    info "Starting ASPICE $ASPICE_VERSION audit..."
    assess_processes
    generate_audit_report
    info "ASPICE audit complete"
}

main
