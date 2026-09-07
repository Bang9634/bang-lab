# bang-lab

개인 개발자 포트폴리오 겸 개발 로그 작성 웹사이트입니다.

## 기술 스택과 아키텍처

Astro, TypeScript, Markdown/MDX, npm workspaces를 사용합니다.
대부분의 페이지는 정적 HTML로 생성합니다.

계획한 서비스 구조는 다음과 같습니다.

```text
Markdown / MDX → Astro 빌드 → 정적 파일 → Nginx → 브라우저
```

Oracle Cloud VM, Nginx, Let's Encrypt, GitHub Actions를 이용한 배포를 계획하고 있습니다.
현재는 로컬 사이트와 CI 검증 워크플로가 구현돼 있고, 자동 배포는 아직 구현하지 않았습니다.

## 로컬 개발

Node.js 22.12 이상이 필요해. CI에서는 Node.js 24를 사용합니다.
저장소 루트에서 다음 명령을 실행하면 합니다.

```sh
npm ci
npm run dev
```

개발 서버 주소는 터미널에 표시되며 타입 검사와 빌드, 빌드 결과 미리보기는 다음 명령으로 실행합니다.

```sh
npm run check
npm run build
npm run preview
```

빌드 결과는 `apps/web/dist/`에 생성됩니다.

## 사이트 표시 정보 설정

푸터의 이메일과 저작권 이름은 소스에 직접 작성하지 않고 빌드 환경변수로 전달합니다.
`apps/web/.env.example`을 `apps/web/.env`로 복사한 뒤 값을 입력합니다.
기존 `.env`가 있다면 덮어쓰지 않고 필요한 항목만 수정합니다.

| 변수 | 용도 | 비어 있을 때 |
| --- | --- | --- |
| `CONTACT_EMAIL` | 푸터의 이메일과 메일 링크 | 연락처를 표시하지 않음 |
| `PROFILE_NAME` | 푸터 저작권 이름 | `Bang's Lab` 표시 |

`.env`는 Git에서 제외하며, `.env.example`에는 실제 개인정보를 넣지 않습니다.
이메일 형식이 잘못되면 값을 출력하지 않는 오류 메시지와 함께 빌드가 실패합니다.
환경변수 변경 후 개발 서버를 재시작하고, 배포 사이트는 다시 빌드해야 합니다.
화면에 출력한 값은 최종 HTML과 빌드 아티팩트에서 볼 수 있습니다.
이 구조는 Git 소스·커밋에서 정보를 분리하며, 사이트 방문자에게 숨기는 기능은 아닙니다.

GitHub Actions 설정은 [배포 문서](docs/deployment.md#빌드-환경변수)를 참고합니다.

## 페이지 구성

현재는 터미널 첫 화면과 About, Work, Contact 섹션으로 구성된 홈,
그리고 404 페이지만 제공합니다. 페이지를 새로 열거나 새로고침하면 홈 최상단에서 시작합니다.

Log는 홈 제작 이후 구현할 예정입니다. 이전 초안의 글 목록·상세 페이지,
프로젝트 페이지와 실험 글 템플릿은 삭제했습니다.
Markdown/MDX 기반 글 작성 구조는 Log를 구현할 때 새로 구성할 예정입니다.

## 저장소 구조

```text
apps/web/             Astro 웹사이트
infra/nginx/          Nginx HTTP 초기 설정 템플릿
infra/scripts/        향후 배포 스크립트를 둘 위치
docs/                 아키텍처, 설계 결정, 배포 문서
docs/ai-context/      AI 코딩 에이전트를 위한 프로젝트 맥락과 작업 규칙
.github/workflows/    CI 검증 워크플로
```

자세한 내용은 [아키텍처](docs/architecture.md), [배포](docs/deployment.md),
[설계 결정](docs/decisions.md), [현재 구현 상태](docs/ai-context/current-state.md)를 참고바랍니다.

## 라이선스

소스 코드는 [MIT 라이선스](LICENSE)를 적용합니다.
블로그 글과 직접 작성한 문서·콘텐츠는 소스 코드 라이선스 적용 대상에서 제외하며,
별도 표시가 없는 한 **모든 권리를 저작권자가 보유합니다(All rights reserved)**.
자세한 범위는 [콘텐츠 라이선스 안내](CONTENT-LICENSE.md)를 참고바랍니다.
