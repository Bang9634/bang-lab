# bang-lab

개인 개발자 포트폴리오 겸 개발 로그 작성 웹사이트입니다.

## 기술 스택과 아키텍처

Astro, TypeScript, Markdown/MDX, npm workspaces를 사용합니다.
대부분의 페이지는 정적 HTML로 생성합니다.

계획한 서비스 구조는 다음과 같습니다.

```text
Markdown / MDX → Astro 빌드 → 정적 파일 → Nginx → 브라우저
```

Oracle Cloud VM, Nginx, Let's Encrypt로 수동 배포와 HTTPS 설정을 완료했습니다.
GitHub Actions의 수동 배포 성공을 확인했고, `main` push 시 검사·빌드·배포하는 자동 배포 설정도 완료했습니다.
Secrets 등록과 자동 배포 활성화 절차는 [배포 문서](docs/deployment.md)를 참고합니다.

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

푸터 이메일과 저작권 이름은 [`apps/web/src/config/profile.ts`](apps/web/src/config/profile.ts)에서 정적으로 관리합니다.
`contactEmail`과 `profileName`을 수정한 뒤 빌드·배포하면 반영됩니다.
이메일이 비어 있으면 숨기고, 이름이 비어 있으면 `Bang's Lab`을 표시합니다.
잘못된 이메일 형식은 빌드 오류로 처리합니다.

이 값은 공개 소스와 배포 HTML에 포함됩니다. `.env`나 GitHub Secrets에 등록할 필요가 없습니다.
배포 접속 정보와 개인키는 계속 GitHub Secrets에서 관리합니다.

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
infra/scripts/        SSH 전송·릴리스 전환 스크립트
docs/                 아키텍처, 설계 결정, 배포 문서
docs/ai-context/      AI 코딩 에이전트를 위한 프로젝트 맥락과 작업 규칙
.github/workflows/    CI/CD 워크플로
```

자세한 내용은 [아키텍처](docs/architecture.md), [배포](docs/deployment.md),
[설계 결정](docs/decisions.md), [현재 구현 상태](docs/ai-context/current-state.md)를 참고바랍니다.

## 라이선스

소스 코드는 [MIT 라이선스](LICENSE)를 적용합니다.
블로그 글과 직접 작성한 문서·콘텐츠는 소스 코드 라이선스 적용 대상에서 제외하며,
별도 표시가 없는 한 **모든 권리를 저작권자가 보유합니다(All rights reserved)**.
자세한 범위는 [콘텐츠 라이선스 안내](CONTENT-LICENSE.md)를 참고바랍니다.
