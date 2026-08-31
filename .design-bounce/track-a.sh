#!/bin/bash
# 트랙 A — 명세 준수 자동 검증.
set -uo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, glob, sys
src = {f: open(f).read() for f in glob.glob("Sources/SweepApp/*.swift")}
THEME = "Sources/SweepApp/Theme.swift"
theme = src[THEME]
views = {f: s for f, s in src.items() if f != THEME}

bad = 0
def chk(label, ok, detail=""):
    global bad
    bad += not ok
    print(f"  {'✅' if ok else '❌'} {label:44s} {detail}")

# 반투명 틴트 폐지 (Blocker B1)
uses = [f.split('/')[-1] for f, s in views.items() if "selectionTint" in s]
chk("selectionTint 사용처 0건", not uses, str(uses) if uses else "")

# .tertiary 교체 (Blocker B2). .secondary는 통과하므로 그대로 둔다.
t = [f.split('/')[-1] for f, s in views.items() if "foregroundStyle(.tertiary)" in s]
chk(".tertiary → textTertiary 교체", not t, str(t) if t else "")

# 표면 토큰이 다크·라이트 양쪽 값을 갖는가
for tok in ["surface", "surfaceSunken", "surfaceRaised", "border"]:
    m = re.search(rf'static let {tok} = adaptive\(dark: (0x[0-9A-Fa-f]+), light: (0x[0-9A-Fa-f]+)\)', theme)
    chk(f"표면 토큰 {tok}", bool(m), f"{m.group(1)}/{m.group(2)}" if m else "없음")

# 뷰에는 리터럴 폰트 크기가 없어야 한다 (Theme.Icon.* 참조는 허용)
lit = {}
for f, s in views.items():
    hits = re.findall(r'\.system\(size:\s*(\d+)', s)
    if hits: lit[f.split('/')[-1]] = sorted(set(map(int, hits)))
chk("뷰에 리터럴 폰트 크기 0건", not lit, str(lit) if lit else "전부 토큰 참조")

# 서체 단계 수
steps = sorted({int(m) for m in re.findall(r'Font\.system\(size: (\d+)', theme)})
chk("서체 단계 6종 이하", len(steps) <= 6, f"{steps} ({len(steps)}종)")

# 간격만 8px 그리드로 본다. radius는 별도 표준(버튼 4~6 / 카드 8~12).
nums = {k: float(v) for k, v in re.findall(r'static let (\w+): CGFloat = ([\d.]+)', theme)}
RADIUS = {"rowCornerRadius", "cardRadius"}
spacing = {k: v for k, v in nums.items() if k not in RADIUS and "width" not in k.lower() and "height" not in k.lower()}
off = {k: v for k, v in spacing.items() if v % 4 != 0}
chk("간격 상수 4의 배수", not off, str(off) if off else str(sorted(spacing.values())))

chk("버튼 radius 4~6", 4 <= nums.get("rowCornerRadius", 0) <= 6, f"{nums.get('rowCornerRadius')}")
chk("카드 radius 8~12", 8 <= nums.get("cardRadius", 0) <= 12, f"{nums.get('cardRadius')}")

# 뷰의 radius 종류 (위험 바 1.5는 예외)
radii = sorted({float(v) for v in re.findall(r'cornerRadius: ([\d.]+)', "\n".join(views.values()))})
chk("뷰 radius 종류", set(radii) <= {1.0, 1.5}, f"{radii} (나머지는 Theme 참조)")

# 버튼 5상태
btn = theme[theme.index("struct PrimaryButtonStyle"):]
for st, tok in [("disabled", "isEnabled"), ("hover", "isHovering"),
                ("active", "isPressed"), ("transition", "Theme.transition")]:
    chk(f"PrimaryButtonStyle {st}", tok in btn)
chk("버튼 Capsule 폐지", "in: Capsule()" not in theme)

print()
print("트랙 A:", "✅ 전부 통과" if bad == 0 else f"❌ {bad}건 미달")
sys.exit(1 if bad else 0)
PY
