# release-please 중앙 설정

내(`dbsdud`) 모든 프로젝트의 릴리스 자동화를 한 곳에서 관리한다.
[release-please](https://github.com/googleapis/release-please)가 conventional commit을
읽어 버전 산정 → release PR 생성 → 머지 시 태그/릴리스/CHANGELOG를 만든다.

## 구조

| 경로 | 역할 |
|------|------|
| `.github/workflows/release-please.yml` | **재사용 워크플로(로직 1곳)**. 각 프로젝트가 호출한다. |
| `templates/release.yml` | 각 repo에 두는 **호출용** 워크플로(`.github/workflows/release.yml`) |
| `templates/release-please-config.json` | 단일 패키지용 설정 |
| `templates/release-please-config.monorepo.json` | 멀티언어 모노레포용 설정 |
| `templates/.release-please-manifest*.json` | 현재 버전 추적 파일 |
| `setup-release-please.sh` | 새 프로젝트 온보딩(템플릿 복사 + secret 주입) |

## 인증: GitHub App

릴리스 PR/태그가 **후속 워크플로(예: publish)를 트리거**할 수 있도록 App 토큰을 쓴다.
(기본 `GITHUB_TOKEN`으로 만든 이벤트는 다른 워크플로를 트리거하지 못함)

- App ID는 민감정보가 아니므로 재사용 워크플로의 `app-id` 기본값에 박아둔다.
- **비밀키(PEM)만** 각 repo의 secret `RELEASE_PLEASE_APP_PRIVATE_KEY`로 주입한다.
  - 개인 계정은 조직 공유 secret이 없으므로 repo마다 1회 주입 필요(스크립트가 자동화).

### App 1회 생성

1. https://github.com/settings/apps/new
2. 권한(Repository permissions):
   - **Contents: Read and write**
   - **Pull requests: Read and write**
   - **Issues: Read and write**
3. "Where can this GitHub App be installed?" → **Only on this account**
4. 생성 후: **App ID**를 재사용 워크플로의 `app-id` 기본값에 기입.
5. "Generate a private key" → 받은 `.pem`을 안전하게 보관(repo secret 주입에 사용).
6. **Install App** → 릴리스를 돌릴 repo들에 설치(All repositories 권장).

## 새 프로젝트에 적용

프로젝트 루트에서:

```bash
# 단일 패키지
curl -fsSL https://raw.githubusercontent.com/dbsdud/.github/main/setup-release-please.sh \
  | bash -s -- --key ~/release-please-app.pem

# 멀티언어 모노레포
curl -fsSL https://raw.githubusercontent.com/dbsdud/.github/main/setup-release-please.sh \
  | bash -s -- --key ~/release-please-app.pem --monorepo
```

생성된 `release-please-config.json` / `.release-please-manifest.json`을 프로젝트에 맞게
수정(release-type, packages, 초기 버전)한 뒤 커밋 → main에 push.

## 동작 흐름

1. main에 conventional commit이 쌓이면 release-please가 **release PR**을 연다(버전·CHANGELOG 미리보기).
2. 그 PR을 머지하면 → 태그 + GitHub Release 생성.
3. (App 토큰 덕분에) 태그 push가 publish 같은 후속 워크플로를 트리거할 수 있다.

> 이 계정 규칙: **squash 비허용 — merge commit + rebase만 허용.**
> 머지 시 개별 커밋이 main에 보존되어 release-please가 모든 conventional 커밋을 읽는다.
> 커밋이 전부 비표준이면 그 변경은 릴리스에서 조용히 누락되니, 커밋마다 `type:`을 지킬 것.
