# 탁상 AI 스터디 매니저

> 스마트폰을 뒤집어 공부에 집중하고, AI가 공부 패턴을 분석해주는 데스크탑 학습 보조 앱

---

## 앱 주요 기능

### AI 플래너 탭
- **AI 채팅 인터페이스**: 자연어로 오늘의 할 일을 입력하면 AI가 과목별 체크리스트로 정리
    - OpenRouter API 스트리밍 응답 지원 (SSE)
    - 로컬 Hermes Agent 서버도 백엔드로 활용 가능
- **음성 입력**: 한국어 음성 인식으로 손쉽게 할 일 입력 (speech_to_text)
- **체크리스트 추출**: AI 응답에서 과목별 항목을 파싱하여 "체크리스트에 추가" 버튼 제공
- **세션 관리**: 날짜별 대화 히스토리 저장/조회/삭제
- **마크다운 렌더링**: AI 응답을 마크다운 형식으로 표시

### 오늘 탭
- **주간 날짜 바**: 월~일 7일 표시, 이전/다음 주 이동, 오늘 날짜 점 표시
- **체크리스트 관리**
    - 카테고리 > 과목 순서로 선택하여 항목 추가/편집/삭제/순서 변경
    - 완료 체크박스로 달성 여부 관리
- **공부 모드 상태 머신**
    - `idle` → `waiting` (스마트폰 뒤집기 감지) → `active` → `paused` (스마트폰 들어올리기)
    - 가속도계 Z축 센서 폴링으로 뒤집기/ 들어올리기 감지
    - 30초 유예 시간 후 패널티 부여
- **전화 수신 처리**: 공부 중 전화 수신 시 세션 자동 종료
- **포그라운드 서비스**: Android 알림으로 공부 과목 및 경과 시간 표시
- **공부 기록 카드**: 세션별 과목, 시간, 시작 시각, 패널티 표시 (로컬/RPi 구분)

### 통계 탭
- **과목별 도넛 차트**: 공부 시간 분포를 원형 그래프로 시각화
- **집중 점수**: 세션 수, 핸드폰 든 횟수, 패널티, 총 공부 시간 기반 산출 (30분 이상일 때 활성화)
    - 등급: 우수/양호/보통/주의/위험
- **AI 브리핑**: 하루 공부 패턴을 AI가 3줄 요약 (로컬 캐시 + 백그라운드 갱신)
- **요약 타일**: 공부 세션 수, 핸드폰 든 횟수, 패널티 수 표시 (로컬/RPi 분리 표시)
- **접이식 월간 캘린더**: 월별 이동, 체크리스트 존재 날짜 표시

### 설정 탭
- **카테고리/과목 관리**: 카테고리 CRUD, 과목 추가/편집/삭제, 8가지 프리셋 색상
- **테마 설정**: 시스템/라이트/다크 모드 지원
- **기기 ID 관리**: 3자리 기기 번호 (000-999) 등록, Supabase 중복 확인
- **AI API 설정**
    - OpenRouter API 키 및 모델명 설정 (기본: google/gemini-2.5-flash-preview)
    - Hermes Agent 서버 URL 설정 및 연결 테스트
- **Supabase 클라우드 동기화**: 로컬 ↔ 클라우드 수동 푸시/풀

---

## 클라우드 동기화 (Supabase)

| 기능 | 설명 |
|------|------|
| 기기 식별 | 3자리 기기 번호 (000-999)로 RLS 필터링 |
| 푸시 (로컬 → 클라우드) | 카테고리, 과목, 체크리스트, 세션 개별/일괄 업로드 |
| 풀 (클라우드 → 로컬) | 전체 엔티티 다운로드, 날짜별 온디맨드 조회 |
| 실시간 구독 | Supabase Realtime으로 NFC 상태 업데이트 수신 |
| RPi 세션 병합 | RPi에서 업로드한 세션 데이터(10자리 ID)와 로컬 데이터 통합 |
| NFC 태그 추적 | RPi가 NFC 태그를 기기에 연결하면 앱에서 상태 표시 |

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| 앱 프레임워크 | Flutter (Dart) |
| 상태 관리 | Riverpod |
| 로컬 DB | Drift (SQLite) |
| AI | OpenRouter API, Hermes Agent 서버 |
| 음성 인식 | speech_to_text |
| 키 저장 | SharedPreferences |
| 클라우드 | Supabase (데이터 동기화, 실시간) |
| 센서 | 가속도계 (MethodChannel, 스마트폰 뒤집기 감지) |
| 알림 | flutter_local_notifications, Android Foreground Service |

---

## 프로젝트 구조

```
lib/
├── main.dart
├── database/
│   ├── database.dart              # Drift DB 스키마 (카테고리/과목/세션/체크리스트)
│   └── database.g.dart            # 생성된 코드
├── services/
│   ├── api_key_service.dart       # OpenRouter API 키 로컬 저장
│   ├── briefing_service.dart      # AI 포커스 브리핑 생성/캐시
│   ├── call_state_service.dart    # 전화 수신 상태 스트림
│   ├── study_service.dart         # 포그라운드 서비스/가속도계 제어
│   └── supabase_sync_service.dart # Supabase 클라우드 동기화
├── viewmodels/
│   ├── focus_briefing_view_model.dart  # AI 브리핑 상태 관리
│   ├── study_view_model.dart           # 데이터 CRUD
│   ├── sync_provider.dart              # 동기화 상태 관리
│   └── ui_state.dart                   # 전역 UI 상태
└── views/
    ├── main_screen.dart
    └── tabs/
        ├── ai_tab.dart            # AI 플래너 (채팅)
        ├── today_tab.dart         # 오늘의 체크리스트/공부 모드
        ├── stats_tab.dart         # 통계/브리핑
        └── settings_tab.dart      # 설정
```

---

## API 키 설정

1. [OpenRouter](https://openrouter.ai) 에서 API 키 발급
2. 앱 실행 → 설정 탭 → OpenRouter API 설정에서 키 입력
3. (선택) 로컬 Hermes Agent 서버 URL 설정
