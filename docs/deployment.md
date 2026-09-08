# 배포

2026-09-09 사용자가 Ubuntu 서버의 수동 배포·HTTPS·외부 접속과 `deploy` 계정의
SSH 접속·배포 경로 쓰기 권한 확인을 완료했다. 에이전트가 원격 서버를 직접 검증한 것은 아니다.
이후 사용자가 GitHub Actions 수동 배포 성공과 자동 배포 설정 완료를 확인했다.
최초 서버 구성은 [Ubuntu 최초 배포 안내](first-deployment.md)를 참고한다.

## 워크플로 동작

`.github/workflows/ci.yml`에서 검사·빌드한 아티팩트를 배포 작업이 그대로 내려받는다.
PR은 검사·빌드만 수행한다. `main`에서 수동 실행하면 배포하며,
repository variable `AUTO_DEPLOY=true`를 등록하면 `main` push도 자동 배포한다.
이 값이 없거나 `false`이면 push는 CI만 수행한다.

1. `npm ci`, `npm run check`, `npm run build`를 실행한다.
2. 커밋 SHA를 `release.txt`에 기록하고 아티팩트를 7일간 보관한다.
3. 전용 SSH 키와 사전에 확인한 호스트 키로 서버에 접속한다.
4. `/var/www/bang-lab/releases/<SHA>-<run ID>-<attempt>/`에 파일을 전송한다.
5. 서버 잠금을 획득하고 `current` 심볼릭 링크를 원자적으로 교체한다.
6. HTTPS의 `release.txt`가 배포 SHA인지, 홈 요청이 성공하는지 확인한다.
7. 확인 실패 시 이전 링크로 복구하고 워크플로를 실패 처리한다.

동일 브랜치의 워크플로는 직렬화하며 진행 중 배포를 새 push로 취소하지 않는다.
GitHub의 대기 실행 교체 정책에 따라 중간 커밋 배포는 생략될 수 있다.
Nginx 재시작이나 인증서 수정은 필요하지 않다. 기존 운영 설정을 템플릿으로 덮어쓰지 않는다.
배포 계정에는 `sudo`를 주지 않는다. 서버에는 `bash`, `rsync`, `curl`, `flock`이 필요하다.

## GitHub 값 등록

저장소의 **Settings → Secrets and variables → Actions → Secrets → New repository secret**에서 등록한다.
Environment secrets가 아닌 **Repository secrets**를 사용한다.

| 이름 | 값 |
| --- | --- |
| `DEPLOY_HOST` | 서버 IPv4 또는 SSH 호스트명. `https://`와 포트 제외 |
| `DEPLOY_USER` | `deploy` |
| `DEPLOY_PORT` | SSH 포트. 기본값 `22`도 명시 |
| `DEPLOY_SSH_KEY` | `~/.ssh/bang-lab-deploy` 개인키 전체. BEGIN/END 줄 포함 |
| `DEPLOY_KNOWN_HOSTS` | 아래 방법으로 만든 서버 호스트 공개키 한 줄 |
| `SITE_URL` | 실제 최종 HTTPS 주소. 예: `https://example.com`. 끝 `/` 제외 |

현재 스크립트는 IPv4·DNS 호스트명과 HTTPS origin만 지원한다.
`SITE_URL`은 리다이렉트 전 주소가 아니라 브라우저에 최종 표시되는 주소를 사용한다.
실제 도메인·IP·개인키는 저장소 파일에 작성하지 않는다.

Mac에서 개인키를 출력하지 않고 복사한다.

```sh
pbcopy < ~/.ssh/bang-lab-deploy
```

### 서버 호스트 키

기존에 신원을 확인한 `ubuntu` SSH 연결 안에서 다음을 실행한다.

```sh
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

출력 중 `ssh-ed25519`와 바로 뒤 키 부분을 사용한다. 이것은 서버 공개키이며
배포 계정의 `authorized_keys`에 넣었던 사용자 공개키와 다르다.
`DEPLOY_HOST`와 똑같은 주소를 앞에 붙여 `DEPLOY_KNOWN_HOSTS`에 등록한다.

기본 포트 22:

```text
SERVER_IP ssh-ed25519 AAAA...실제서버공개키...
```

다른 포트(예: 2222):

```text
[SERVER_IP]:2222 ssh-ed25519 AAAA...실제서버공개키...
```

확인하지 않은 `ssh-keyscan` 결과를 그대로 신뢰하거나
`StrictHostKeyChecking`을 끄지 않는다. 서버 재설치로 호스트 키가 바뀌면 신원을 다시 확인하고 갱신한다.

## 첫 실행과 자동 배포 활성화

1. Ubuntu의 기존 관리자 연결에서 도구를 확인한다.

   ```sh
   command -v bash rsync curl flock
   ```

   누락된 도구가 있다면 관리자가 설치한다.

   ```sh
   sudo apt-get update
   sudo apt-get install -y rsync curl util-linux
   ```

2. 위 Secrets를 등록한다. Variables 탭의 `AUTO_DEPLOY`는 아직 만들지 않거나 `false`로 둔다.
3. 변경한 워크플로·스크립트·문서를 커밋하고 기본 브랜치인 `main`에 반영한다.
4. **Actions → Validate and deploy website → Run workflow → main → Run workflow**를 선택한다.
5. `build`와 `deploy`의 성공, 실제 사이트의 표시와 `/release.txt`의 커밋 SHA를 확인한다.
6. **Settings → Secrets and variables → Actions → Variables → New repository variable**에서
   이름 `AUTO_DEPLOY`, 값 `true`를 등록한다. 이후 `main` push마다 배포된다.

수동 실행 버튼은 워크플로가 기본 브랜치에 있어야 표시된다. 등록한 값만 바꿔서는
실행이 시작되지 않으며 push 또는 수동 실행이 필요하다.

## 사이트 표시 정보

푸터의 이메일과 이름은 `apps/web/src/config/profile.ts`의 `contactEmail`, `profileName`으로 관리한다.
공개 소스에 정적으로 작성하며 빌드 후 HTML에 반영된다.
`CONTACT_EMAIL`, `PROFILE_NAME` 환경변수와 GitHub Secrets는 사용하지 않는다.
기존에 등록한 두 Secret은 삭제해도 된다. 배포 접속용 Secrets는 계속 필요하다.
값을 수정한 뒤 다시 빌드·배포한다. 이메일이 비어 있으면 숨기고 이름이 비어 있으면 브랜드명을 표시한다.

## 장애와 복구

전송이나 사전 검사가 실패하면 현재 링크를 변경하지 않는다. 활성화 후 HTTPS 검증이
실패하면 이전 릴리스 링크로 복구한다. 네트워크 문제도 검증 실패에 포함된다.
복구는 링크를 되돌리는 것으로, 외부 네트워크·Nginx·인증서 문제까지 해결하지는 않는다.
SIGKILL, VM 중단 등으로 복구 코드가 실행되지 못하면 관리자 확인이 필요하다.

필요하면 기존 `ubuntu` 연결에서 알려진 정상 릴리스로 수동 복구한다.
아래 `release-001`은 실제 남아 있는 정상 릴리스로 바꾼다. 실행 중 배포와 같은 잠금을 사용한다.

```sh
sudo -u deploy bash -c '
  set -e
  exec 9>/var/www/bang-lab/.deploy.lock
  flock -w 60 9
  test -d /var/www/bang-lab/releases/release-001
  ln -s /var/www/bang-lab/releases/release-001 /var/www/bang-lab/.manual-rollback
  mv -Tf /var/www/bang-lab/.manual-rollback /var/www/bang-lab/current
'
```

릴리스는 자동 삭제하지 않는다. 실패한 전송 디렉토리도 남을 수 있으므로 용량을 점검하고,
현재·복구용 릴리스를 보존하며 나머지를 정리한다. 최초 `root` 소유 릴리스 정리에는 관리자 권한이 필요하다.
이전 릴리스 보관은 이미 열린 브라우저가 요청하는 이전 해시 자산의 제공을 보장하지 않는다.
클라이언트 자산이 늘어나면 공유 자산 보관 여부를 별도로 검토한다.

로컬 검증 통과를 실제 GitHub Actions·서버 배포 성공으로 표현하지 않는다.
