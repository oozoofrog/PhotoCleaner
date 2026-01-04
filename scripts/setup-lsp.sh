#!/bin/bash
# iOS 프로젝트 LSP 설정 스크립트
# 사용법: ./scripts/setup-lsp.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 프로젝트 감지 중..."

# xcode-build-server 설치 확인
if ! command -v xcode-build-server &> /dev/null; then
    echo "📦 xcode-build-server 설치 중..."
    brew install xcode-build-server
fi

# 프로젝트 파일 찾기
WORKSPACE=$(find . -maxdepth 1 -name "*.xcworkspace" -type d | head -1)
PROJECT=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -1)

if [ -z "$PROJECT" ] && [ -z "$WORKSPACE" ]; then
    echo "❌ Xcode 프로젝트를 찾을 수 없습니다"
    exit 1
fi

# Scheme 찾기
if [ -n "$WORKSPACE" ]; then
    SCHEME=$(xcodebuild -workspace "$WORKSPACE" -list 2>/dev/null | grep -A100 "Schemes:" | tail -n +2 | head -1 | xargs)
    BUILD_TARGET="-workspace $WORKSPACE"
else
    SCHEME=$(xcodebuild -project "$PROJECT" -list 2>/dev/null | grep -A100 "Schemes:" | tail -n +2 | head -1 | xargs)
    BUILD_TARGET="-project $PROJECT"
fi

echo "📱 프로젝트: ${WORKSPACE:-$PROJECT}"
echo "🎯 Scheme: $SCHEME"

# .compile 파일이 이미 있고 최신인지 확인
if [ -f ".compile" ]; then
    COMPILE_AGE=$((($(date +%s) - $(stat -f %m .compile)) / 3600))
    if [ $COMPILE_AGE -lt 24 ]; then
        echo "✅ LSP 설정이 이미 최신입니다 (${COMPILE_AGE}시간 전)"
        exit 0
    fi
    echo "🔄 LSP 설정 갱신 중... (${COMPILE_AGE}시간 경과)"
fi

echo "🔨 빌드 및 LSP 설정 생성 중..."
xcodebuild $BUILD_TARGET -scheme "$SCHEME" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    clean build 2>&1 | xcode-build-server parse

echo "✅ LSP 설정 완료!"
echo "   - .compile 생성됨"
echo "   - buildServer.json 생성됨"
