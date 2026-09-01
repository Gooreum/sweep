#!/bin/bash
#
# Developer ID Application 인증서를 신청할 CSR을 만든다.
#
# Apple 포털은 CSR(인증서 서명 요청)을 올려야 인증서를 내준다. CSR을 만들려면
# **개인 키가 이 Mac의 키체인에 있어야** 한다 — 나중에 내려받은 `.cer`가 그 키와
# 짝지어져야 `codesign`이 쓸 수 있기 때문이다.
#
# Keychain Access의 인증서 지원 마법사로도 되지만 GUI를 거쳐야 해서,
# 여기서는 같은 일을 명령으로 한다.
#
# 실행: bash scripts/make-csr.sh <이메일> [이름]
#
set -uo pipefail

EMAIL="${1:-}"
NAME="${2:-MINGU SEO}"

if [ -z "$EMAIL" ]; then
  echo "사용법: bash scripts/make-csr.sh <Apple ID 이메일> [이름]"
  echo "  예: bash scripts/make-csr.sh you@example.com \"MINGU SEO\""
  exit 1
fi

OUT="$HOME/Desktop"
CSR="$OUT/SweepDeveloperID.certSigningRequest"
# 개인 키는 키체인에 넣고 파일은 지운다. 디스크에 남기지 않는다.
KEY=$(mktemp -t sweep-devid-key)
trap 'rm -f "$KEY"' EXIT

echo "── 키와 CSR 생성 ──"
openssl req -new -newkey rsa:2048 -nodes \
  -keyout "$KEY" \
  -out "$CSR" \
  -subj "/emailAddress=$EMAIL/CN=$NAME/C=KR" 2>/dev/null || {
    echo "FAIL: CSR 생성 실패"; exit 1
  }
echo "  CSR: $CSR"

echo "── 개인 키를 로그인 키체인에 넣기 ──"
# `-T /usr/bin/codesign`으로 codesign이 이 키를 쓸 수 있게 허용한다.
# 없으면 서명할 때마다 키체인 암호를 묻는다.
if security import "$KEY" \
     -k "$HOME/Library/Keychains/login.keychain-db" \
     -T /usr/bin/codesign -T /usr/bin/security 2>&1 | sed 's/^/  /'; then
  echo "  키체인에 넣음"
else
  echo "FAIL: 키체인 가져오기 실패"
  exit 1
fi

echo
echo "다음 순서:"
echo "  1. developer.apple.com/account/resources/certificates/list 열기"
echo "  2. + 버튼 → Software 목록에서 'Developer ID Application' 선택 → Continue"
echo "  3. Profile Type은 'G2 Sub-CA (Xcode 11 or later)' 그대로 두기"
echo "  4. Choose File 에서 이 파일을 올리기:"
echo "       $CSR"
echo "  5. Continue → Download → 내려받은 .cer 를 더블클릭"
echo
echo "  ※ 팀을 고르라고 하면 LHW4ZX343L (MINGU SEO) 을 고르세요."
echo "     Developer ID는 유료 멤버십 팀에서만 만들 수 있습니다."
