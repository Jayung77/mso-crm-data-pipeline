/* ============================================================================
Project: 의료 MSO 데이터 정제·적재 및 매출 분석
File: 03_clean_data_validation.sql
Author: 박재정
Purpose:
  HeidiSQL CSV Import 후 crm_transaction_clean의 적재 건수, 데이터 품질,
  예약 상태 및 금액 KPI를 검증하고 Excel 분석 결과와 대조합니다.

Prerequisites:
  1) 01_schema_and_dummy_data_setup.sql 실행 (원천 데이터 50건)
  2) Excel에서 이상치 처리: 마스터 불일치 3건 제외, 금액 오류 6건 보정
  3) CREATE TABLE practice.crm_transaction_clean LIKE practice.crm_transaction_log;
  4) HeidiSQL CSV Import로 정제 데이터 47건 INSERT

Note:
  - 읽기 전용 검증 SQL입니다. 원천/정제 테이블의 데이터를 수정하지 않습니다.
  - 아래 기대값은 Excel 포트폴리오의 합성 데이터 기준입니다.
  - 실제 DB 검증 완료 여부는 각 SELECT 실행 결과로 판단하세요.
  - 노쇼·취소 금액 0원 규칙은 본 합성 데이터에 한정됩니다.
============================================================================ */

USE practice;

-- VAL-01. 원천 및 정제 데이터 건수 (기대: 50건 / 47건)
SELECT '원천 데이터' AS Data_Stage, COUNT(*) AS Row_Count,
       CASE WHEN COUNT(*) = 50 THEN 'PASS' ELSE 'CHECK' END AS Validation_Result
FROM crm_transaction_log
UNION ALL
SELECT '정제 데이터', COUNT(*),
       CASE WHEN COUNT(*) = 47 THEN 'PASS' ELSE 'CHECK' END
FROM crm_transaction_clean;


-- VAL-02. 정제 전·후 QA 오류 건수 (기대: 정제 전 3/5/1, 정제 후 0/0/0)
SELECT '정제 전' AS Data_Stage,
  (SELECT COUNT(*) FROM crm_transaction_log t
   LEFT JOIN customer_master c ON t.Chart_No = c.Chart_No
   WHERE c.Chart_No IS NULL) AS Master_Error,
  (SELECT COUNT(*) FROM crm_transaction_log
   WHERE Reservation_Status IN ('노쇼','예약취소')
     AND (Payment_Amount > 0 OR Unpaid_Amount > 0)) AS Status_Amount_Error,
  (SELECT COUNT(*) FROM crm_transaction_log
   WHERE Unpaid_Amount < 0) AS Negative_Unpaid_Error
UNION ALL
SELECT '정제 후',
  (SELECT COUNT(*) FROM crm_transaction_clean t
   LEFT JOIN customer_master c ON t.Chart_No = c.Chart_No
   WHERE c.Chart_No IS NULL),
  (SELECT COUNT(*) FROM crm_transaction_clean
   WHERE Reservation_Status IN ('노쇼','예약취소')
     AND (Payment_Amount > 0 OR Unpaid_Amount > 0)),
  (SELECT COUNT(*) FROM crm_transaction_clean
   WHERE Unpaid_Amount < 0);


-- VAL-03. 정제 후 데이터 추가 품질 검증 (각 0건 기대)
SELECT
  SUM(CASE WHEN Chart_No IS NULL OR Chart_No = '' THEN 1 ELSE 0 END)
    AS Missing_Chart_No,
  SUM(CASE WHEN Is_First_Visit IS NULL OR Is_First_Visit NOT IN ('Y','N')
           THEN 1 ELSE 0 END) AS Invalid_First_Visit,
  SUM(CASE WHEN Reservation_Status IS NULL
                OR Reservation_Status NOT IN ('진료완료','노쇼','예약취소')
           THEN 1 ELSE 0 END) AS Invalid_Status,
  SUM(CASE WHEN Payment_Amount IS NULL OR Unpaid_Amount IS NULL
           THEN 1 ELSE 0 END) AS Missing_Amount,
  SUM(CASE WHEN Payment_Amount < 0 OR Unpaid_Amount < 0
           THEN 1 ELSE 0 END) AS Negative_Amount
FROM crm_transaction_clean;


-- VAL-04. 예약 상태·금액 KPI (Excel 기대: 47/34/7/6, 13,804,000/900,000/14,704,000)
SELECT
  COUNT(*) AS Total_Reservations,
  SUM(CASE WHEN Reservation_Status = '진료완료' THEN 1 ELSE 0 END)
    AS Completed_Count,
  SUM(CASE WHEN Reservation_Status = '노쇼' THEN 1 ELSE 0 END)
    AS NoShow_Count,
  SUM(CASE WHEN Reservation_Status = '예약취소' THEN 1 ELSE 0 END)
    AS Cancel_Count,
  SUM(CASE WHEN Reservation_Status = '진료완료' AND Is_First_Visit = 'Y'
           THEN 1 ELSE 0 END) AS New_Completed_Count,
  SUM(CASE WHEN Reservation_Status = '진료완료' AND Is_First_Visit = 'N'
           THEN 1 ELSE 0 END) AS Returning_Completed_Count,
  SUM(CASE WHEN Reservation_Status = '진료완료' THEN Payment_Amount ELSE 0 END)
    AS Total_Payment,
  SUM(CASE WHEN Reservation_Status = '진료완료' THEN Unpaid_Amount ELSE 0 END)
    AS Total_Unpaid,
  SUM(CASE WHEN Reservation_Status = '진료완료'
           THEN Payment_Amount + Unpaid_Amount ELSE 0 END)
    AS Total_Billing
FROM crm_transaction_clean;


-- VAL-05. 주요 KPI 기대값 자동 비교 (모두 PASS이면 Excel 주요 합계와 일치)
SELECT
  CASE WHEN COUNT(*) = 47 THEN 'PASS' ELSE 'CHECK' END AS Reservations_Check,
  CASE WHEN SUM(Reservation_Status = '진료완료') = 34
       THEN 'PASS' ELSE 'CHECK' END AS Completed_Check,
  CASE WHEN SUM(Reservation_Status = '노쇼') = 7
       THEN 'PASS' ELSE 'CHECK' END AS NoShow_Check,
  CASE WHEN SUM(Reservation_Status = '예약취소') = 6
       THEN 'PASS' ELSE 'CHECK' END AS Cancel_Check,
  CASE WHEN SUM(CASE WHEN Reservation_Status = '진료완료'
                     THEN Payment_Amount ELSE 0 END) = 13804000
       THEN 'PASS' ELSE 'CHECK' END AS Payment_Check,
  CASE WHEN SUM(CASE WHEN Reservation_Status = '진료완료'
                     THEN Unpaid_Amount ELSE 0 END) = 900000
       THEN 'PASS' ELSE 'CHECK' END AS Unpaid_Check,
  CASE WHEN SUM(CASE WHEN Reservation_Status = '진료완료'
                     THEN Payment_Amount + Unpaid_Amount ELSE 0 END) = 14704000
       THEN 'PASS' ELSE 'CHECK' END AS Billing_Check
FROM crm_transaction_clean;


-- VAL-06. 일별 Excel 대시보드 대조용 집계
SELECT Reservation_Date,
  COUNT(*) AS Total_Reservations,
  SUM(Reservation_Status = '진료완료') AS Completed_Count,
  SUM(Reservation_Status = '노쇼') AS NoShow_Count,
  SUM(Reservation_Status = '예약취소') AS Cancel_Count,
  SUM(CASE WHEN Reservation_Status = '진료완료'
           THEN Payment_Amount ELSE 0 END) AS Total_Payment,
  SUM(CASE WHEN Reservation_Status = '진료완료'
           THEN Unpaid_Amount ELSE 0 END) AS Total_Unpaid
FROM crm_transaction_clean
GROUP BY Reservation_Date
ORDER BY Reservation_Date;


-- VAL-07. 채널별 Excel 대시보드 대조용 집계
SELECT Inflow_Channel,
  COUNT(*) AS Total_Reservations,
  SUM(Reservation_Status = '진료완료') AS Completed_Count,
  SUM(Reservation_Status IN ('노쇼','예약취소')) AS Drop_Count,
  SUM(CASE WHEN Reservation_Status = '진료완료'
           THEN Payment_Amount ELSE 0 END) AS Total_Payment,
  SUM(CASE WHEN Reservation_Status = '진료완료'
           THEN Unpaid_Amount ELSE 0 END) AS Total_Unpaid,
  ROUND(100.0 * SUM(Reservation_Status IN ('노쇼','예약취소'))
        / NULLIF(COUNT(*), 0), 1) AS Drop_Rate
FROM crm_transaction_clean
GROUP BY Inflow_Channel
ORDER BY Total_Payment DESC;
