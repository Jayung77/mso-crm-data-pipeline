# 🏥 의료 MSO 비즈니스 데이터 파이프라인 및 CRM Data QA
> **의료 MSO 환경의 결제·예약 트랜잭션 무결성 검증(Data QA) 및 실시간 경영 의사결정 KPI 대시보드 구축**

[![Tech Stack](https://img.shields.io/badge/Stack-MySQL%20%7C%20HeidiSQL%20%7C%20Excel%20%7C%20GoogleSheets-blue)](https://github.com/Jayung77/mso-crm-data-pipeline)
[![Data QA](https://img.shields.io/badge/Data%20QA-9%20Errors%20Cleaned%20(100%25)-success)](https://github.com/Jayung77/mso-crm-data-pipeline)
[![Target Role](https://img.shields.io/badge/Target%20Role-Data%20Analyst%20%7C%20Data%20Ops%20%7C%20Hospital%20IT-orange)](https://github.com/Jayung77/mso-crm-data-pipeline)

---

## 🛠️ 사용 기술 스택
- **Database & Query:** SQL, MySQL, HeidiSQL
- **Data QA & Governance:** Microsoft Excel (`VLOOKUP`, 다중 논리 함수 `IF`/`AND`/`OR`, 조건부 서식, 필터)
- **BI & Dynamic Dashboard:** Google Sheets (`COUNTIFS`, `SUMIFS`, `LET`, `UNIQUE`, `SORT`, `CHOOSEROWS`)

---

## 📌 1. 프로젝트 배경 및 추진 목표 (Overview)
- **추진 배경:**
  - 현업 의료 MSO(병원경영지원) 환경에서 환자 예약 시스템과 수납 단말기 기록 간의 휴먼 에러, 수납 누락, 취소 미반영 등으로 인한 데이터 불일치 빈번 발생.
  - 데이터 정합성이 결여된 상태로 집계 시 실 수납액 과대 계상, 미수금 누락 등 경영진 의사결정 왜곡 초래.
- **핵심 목표:**
  1. **데이터 무결성(Data QA) 100% 확보**: 다중 검증 함수와 SQL을 활용한 논리적 이상치 9건 전수 탐지 및 정제.
  2. **재발 방지 시스템 거버넌스 수립**: RDBMS 무결성 제약 조건(FK, CHECK) 및 4단계 정기 마감 QA 체계 설계.
  3. **심화 비즈니스 인사이트 도출**: 신환/구환 세그먼트 분석 및 채널별 이탈률(노쇼/취소) 기반 실행 전략 제언.

---

## 🗄️ 2. 데이터 아키텍처 & 관계형 모델링 (ERD)

환자 기준정보 마스터와 일일 예약/수납 트랜잭션 로그 간의 **1:N 관계형 데이터 스키마**를 설계하여 데이터 중복을 제거하고 참조 무결성을 보장했습니다.

```text
[customer_master] (환자 마스터 / 20건)
├── Chart_No (PK, VARCHAR(20))
├── Customer_ID (VARCHAR(20))
├── Customer_Name (VARCHAR(50))
├── Phone_Number (VARCHAR(20))
├── Customer_Grade (ENUM('일반', '우수', 'VIP'))
└── Join_Date (DATE)
       │ 1
       │
       │ N (1:N 참조 무결성 연결)
       ▼
[crm_transaction_log] (진료/결제 트랜잭션 / 50건)
├── Reservation_Date (DATE)
├── Reservation_Time (TIME)
├── Chart_No (FK, REFERENCES customer_master)
├── Is_First_Visit (CHAR(1), CHECK IN ('Y', 'N'))
├── Inflow_Channel (VARCHAR(30))
├── Consultant_ID (VARCHAR(20))
├── Reservation_Status (ENUM('진료완료', '노쇼', '예약취소'))
├── Treatment_Item (VARCHAR(50))
├── Payment_Amount (INT, CHECK >= 0)
└── Unpaid_Amount (INT, CHECK >= 0)

````

-----

## 🔍 3. 데이터 파이프라인 및 정합성 검증 (Data QA & Cleansing)

원천 데이터 50건 중 **총 9건의 이상치 및 논리적 오류**를 3단계로 탐지하여 데이터 신뢰도를 100%로 복원했습니다.

| 구분        | 검증 유형                     | 발생 시나리오 및 이상 데이터                                       | 검증 및 조치 방식 (수식 / SQL)                                                                                         | 조치 건수  |
| :-------: | :-----------------------: | :----------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :----: |
| **QA-01** | **기준정보 누락<br>(참조 무결성)**   | 마스터에 미등록된 임의 차트번호<br>(`C299999`, `C288888`, `C277777`) | `=VLOOKUP($C2, customer_master!$A$2:$F$21, 1, 0)`<br>➔ `#N/A` 탐지 후 행 제외 처리 (식별 불가 데이터 분리)                     | **3건** |
| **QA-02** | **비즈니스 모순<br>(가공 매출 방지)** | 예약취소/노쇼 상태임에도 결제액이나 미수 잔금이 잔존                          | `=IF(OR(G2="예약취소", G2="노쇼"), IF(AND(I2=0, J2=0), TRUE, FALSE), TRUE)`<br>➔ `FALSE` 탐지 후 **수납액 및 잔금 0원 일괄 보정** | **5건** |
| **QA-03** | **수납 이상치<br>(도메인 제약)**    | 결제 단말기/수기 기입 착오로 미수 잔금이 음수(-20,000원)로 표기               | 잔금 0원 정상화 조치 (`Unpaid_Amount = 0`)                                                                            | **1건** |

-----

## 🛡️ 4. 데이터 운영 및 재발 방지 거버넌스 (Data Governance)

일회성 수기 정제에 그치지 않고, 시스템 입력단 원천 차단 및 정기 마감 SLA를 수립했습니다.

### 1\) 시스템 입력단 제약 조건 (System Constraints)

  - **외래키(FK) 참조 무결성 강제**: 마스터에 없는 차트번호 입력 원천 차단.
  - **예약 부도 시 결제액 0원 강제 규칙**:
    ``` sql
    CHECK (
      (Reservation_Status IN ('노쇼', '예약취소') AND Payment_Amount = 0 AND Unpaid_Amount = 0)
      OR (Reservation_Status = '진료완료')
    )
    
    ```
  - **음수 금액 방지**: `CHECK (Payment_Amount >= 0 AND Unpaid_Amount >= 0)`

### 2\) 4단계 QA 운영 주기 (SLA)

1.  **실시간 (Real-time)**: CRM 입력 화면에서 유효성 검사 규칙 적용 (이상치 입력 1차 차단).
2.  **일일 마감 (19:30)**: PG 카드사 승인 매출과 EMR 수납액 1:1 대사 (오차 0원 검증).
3.  **익일 감사 (09:00)**: 전일 노쇼/취소 환자의 수납액 0원 보정 여부 일괄 감사.
4.  **월간 결산**: Zero-Defect 데이터 품질 모니터링 리포트 발행.

-----

## 📊 5. 핵심 경영 인사이트 및 전략적 제언 (Key Insights)

정제 완료된 47건(진료 완료 34건) 데이터를 기반으로 도출한 실행 가능한(Actionable) 전략입니다.

### 💡 1. 인스타그램: 최고 매출 채널 & 미수 잔금 집중 리스크 관리

  - **현황**: 총 5건 진료 완료로 \*\*4,245,000원(전체 수납액의 30.8%)\*\*을 달성한 매출 기여도 1위 채널.
  - **리스크**: 전체 미수 잔금(900,000원) 중 \*\*88.9%(800,000원)\*\*가 인스타그램 유입 환자에게 편중 (`C250014` 울쎄라 300샷 잔금 30만 원, `C260028` 써마지 600샷 잔금 50만 원).
  - **실행 제언**: 고단가 프리미엄 시술에 집중된 유입 특성을 고려하여, **사전 예약금(Deposit) 결제 프로토콜 도입** 및 당일 수납 완납 원칙 확립 필요.

### 💡 2. 카카오톡: 이탈률 0% 및 강력한 환자 락인(Lock-in)

  - **현황**: 총 9건 예약 중 노쇼/취소 0건으로 **진료 이행도 100% 달성**, 안정적인 수납액(2,645,000원, 비중 19.2%) 및 미수금 50,000원에 불과.
  - **실행 제언**: 진료 신뢰도가 검증된 채널이므로 정기 리텐션 알림톡 및 지인 추천 프로모션을 연계하여 충성 고객층으로 확고히 락인.

### 💡 3. 네이버검색 & 당근마켓: 높은 이탈률(노쇼/취소) 개선 및 스케줄링 최적화

  - **현황**: 네이버검색 이탈률 **57.1%**(7건 중 4건), 당근마켓 이탈률 **40.0%**(5건 중 2건). 병원 전체 이탈(13건)의 \*\*46.2%\*\*가 두 채널에 집중되어 원장단 진료 공백 초래.
  - **실행 제언**: 예약 전일/당일 카카오 알림톡 자동 재확인 시스템 의무화 및 당일 대기 환자를 우선 배정하는 가변 스케줄링(오버부킹 버퍼) 도입.

-----

## 💻 6. 주요 SQL 스크립트 (Core SQL)

\<details\>
\<summary\>\<b\>▶ Data QA: 이상치 탐지 및 자동 정제 쿼리\</b\>\</summary\>

``` sql
-- 1. 기준정보 미등록 이상 차트번호 탐지
SELECT t.*
FROM crm_transaction_log t
LEFT JOIN customer_master c ON t.Chart_No = c.Chart_No
WHERE c.Chart_No IS NULL;

-- 2. 비즈니스 로직 모순 데이터(노쇼/취소 건의 가공 매출) 0원 보정
UPDATE crm_transaction_log
SET Payment_Amount = 0, Unpaid_Amount = 0
WHERE Reservation_Status IN ('노쇼', '예약취소')
  AND (Payment_Amount > 0 OR Unpaid_Amount > 0);

-- 3. 음수 잔금 정상화
UPDATE crm_transaction_log
SET Unpaid_Amount = 0
WHERE Unpaid_Amount < 0;

```

\</details\>

\<details\>
\<summary\>\<b\>▶ Business KPI: 일일 마감 및 채널별 성과 집계 쿼리\</b\>\</summary\>

``` sql
-- 채널별 성과, 신환 비율, 수납액 및 이탈률 집계
SELECT 
    Inflow_Channel,
    COUNT(*) AS Total_Reservations,
    SUM(CASE WHEN Reservation_Status = '진료완료' THEN 1 ELSE 0 END) AS Completed_Count,
    SUM(CASE WHEN Reservation_Status = '노쇼' THEN 1 ELSE 0 END) AS No_Show_Count,
    SUM(CASE WHEN Reservation_Status = '예약취소' THEN 1 ELSE 0 END) AS Cancelled_Count,
    SUM(Payment_Amount) AS Total_Payment,
    SUM(Unpaid_Amount) AS Total_Unpaid,
    ROUND((SUM(CASE WHEN Reservation_Status IN ('노쇼', '예약취소') THEN 1 ELSE 0 END) / COUNT(*)) * 100, 1) AS Churn_Rate_Pct
FROM crm_transaction_log
GROUP BY Inflow_Channel
ORDER BY Total_Payment DESC;

```

\</details\>

-----

## 📂 파일 구성 안내 (Repository Structure)

  - **`01_schema_and_dummy_data_setup.sql`**
      - 기준정보 및 트랜잭션 테이블 생성(`CREATE TABLE`, 무결성 제약조건 포함) 및 샘플 데이터 적재 스크립트. *(※ 개인정보 보호를 위해 비식별화된 가명 데이터 활용)*
  - **`02_daily_transaction_extraction.sql`**
      - Data QA 검증 및 일일 마감 대시보드 반영을 위한 트랜잭션 추출 및 지표 집계 쿼리.
  - **`MSO_CRM_일일운영지표_RAW.xlsx`**
      - 엑셀 다중 논리 함수 기반의 정합성 검증 시트 및 정제 완료 데이터셋 원본.
  - **대시보드 원본 링크:** 👉 [MSO\_일일매출시트 대시보드 바로가기](https://docs.google.com/spreadsheets/d/1RXjJdhmyij5JQC2KHtNI_ndIr7pQMRP8DBqcwKrKr08/edit?gid=1242441615#gid=1242441615)

-----

## 👤 Author

  - **GitHub**: [@Jayung77](https://github.com/Jayung77)
  - **Repository**: [mso-crm-data-pipeline](https://github.com/Jayung77/mso-crm-data-pipeline)

<!-- end list -->
