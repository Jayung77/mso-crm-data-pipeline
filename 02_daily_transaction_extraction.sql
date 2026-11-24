
/* ============================================================
Project: 의료 MSO 데이터 정제·적재 및 매출 분석
File: 02_daily_transaction_extraction.sql
Author: 박재정

Description:
  1. 원천 예약·결제 데이터 및 고객 마스터 추출
  2. 정제 전 데이터의 이상치 9건 탐지
  3. 정제 완료 테이블 기반 일일·채널별 KPI 집계

Execution:
  - 섹션 1~2: 01번 SQL 실행 후 사용 가능
  - 섹션 3: crm_transaction_clean 적재 후 실행
============================================================ */


USE practice;

-- --------------------------------------------------------------------------
-- 1. 트랜잭션 및 기준정보 원천 데이터 추출 (Data Extraction)
-- --------------------------------------------------------------------------

-- (1) 일일/기간별 예약·수납 트랜잭션 추출 (Excel QA 대상 데이터)
SELECT 
    Reservation_Date,   -- 예약일자
    Reservation_Time,   -- 예약시간
    Chart_No,           -- 차트번호
    Is_First_Visit,     -- 신환여부 (Y/N)
    Inflow_Channel,     -- 유입경로
    Consultant_ID,      -- 상담실장 ID
    Reservation_Status, -- 예약상태
    Treatment_Item,     -- 진료과목
    Payment_Amount,     -- 당일 결제금액
    Unpaid_Amount       -- 미수 잔금
FROM crm_transaction_log
WHERE Reservation_Date BETWEEN '2026-10-15' AND '2026-10-18'
ORDER BY Reservation_Date ASC, Reservation_Time ASC;

-- (2) 회원 마스터 기준정보 추출 (Excel VLOOKUP 대조용)
SELECT 
    Chart_No,       -- 차트번호 (고유키)
    Customer_ID,    -- 고객번호
    Customer_Name,  -- 고객명
    Phone_Number,   -- 연락처
    Customer_Grade, -- 고객등급
    Join_Date       -- 최초 등록일
FROM customer_master
ORDER BY Chart_No ASC;


-- --------------------------------------------------------------------------
-- 2. Data QA: 9건 이상치 전수 탐지 쿼리 (Data Validation)
-- --------------------------------------------------------------------------

-- QA-01. 마스터 미등록 이상 차트번호 3건 탐지 (참조 무결성 불일치)
SELECT 
    t.Reservation_Date,
    t.Chart_No,
    t.Treatment_Item,
    t.Payment_Amount,
    '마스터 미등록 이상치' AS QA_Issue_Type
FROM crm_transaction_log t
LEFT JOIN customer_master c ON t.Chart_No = c.Chart_No
WHERE c.Chart_No IS NULL;

-- QA-02. 예약취소/노쇼 상태인데 결제액/잔금이 남아있는 모순 5건 탐지 (비즈니스 로직 오류)
SELECT 
    Reservation_Date,
    Chart_No,
    Reservation_Status,
    Payment_Amount,
    Unpaid_Amount,
    '예약부도 건 허위 매출/잔금 잔존' AS QA_Issue_Type
FROM crm_transaction_log
WHERE Reservation_Status IN ('예약취소', '노쇼')
  AND (Payment_Amount > 0 OR Unpaid_Amount > 0);

-- QA-03. 미수 잔금이 음수로 오입력된 수납 기입 오류 1건 탐지 (도메인 제약 위반)
SELECT 
    Reservation_Date,
    Chart_No,
    Treatment_Item,
    Unpaid_Amount,
    '잔금 음수 오입력' AS QA_Issue_Type
FROM crm_transaction_log
WHERE Unpaid_Amount < 0;



-- ============================================================
-- 3. 정제 완료 데이터 기반 Business KPI 집계
-- ============================================================

-- KPI-01. 유입 채널별 예약·수납 및 이탈률 분석
SELECT
    Inflow_Channel,
    COUNT(*) AS Total_Reservations,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        THEN 1 ELSE 0
    END) AS Completed_Count,

    SUM(CASE
        WHEN Reservation_Status = '노쇼'
        THEN 1 ELSE 0
    END) AS NoShow_Count,

    SUM(CASE
        WHEN Reservation_Status = '예약취소'
        THEN 1 ELSE 0
    END) AS Cancel_Count,

    SUM(CASE
        WHEN Is_First_Visit = 'Y'
        THEN 1 ELSE 0
    END) AS New_Patient_Count,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        THEN Payment_Amount ELSE 0
    END) AS Total_Payment,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        THEN Unpaid_Amount ELSE 0
    END) AS Total_Unpaid,

    ROUND(
        100.0 * SUM(CASE
            WHEN Reservation_Status IN ('노쇼', '예약취소')
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        1
    ) AS Drop_Rate

FROM crm_transaction_clean
GROUP BY Inflow_Channel
ORDER BY Total_Payment DESC;


-- KPI-02. 일자별 마감 및 예약 현황
SELECT
    Reservation_Date,
    COUNT(*) AS Total_Reservations,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        THEN 1 ELSE 0
    END) AS Completed_Count,

    SUM(CASE
        WHEN Reservation_Status = '노쇼'
        THEN 1 ELSE 0
    END) AS NoShow_Count,

    SUM(CASE
        WHEN Reservation_Status = '예약취소'
        THEN 1 ELSE 0
    END) AS Cancel_Count,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        AND Is_First_Visit = 'Y'
        THEN 1 ELSE 0
    END) AS New_Patients,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        THEN Payment_Amount ELSE 0
    END) AS Total_Payment,

    SUM(CASE
        WHEN Reservation_Status = '진료완료'
        THEN Unpaid_Amount ELSE 0
    END) AS Total_Unpaid

FROM crm_transaction_clean
GROUP BY Reservation_Date
ORDER BY Reservation_Date;
