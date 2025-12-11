# Firebase 설정 가이드

Firebase DB에 문제를 업로드하기 위한 인증 설정 방법입니다.

---

## 방법 1: 서비스 계정 키 사용 (권장)

### 1. Firebase Console에서 서비스 계정 키 생성

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택: `real-math-d9ddf`
3. 좌측 메뉴에서 **⚙️ 프로젝트 설정** 클릭
4. **서비스 계정** 탭 선택
5. **새 비공개 키 생성** 버튼 클릭
6. JSON 파일 다운로드

### 2. 서비스 계정 키 파일 저장

다운로드한 JSON 파일을 다음 경로에 저장하세요:

```bash
~/.claude/projects/problem-generator/firebase-credentials.json
```

또는 터미널에서:

```bash
# 다운로드한 파일 이동
mv ~/Downloads/real-math-d9ddf-*.json ~/.claude/projects/problem-generator/firebase-credentials.json

# 권한 설정 (보안)
chmod 600 ~/.claude/projects/problem-generator/firebase-credentials.json
```

### 3. 테스트

```bash
cd ~/.claude/projects/problem-generator
python3 tools/upload_to_firebase.py
```

---

## 방법 2: Application Default Credentials (ADC) 사용

### 1. gcloud CLI 설치

```bash
# Homebrew로 설치
brew install google-cloud-sdk

# 또는 공식 설치 스크립트
curl https://sdk.cloud.google.com | bash
```

### 2. 인증 설정

```bash
# Google 계정으로 로그인
gcloud auth application-default login

# 프로젝트 설정
gcloud config set project real-math-d9ddf
```

### 3. 테스트

```bash
cd ~/.claude/projects/problem-generator
python3 tools/upload_to_firebase.py
```

---

## 현재 설정 상태 확인

```bash
# 서비스 계정 키 파일 확인
ls -la ~/.claude/projects/problem-generator/firebase-credentials.json

# ADC 확인
gcloud auth application-default print-access-token
```

---

## 문제 해결

### 오류: `DefaultCredentialsError`

**원인:** Firebase 인증 정보가 설정되지 않음

**해결:**
1. 위의 방법 1 또는 방법 2를 따라 인증 설정
2. 환경 변수 확인:
   ```bash
   echo $GOOGLE_APPLICATION_CREDENTIALS
   ```
3. 필요시 환경 변수 설정:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.claude/projects/problem-generator/firebase-credentials.json"
   ```

### 오류: `Permission denied`

**원인:** Firebase 프로젝트에 대한 권한 부족

**해결:**
1. Firebase Console에서 사용자 권한 확인
2. 서비스 계정에 **Cloud Datastore User** 역할 부여

### 오류: `Module not found: firebase_admin`

**원인:** firebase-admin 패키지 미설치

**해결:**
```bash
pip3 install firebase-admin
```

---

## 워크플로우

### 1. 문제 생성
```bash
/generate-problem topic="연립방정식" difficulty="상" theme="실물자산 투자"
```

### 2. Chrome에서 미리보기 자동 오픈
- HTML 페이지가 자동으로 열림
- 문제 내용, 풀이, 도표 검수

### 3. 검수 완료 후 승인
- **✅ 승인 및 Firebase 업로드** 버튼 클릭
- `tools/upload_to_firebase.py` 자동 실행
- Firebase Firestore에 문제 업로드

### 4. Firebase Console에서 확인
[https://console.firebase.google.com/project/real-math-d9ddf/firestore](https://console.firebase.google.com/project/real-math-d9ddf/firestore)

---

## Firebase Firestore 데이터 구조

```json
{
  "problems": {
    "PID_20251204_gold_diamond_m2": {
      "problemId": "PID_20251204_gold_diamond_m2",
      "week": "20251204",
      "date": "2025-12-04",
      "title": "금·다이아몬드 가격 역전현상...",
      "content": { ... },
      "questions": [ ... ],
      "solution": { ... },
      "metadata": {
        "difficulty": "상",
        "qualityScore": 94
      },
      "statistics": {
        "totalAttempts": 0,
        "correctAttempts": 0
      }
    }
  }
}
```

---

## 보안 주의사항

⚠️ **절대로** 다음 파일을 Git에 커밋하지 마세요:
- `firebase-credentials.json`
- `serviceAccountKey.json`
- `*.pem`

`.gitignore`에 이미 추가되어 있는지 확인:
```bash
cat .gitignore | grep firebase
```

없으면 추가:
```bash
echo "firebase-credentials.json" >> .gitignore
echo "*serviceAccount*.json" >> .gitignore
```

---

## 참고 자료

- [Firebase Admin SDK 설정](https://firebase.google.com/docs/admin/setup)
- [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
- [Firestore 데이터 모델](https://firebase.google.com/docs/firestore/data-model)

---

**설정 완료 후 다시 업로드를 시도하세요!** 🚀
