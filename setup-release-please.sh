#!/usr/bin/env bash
set -euo pipefail

# release-please를 새 프로젝트에 온보딩한다.
#  1) 중앙 repo(dbsdud/.github)에서 템플릿을 내려받아 현재 프로젝트에 배치
#  2) GitHub App 비밀키를 해당 repo의 secret으로 주입
#
# 사용법(프로젝트 루트에서 실행):
#   curl -fsSL https://raw.githubusercontent.com/dbsdud/.github/main/setup-release-please.sh | bash -s -- --key ~/release-please-app.pem
# 또는 로컬에서:
#   ./setup-release-please.sh [--repo owner/name] [--key path/to/app.pem] [--monorepo] [--force]

CENTRAL_REPO="dbsdud/.github"
MONOREPO=false
KEY_PATH=""
REPO=""
FORCE=false

usage() {
  cat <<'EOF'
사용법: setup-release-please.sh [옵션]
  --repo owner/name   대상 repo (생략 시 현재 디렉토리에서 자동 감지)
  --key  path         GitHub App 비밀키(PEM) 파일 경로 (secret 주입에 사용)
  --monorepo          멀티언어 모노레포 템플릿 사용
  --force             기존 파일이 있어도 덮어쓰기
  -h, --help          도움말
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --key) KEY_PATH="$2"; shift 2 ;;
    --monorepo) MONOREPO=true; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "알 수 없는 인자: $1" >&2; usage; exit 1 ;;
  esac
done

command -v gh >/dev/null || { echo "gh CLI가 필요합니다." >&2; exit 1; }

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [[ -z "$REPO" ]]; then
  echo "repo를 감지하지 못했습니다. --repo owner/name 으로 지정하세요." >&2
  exit 1
fi
echo "대상 repo: $REPO"

fetch() { # $1=중앙 repo 내 경로, $2=로컬 대상
  gh api -H "Accept: application/vnd.github.raw" \
    "repos/$CENTRAL_REPO/contents/$1?ref=main" > "$2"
  echo "  + $2"
}

place() { # $1=원본, $2=대상
  if [[ -f "$2" && "$FORCE" == false ]]; then
    echo "  = skip(이미 존재): $2"
  else
    fetch "$1" "$2"
  fi
}

mkdir -p .github/workflows
echo "템플릿 배치:"
place "templates/release.yml" ".github/workflows/release.yml"

if $MONOREPO; then
  place "templates/release-please-config.monorepo.json" "release-please-config.json"
  place "templates/.release-please-manifest.monorepo.json" ".release-please-manifest.json"
else
  place "templates/release-please-config.json" "release-please-config.json"
  place "templates/.release-please-manifest.json" ".release-please-manifest.json"
fi

echo "secret 주입:"
if [[ -n "$KEY_PATH" ]]; then
  [[ -f "$KEY_PATH" ]] || { echo "  키 파일 없음: $KEY_PATH" >&2; exit 1; }
  gh secret set RELEASE_PLEASE_APP_PRIVATE_KEY --repo "$REPO" < "$KEY_PATH"
  echo "  + RELEASE_PLEASE_APP_PRIVATE_KEY → $REPO"
else
  echo "  ! 키 미지정(--key). 나중에 아래 명령으로 주입하세요:"
  echo "      gh secret set RELEASE_PLEASE_APP_PRIVATE_KEY --repo $REPO < app.pem"
fi

cat <<EOF

완료. 다음을 확인/수정하세요:
  - .release-please-manifest.json 의 초기 버전(기본 0.0.0)
  - release-please-config.json 의 release-type / packages
그 후 커밋해서 main에 push하면 release-please가 release PR을 엽니다.
  git add .github/workflows/release.yml release-please-config.json .release-please-manifest.json
  git commit -m "chore: release-please 설정 추가"
EOF
