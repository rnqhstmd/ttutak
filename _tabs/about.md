---
icon: fas fa-info-circle
order: 4
---

## ttutak 뚝딱

"개발해줘" 한마디면 PRD, 설계, 구현, 리뷰, 테스트, PR까지 뚝딱.

말하면 만들어주는 Claude Code 개발 자동화 플러그인입니다.

### 설치

```bash
/plugin marketplace add rnqhstmd/ttutak
/plugin install ttutak@ttutak
/ttutak:setup
```

---

### 스킬 목록 (v1.2.0)

| 스킬 | 한마디 설명 | 트리거 예시 |
|------|-----------|------------|
| **dev** | PRD부터 PR까지 전체 개발 사이클 | "로그인 기능 개발해줘" |
| **context** | 도메인 지식 등록/관리 | "context 만들어줘" |
| **lens** | 비즈니스 정책 분석 (읽기 전용) | "결제 정책 확인해줘" |
| **tech-debt** | 기술 부채 분석 (읽기 전용) | "기술 부채 분석해줘" |
| **test** | 단위/통합/E2E 테스트 작성 | "테스트 작성해줘" |
| **commit** | 한국어 커밋 메시지 자동 생성 | "커밋해줘" |
| **pull-request** | PR 제목/본문 자동 생성 | "PR 올려줘" |
| **humanizer** | AI 글쓰기 패턴 감지/교정 | "AI 흔적 교정해줘" |
| **research** | 웹 검색 기반 도메인 리서치 | "OAuth 조사해줘" |
| **setup** | 플러그인 초기 설정 | `/ttutak:setup` |

---

### dev 파이프라인

```
"개발해줘" 한마디로 아래 전체가 실행됩니다:

1. setup        — 프로젝트 분석, 코드 맵 생성
2. requirements — PO 에이전트가 PRD 작성 → 사용자 확인
3. design       — 설계자가 기술 설계 → 비판 검토 → 사용자 확인
4. implement    — 개발자가 구현 → 자기점검 → 테스트 작성
5. review       — QA + 보안 감사자가 코드와 테스트를 함께 리뷰
6. complete     — 인수 검증 → 커밋 → PR 생성
```

각 단계 사이에 사용자 승인이 필요합니다. 승인 없이 다음으로 넘어가지 않습니다.

---

### 분석 스킬 비교

| 질문 | 스킬 | 대상 |
|------|------|------|
| "이 정책 바꾸면 어디 영향?" | **lens** | PO/PD |
| "코드 어디가 아프고 뭘 먼저 고쳐?" | **tech-debt** | 개발자/테크리드 |

**lens**는 비즈니스 정책을 코드에서 찾아 비기술자가 읽을 수 있는 보고서로 번역합니다.
**tech-debt**는 코드 복잡도, 아키텍처 위반, 오래된 의존성, 테스트 부족을 진단하고 Health Score(A~F)와 우선순위 로드맵을 제공합니다.

둘 다 읽기 전용이며 코드를 수정하지 않습니다.

---

### 자주 쓰는 조합

| 상황 | 명령 |
|------|------|
| 새 프로젝트 투입 | `/context` → `/tech-debt` → `/lens 핵심 정책` |
| 기능 개발 | `/dev 기능 설명` |
| 빠른 버그 수정 | `/dev 버그 설명` → hotfix 선택 |
| 리팩토링 전 | `/tech-debt` → 우선순위 확인 → `/dev 리팩토링` |
| 의존성 점검 | `/tech-debt --type deps` |
| 커밋 + PR | "커밋하고 PR 올려줘" |

---

### 안전장치

- PR 생성까지만 자동화합니다. PR 머지는 사용자가 직접 수행합니다.
- `git push --force`, `gh pr merge`는 설정 수준에서 차단됩니다.
- 보호 브랜치(main)에서 직접 커밋을 차단합니다.
- 커밋 전 민감 파일 감지 시 경고합니다.

---

### 링크

- [GitHub](https://github.com/rnqhstmd/ttutak)
- [CHANGELOG](https://github.com/rnqhstmd/ttutak/blob/main/CHANGELOG.md)
