# 공구마켓 (MVP)

구성:
- `index.html`: 구매자 상품 목록/주문 신청 + 판매자 대시보드 UI
- `supabase_setup.sql`: 데이터베이스/권한/주문 원자적 재고 차감 SQL

## 중요한 점
이 웹앱은 아직 DB 설정이 없는 상태입니다. `index.html`의 아래 두 상수를 본인의 Supabase 프로젝트 값으로 바꿔야 여러 기기에서 실제로 공유됩니다.
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (또는 publishable key)

`service_role` 키는 절대 브라우저 HTML에 넣지 마세요.

## 무료 Supabase 설정
1. https://supabase.com 에서 무료 프로젝트를 만듭니다.
2. Project Settings > API에서 Project URL 및 publishable/anon key를 확인합니다.
3. SQL Editor에서 `supabase_setup.sql` 전체를 실행합니다.
4. Authentication > Users에서 판매자 계정을 생성합니다.
5. Database > Replication/Publication 설정에서 `products`, `orders`가 `supabase_realtime`에 포함되어 있는지 확인합니다. SQL은 가능하면 자동 추가합니다.
6. `index.html`에 URL/key를 입력하고 GitHub Pages에 배포합니다.

## 사용
- 구매자: 공개 링크 접속 → 상품 선택 → 이름/전화번호/수량 → 신청. 신청과 동시에 재고가 차감됩니다.
- 판매자: 판매자 관리 탭 → 등록한 이메일/비밀번호 로그인 → 상품 등록/수정/판매 중지 → 주문 확인/상태 변경/CSV 다운로드.
- 주문 취소는 판매자만 가능하며 재고가 자동 복구됩니다.

## 보안/운영 전 확인
- 이 MVP의 SQL은 소규모 단일 판매자/신뢰된 판매자 계정 기준의 기본 예시입니다. 판매자 계정을 여러 명에게 공개하기 전에는 사용자별 상품 소유권 정책(RLS)을 추가해야 합니다.
- 주문자 전화번호는 개인정보입니다. 주문 처리 목적, 보관 기간, 파기 방식 및 개인정보 처리방침을 운영자가 정하고 안내해야 합니다.
- 재고 차감은 DB 함수 내에서 행 잠금을 사용하므로 동시에 신청이 들어와도 재고 초과를 방지합니다.
- Supabase 무료 요금제에는 사용량/일시 중지 등 제한이 있을 수 있습니다. 실제 운영 전 서비스 약관과 한도를 확인하세요.
