"""App Store 스크린샷 합성 (Codex 아트디렉션: 청록 그라디언트·그레인, 두 겹 그림자, 하단 블리드).

창 캡처 원본(2200×1376)에 `scripts/store-screenshots.json`의 카피를 얹어 2880×1800으로 만든다.
결과는 fastlane deliver가 그대로 올리는 `fastlane/screenshots/{ko,en-US}/NN.png`다.

  python3 scripts/store-compose.py                          6장면 전부
  python3 scripts/store-compose.py store-summary store-xcode 고른 장면만 (나머지 파일은 그대로)
  --captures DIR  캡처 폴더 (기본 .build/store-captures, 아래에 ko/ en/)
  --out DIR       출력 폴더 (기본 fastlane/screenshots)
  --sheet FILE    확인용 컨택트 시트 (기본 .build/store-sheet.png — deliver가 올리지 않게 출력 폴더 밖)
"""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageCms
ROOT=Path(__file__).resolve().parent.parent
CAPTURES=ROOT/'.build/store-captures'
OUT=ROOT/'fastlane/screenshots'
W,H=2880,1800
FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
IVORY=(242,245,243)
COPY=json.loads((ROOT/'scripts/store-screenshots.json').read_text())
checks=[]
def font(size,bold=False): return ImageFont.truetype(FONT,size,index=6 if bold else 0)
def background(kind):
 y,x=np.mgrid[0:H,0:W].astype(np.float32); x/=W; y/=H
 if kind==1:
  glow=np.exp(-(((x-.36)/.65)**2+((y-.32)/.8)**2)*2)
  base=np.array([5,29,31]); tint=np.array([11,47,44])
 else:
  glow=np.exp(-(((x-.22)/.8)**2+((y-.60)/.9)**2)*2)
  base=np.array([4,26,29]); tint=np.array([11,57,52])
 a=base+glow[:,:,None]*tint
 rng=np.random.default_rng(95)
 grain=rng.normal(0,.65,(H,W,1))
 dither=((np.indices((H,W)).sum(axis=0)%2)*2-1)[:,:,None]*.24
 return Image.fromarray(np.uint8(np.clip(a+grain+dither,0,255)),'RGB').convert('RGBA')
def latin_font(size,bold):
 f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',size)
 f.set_variation_by_name(b'Bold' if bold else b'Regular')
 return f

def runs(text):
 result=[]
 for c in text:
  korean=not c.isascii()
  if result and result[-1][0]==korean: result[-1][1]+=c
  else: result.append([korean,c])
 return result

def layout(text,size,bold,tracking=0):
 # SF's lowercase height at this size closely matches Neo's Latin metrics;
 # all runs share a baseline, including punctuation and descenders.
 fs={True:font(size,bold),False:latin_font(size,bold)}
 result=[]; x=0
 for korean,run in runs(text):
  f=fs[korean]
  for i,c in enumerate(run):
   kern=(f.getlength(run[:i+1])-f.getlength(run[:i])-f.getlength(c)) if i else 0
   x+=kern
   result.append((c,f,x))
   x+=f.getlength(c)+tracking
 return result,x-tracking

def text_tracked(im,text,xy,size,bold,fill=IVORY,tracking=0):
 glyphs,width=layout(text,size,bold,tracking)
 x,y=xy
 assert x+width<=W-180,(text,width)
 # Align the visible Hangul top to y while retaining the actual baseline.
 baseline=y-font(size,bold).getbbox('가',anchor='ls')[1]
 mask=Image.new('L',(W,H)); md=ImageDraw.Draw(mask)
 for c,f,dx in glyphs: md.text((x+dx,baseline),c,font=f,fill=255,anchor='ls')
 bbox=mask.getbbox(); assert bbox and bbox[2]<=W-180
 checks.append({'text':text,'bbox':bbox,'size':size})
 im.paste(fill,(0,0,W,H),mask)

ICC=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
def save(im,path):
 path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
 im.save(path,icc_profile=ICC)

HEADLINE_SIZE=next(size for size in range(140,79,-1)
 if all(layout(c[lang]['headline'],size,True,-3.3)[1]<=W-400
 for c in COPY for lang in ('ko','en')))

def product(im,source,width,xy,refined=False):
 src=Image.open(source).convert('RGBA'); src=src.resize((width,round(src.height*width/src.width)),Image.Resampling.LANCZOS)
 x,y=xy
 # Two photographic shadows: ambient spread and close contact.
 for blur,offset,opacity in [(78,(24,58),105),(17,(4,12),100)]:
  m=Image.new('L',(W,H)); m.paste(src.getchannel('A'),(x+offset[0],y+offset[1])); m=m.filter(ImageFilter.GaussianBlur(blur))
  m=m.point(lambda p:round(p*opacity/255)); im.alpha_composite(Image.new('RGBA',(W,H),(0,9,12,0)))
  shade=Image.new('RGBA',(W,H),(0,8,10,255)); shade.putalpha(m); im.alpha_composite(shade)
 im.alpha_composite(src,xy)
 d=ImageDraw.Draw(im)
 # A single restrained bevel catches the light along the existing window edge.
 d.line((x+32,y+1,x+width-32,y+1),fill=(243,249,242,210 if refined else 130),width=1)
 if refined: d.line((x+1,y+33,x+1,min(H,y+src.height-30)),fill=(225,242,234,120),width=1)
def render(name,lang,stage,variant):
 c=next(v[lang] for v in COPY if v['stage']==stage)
 im=background(1 if variant==1 else 2)
 if variant==1:
  text_tracked(im,c['headline'],(340,88),130,True,tracking=-3)
  text_tracked(im,c['subhead'],(344,244),52,False,fill=(189,211,205))
  product(im,CAPTURES/lang/f'{stage}.png',2200,(340,350))
 else:
  # The only quotation outside the product: one small titlebar-like material swatch.
  d=ImageDraw.Draw(im)
  if variant==2:
   d.rectangle((222,100,298,108),fill=(145,173,165))
  else:
   d.rectangle((222,102,298,110),fill=(178,197,182))
   d.line((222,102,298,102),fill=(233,241,221),width=1)
  text_tracked(im,c['headline'],(220,160 if variant==2 else 158),HEADLINE_SIZE,True,tracking=-3.3)
  text_tracked(im,c['subhead'],(225,332 if variant==2 else 330),54,False,fill=(190,213,206))
  product(im,CAPTURES/lang/f'{stage}.png',2500 if variant==2 else 2440,(220,508 if variant==2 else 490),variant==3)
 save(im.convert('RGB'),name)
 return im
# App Store Connect 언어 코드. 캡처 폴더는 앱 언어(ko/en)로, 출력은 스토어 언어로 둔다.
LOCALES={'ko':'ko','en':'en-US'}
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser()
 p.add_argument('stages',nargs='*')
 p.add_argument('--captures',type=Path,default=CAPTURES)
 p.add_argument('--out',type=Path,default=OUT)
 p.add_argument('--sheet',type=Path,default=ROOT/'.build/store-sheet.png')
 a=p.parse_args()
 CAPTURES=a.captures
 order=[item['stage'] for item in COPY]
 unknown=[s for s in a.stages if s not in order]
 if unknown: sys.exit(f"모르는 장면: {' '.join(unknown)} — 가능한 장면: {' '.join(order)}")
 stages=a.stages or order
 # 하나라도 없으면 아무것도 만들지 않는다. 반만 바뀐 세트가 올라가면 안 된다.
 missing=[str(CAPTURES/lang/f'{s}.png') for lang in LOCALES for s in stages if not (CAPTURES/lang/f'{s}.png').is_file()]
 if missing: sys.exit('캡처가 없다:\n  '+'\n  '.join(missing))
 for lang,locale in LOCALES.items():
  (a.out/locale).mkdir(parents=True,exist_ok=True)
  for s in stages:
   render(a.out/locale/f'{order.index(s)+1:02}.png',lang,s,3)
 files=sorted(a.out.glob('*/[0-9][0-9].png'))
 sheet=Image.new('RGB',(2160,480*((len(files)+2)//3)),(15,35,35)); d=ImageDraw.Draw(sheet)
 for i,f in enumerate(files):
  x=(i%3)*720; y=(i//3)*480
  d.text((x+16,y+8),f'{f.parent.name}/{f.name}',font=latin_font(22,False),fill=IVORY)
  sheet.paste(Image.open(f).resize((704,440),Image.Resampling.LANCZOS),(x+8,y+36))
 a.sheet.parent.mkdir(parents=True,exist_ok=True)
 save(sheet,a.sheet)
 print(f'{len(stages)}장면 × {len(LOCALES)}언어 → {a.out}  시트: {a.sheet}')
