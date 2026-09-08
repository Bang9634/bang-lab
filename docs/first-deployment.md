# Ubuntu 최초 수동 배포

새 Ubuntu 서버 한 대에 bang-lab을 처음 배포하는 절차이다.
실제 서버에서 실행한 기록이 아니라, 현재 저장소 구조에 맞춘 실행 안내이다.
기존 웹사이트가 운영 중인 서버라면 도메인·포트·설정 충돌을 먼저 확인한다.

예시의 `SERVER_IP`, `example.com`, `~/.ssh/your-key`를 실제 값으로 바꾼다.
SSH 사용자는 `ubuntu`로 가정한다. 이미지에 따라 다르면 실제 계정을 사용한다.
Mac과 서버의 터미널을 각각 하나씩 열어두면 실행 위치를 구분하기 쉽다.

## 1. 서버 SSH 접속 — Mac

클라우드 콘솔에서 공인 IPv4와 SSH 키를 확인한다.
도메인을 연결할 IP는 변경되지 않도록 고정/예약 공인 IP를 사용하는 편이 좋다.

```sh
chmod 600 ~/.ssh/your-key
ssh -i ~/.ssh/your-key ubuntu@SERVER_IP
```

처음 표시되는 호스트 키는 서버 콘솔 등 신뢰할 수 있는 경로의 지문과 비교한다.
SSH 개인 키는 서버나 GitHub 저장소에 업로드하지 않는다.

## 2. 도메인 DNS — DNS 관리 화면

실제 권한 있는 네임서버를 관리하는 업체에서 레코드를 추가한다.
구매처 네임서버를 그대로 사용 중이면 보통 구매처 DNS 관리 화면에서 설정한다.
URL 포워딩이 아니라 DNS 레코드를 설정한다.

| 유형 | 이름/호스트 | 값 |
| --- | --- | --- |
| A | `@` 또는 빈칸 | 서버의 공인 IPv4 |
| CNAME | `www` | `example.com` |

같은 이름의 기존 주차/포워딩용 A 또는 CNAME 레코드는 충돌하지 않도록 정리한다.
메일용 MX/TXT 등 다른 목적의 레코드는 건드리지 않는다.
IPv6를 구성하지 않았다면 해당 웹 도메인에 잘못된 AAAA 레코드가 남지 않도록 확인한다.
`www`를 사용할 생각이 없으면 해당 레코드와 이후 Nginx/Certbot 명령의 www 도메인을 함께 생략한다.

Mac에서 전파 상태를 확인한다.

```sh
dig +short A example.com
dig +short A www.example.com
dig +short AAAA example.com
```

A 조회 결과가 서버 IP여야 한다. 반영 시간은 이전 레코드의 TTL과 DNS 캐시에 따라 다르다.

## 3. 방화벽 — 클라우드 콘솔과 서버

Oracle Cloud라면 인스턴스가 속한 서브넷 Security List 또는 VNIC에 적용된 NSG에
TCP 인바운드 규칙을 추가한다. Source port는 전체, Destination port는 아래 값이다.

| 목적 | 대상 포트 | 소스 |
| --- | --- | --- |
| SSH | 22 | 가능하면 현재 접속하는 내 공인 IP `/32` |
| HTTP | 80 | `0.0.0.0/0` |
| HTTPS | 443 | `0.0.0.0/0` |

공인 IP, 공용 서브넷과 Internet Gateway를 향한 라우팅도 필요하다.
4321 같은 개발 서버 포트를 인터넷에 열 필요는 없다.
IPv6를 서비스할 경우 IPv6 라우팅과 방화벽도 따로 구성한다.

서버의 UFW 상태를 확인한다.

```sh
sudo ufw status verbose
```

UFW가 active이고 SSH가 기본 22 포트라면 아래 규칙을 추가한다.

```sh
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

이미 클라우드 이미지의 iptables/nftables 규칙을 사용 중이면 UFW가 inactive여도
별도 차단 규칙이 있을 수 있다. 방화벽 전체 초기화나 무조건적인 UFW 활성화는 하지 않는다.
SSH 포트를 바꿨다면 22 대신 실제 포트를 먼저 허용하고 기존 SSH 연결을 유지한다.

## 4. Nginx 설치 — 서버

```sh
sudo apt update
sudo apt install -y nginx snapd
sudo systemctl enable --now nginx
```

서버에서 기본 응답을 확인한다.

```sh
curl -I http://127.0.0.1/
```

## 5. 빌드 및 전송 — Mac의 저장소 루트

`apps/web/src/config/profile.ts`의 공개할 이름·이메일을 확인하고 빌드한다.
현재 설치된 의존성이 없다면 먼저 `npm ci`를 실행한다.

```sh
npm run check
npm run build
scp -i ~/.ssh/your-key -r apps/web/dist ubuntu@SERVER_IP:~/bang-lab-dist
scp -i ~/.ssh/your-key infra/nginx/bang-lab.conf ubuntu@SERVER_IP:~/bang-lab.conf
```

위 전송 경로는 첫 배포에서 아직 존재하지 않는다고 가정한다.
서버에 `.env`, `node_modules`, 소스 저장소 전체를 보내지 않는다.
Mac에서 만든 정적 HTML/CSS/JS는 Ubuntu CPU 아키텍처와 관계없이 서비스할 수 있다.

## 6. 릴리스와 Nginx 설정 — 서버

아래는 `release-001`과 `current`가 아직 없는 최초 설치 명령이다.

```sh
sudo install -d -m 755 /var/www/bang-lab/releases/release-001
sudo cp -R ~/bang-lab-dist/. /var/www/bang-lab/releases/release-001/
sudo chmod -R u=rwX,go=rX /var/www/bang-lab/releases/release-001
sudo ln -s /var/www/bang-lab/releases/release-001 /var/www/bang-lab/current
sudo install -m 644 ~/bang-lab.conf /etc/nginx/sites-available/bang-lab
sudo nano /etc/nginx/sites-available/bang-lab
```

설정 안의 도메인을 수정한다. root는 위 명령의 경로와 이미 일치한다.

```nginx
server_name example.com www.example.com;
root /var/www/bang-lab/current;
```

설정을 활성화하고 검사한다.

```sh
sudo ln -s /etc/nginx/sites-available/bang-lab /etc/nginx/sites-enabled/bang-lab
sudo nginx -t
```

검사가 성공한 경우에만 적용한다.

```sh
sudo systemctl reload nginx
```

Mac 브라우저에서 `http://example.com`과 `http://www.example.com`으로 사이트를 확인한다.
서버 IP로 접속하면 기본 Nginx 사이트가 나타날 수 있으므로 도메인으로 확인한다.
인증서 발급 전에 두 도메인 모두 외부 인터넷에서 HTTP로 접속돼야 한다.

## 7. HTTPS 발급과 갱신 확인 — 서버

기존 Certbot이 없는 새 서버 기준이다. apt 등으로 설치된 Certbot이 있다면 설치 방식을
확인하고 한 방식으로 통일한다. 아래에서는 Snap 버전의 절대 경로를 사용한다.

```sh
sudo snap install --classic certbot
sudo /snap/bin/certbot --nginx --redirect -d example.com -d www.example.com
```

대화형 안내에 따라 실제 연락용 이메일과 이용 조건을 확인한다.
Certbot이 Nginx 도메인 설정에 인증서를 연결하고 HTTP를 HTTPS로 전환한다.

```sh
sudo nginx -t
sudo /snap/bin/certbot renew --dry-run
systemctl list-timers --all | grep certbot
```

갱신 시험이 성공하고 갱신 타이머가 등록돼 있는지 확인한다.
도메인과 80/443 접근을 유지한다. Certbot이 수정한 설정을 초기 HTTP 템플릿으로 덮어쓰지 않는다.

## 8. 외부에서 최종 확인 — Mac

```sh
curl -I http://example.com
curl -I https://example.com
curl -I https://example.com/does-not-exist
```

- HTTP가 HTTPS로 리다이렉트되는지 확인한다.
- HTTPS 홈은 200, 없는 주소는 404여야 한다.
- 브라우저에 인증서 오류가 없어야 한다.
- 휴대폰에서 메뉴, 스크롤, 타이핑과 연락처 링크를 확인한다.
- 서버 로그의 수집 항목과 보관 정책을 확인한다.

## 이후 수정 배포

새 빌드를 새로운 임시 업로드 디렉토리에 전송하고 `release-002`처럼 새 릴리스를 만든다.
이전 릴리스는 보존하고, 파일 배치와 읽기 권한을 검증한 후 링크를 전환한다.
아래는 새 릴리스가 준비됐고 `current.next`가 없을 때 서버에서 실행한다.

```sh
sudo ln -s /var/www/bang-lab/releases/release-002 /var/www/bang-lab/current.next
sudo mv -Tf /var/www/bang-lab/current.next /var/www/bang-lab/current
```

HTML/CSS/JS만 갱신할 때 Nginx 재시작은 필요하지 않다.
롤백도 이전 릴리스로 같은 방식의 링크 전환을 수행한다.
열어둔 이전 페이지가 이전 해시 자산을 요청할 수 있으므로 서비스가 커지면
이전 자산 보존 전략도 추가한다. 자동 배포는 수동 첫 배포를 확인한 뒤 연결한다.

## 접속이 안 될 때

- `dig`가 다른 IP를 반환: DNS 레코드와 실제 네임서버를 확인한다.
- 외부 요청이 timeout: 클라우드 인바운드 규칙, 라우팅, OS 방화벽을 확인한다.
- Nginx 기본 화면: `server_name`, DNS, 사이트 활성화와 reload 여부를 확인한다.
- 403: root 경로, `index.html` 존재 여부, 상위 디렉토리와 파일 읽기 권한을 확인한다.
- 인증서 발급 실패: 두 도메인의 A/AAAA와 외부 HTTP 접근부터 확인한다.

```sh
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 50 /var/log/nginx/error.log
```

## 공식 참고 자료

- [Ubuntu Nginx 설치](https://ubuntu.com/tutorials/install-and-configure-nginx)
- [Oracle Cloud Security Lists](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm)
- [Certbot Nginx/Snap 안내](https://certbot.eff.org/instructions?os=snap&ws=nginx)
- [Ubuntu TLS 인증서 안내](https://ubuntu.com/server/docs/how-to/security/obtain-tls-certificates/)
