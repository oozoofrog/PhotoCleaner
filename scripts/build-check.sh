#!/bin/bash
#
# build-check.sh - PhotoCleaner 빌드 경고 및 오류 체크 스크립트
#
# 사용법:
#   ./scripts/build-check.sh           # 기본 빌드 (Debug)
#   ./scripts/build-check.sh release   # Release 빌드
#   ./scripts/build-check.sh clean     # 클린 빌드
#   ./scripts/build-check.sh test      # 테스트 실행

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 프로젝트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_PATH="$PROJECT_DIR/PhotoCleaner.xcodeproj"
PROJECT_PBX_PATH="$PROJECT_PATH/project.pbxproj"
SCHEME="PhotoCleaner"
DERIVED_DATA="$PROJECT_DIR/DerivedData"
LOG_FILE="$PROJECT_DIR/.build-log.txt"
BUILD_RESULT_FILE="$PROJECT_DIR/.build-result.toon"

# 기본값
CONFIGURATION="Debug"
CLEAN_BUILD=false
RUN_TESTS=false
QUIET_MODE=false

# 도움말
validate_project() {
    if [ ! -d "$PROJECT_PATH" ]; then
        echo -e "${RED}❌ Project file not found: $PROJECT_PATH${NC}"
        exit 1
    fi

    if [ ! -f "$PROJECT_PBX_PATH" ]; then
        echo -e "${RED}❌ project.pbxproj not found: $PROJECT_PBX_PATH${NC}"
        exit 1
    fi

    if ! xcodebuild -list -project "$PROJECT_PATH" >/dev/null 2>&1; then
        echo -e "${RED}❌ xcodebuild cannot read project (project may be malformed).${NC}"
        echo -e "${YELLOW}Run: xcodebuild -list -project \"$PROJECT_PATH\"${NC}"
        exit 1
    fi
}

resolve_test_destination() {
    local destination_line
    local destination_name
    local destination_id

    if command -v xcodebuild >/dev/null 2>&1; then
        destination_line="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showdestinations 2>/dev/null \
            | awk '
                /{ platform:iOS Simulator/ {
                    if ($0 !~ /Any iOS Simulator Device/) {
                        print;
                        exit;
                    }
                }'
        )"
        if [ -n "${destination_line:-}" ]; then
            destination_name="$(printf '%s' "$destination_line" | sed -n 's/.*name:\([^,}]*\).*/\1/p' | head -n 1 | xargs)"
            destination_id="$(printf '%s' "$destination_line" | sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -n 1 | xargs)"
            if [ -n "${destination_id:-}" ] && [ "$destination_id" != "dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder" ]; then
                echo "id=$destination_id"
                return 0
            fi
            if [ -n "${destination_name:-}" ] && [ "$destination_name" != "Any iOS Simulator Device" ]; then
                echo "platform=iOS Simulator,name=$destination_name"
                return 0
            fi
        fi
    fi

    if command -v xcrun >/dev/null 2>&1; then
        destination_id="$(xcrun simctl list devices available 2>/dev/null \
            | awk '/^[[:space:]]*(iPhone|iPad)/ {
                if (match($0, /[0-9A-Fa-f-]{8,}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}/)) {
                    print substr($0, RSTART, RLENGTH);
                    exit
                }
            }'
        )"
        if [ -n "${destination_id:-}" ]; then
            echo "id=$destination_id"
            return 0
        fi

        destination_name="$(xcrun simctl list devices available 2>/dev/null \
            | awk '/^[[:space:]]*(iPhone|iPad)/ {
                gsub(/^[[:space:]]*/, "", $0);
                sub(/ \([0-9A-Fa-f-]+\) \([^)]+\)[[:space:]]*$/, "", $0);
                gsub(/[[:space:]]*$/, "", $0);
                print;
                exit;
            }')"
        if [ -n "${destination_name:-}" ]; then
            echo "platform=iOS Simulator,name=$destination_name"
            return 0
        fi
    fi

    return 1
}

# 도움말
show_help() {
    echo -e "${BOLD}PhotoCleaner Build Check Script${NC}"
    echo ""
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Commands:"
    echo "  (none)     기본 빌드 (Debug)"
    echo "  release    Release 빌드"
    echo "  clean      클린 후 빌드"
    echo "  test       테스트 실행"
    echo ""
    echo "Options:"
    echo "  -q, --quiet    경고/오류만 출력"
    echo "  -h, --help     도움말 표시"
    echo ""
}

# 인자 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        release)
            CONFIGURATION="Release"
            shift
            ;;
        clean)
            CLEAN_BUILD=true
            shift
            ;;
        test)
            RUN_TESTS=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 헤더 출력
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  📱 PhotoCleaner Build Check${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC} $CONFIGURATION"
echo -e "${CYAN}Clean Build:${NC}   $CLEAN_BUILD"
echo -e "${CYAN}Run Tests:${NC}     $RUN_TESTS"
echo ""

validate_project

# 클린 빌드
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build...${NC}"
    xcodebuild clean \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -quiet 2>/dev/null || true
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# 빌드 명령 구성
BUILD_CMD="xcodebuild"
if [ "$RUN_TESTS" = true ]; then
    BUILD_CMD="$BUILD_CMD test"
else
    BUILD_CMD="$BUILD_CMD build"
fi

BUILD_DESTINATION="generic/platform=iOS Simulator"
if [ "$RUN_TESTS" = true ]; then
    if ! RESOLVED_DESTINATION="$(resolve_test_destination)"; then
        echo -e "${YELLOW}⚠️  No concrete simulator destination found. Falling back to generic placeholder.${NC}"
    else
        BUILD_DESTINATION="$RESOLVED_DESTINATION"
    fi
fi

BUILD_CMD="$BUILD_CMD \
    -project \"$PROJECT_PATH\" \
    -scheme \"$SCHEME\" \
    -configuration \"$CONFIGURATION\" \
    -derivedDataPath \"$DERIVED_DATA\" \
    -destination \"$BUILD_DESTINATION\""

# 빌드 실행
echo -e "${YELLOW}🔨 Building...${NC}"
echo -e "${CYAN}Destination:${NC} $BUILD_DESTINATION"
echo ""

BUILD_START=$(date +%s)

if ! command -v xcsift &> /dev/null; then
    echo -e "${RED}❌ xcsift not found. Install: brew install xcsift${NC}"
    exit 1
fi

if [ "$QUIET_MODE" = true ]; then
    eval "$BUILD_CMD" 2>&1 | tee "$LOG_FILE" | xcsift -f toon --quiet | tee "$BUILD_RESULT_FILE"
else
    eval "$BUILD_CMD" 2>&1 | tee "$LOG_FILE" | xcsift -f toon | tee "$BUILD_RESULT_FILE"
fi
BUILD_EXIT_CODE=${PIPESTATUS[0]}

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  📊 Build Summary${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 경고 및 오류 카운트
if [ -f "$BUILD_RESULT_FILE" ] || [ -f "$LOG_FILE" ]; then
    if [ -f "$BUILD_RESULT_FILE" ]; then
        ERROR_COUNT="$(awk '/^  errors:/ {print $2}' "$BUILD_RESULT_FILE" | tr -d '[:space:]')"
        WARNING_COUNT="$(awk '/^  warnings:/ {print $2}' "$BUILD_RESULT_FILE" | tr -d '[:space:]')"
    else
        ERROR_COUNT="$(printf '0')"
        WARNING_COUNT="$(printf '0')"
    fi
    [ -z "$ERROR_COUNT" ] && ERROR_COUNT="0"
    [ -z "$WARNING_COUNT" ] && WARNING_COUNT="0"

    echo -e "${CYAN}⏱  Build Time:${NC}  ${BUILD_DURATION}s"

    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}❌ Errors:${NC}      $ERROR_COUNT"
    else
        echo -e "${GREEN}✓  Errors:${NC}      0"
    fi

    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warnings:${NC}    $WARNING_COUNT"
    else
        echo -e "${GREEN}✓  Warnings:${NC}    0"
    fi

    echo ""

    # 오류 상세 표시
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}${BOLD}━━━ Errors ━━━${NC}"
        grep -En "[0-9]+:[0-9]+:[0-9]+: error:" "$LOG_FILE" | head -20 | while read -r line; do
            echo -e "${RED}  $line${NC}"
        done
        echo ""
    fi

    # 경고 상세 표시
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}━━━ Warnings ━━━${NC}"
        grep -En "[0-9]+:[0-9]+:[0-9]+: warning:" "$LOG_FILE" | head -20 | while read -r line; do
            echo -e "${YELLOW}  $line${NC}"
        done
        if [ "$WARNING_COUNT" -gt 20 ]; then
            echo -e "${YELLOW}  ... and $((WARNING_COUNT - 20)) more warnings${NC}"
        fi
        echo ""
    fi
fi

# 최종 결과
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$BUILD_EXIT_CODE" -eq 0 ]; then
    if [ "$RUN_TESTS" = true ]; then
        echo -e "${GREEN}${BOLD}  ✅ Tests Passed!${NC}"
    else
        echo -e "${GREEN}${BOLD}  ✅ Build Succeeded!${NC}"
    fi
else
    if [ "$RUN_TESTS" = true ]; then
        echo -e "${RED}${BOLD}  ❌ Tests Failed!${NC}"
    else
        echo -e "${RED}${BOLD}  ❌ Build Failed!${NC}"
    fi
fi
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

exit $BUILD_EXIT_CODE
