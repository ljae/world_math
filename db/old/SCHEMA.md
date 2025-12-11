# 표준화된 JSON 스키마 (v2.0)

모든 문제 JSON 파일은 다음 스키마를 따라야 합니다.

## 최상위 구조

```json
{
  "problem_id": "string (p_YYYYMMDD 형식)",
  "id": "string (problem_id와 동일)",
  "date": "YYYY-MM-DD",
  "day_of_week": "string",
  "title": "string",
  "problem": { ... },
  "solution": { ... },
  "economic_insight": { ... },
  "news_reference": { ... },
  "metadata": { ... },
  "created_at": "ISO8601",
  "final_status": "approved"
}
```

## problem 구조

```json
"problem": {
  "scenario_text": "string (markdown과 LaTeX 지원, LaTeX는 반드시 $...$ 또는 $$...$$ 로 감싸야 함)",
  "questions": [
    {
      "number": 1,
      "question": "string (markdown/LaTeX 지원)",
      "choices": ["① ...", "② ...", ...],
      "correct_answer": "string (선택지 번호와 내용 포함, 예: '③ 22년' 또는 숫자만 '3')",
      "answer_value": number|null
    }
  ]
}
```

### 규칙
- `scenario_text`: Markdown 형식 사용, 수식은 LaTeX로 작성하되 반드시 `$...$` 또는 `$$...$$`로 감싸야 함
- `questions`: 배열 형태로 하나 이상의 질문 포함
- `correct_answer`: 선택지 기호와 답안 내용을 함께 표시 (예: "③ 22년")
- `answer_value`: 수치형 답안일 경우 숫자로, 그 외는 null

## solution 구조 (표준형)

모든 solution은 다음 표준 구조를 사용해야 합니다:

```json
"solution": {
  "approach": "string (선택사항: 전체 접근 방법 설명)",
  "steps": [
    {
      "step": 1,
      "title": "string (단계 제목)",
      "calculation": "string (LaTeX로 작성, $...$ 또는 $$...$$ 사용)",
      "explanation": "string (선택사항: 단계 설명)",
      "note": "string (선택사항: 추가 참고사항)"
    }
  ],
  "verification": {
    "description": "string (검증 방법 설명)",
    "check_values": "object (선택사항: 검증에 사용된 값들)"
  },
  "answer": "string (최종 답안, correct_answer와 일치해야 함)"
}
```

### LaTeX 사용 규칙
- **인라인 수식**: `$...$` 사용
- **블록 수식**: `$$...$$` 사용
- **텍스트 포함**: `\\text{...}` 사용
- **줄바꿈**: `\\n` 또는 실제 줄바꿈 문자 사용
- **예시**:
  ```
  "$y(1.5) = -0.8(1.5)^2 + 8(1.5) + 30 = 40.2$ 억 원"
  ```

### 특수한 경우의 solution 구조

#### 1. 케이스별 비교 문제 (예: p_20251118)
여러 케이스를 비교하는 문제의 경우:

```json
"solution": {
  "approach": "string",
  "case_a": {
    "period": "string",
    "steps": [
      {
        "step": 1,
        "title": "string",
        "calculation": "string"
      }
    ],
    "result": "number or string"
  },
  "case_b": {
    "period": "string",
    "steps": [ ... ],
    "result": "number or string"
  },
  "final_calculation": {
    "step": "number",
    "title": "string",
    "calculation": "string"
  },
  "answer": "string"
}
```

#### 2. 복잡한 도출 과정 문제 (예: p_20251202, p_20251208)
수학적 도출이 복잡한 경우:

```json
"solution": {
  "title": "string (선택사항)",
  "derivation": [
    {
      "step": "string (단계 제목)",
      "details": [
        {
          "sub_step": 1,
          "description": "string",
          "equation": "string (LaTeX)",
          "equation2": "string (선택사항: 추가 방정식)"
        }
      ]
    }
  ],
  "final_answer": {
    "key": "value (최종 답안 정보)"
  }
}
```

#### 3. 다단계 검증 문제 (예: p_20251203)
여러 조건을 검증하는 문제:

```json
"solution": {
  "step1": {
    "title": "string",
    "equation": "string",
    "process": ["string (단계별 과정)"],
    "conclusion": "string"
  },
  "step2": { ... },
  "final_answer": "string"
}
```

### 중요 원칙
1. **모든 수식은 LaTeX로 작성하고 반드시 `$...$` 또는 `$$...$$`로 감싸야 함**
2. **steps 배열의 각 항목은 논리적 순서를 따라야 함**
3. **verification 섹션으로 답안의 정확성을 검증해야 함**
4. **answer 필드는 problem.questions[0].correct_answer와 일치해야 함**

## economic_insight 구조 (표준형)

```json
"economic_insight": {
  "title": "string (인사이트 제목)",
  "main_point": "string (핵심 요약, 200자 이내)",
  "key_insights": [
    "string (markdown 지원, 각 항목은 구체적 데이터나 분석 포함)"
  ],
  "reality_check": "string (선택사항: 현실 적용 가능성이나 한계점)"
}
```

### 변형 구조

일부 문제에서는 다음 필드명 변형이 허용됩니다:
- `key_points` 또는 `key_findings` → `key_insights`로 통일 권장
- `investment_lesson` → `reality_check`와 유사한 용도

### 작성 규칙
1. **title**: 경제적 현상이나 교훈을 명확히 표현
2. **main_point**: 문제에서 도출된 가장 중요한 경제적 통찰 요약
3. **key_insights**:
   - 배열 형태로 여러 인사이트 나열
   - 각 항목은 **Bold** 제목 + 내용 형식 권장
   - 구체적 수치나 비율 포함
   - Markdown 형식 적극 활용
4. **reality_check**: 실제 경제 상황 적용 시 고려사항이나 한계점

## news_reference 구조

### 표준 구조 (단일 출처)

대부분의 문제는 이 형식을 사용합니다:

```json
"news_reference": {
  "title": "string (뉴스 기사 제목)",
  "theme": "string (선택사항: 주요 테마 요약)",
  "url": "string (유효한 URL)"
}
```

### 확장 구조 (다중 출처)

여러 출처가 필요한 경우:

```json
"news_reference": {
  "primary_source": {
    "title": "string",
    "url": "string",
    "date": "YYYY-MM-DD (선택사항)",
    "description": "string (선택사항)"
  },
  "additional_sources": [
    {
      "title": "string",
      "url": "string"
    }
  ],
  "stock_data_source": {
    "title": "string (선택사항)",
    "url": "string (선택사항)"
  }
}
```

### 작성 규칙
1. **단일 출처 문제**: 표준 구조 사용
2. **다중 출처 문제**: 확장 구조 사용
3. **URL 검증**: 모든 URL은 실제 접근 가능해야 함
4. **theme**: 뉴스의 핵심 내용을 50자 이내로 요약

## metadata 구조

```json
"metadata": {
  "topic": "string (수학 주제)",
  "grade_level": "string (학년)",
  "difficulty": "string (난이도: 상/중/하)",
  "economic_theme": "string (경제 테마)",
  "estimated_solving_time": "string (예상 풀이 시간)",
  "target_accuracy": "string (목표 정답률)",
  "target_audience": "string (대상 독자)",
  "csat_classification": {
    "subject": "string",
    "chapter": "string",
    "section": "string",
    "difficulty_tier": "string",
    "question_type": "string",
    "skill_required": ["string"]
  },
  "updated_at": "ISO8601",
  "standardized": true
}
```

## LaTeX 및 Markdown 사용 규칙

### LaTeX 필수 규칙
- **인라인 수식**: `$...$` 사용 (예: `$x^2 + y^2$`)
- **블록 수식**: `$$...$$` 사용
- **텍스트 포함**: `\\text{...}` 사용 (예: `$10 \\text{ km/L}$`)
- **분수**: `\\frac{a}{b}`
- **극한**: `\\lim_{x \\to 0}`
- **그리스 문자**: `\\theta`, `\\pi` 등
- **특수문자 이스케이프**: `^`, `_`, `{`, `}` 등은 LaTeX 내에서 사용

### Markdown 규칙
- **굵은 글씨**: `**텍스트**`
- **기울임**: `*텍스트*`
- **목록**: `- 항목` 또는 `1. 항목`
- **제목**: `# 제목`, `## 부제목` 등
- **코드 블록**: \`\`\`...\`\`\`

### 결합 예시
```markdown
**[모델 A: 가솔린 2.5 베이직]**
- 차량 가격: 3,768만원
- 평균 연비: $10 \\text{ km/L}$
- 연간 유류비: $300$ 만원

**계산식:**

$$
C(n) = 37,680,000 + 3,000,000n
$$

여기서 $n$은 경과 년수입니다.
```

### 중요 주의사항
1. **모든 수식은 반드시 `$...$` 또는 `$$...$$`로 감싸야 함**
2. **JSON 내 백슬래시는 이중 백슬래시 `\\`로 이스케이프**
3. **줄바꿈은 `\\n` 또는 실제 줄바꿈 문자 사용**
4. **LaTeX 내 텍스트는 `\\text{}`로 감싸기**

## 표준화 체크리스트

문제 JSON을 작성/수정할 때 다음을 확인하세요:

### 필수 항목
- [ ] `problem_id`와 `id`가 일치하고 `p_YYYYMMDD` 형식
- [ ] `date`가 `YYYY-MM-DD` 형식
- [ ] `day_of_week`가 한글로 작성됨 (예: "월요일")
- [ ] `problem.scenario_text`가 명확히 작성되고 LaTeX 수식이 올바르게 감싸짐
- [ ] `problem.questions`가 배열이며 최소 1개 이상
- [ ] `problem.questions[].correct_answer`가 명확히 표시됨
- [ ] `solution.steps`가 논리적 순서로 작성됨
- [ ] `solution.answer`가 `correct_answer`와 일치
- [ ] 모든 LaTeX 수식이 `$...$` 또는 `$$...$$`로 감싸짐
- [ ] Markdown 형식이 일관되게 사용됨
- [ ] `economic_insight.key_insights`가 배열 형태
- [ ] `news_reference.url`이 유효한 URL
- [ ] `metadata.standardized`가 `true`로 설정됨
- [ ] `metadata.updated_at`이 ISO8601 형식
- [ ] `final_status`가 "approved"

### 권장 항목
- [ ] `solution.verification`으로 답안 검증
- [ ] `economic_insight.reality_check`로 실용성 평가
- [ ] `metadata.csat_classification`에 상세 분류 정보 포함
- [ ] 모든 수치에 단위 명시
- [ ] 계산 과정의 중간 결과 표시

## 변경 이력

### v2.0 (2025-12-07)
- LaTeX 사용 규칙 명확화 및 필수화
- solution 구조 다양화 및 특수 케이스 문서화
- economic_insight 필드명 표준화 (key_insights 통일)
- correct_answer 형식 명확화
- news_reference 단순/확장 구조 구분
- 표준화 체크리스트 세분화

### v1.0 (초기 버전)
- 기본 스키마 정의
