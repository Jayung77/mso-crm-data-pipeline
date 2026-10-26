/* ==========================================================================
   Project: MSO CRM 일일 운영 지표 및 매출 마감 데이터 추출
   Author: 박재정
   Date: 2026-10-15
   Description:
     - CRM 예약·수납 트랜잭션 및 회원 마스터 원천 데이터 추출
     - Excel 정합성 검증(QA) 템플릿 이관 및 Google Sheets 대시보드 반영 목적
   ========================================================================== */

USE practice;

-- --------------------------------------------------------------------------
-- 1. 일일/기간별 트랜잭션 원천 데이터 추출 (Excel QA 대상 데이터)
-- --------------------------------------------------------------------------
SELECT 
    Reservation_Date,      -- 예약일자
    Reservation_Time,      -- 예약시간
    Chart_No,              -- 차트번호
    Is_First_Visit,        -- 신환여부 (Y/N)
    Inflow_Channel,        -- 유입경로
    Consultant_ID,         -- 상담실장 ID
    Reservation_Status,    -- 예약상태
    Treatment_Item,        -- 진료과목
    Payment_Amount,        -- 당일 결제금액
    Unpaid_Amount          -- 미수 잔금
FROM 
    crm_transaction_log
WHERE 
    Reservation_Date BETWEEN '2026-10-15' AND '2026-10-18'
ORDER BY 
    Reservation_Date ASC, 
    Reservation_Time ASC;


-- --------------------------------------------------------------------------
-- 2. 회원 마스터(기준정보) 데이터 추출 (Excel VLOOKUP 대조용)
-- --------------------------------------------------------------------------
SELECT 
    Chart_No,              -- 차트번호 (고유키)
    Customer_ID,           -- 고객번호
    Customer_Name,         -- 고객명
    Phone_Number,          -- 연락처
    Customer_Grade,        -- 고객등급
    Join_Date              -- 최초 등록일
FROM 
    customer_master
ORDER BY 
    Chart_No ASC;
