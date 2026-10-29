      >>SOURCE FORMAT FREE
      *> ------------------------------------------------------------------
      *> TESTPROC - portable COBOL unit tests for BNKPROC.
      *>
      *> The driver applies deposits, withdrawals, transfers and rejection
      *> paths to an in-memory account table and asserts exact COMP-3
      *> balances, movement totals and ledger effects.
      *> ------------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "ACCOUNT.cpy".
       COPY "TRANSACT.cpy".
       COPY "INTERFACES.cpy".

       01  WS-TEST-COUNT             PIC 9(04) VALUE ZERO.
       01  WS-FAIL-COUNT             PIC 9(04) VALUE ZERO.
       01  WS-TEST-NAME              PIC X(40).
       01  WS-CASE-OK                PIC X(01).

       PROCEDURE DIVISION.
       MAIN.
           PERFORM TEST-DEPOSIT
           PERFORM TEST-WITHDRAWAL
           PERFORM TEST-TRANSFER
           PERFORM TEST-INSUFFICIENT-WITHDRAWAL
           PERFORM TEST-INSUFFICIENT-TRANSFER
           PERFORM TEST-CLOSED-ACCOUNT
           PERFORM TEST-VALIDATION-GUARD
           PERFORM TEST-EXACT-FUNDS
           PERFORM TEST-DEPOSIT-OVERFLOW

           DISPLAY "SUMMARY|TESTS=" WS-TEST-COUNT
                   "|FAILURES=" WS-FAIL-COUNT
           END-DISPLAY
           IF WS-FAIL-COUNT > 0
               MOVE 1 TO RETURN-CODE
           END-IF
           STOP RUN.

      *> ------------------------------------------------------------------
       SETUP-ACCOUNTS.
           INITIALIZE ACCOUNT-TABLE VALIDATION-RESULT PROCESS-RESULT
           MOVE "ACC0000001" TO ACT-ID(1)
           MOVE "CUST00000001" TO ACT-CUSTOMER-REF(1)
           MOVE "A" TO ACT-STATUS(1)
           MOVE "CH" TO ACT-TYPE(1)
           MOVE 1000.00 TO ACT-OPENING-BAL(1) ACT-BALANCE(1)
           MOVE "ACC0000002" TO ACT-ID(2)
           MOVE "CUST00000002" TO ACT-CUSTOMER-REF(2)
           MOVE "A" TO ACT-STATUS(2)
           MOVE "SV" TO ACT-TYPE(2)
           MOVE 500.00 TO ACT-OPENING-BAL(2) ACT-BALANCE(2)
           MOVE "Y" TO VLR-OK
           MOVE "+000000100.00" TO VAL-AMOUNT-TEXT
           MOVE 100.00 TO VAL-AMOUNT
           MOVE 1 TO VAL-SRC-INDEX.

       RUN-PROCESSOR.
           CALL "BNKPROC" USING TRANSACTION-FILE-RECORD
                                 ACCOUNT-TABLE
                                 VALIDATION-RESULT
                                 PROCESS-RESULT
           END-CALL.

       CHECK-CASE.
           ADD 1 TO WS-TEST-COUNT END-ADD
           IF WS-CASE-OK = "Y"
               DISPLAY "PASS|" FUNCTION TRIM(WS-TEST-NAME) END-DISPLAY
           ELSE
               ADD 1 TO WS-FAIL-COUNT END-ADD
               DISPLAY "FAIL|" FUNCTION TRIM(WS-TEST-NAME)
                       "|STATUS=" PROC-STATUS
                       "|ERROR=" PROC-ERROR-CODE
               END-DISPLAY
           END-IF.

      *> ------------------------------------------------------------------
       TEST-DEPOSIT.
           PERFORM SETUP-ACCOUNTS
           MOVE "DEPOSIT" TO VAL-TYPE
           MOVE "TXN000000001" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "deposit updates credit ledger" TO WS-TEST-NAME
           IF PROC-STATUS = "Y"
               AND ACT-BALANCE(1) = 1100.00
               AND ACT-CREDITS(1) = 100.00
               AND ACT-DEBITS(1) = 0
               AND ACT-TXN-COUNT(1) = 1
               AND PROC-LEDGER-COUNT = 1
               AND PLE-ENTRY-TYPE(1) = "CREDIT"
               AND PLE-ACCOUNT-ID(1) = "ACC0000001"
               AND PLE-AMOUNT-TEXT(1) = "+000000100.00"
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-WITHDRAWAL.
           PERFORM SETUP-ACCOUNTS
           MOVE "WITHDRAWAL" TO VAL-TYPE
           MOVE "+000000250.00" TO VAL-AMOUNT-TEXT
           MOVE 250.00 TO VAL-AMOUNT
           MOVE "TXN000000002" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "withdrawal updates debit ledger" TO WS-TEST-NAME
           IF PROC-STATUS = "Y"
               AND ACT-BALANCE(1) = 750.00
               AND ACT-DEBITS(1) = 250.00
               AND ACT-CREDITS(1) = 0
               AND PROC-LEDGER-COUNT = 1
               AND PLE-ENTRY-TYPE(1) = "DEBIT"
               AND PLE-ACCOUNT-ID(1) = "ACC0000001"
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-TRANSFER.
           PERFORM SETUP-ACCOUNTS
           MOVE "TRANSFER" TO VAL-TYPE
           MOVE "+000000300.00" TO VAL-AMOUNT-TEXT
           MOVE 300.00 TO VAL-AMOUNT
           MOVE 2 TO VAL-DST-INDEX
           MOVE "TXN000000003" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "transfer writes balanced debit/credit" TO WS-TEST-NAME
           IF PROC-STATUS = "Y"
               AND ACT-BALANCE(1) = 700.00
               AND ACT-BALANCE(2) = 800.00
               AND ACT-DEBITS(1) = 300.00
               AND ACT-CREDITS(2) = 300.00
               AND ACT-TXN-COUNT(1) = 1
               AND ACT-TXN-COUNT(2) = 1
               AND PROC-LEDGER-COUNT = 2
               AND PLE-ENTRY-TYPE(1) = "DEBIT"
               AND PLE-ACCOUNT-ID(1) = "ACC0000001"
               AND PLE-COUNTERPARTY(1) = "ACC0000002"
               AND PLE-ENTRY-TYPE(2) = "CREDIT"
               AND PLE-ACCOUNT-ID(2) = "ACC0000002"
               AND PLE-COUNTERPARTY(2) = "ACC0000001"
               AND PLE-AMOUNT-TEXT(1) = PLE-AMOUNT-TEXT(2)
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-INSUFFICIENT-WITHDRAWAL.
           PERFORM SETUP-ACCOUNTS
           MOVE "WITHDRAWAL" TO VAL-TYPE
           MOVE "+000001001.00" TO VAL-AMOUNT-TEXT
           MOVE 1001.00 TO VAL-AMOUNT
           MOVE "TXN000000004" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "insufficient withdrawal is atomic" TO WS-TEST-NAME
           IF PROC-STATUS = "N"
               AND PROC-ERROR-CODE = "E0014"
               AND ACT-BALANCE(1) = 1000.00
               AND ACT-BALANCE(2) = 500.00
               AND ACT-DEBITS(1) = 0
               AND ACT-TXN-COUNT(1) = 0
               AND PROC-LEDGER-COUNT = 0
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-INSUFFICIENT-TRANSFER.
           PERFORM SETUP-ACCOUNTS
           MOVE "TRANSFER" TO VAL-TYPE
           MOVE "+000001200.00" TO VAL-AMOUNT-TEXT
           MOVE 1200.00 TO VAL-AMOUNT
           MOVE 2 TO VAL-DST-INDEX
           MOVE "TXN000000005" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "insufficient transfer is atomic" TO WS-TEST-NAME
           IF PROC-STATUS = "N"
               AND PROC-ERROR-CODE = "E0014"
               AND ACT-BALANCE(1) = 1000.00
               AND ACT-BALANCE(2) = 500.00
               AND ACT-DEBITS(1) = 0
               AND ACT-CREDITS(2) = 0
               AND PROC-LEDGER-COUNT = 0
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-CLOSED-ACCOUNT.
           PERFORM SETUP-ACCOUNTS
           MOVE "C" TO ACT-STATUS(1)
           MOVE "DEPOSIT" TO VAL-TYPE
           MOVE "TXN000000006" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "closed account cannot be changed" TO WS-TEST-NAME
           IF PROC-STATUS = "N"
               AND PROC-ERROR-CODE = "E0010"
               AND ACT-BALANCE(1) = 1000.00
               AND ACT-CREDITS(1) = 0
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-VALIDATION-GUARD.
           PERFORM SETUP-ACCOUNTS
           MOVE "N" TO VLR-OK
           MOVE "E0014" TO VAL-ERROR-CODE
           MOVE "TXN000000007" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "processor rejects invalid validation" TO WS-TEST-NAME
           IF PROC-STATUS = "N"
               AND PROC-ERROR-CODE = "E0017"
               AND ACT-BALANCE(1) = 1000.00
               AND PROC-LEDGER-COUNT = 0
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-EXACT-FUNDS.
           PERFORM SETUP-ACCOUNTS
           MOVE "WITHDRAWAL" TO VAL-TYPE
           MOVE "+000001000.00" TO VAL-AMOUNT-TEXT
           MOVE 1000.00 TO VAL-AMOUNT
           MOVE "TXN000000008" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "withdrawal of exact balance succeeds" TO WS-TEST-NAME
           IF PROC-STATUS = "Y"
               AND ACT-BALANCE(1) = 0
               AND ACT-DEBITS(1) = 1000.00
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.

       TEST-DEPOSIT-OVERFLOW.
           PERFORM SETUP-ACCOUNTS
           MOVE 999999999.00 TO ACT-BALANCE(1)
           MOVE "DEPOSIT" TO VAL-TYPE
           MOVE "+000000001.00" TO VAL-AMOUNT-TEXT
           MOVE 1.00 TO VAL-AMOUNT
           MOVE "TXN000000009" TO TXF-ID
           PERFORM RUN-PROCESSOR
           MOVE "deposit overflow rejected atomically" TO WS-TEST-NAME
           IF PROC-STATUS = "N"
               AND PROC-ERROR-CODE = "E0016"
               AND ACT-BALANCE(1) = 999999999.00
               AND ACT-CREDITS(1) = 0
               AND PROC-LEDGER-COUNT = 0
               MOVE "Y" TO WS-CASE-OK
           ELSE
               MOVE "N" TO WS-CASE-OK
           END-IF
           PERFORM CHECK-CASE.
