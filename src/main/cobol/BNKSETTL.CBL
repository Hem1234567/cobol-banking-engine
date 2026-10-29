      >>SOURCE FORMAT FREE
      *> ------------------------------------------------------------------
      *> BNKSETTL - independent end-of-day settlement and reconciliation.
      *>
      *> Consumes the batch outputs produced by BNKMAIN:
      *>   batch_control.dat, accounts_out.dat, accepted.dat,
      *>   rejected.dat, account_exceptions.dat, ledger.dat
      *>
      *> Produces:
      *>   settlement.dat       machine-readable control totals
      *>   reconciliation.dat   one check per line with PASS/FAIL
      *>
      *> The program does not trust BNKMAIN's own counters. It derives counts
      *> and totals from the output records, verifies every ledger row against
      *> its accepted transaction, and checks the accounting equation per
      *> account and in aggregate. A nonzero SET-RC is returned when any
      *> integrity check fails.
      *> ------------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNKSETTL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CONTROL-INPUT-FILE ASSIGN TO WS-CONTROL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-CONTROL-FS.
           SELECT ACCOUNTS-INPUT-FILE ASSIGN TO WS-ACCOUNTS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCOUNTS-FS.
           SELECT ACCEPTED-INPUT-FILE ASSIGN TO WS-ACCEPTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCEPTED-FS.
           SELECT REJECTED-INPUT-FILE ASSIGN TO WS-REJECTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REJECTED-FS.
           SELECT LEDGER-INPUT-FILE ASSIGN TO WS-LEDGER-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-LEDGER-FS.
           SELECT EXCEPTIONS-INPUT-FILE ASSIGN TO WS-EXCEPTIONS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-EXCEPTIONS-FS.
           SELECT SETTLEMENT-FILE ASSIGN TO WS-SETTLEMENT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-SETTLEMENT-FS.
           SELECT RECON-FILE ASSIGN TO WS-RECON-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-RECON-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  CONTROL-INPUT-FILE.
       01  CONTROL-BUFFER             PIC X(300).
       FD  ACCOUNTS-INPUT-FILE.
       01  ACCOUNTS-BUFFER            PIC X(100).
       FD  ACCEPTED-INPUT-FILE.
       01  ACCEPTED-BUFFER            PIC X(100).
       FD  REJECTED-INPUT-FILE.
       01  REJECTED-BUFFER            PIC X(124).
       FD  LEDGER-INPUT-FILE.
       01  LEDGER-BUFFER              PIC X(100).
       FD  EXCEPTIONS-INPUT-FILE.
       01  EXCEPTIONS-BUFFER          PIC X(100).
       FD  SETTLEMENT-FILE.
       01  SETTLEMENT-BUFFER          PIC X(300).
       FD  RECON-FILE.
       01  RECON-BUFFER               PIC X(300).

       WORKING-STORAGE SECTION.
       COPY "ACCOUNT.cpy".
       COPY "TRANSACT.cpy".
       COPY "LEDGER.cpy".

       01  WS-CONTROL-PATH            PIC X(512).
       01  WS-ACCOUNTS-PATH           PIC X(512).
       01  WS-ACCEPTED-PATH           PIC X(512).
       01  WS-REJECTED-PATH           PIC X(512).
       01  WS-LEDGER-PATH             PIC X(512).
       01  WS-EXCEPTIONS-PATH         PIC X(512).
       01  WS-SETTLEMENT-PATH         PIC X(512).
       01  WS-RECON-PATH              PIC X(512).

       01  WS-CONTROL-FS              PIC XX.
       01  WS-ACCOUNTS-FS             PIC XX.
       01  WS-ACCEPTED-FS             PIC XX.
       01  WS-REJECTED-FS             PIC XX.
       01  WS-LEDGER-FS               PIC XX.
       01  WS-EXCEPTIONS-FS           PIC XX.
       01  WS-SETTLEMENT-FS           PIC XX.
       01  WS-RECON-FS                PIC XX.

       01  WS-FATAL-FLAG              PIC X(01).
       01  WS-FAIL-CODE               PIC X(06).
       01  WS-FAIL-DETAIL             PIC X(120).
       01  WS-FAIL-RC                 PIC 9(02) COMP.

       01  WS-ACCOUNT-COUNT           PIC 9(04) COMP.
       01  WS-ACCEPTED-COUNT          PIC 9(06) COMP.
       01  WS-REJECTED-COUNT          PIC 9(06) COMP.
       01  WS-LEDGER-COUNT            PIC 9(08) COMP.
       01  WS-TRANSFER-COUNT          PIC 9(06) COMP.
       01  WS-EXCEPTION-COUNT         PIC 9(06) COMP.

       01  WS-CONTROL-INPUT-COUNT     PIC 9(08).
       01  WS-CONTROL-ACCEPTED-COUNT  PIC 9(08).
       01  WS-CONTROL-REJECTED-COUNT  PIC 9(08).
       01  WS-CONTROL-LEDGER-COUNT    PIC 9(08).
       01  WS-CONTROL-ACCOUNT-COUNT   PIC 9(08).
       01  WS-CONTROL-ACCOUNT-RECORDS PIC 9(08).
       01  WS-CONTROL-EXCEPTION-COUNT PIC 9(08).
       01  WS-CONTROL-RUN-ID          PIC X(10).
       01  WS-CONTROL-DATE            PIC X(10).
       01  WS-CONTROL-CURRENCY        PIC X(03).
       01  WS-CONTROL-INPUT-FOUND     PIC X(01).
       01  WS-CONTROL-ACCEPTED-FOUND  PIC X(01).
       01  WS-CONTROL-REJECTED-FOUND  PIC X(01).
       01  WS-CONTROL-LEDGER-FOUND    PIC X(01).
       01  WS-CONTROL-ACCOUNT-FOUND   PIC X(01).
       01  WS-CONTROL-ACCOUNT-RECORDS-FOUND PIC X(01).
       01  WS-CONTROL-EXCEPTION-FOUND PIC X(01).
       01  WS-CONTROL-META-FOUND      PIC X(01).

       01  WS-KEY                     PIC X(40).
       01  WS-VALUE                   PIC X(240).
       01  WS-COUNTER-VALUE           PIC 9(08).
       01  WS-META-VALUE              PIC X(40).

       01  WS-DEPOSIT-TOTAL           PIC S9(13)V99 COMP-3.
       01  WS-WITHDRAWAL-TOTAL        PIC S9(13)V99 COMP-3.
       01  WS-TRANSFER-TOTAL          PIC S9(13)V99 COMP-3.
       01  WS-ACCEPTED-TOTAL          PIC S9(13)V99 COMP-3.
       01  WS-REJECTED-TOTAL          PIC S9(13)V99 COMP-3.
       01  WS-LEDGER-DEBITS           PIC S9(13)V99 COMP-3.
       01  WS-LEDGER-CREDITS          PIC S9(13)V99 COMP-3.
       01  WS-OPENING-TOTAL           PIC S9(13)V99 COMP-3.
       01  WS-CLOSING-TOTAL           PIC S9(13)V99 COMP-3.
       01  WS-NET-MOVEMENT            PIC S9(13)V99 COMP-3.
       01  WS-EXPECTED-MOVEMENT       PIC S9(13)V99 COMP-3.
       01  WS-LEDGER-NET              PIC S9(13)V99 COMP-3.
       01  WS-WORK-AMOUNT             PIC S9(15)V99 COMP-3.
       01  WS-WORK-BALANCE            PIC S9(15)V99 COMP-3.

       01  WS-TOTAL-EDIT              PIC +9(15).99.
       01  WS-COUNT-EDIT              PIC 9(8).
       01  WS-COUNT4-EDIT             PIC 9(4).
       01  WS-INPUT-COUNT             PIC 9(6) COMP.
       01  WS-DUP-FOUND               PIC X(01).
       01  WS-OUT-LINE                PIC X(300).
       01  WS-CHECK-LINE              PIC X(300).

       01  WS-CHECK-CONTROL           PIC X(04).
       01  WS-CHECK-ACCOUNT           PIC X(04).
       01  WS-CHECK-MOVEMENT          PIC X(04).
       01  WS-CHECK-COUNT             PIC X(04).
       01  WS-CHECK-LEDGER            PIC X(04).
       01  WS-CHECK-TRANSFER          PIC X(04).
       01  WS-CHECK-REJECT            PIC X(04).
       01  WS-DETAIL-CONTROL          PIC X(80).
       01  WS-DETAIL-ACCOUNT          PIC X(80).
       01  WS-DETAIL-MOVEMENT         PIC X(80).
       01  WS-DETAIL-COUNT            PIC X(80).
       01  WS-DETAIL-LEDGER           PIC X(80).
       01  WS-DETAIL-TRANSFER         PIC X(80).
       01  WS-DETAIL-REJECT           PIC X(80).

       01  WS-ACCOUNT-MISMATCHES      PIC 9(06) COMP.
       01  WS-TRANSFER-MISMATCHES     PIC 9(06) COMP.
       01  WS-LEDGER-READ-COUNT       PIC 9(08) COMP.
       01  WS-ENTRIES-NEEDED         PIC 9(01) COMP.
       01  WS-ENTRY-IDX               PIC 9(01) COMP.
       01  WS-IDX                     PIC 9(04) COMP.
       01  WS-EOF                     PIC X(01).
       01  WS-LEDGER-EOF              PIC X(01).
       01  WS-ALL-CHECKS-PASS         PIC X(01).

       01  WS-AMT-TEXT                PIC X(13).
       01  WS-AMT-OK                  PIC X(01).
       01  WS-AMT-VALUE               PIC S9(13)V99 COMP-3.
       01  WS-AMT-ABS                 PIC S9(13)V99 COMP-3.
       01  WS-UNSIGNED-TEXT           PIC X(12).
       01  WS-UNSIGNED-OK             PIC X(01).
       01  WS-UNSIGNED-VALUE          PIC S9(13)V99 COMP-3.

       01  WS-RECON-ACCOUNT-TABLE.
           05  WS-RA OCCURS 1000 TIMES.
               10  WS-RA-ID             PIC X(10).
               10  WS-RA-STATUS         PIC X(01).
               10  WS-RA-OPENING        PIC S9(13)V99 COMP-3.
               10  WS-RA-CLOSING        PIC S9(13)V99 COMP-3.
               10  WS-RA-OUT-DEBITS     PIC S9(13)V99 COMP-3.
               10  WS-RA-OUT-CREDITS    PIC S9(13)V99 COMP-3.
               10  WS-RA-CALC-DEBITS    PIC S9(13)V99 COMP-3.
               10  WS-RA-CALC-CREDITS   PIC S9(13)V99 COMP-3.
               10  WS-RA-OUT-COUNT      PIC 9(06) COMP.
               10  WS-RA-CALC-COUNT     PIC 9(06) COMP.

       LINKAGE SECTION.
       01  LK-OUTPUT-DIR              PIC X(300).
       01  LK-RUN-ID                  PIC X(10).
       01  LK-PROCESS-DATE            PIC X(10).
       01  LK-CURRENCY                PIC X(03).
       COPY "INTERFACES.cpy".

       PROCEDURE DIVISION USING LK-OUTPUT-DIR LK-RUN-ID
                                LK-PROCESS-DATE LK-CURRENCY
                                SETTLEMENT-RESULT.
       SETTLE-BATCH.
           INITIALIZE SETTLEMENT-RESULT WS-RECON-ACCOUNT-TABLE
           MOVE "N" TO WS-FATAL-FLAG
           MOVE "PASS" TO WS-CHECK-CONTROL WS-CHECK-ACCOUNT
                          WS-CHECK-MOVEMENT WS-CHECK-COUNT
                          WS-CHECK-LEDGER WS-CHECK-TRANSFER
                          WS-CHECK-REJECT
           MOVE "CONTROL METADATA VERIFIED" TO WS-DETAIL-CONTROL
           MOVE "ACCOUNT BALANCES RECONCILED" TO WS-DETAIL-ACCOUNT
           MOVE "MOVEMENTS RECONCILE" TO WS-DETAIL-MOVEMENT
           MOVE "RECORD COUNTS RECONCILE" TO WS-DETAIL-COUNT
           MOVE "LEDGER ENTRIES MATCH ACCEPTED TRANSACTIONS"
               TO WS-DETAIL-LEDGER
           MOVE "TRANSFERS ARE BALANCED" TO WS-DETAIL-TRANSFER
           MOVE "REJECTED RECORDS DID NOT MOVE FUNDS"
               TO WS-DETAIL-REJECT
           MOVE ZERO TO WS-ACCOUNT-COUNT WS-ACCEPTED-COUNT
                        WS-REJECTED-COUNT WS-LEDGER-COUNT
                        WS-TRANSFER-COUNT WS-EXCEPTION-COUNT
                        WS-DEPOSIT-TOTAL WS-WITHDRAWAL-TOTAL
                        WS-TRANSFER-TOTAL WS-ACCEPTED-TOTAL
                        WS-REJECTED-TOTAL WS-LEDGER-DEBITS
                        WS-LEDGER-CREDITS WS-OPENING-TOTAL
                        WS-CLOSING-TOTAL WS-NET-MOVEMENT
                        WS-ACCOUNT-MISMATCHES WS-TRANSFER-MISMATCHES
                        WS-LEDGER-READ-COUNT
           MOVE ZERO TO WS-CONTROL-INPUT-COUNT
                        WS-CONTROL-ACCEPTED-COUNT
                        WS-CONTROL-REJECTED-COUNT
                        WS-CONTROL-LEDGER-COUNT
                        WS-CONTROL-ACCOUNT-COUNT
                        WS-CONTROL-ACCOUNT-RECORDS
                        WS-CONTROL-EXCEPTION-COUNT
           MOVE "N" TO WS-CONTROL-INPUT-FOUND
                       WS-CONTROL-ACCEPTED-FOUND
                       WS-CONTROL-REJECTED-FOUND
                       WS-CONTROL-LEDGER-FOUND
                       WS-CONTROL-ACCOUNT-FOUND
                       WS-CONTROL-ACCOUNT-RECORDS-FOUND
                       WS-CONTROL-EXCEPTION-FOUND
                       WS-CONTROL-META-FOUND

           PERFORM BUILD-PATHS
           PERFORM READ-CONTROL
           IF WS-FATAL-FLAG = "N"
               PERFORM READ-ACCOUNTS
           END-IF
           IF WS-FATAL-FLAG = "N"
               PERFORM READ-ACCEPTED-AND-LEDGER
           END-IF
           IF WS-FATAL-FLAG = "N"
               PERFORM READ-REJECTED
           END-IF
           IF WS-FATAL-FLAG = "N"
               PERFORM READ-EXCEPTIONS
           END-IF

           PERFORM EVALUATE-RECONCILIATION
           PERFORM WRITE-REPORTS
           PERFORM POPULATE-RESULT
           GOBACK.

      *> ------------------------------------------------------------------
       BUILD-PATHS.
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/batch_control.dat"
               DELIMITED BY SIZE INTO WS-CONTROL-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/accounts_out.dat"
               DELIMITED BY SIZE INTO WS-ACCOUNTS-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/accepted.dat"
               DELIMITED BY SIZE INTO WS-ACCEPTED-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/rejected.dat"
               DELIMITED BY SIZE INTO WS-REJECTED-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/ledger.dat"
               DELIMITED BY SIZE INTO WS-LEDGER-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/account_exceptions.dat"
               DELIMITED BY SIZE INTO WS-EXCEPTIONS-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/settlement.dat"
               DELIMITED BY SIZE INTO WS-SETTLEMENT-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/reconciliation.dat"
               DELIMITED BY SIZE INTO WS-RECON-PATH
           END-STRING.

      *> ------------------------------------------------------------------
       READ-CONTROL.
           OPEN INPUT CONTROL-INPUT-FILE
           IF WS-CONTROL-FS NOT = "00"
               MOVE "S0001" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN batch_control.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y"
               READ CONTROL-INPUT-FILE END-READ
               EVALUATE WS-CONTROL-FS
                   WHEN "00"
                       PERFORM PARSE-CONTROL-LINE
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "S0002" TO WS-FAIL-CODE
                       MOVE "UNABLE TO READ batch_control.dat"
                           TO WS-FAIL-DETAIL
                       PERFORM SET-FATAL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE CONTROL-INPUT-FILE
           IF WS-FATAL-FLAG = "N" AND WS-CONTROL-FS NOT = "00"
               MOVE "S0003" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE batch_control.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

       PARSE-CONTROL-LINE.
           MOVE SPACES TO WS-KEY WS-VALUE
           UNSTRING CONTROL-BUFFER DELIMITED BY "|"
               INTO WS-KEY WS-VALUE
           END-UNSTRING
           EVALUATE FUNCTION TRIM(WS-KEY)
               WHEN "run_id"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-CONTROL-RUN-ID
                   MOVE "Y" TO WS-CONTROL-META-FOUND
               WHEN "process_date"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-CONTROL-DATE
               WHEN "currency"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-CONTROL-CURRENCY
               WHEN "accounts_loaded"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-ACCOUNT-COUNT
                   MOVE "Y" TO WS-CONTROL-ACCOUNT-FOUND
               WHEN "account_records"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-ACCOUNT-RECORDS
                   MOVE "Y" TO WS-CONTROL-ACCOUNT-RECORDS-FOUND
               WHEN "account_rejections"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-EXCEPTION-COUNT
                   MOVE "Y" TO WS-CONTROL-EXCEPTION-FOUND
               WHEN "input_transactions"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-INPUT-COUNT
                   MOVE "Y" TO WS-CONTROL-INPUT-FOUND
               WHEN "accepted_transactions"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-ACCEPTED-COUNT
                   MOVE "Y" TO WS-CONTROL-ACCEPTED-FOUND
               WHEN "rejected_transactions"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-REJECTED-COUNT
                   MOVE "Y" TO WS-CONTROL-REJECTED-FOUND
               WHEN "ledger_entries"
                   PERFORM PARSE-CONTROL-COUNT
                   MOVE WS-COUNTER-VALUE TO WS-CONTROL-LEDGER-COUNT
                   MOVE "Y" TO WS-CONTROL-LEDGER-FOUND
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       PARSE-CONTROL-COUNT.
           MOVE ZERO TO WS-COUNTER-VALUE
           IF WS-VALUE(1:8) IS NUMERIC
               COMPUTE WS-COUNTER-VALUE =
                   FUNCTION NUMVAL(WS-VALUE(1:8))
               END-COMPUTE
           ELSE
               MOVE "S0004" TO WS-FAIL-CODE
               MOVE "NON-NUMERIC COUNT IN batch_control.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

      *> ------------------------------------------------------------------
       READ-ACCOUNTS.
           OPEN INPUT ACCOUNTS-INPUT-FILE
           IF WS-ACCOUNTS-FS NOT = "00"
               MOVE "S0010" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN accounts_out.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y"
               READ ACCOUNTS-INPUT-FILE END-READ
               EVALUATE WS-ACCOUNTS-FS
                   WHEN "00"
                       PERFORM PARSE-ACCOUNT-SUMMARY
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "S0011" TO WS-FAIL-CODE
                       MOVE "UNABLE TO READ accounts_out.dat"
                           TO WS-FAIL-DETAIL
                       PERFORM SET-FATAL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE ACCOUNTS-INPUT-FILE
           IF WS-FATAL-FLAG = "N" AND WS-ACCOUNTS-FS NOT = "00"
               MOVE "S0012" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE accounts_out.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

       PARSE-ACCOUNT-SUMMARY.
           MOVE ACCOUNTS-BUFFER TO ACCOUNT-OUT-RECORD
           IF ACO-ID(1:3) NOT = "ACC" OR ACO-ID(4:7) IS NOT NUMERIC
               MOVE "ACCOUNT SUMMARY HAS AN INVALID ID"
                   TO WS-DETAIL-ACCOUNT
               MOVE "FAIL" TO WS-CHECK-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-ACCOUNT-COUNT
               IF WS-RA-ID(WS-IDX) = ACO-ID
                   MOVE "DUPLICATE ACCOUNT IN accounts_out.dat"
                       TO WS-DETAIL-ACCOUNT
                   MOVE "FAIL" TO WS-CHECK-ACCOUNT
                   EXIT PARAGRAPH
               END-IF
           END-PERFORM
           IF WS-ACCOUNT-COUNT >= 1000
               MOVE "S0013" TO WS-FAIL-CODE
               MOVE "SETTLEMENT ACCOUNT TABLE CAPACITY EXCEEDED"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF

           MOVE ACO-OPENING-TEXT TO WS-UNSIGNED-TEXT
           PERFORM PARSE-UNSIGNED-AMOUNT
           IF WS-UNSIGNED-OK NOT = "Y"
               PERFORM ACCOUNT-PARSE-ERROR
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-ACCOUNT-COUNT END-ADD
           MOVE ACO-ID TO WS-RA-ID(WS-ACCOUNT-COUNT)
           MOVE ACO-STATUS TO WS-RA-STATUS(WS-ACCOUNT-COUNT)
           MOVE WS-UNSIGNED-VALUE TO WS-RA-OPENING(WS-ACCOUNT-COUNT)
           MOVE ACO-TXN-COUNT TO WS-RA-OUT-COUNT(WS-ACCOUNT-COUNT)

           MOVE ACO-CLOSING-TEXT TO WS-UNSIGNED-TEXT
           PERFORM PARSE-UNSIGNED-AMOUNT
           IF WS-UNSIGNED-OK NOT = "Y"
               PERFORM ACCOUNT-PARSE-ERROR
               EXIT PARAGRAPH
           END-IF
           MOVE WS-UNSIGNED-VALUE TO WS-RA-CLOSING(WS-ACCOUNT-COUNT)

           MOVE ACO-DEBITS-TEXT TO WS-UNSIGNED-TEXT
           PERFORM PARSE-UNSIGNED-AMOUNT
           IF WS-UNSIGNED-OK NOT = "Y"
               PERFORM ACCOUNT-PARSE-ERROR
               EXIT PARAGRAPH
           END-IF
           MOVE WS-UNSIGNED-VALUE TO WS-RA-OUT-DEBITS(WS-ACCOUNT-COUNT)

           MOVE ACO-CREDITS-TEXT TO WS-UNSIGNED-TEXT
           PERFORM PARSE-UNSIGNED-AMOUNT
           IF WS-UNSIGNED-OK NOT = "Y"
               PERFORM ACCOUNT-PARSE-ERROR
               EXIT PARAGRAPH
           END-IF
           MOVE WS-UNSIGNED-VALUE TO WS-RA-OUT-CREDITS(WS-ACCOUNT-COUNT)

           ADD WS-RA-CLOSING(WS-ACCOUNT-COUNT) TO WS-CLOSING-TOTAL
           END-ADD
           ADD WS-RA-OPENING(WS-ACCOUNT-COUNT) TO WS-OPENING-TOTAL
           END-ADD.

       ACCOUNT-PARSE-ERROR.
           MOVE "INVALID AMOUNT FIELD IN accounts_out.dat"
               TO WS-DETAIL-ACCOUNT
           MOVE "FAIL" TO WS-CHECK-ACCOUNT.

       PARSE-UNSIGNED-AMOUNT.
           MOVE "N" TO WS-UNSIGNED-OK
           IF WS-UNSIGNED-TEXT(1:9) IS NUMERIC
               AND WS-UNSIGNED-TEXT(10:1) = "."
               AND WS-UNSIGNED-TEXT(11:2) IS NUMERIC
               COMPUTE WS-UNSIGNED-VALUE =
                   FUNCTION NUMVAL(WS-UNSIGNED-TEXT)
               END-COMPUTE
               MOVE "Y" TO WS-UNSIGNED-OK
           END-IF.

      *> ------------------------------------------------------------------
       READ-ACCEPTED-AND-LEDGER.
           OPEN INPUT ACCEPTED-INPUT-FILE
           IF WS-ACCEPTED-FS NOT = "00"
               MOVE "S0020" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN accepted.dat" TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           OPEN INPUT LEDGER-INPUT-FILE
           IF WS-LEDGER-FS NOT = "00"
               MOVE "S0021" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN ledger.dat" TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y" OR WS-FATAL-FLAG = "Y"
               READ ACCEPTED-INPUT-FILE END-READ
               EVALUATE WS-ACCEPTED-FS
                   WHEN "00"
                       PERFORM PROCESS-ACCEPTED-TRANSACTION
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "S0022" TO WS-FAIL-CODE
                       MOVE "UNABLE TO READ accepted.dat"
                           TO WS-FAIL-DETAIL
                       PERFORM SET-FATAL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM

           IF WS-FATAL-FLAG = "N"
               PERFORM CHECK-FOR-EXTRA-LEDGER
           END-IF
           CLOSE ACCEPTED-INPUT-FILE
           CLOSE LEDGER-INPUT-FILE
           IF WS-FATAL-FLAG = "N" AND
               (WS-ACCEPTED-FS NOT = "00" OR WS-LEDGER-FS NOT = "00")
               MOVE "S0023" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE accepted/ledger files"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

       PROCESS-ACCEPTED-TRANSACTION.
           MOVE ACCEPTED-BUFFER TO ACCEPTED-RECORD
           ADD 1 TO WS-ACCEPTED-COUNT END-ADD
           IF ACR-STATUS NOT = "ACCEPTED"
               MOVE "ACCEPTED RECORD HAS INVALID STATUS"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
           END-IF
           MOVE ACR-AMOUNT-TEXT TO WS-AMT-TEXT
           PERFORM PARSE-SIGNED-AMOUNT
           IF WS-AMT-OK NOT = "Y" OR WS-AMT-VALUE <= 0
               MOVE "ACCEPTED RECORD HAS INVALID AMOUNT"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
               MOVE ZERO TO WS-AMT-VALUE
           END-IF
           ADD WS-AMT-VALUE TO WS-ACCEPTED-TOTAL END-ADD

           EVALUATE FUNCTION TRIM(ACR-TYPE)
               WHEN "DEPOSIT"
                   ADD WS-AMT-VALUE TO WS-DEPOSIT-TOTAL END-ADD
                   MOVE 1 TO WS-ENTRIES-NEEDED
               WHEN "WITHDRAWAL"
                   ADD WS-AMT-VALUE TO WS-WITHDRAWAL-TOTAL END-ADD
                   MOVE 1 TO WS-ENTRIES-NEEDED
               WHEN "TRANSFER"
                   ADD WS-AMT-VALUE TO WS-TRANSFER-TOTAL END-ADD
                   ADD 1 TO WS-TRANSFER-COUNT END-ADD
                   MOVE 2 TO WS-ENTRIES-NEEDED
               WHEN OTHER
                   MOVE "S0024" TO WS-FAIL-CODE
                   MOVE "ACCEPTED RECORD HAS UNKNOWN TYPE"
                       TO WS-FAIL-DETAIL
                   PERFORM SET-FATAL
                   MOVE 1 TO WS-ENTRIES-NEEDED
           END-EVALUATE

           PERFORM CHECK-ACCEPTED-LEDGER.

       CHECK-ACCEPTED-LEDGER.
           PERFORM VARYING WS-ENTRY-IDX FROM 1 BY 1
                   UNTIL WS-ENTRY-IDX > WS-ENTRIES-NEEDED
                   OR WS-FATAL-FLAG = "Y"
               READ LEDGER-INPUT-FILE END-READ
               IF WS-LEDGER-FS NOT = "00"
                   MOVE "S0025" TO WS-FAIL-CODE
                   MOVE "LEDGER ENDED BEFORE ACCEPTED TRANSACTION"
                       TO WS-FAIL-DETAIL
                   PERFORM SET-FATAL
               ELSE
                   MOVE LEDGER-BUFFER TO LEDGER-FILE-RECORD
                   ADD 1 TO WS-LEDGER-READ-COUNT END-ADD
                   PERFORM PARSE-LEDGER-ENTRY
                   PERFORM VERIFY-LEDGER-LINK
               END-IF
           END-PERFORM.

       PARSE-LEDGER-ENTRY.
           MOVE LGR-AMOUNT-TEXT TO WS-AMT-TEXT
           PERFORM PARSE-SIGNED-AMOUNT
           IF WS-AMT-OK NOT = "Y" OR WS-AMT-VALUE <= 0
               MOVE "LEDGER ENTRY HAS INVALID AMOUNT"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
               MOVE ZERO TO WS-AMT-VALUE
           END-IF
           EVALUATE LGR-ENTRY-TYPE
               WHEN "DEBIT"
                   ADD WS-AMT-VALUE TO WS-LEDGER-DEBITS END-ADD
               WHEN "CREDIT"
                   ADD WS-AMT-VALUE TO WS-LEDGER-CREDITS END-ADD
               WHEN OTHER
                   MOVE "LEDGER ENTRY HAS INVALID TYPE"
                       TO WS-DETAIL-LEDGER
                   MOVE "FAIL" TO WS-CHECK-LEDGER
           END-EVALUATE
           IF LGR-DATE NOT = LK-PROCESS-DATE
               OR LGR-RUN-ID NOT = LK-RUN-ID
               MOVE "LEDGER DATE OR RUN ID DOES NOT MATCH CONTROL"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
           END-IF
           PERFORM ADD-LEDGER-ACCOUNT-MOVEMENT.

       ADD-LEDGER-ACCOUNT-MOVEMENT.
           MOVE "N" TO WS-DUP-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-ACCOUNT-COUNT
               IF WS-RA-ID(WS-IDX) = LGR-ACCOUNT-ID
                   EVALUATE LGR-ENTRY-TYPE
                       WHEN "DEBIT"
                           ADD WS-AMT-VALUE
                               TO WS-RA-CALC-DEBITS(WS-IDX)
                           END-ADD
                       WHEN "CREDIT"
                           ADD WS-AMT-VALUE
                               TO WS-RA-CALC-CREDITS(WS-IDX)
                           END-ADD
                   END-EVALUATE
                   ADD 1 TO WS-RA-CALC-COUNT(WS-IDX) END-ADD
                   MOVE "Y" TO WS-DUP-FOUND
                   EXIT PERFORM
               END-IF
           END-PERFORM
           IF WS-DUP-FOUND = "N"
               MOVE "LEDGER REFERENCES AN UNKNOWN ACCOUNT"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
           END-IF.

       VERIFY-LEDGER-LINK.
           IF LGR-TXN-ID NOT = ACR-TXN-ID
               MOVE "LEDGER TRANSACTION ID MISMATCH"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
               IF FUNCTION TRIM(ACR-TYPE) = "TRANSFER"
                   MOVE "FAIL" TO WS-CHECK-TRANSFER
                   ADD 1 TO WS-TRANSFER-MISMATCHES END-ADD
               END-IF
           END-IF
           IF LGR-AMOUNT-TEXT NOT = ACR-AMOUNT-TEXT
               MOVE "LEDGER AMOUNT MISMATCH"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
               IF FUNCTION TRIM(ACR-TYPE) = "TRANSFER"
                   MOVE "FAIL" TO WS-CHECK-TRANSFER
                   ADD 1 TO WS-TRANSFER-MISMATCHES END-ADD
               END-IF
           END-IF
           EVALUATE FUNCTION TRIM(ACR-TYPE)
               WHEN "DEPOSIT"
                   IF LGR-ENTRY-TYPE NOT = "CREDIT"
                       OR LGR-ACCOUNT-ID NOT = ACR-SOURCE
                       MOVE "DEPOSIT LEDGER LINK MISMATCH"
                           TO WS-DETAIL-LEDGER
                       MOVE "FAIL" TO WS-CHECK-LEDGER
                   END-IF
               WHEN "WITHDRAWAL"
                   IF LGR-ENTRY-TYPE NOT = "DEBIT"
                       OR LGR-ACCOUNT-ID NOT = ACR-SOURCE
                       MOVE "WITHDRAWAL LEDGER LINK MISMATCH"
                           TO WS-DETAIL-LEDGER
                       MOVE "FAIL" TO WS-CHECK-LEDGER
                   END-IF
               WHEN "TRANSFER"
                   IF WS-ENTRY-IDX = 1
                       IF LGR-ENTRY-TYPE NOT = "DEBIT"
                           OR LGR-ACCOUNT-ID NOT = ACR-SOURCE
                           OR LGR-COUNTERPARTY NOT = ACR-DEST
                           MOVE "TRANSFER DEBIT LINK MISMATCH"
                               TO WS-DETAIL-LEDGER
                           MOVE "FAIL" TO WS-CHECK-LEDGER
                           ADD 1 TO WS-TRANSFER-MISMATCHES END-ADD
                       END-IF
                   ELSE
                       IF LGR-ENTRY-TYPE NOT = "CREDIT"
                           OR LGR-ACCOUNT-ID NOT = ACR-DEST
                           OR LGR-COUNTERPARTY NOT = ACR-SOURCE
                           MOVE "TRANSFER CREDIT LINK MISMATCH"
                               TO WS-DETAIL-LEDGER
                           MOVE "FAIL" TO WS-CHECK-LEDGER
                           ADD 1 TO WS-TRANSFER-MISMATCHES END-ADD
                       END-IF
                   END-IF
           END-EVALUATE.

       CHECK-FOR-EXTRA-LEDGER.
           READ LEDGER-INPUT-FILE END-READ
           IF WS-LEDGER-FS = "00"
               MOVE "EXTRA LEDGER ENTRY WITHOUT ACCEPTED TRANSACTION"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
               ADD 1 TO WS-LEDGER-READ-COUNT END-ADD
           ELSE
               IF WS-LEDGER-FS NOT = "10"
                   MOVE "S0026" TO WS-FAIL-CODE
                   MOVE "UNABLE TO CHECK LEDGER END"
                       TO WS-FAIL-DETAIL
                   PERFORM SET-FATAL
               END-IF
           END-IF.

      *> ------------------------------------------------------------------
       READ-REJECTED.
           OPEN INPUT REJECTED-INPUT-FILE
           IF WS-REJECTED-FS NOT = "00"
               MOVE "S0030" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN rejected.dat" TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y"
               READ REJECTED-INPUT-FILE END-READ
               EVALUATE WS-REJECTED-FS
                   WHEN "00"
                       PERFORM PROCESS-REJECTED
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "S0031" TO WS-FAIL-CODE
                       MOVE "UNABLE TO READ rejected.dat"
                           TO WS-FAIL-DETAIL
                       PERFORM SET-FATAL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE REJECTED-INPUT-FILE
           IF WS-FATAL-FLAG = "N" AND WS-REJECTED-FS NOT = "00"
               MOVE "S0032" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE rejected.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

       PROCESS-REJECTED.
           MOVE REJECTED-BUFFER TO REJECTED-RECORD
           ADD 1 TO WS-REJECTED-COUNT END-ADD
           IF REJ-STATUS NOT = "REJECTED" OR REJ-ERROR-CODE = SPACES
               MOVE "REJECTED RECORD HAS INVALID STATUS OR ERROR CODE"
                   TO WS-DETAIL-REJECT
               MOVE "FAIL" TO WS-CHECK-REJECT
           END-IF
           MOVE REJ-AMOUNT-TEXT TO WS-AMT-TEXT
           PERFORM PARSE-SIGNED-AMOUNT
           IF WS-AMT-OK = "Y"
               IF WS-AMT-VALUE < 0
                   COMPUTE WS-AMT-ABS = 0 - WS-AMT-VALUE END-COMPUTE
               ELSE
                   MOVE WS-AMT-VALUE TO WS-AMT-ABS
               END-IF
               ADD WS-AMT-ABS TO WS-REJECTED-TOTAL END-ADD
           END-IF.

      *> ------------------------------------------------------------------
       READ-EXCEPTIONS.
           OPEN INPUT EXCEPTIONS-INPUT-FILE
           IF WS-EXCEPTIONS-FS NOT = "00"
               MOVE "S0040" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN account_exceptions.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y"
               READ EXCEPTIONS-INPUT-FILE END-READ
               EVALUATE WS-EXCEPTIONS-FS
                   WHEN "00"
                       ADD 1 TO WS-EXCEPTION-COUNT END-ADD
                       MOVE EXCEPTIONS-BUFFER TO ACCOUNT-EXCEPTION-RECORD
                       IF AEX-STATUS NOT = "REJECTED"
                           OR AEX-ERROR-CODE = SPACES
                           MOVE "ACCOUNT EXCEPTION HAS INVALID STATUS"
                               TO WS-DETAIL-REJECT
                           MOVE "FAIL" TO WS-CHECK-REJECT
                       END-IF
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "S0041" TO WS-FAIL-CODE
                       MOVE "UNABLE TO READ account_exceptions.dat"
                           TO WS-FAIL-DETAIL
                       PERFORM SET-FATAL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE EXCEPTIONS-INPUT-FILE
           IF WS-FATAL-FLAG = "N" AND WS-EXCEPTIONS-FS NOT = "00"
               MOVE "S0042" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE account_exceptions.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

      *> ------------------------------------------------------------------
       EVALUATE-RECONCILIATION.
           COMPUTE WS-INPUT-COUNT =
               WS-ACCEPTED-COUNT + WS-REJECTED-COUNT
           END-COMPUTE
           PERFORM CHECK-CONTROL-METADATA
           PERFORM CHECK-ACCOUNT-EQUATIONS
           PERFORM CHECK-COUNTS
           PERFORM CHECK-MOVEMENT-EQUATION
           PERFORM CHECK-LEDGER-TOTALS
           PERFORM CHECK-TRANSFER-TOTALS
           PERFORM CHECK-REJECT-TOTALS
           IF WS-FATAL-FLAG = "Y"
               MOVE "FAIL" TO WS-CHECK-CONTROL WS-CHECK-ACCOUNT
                              WS-CHECK-MOVEMENT WS-CHECK-COUNT
                              WS-CHECK-LEDGER WS-CHECK-TRANSFER
                              WS-CHECK-REJECT
           END-IF
           MOVE "Y" TO WS-ALL-CHECKS-PASS
           IF WS-CHECK-CONTROL NOT = "PASS"
               OR WS-CHECK-ACCOUNT NOT = "PASS"
               OR WS-CHECK-MOVEMENT NOT = "PASS"
               OR WS-CHECK-COUNT NOT = "PASS"
               OR WS-CHECK-LEDGER NOT = "PASS"
               OR WS-CHECK-TRANSFER NOT = "PASS"
               OR WS-CHECK-REJECT NOT = "PASS"
               MOVE "N" TO WS-ALL-CHECKS-PASS
           END-IF.

       CHECK-CONTROL-METADATA.
           IF WS-CONTROL-META-FOUND NOT = "Y"
               MOVE "CONTROL METADATA IS INCOMPLETE"
                   TO WS-DETAIL-CONTROL
               MOVE "FAIL" TO WS-CHECK-CONTROL
           ELSE
               IF WS-CONTROL-RUN-ID NOT = LK-RUN-ID
                   OR WS-CONTROL-DATE NOT = LK-PROCESS-DATE
                   OR WS-CONTROL-CURRENCY NOT = LK-CURRENCY
                   MOVE "CONTROL RUN ID, DATE OR CURRENCY MISMATCH"
                       TO WS-DETAIL-CONTROL
                   MOVE "FAIL" TO WS-CHECK-CONTROL
               END-IF
           END-IF.

       CHECK-ACCOUNT-EQUATIONS.
           IF WS-CHECK-ACCOUNT = "PASS"
               PERFORM VARYING WS-IDX FROM 1 BY 1
                       UNTIL WS-IDX > WS-ACCOUNT-COUNT
                   COMPUTE WS-WORK-BALANCE =
                       WS-RA-OPENING(WS-IDX)
                       + WS-RA-CALC-CREDITS(WS-IDX)
                       - WS-RA-CALC-DEBITS(WS-IDX)
                   END-COMPUTE
                   IF WS-WORK-BALANCE NOT = WS-RA-CLOSING(WS-IDX)
                       OR WS-RA-OUT-DEBITS(WS-IDX)
                           NOT = WS-RA-CALC-DEBITS(WS-IDX)
                       OR WS-RA-OUT-CREDITS(WS-IDX)
                           NOT = WS-RA-CALC-CREDITS(WS-IDX)
                       OR WS-RA-OUT-COUNT(WS-IDX)
                           NOT = WS-RA-CALC-COUNT(WS-IDX)
                       ADD 1 TO WS-ACCOUNT-MISMATCHES END-ADD
                   END-IF
               END-PERFORM
               IF WS-ACCOUNT-MISMATCHES > 0
                   MOVE "ONE OR MORE ACCOUNT BALANCES DO NOT RECONCILE"
                       TO WS-DETAIL-ACCOUNT
                   MOVE "FAIL" TO WS-CHECK-ACCOUNT
               ELSE
                   MOVE "ACCOUNT BALANCES AND MOVEMENTS RECONCILE"
                       TO WS-DETAIL-ACCOUNT
               END-IF
           END-IF.

       CHECK-COUNTS.
           IF WS-CONTROL-INPUT-FOUND NOT = "Y"
               OR WS-CONTROL-ACCEPTED-FOUND NOT = "Y"
               OR WS-CONTROL-REJECTED-FOUND NOT = "Y"
               OR WS-CONTROL-LEDGER-FOUND NOT = "Y"
               OR WS-CONTROL-ACCOUNT-FOUND NOT = "Y"
               OR WS-CONTROL-ACCOUNT-RECORDS-FOUND NOT = "Y"
               OR WS-CONTROL-EXCEPTION-FOUND NOT = "Y"
               MOVE "CONTROL COUNT FIELDS ARE INCOMPLETE"
                   TO WS-DETAIL-COUNT
               MOVE "FAIL" TO WS-CHECK-COUNT
               EXIT PARAGRAPH
           END-IF
           IF WS-ACCEPTED-COUNT + WS-REJECTED-COUNT
               NOT = WS-CONTROL-INPUT-COUNT
               OR WS-ACCEPTED-COUNT NOT = WS-CONTROL-ACCEPTED-COUNT
               OR WS-REJECTED-COUNT NOT = WS-CONTROL-REJECTED-COUNT
               OR WS-LEDGER-READ-COUNT NOT = WS-CONTROL-LEDGER-COUNT
               OR WS-ACCOUNT-COUNT NOT = WS-CONTROL-ACCOUNT-COUNT
               OR WS-ACCOUNT-COUNT + WS-EXCEPTION-COUNT
                   NOT = WS-CONTROL-ACCOUNT-RECORDS
               OR WS-EXCEPTION-COUNT NOT = WS-CONTROL-EXCEPTION-COUNT
               MOVE "CONTROL COUNTS DO NOT MATCH OUTPUT RECORDS"
                   TO WS-DETAIL-COUNT
               MOVE "FAIL" TO WS-CHECK-COUNT
           END-IF.

       CHECK-MOVEMENT-EQUATION.
           COMPUTE WS-NET-MOVEMENT =
               WS-CLOSING-TOTAL - WS-OPENING-TOTAL
           END-COMPUTE
           COMPUTE WS-EXPECTED-MOVEMENT =
               WS-DEPOSIT-TOTAL - WS-WITHDRAWAL-TOTAL
           END-COMPUTE
           COMPUTE WS-LEDGER-NET =
               WS-LEDGER-CREDITS - WS-LEDGER-DEBITS
           END-COMPUTE
           IF WS-NET-MOVEMENT NOT = WS-EXPECTED-MOVEMENT
               OR WS-LEDGER-NET NOT = WS-EXPECTED-MOVEMENT
               MOVE "OPENING + MOVEMENTS DOES NOT EQUAL CLOSING"
                   TO WS-DETAIL-MOVEMENT
               MOVE "FAIL" TO WS-CHECK-MOVEMENT
           END-IF.

       CHECK-LEDGER-TOTALS.
           COMPUTE WS-WORK-AMOUNT =
               WS-ACCEPTED-COUNT + WS-TRANSFER-COUNT
           END-COMPUTE
           IF WS-LEDGER-READ-COUNT NOT = WS-WORK-AMOUNT
               OR WS-LEDGER-READ-COUNT NOT = WS-CONTROL-LEDGER-COUNT
               MOVE "LEDGER ENTRY COUNT DOES NOT MATCH ACCEPTED RECORDS"
                   TO WS-DETAIL-LEDGER
               MOVE "FAIL" TO WS-CHECK-LEDGER
           END-IF.

       CHECK-TRANSFER-TOTALS.
           IF WS-TRANSFER-MISMATCHES > 0
               MOVE "TRANSFER DEBIT/CREDIT PAIRS DO NOT BALANCE"
                   TO WS-DETAIL-TRANSFER
               MOVE "FAIL" TO WS-CHECK-TRANSFER
           ELSE
               MOVE "EVERY TRANSFER HAS ONE DEBIT AND ONE CREDIT"
                   TO WS-DETAIL-TRANSFER
           END-IF.

       CHECK-REJECT-TOTALS.
           IF WS-REJECTED-COUNT NOT = WS-CONTROL-REJECTED-COUNT
               OR WS-EXCEPTION-COUNT NOT = WS-CONTROL-EXCEPTION-COUNT
               MOVE "REJECTED OR EXCEPTION COUNTS DO NOT MATCH CONTROL"
                   TO WS-DETAIL-REJECT
               MOVE "FAIL" TO WS-CHECK-REJECT
           END-IF.

      *> ------------------------------------------------------------------
       WRITE-REPORTS.
           OPEN OUTPUT SETTLEMENT-FILE
           IF WS-SETTLEMENT-FS NOT = "00"
               MOVE "S0050" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN settlement.dat" TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               EXIT PARAGRAPH
           END-IF
           OPEN OUTPUT RECON-FILE
           IF WS-RECON-FS NOT = "00"
               MOVE "S0051" TO WS-FAIL-CODE
               MOVE "UNABLE TO OPEN reconciliation.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
               CLOSE SETTLEMENT-FILE
               EXIT PARAGRAPH
           END-IF

           MOVE SPACES TO WS-OUT-LINE
           STRING "run_id|" FUNCTION TRIM(LK-RUN-ID)
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE SPACES TO WS-OUT-LINE
           STRING "process_date|" LK-PROCESS-DATE
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE SPACES TO WS-OUT-LINE
           STRING "currency|" LK-CURRENCY
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-ACCOUNT-COUNT TO WS-COUNT4-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "accounts|" WS-COUNT4-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-EXCEPTION-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "account_rejections|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-INPUT-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "input_transactions|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-ACCEPTED-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "accepted_transactions|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-REJECTED-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "rejected_transactions|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-LEDGER-READ-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "ledger_entries|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-TRANSFER-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "transfers|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE WS-DEPOSIT-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "deposits|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-WITHDRAWAL-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "withdrawals|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-TRANSFER-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "transfer_amount|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-ACCEPTED-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "accepted_amount|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-REJECTED-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "rejected_amount|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-LEDGER-DEBITS TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "ledger_debits|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-LEDGER-CREDITS TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "ledger_credits|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-OPENING-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "opening_balance|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-CLOSING-TOTAL TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "closing_balance|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE WS-NET-MOVEMENT TO WS-TOTAL-EDIT
           MOVE SPACES TO WS-OUT-LINE
           STRING "net_movement|" WS-TOTAL-EDIT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW

           MOVE SPACES TO WS-OUT-LINE
           STRING "control_check|" WS-CHECK-CONTROL
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           STRING "account_check|" WS-CHECK-ACCOUNT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           STRING "movement_check|" WS-CHECK-MOVEMENT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           STRING "count_check|" WS-CHECK-COUNT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           STRING "ledger_check|" WS-CHECK-LEDGER
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           STRING "transfer_check|" WS-CHECK-TRANSFER
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           STRING "rejected_check|" WS-CHECK-REJECT
               DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           PERFORM WRITE-SETTLEMENT-ROW
           MOVE SPACES TO WS-OUT-LINE
           IF WS-ALL-CHECKS-PASS = "Y" AND WS-FATAL-FLAG = "N"
               STRING "reconciliation_status|BALANCED"
                   DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           ELSE
               STRING "reconciliation_status|FAILED"
                   DELIMITED BY SIZE INTO WS-OUT-LINE END-STRING
           END-IF
           PERFORM WRITE-SETTLEMENT-ROW

           PERFORM WRITE-RECON-ROW-CONTROL
           PERFORM WRITE-RECON-ROW-ACCOUNT
           PERFORM WRITE-RECON-ROW-MOVEMENT
           PERFORM WRITE-RECON-ROW-COUNT
           PERFORM WRITE-RECON-ROW-LEDGER
           PERFORM WRITE-RECON-ROW-TRANSFER
           PERFORM WRITE-RECON-ROW-REJECT
           MOVE SPACES TO WS-CHECK-LINE
           IF WS-ALL-CHECKS-PASS = "Y" AND WS-FATAL-FLAG = "N"
               STRING "overall|PASS|BALANCED"
                   DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           ELSE
               STRING "overall|FAIL|RECONCILIATION FAILED"
                   DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           END-IF
           PERFORM WRITE-RECON-ROW

           CLOSE SETTLEMENT-FILE
           IF WS-SETTLEMENT-FS NOT = "00"
               MOVE "S0052" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE settlement.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF
           CLOSE RECON-FILE
           IF WS-RECON-FS NOT = "00"
               MOVE "S0053" TO WS-FAIL-CODE
               MOVE "UNABLE TO CLOSE reconciliation.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

       WRITE-SETTLEMENT-ROW.
           MOVE WS-OUT-LINE TO SETTLEMENT-BUFFER
           WRITE SETTLEMENT-BUFFER END-WRITE
           IF WS-SETTLEMENT-FS NOT = "00"
               MOVE "S0054" TO WS-FAIL-CODE
               MOVE "UNABLE TO WRITE settlement.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

       WRITE-RECON-ROW-CONTROL.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|control|" WS-CHECK-CONTROL "|"
                  FUNCTION TRIM(WS-DETAIL-CONTROL)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW-ACCOUNT.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|accounts|" WS-CHECK-ACCOUNT "|"
                  FUNCTION TRIM(WS-DETAIL-ACCOUNT)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW-MOVEMENT.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|movements|" WS-CHECK-MOVEMENT "|"
                  FUNCTION TRIM(WS-DETAIL-MOVEMENT)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW-COUNT.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|counts|" WS-CHECK-COUNT "|"
                  FUNCTION TRIM(WS-DETAIL-COUNT)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW-LEDGER.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|ledger|" WS-CHECK-LEDGER "|"
                  FUNCTION TRIM(WS-DETAIL-LEDGER)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW-TRANSFER.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|transfers|" WS-CHECK-TRANSFER "|"
                  FUNCTION TRIM(WS-DETAIL-TRANSFER)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW-REJECT.
           MOVE SPACES TO WS-CHECK-LINE
           STRING "check|rejected|" WS-CHECK-REJECT "|"
                  FUNCTION TRIM(WS-DETAIL-REJECT)
               DELIMITED BY SIZE INTO WS-CHECK-LINE END-STRING
           PERFORM WRITE-RECON-ROW.

       WRITE-RECON-ROW.
           MOVE WS-CHECK-LINE TO RECON-BUFFER
           WRITE RECON-BUFFER END-WRITE
           IF WS-RECON-FS NOT = "00"
               MOVE "S0055" TO WS-FAIL-CODE
               MOVE "UNABLE TO WRITE reconciliation.dat"
                   TO WS-FAIL-DETAIL
               PERFORM SET-FATAL
           END-IF.

      *> ------------------------------------------------------------------
       PARSE-SIGNED-AMOUNT.
           MOVE "N" TO WS-AMT-OK
           IF WS-AMT-TEXT(1:1) = "+" OR WS-AMT-TEXT(1:1) = "-"
               IF WS-AMT-TEXT(2:9) IS NUMERIC
                   AND WS-AMT-TEXT(11:1) = "."
                   AND WS-AMT-TEXT(12:2) IS NUMERIC
                   COMPUTE WS-AMT-VALUE =
                       FUNCTION NUMVAL(WS-AMT-TEXT)
                   END-COMPUTE
                   MOVE "Y" TO WS-AMT-OK
               END-IF
           END-IF.

       SET-FATAL.
           MOVE "Y" TO WS-FATAL-FLAG
           MOVE 12 TO WS-FAIL-RC.

       POPULATE-RESULT.
           IF WS-FATAL-FLAG = "Y"
               MOVE 12 TO SET-RC
               MOVE "FAILED" TO SET-STATUS
               MOVE WS-FAIL-CODE TO SET-ERROR-CODE
               MOVE WS-FAIL-DETAIL TO SET-ERROR-DETAIL
           ELSE
               IF WS-ALL-CHECKS-PASS = "Y"
                   MOVE 0 TO SET-RC
                   MOVE "SUCCESS" TO SET-STATUS
                   MOVE SPACES TO SET-ERROR-CODE SET-ERROR-DETAIL
               ELSE
                   MOVE 8 TO SET-RC
                   MOVE "FAILED" TO SET-STATUS
                   MOVE "R0001" TO SET-ERROR-CODE
                   MOVE "RECONCILIATION CHECKS FAILED"
                       TO SET-ERROR-DETAIL
               END-IF
           END-IF
           COMPUTE WS-INPUT-COUNT =
               WS-ACCEPTED-COUNT + WS-REJECTED-COUNT
           END-COMPUTE
           MOVE WS-ACCOUNT-COUNT TO SET-ACCOUNT-COUNT
           MOVE WS-INPUT-COUNT TO SET-INPUT-COUNT
           MOVE WS-ACCEPTED-COUNT TO SET-ACCEPTED-COUNT
           MOVE WS-REJECTED-COUNT TO SET-REJECTED-COUNT
           MOVE WS-LEDGER-READ-COUNT TO SET-LEDGER-COUNT
           MOVE WS-TRANSFER-COUNT TO SET-TRANSFER-COUNT
           MOVE WS-DEPOSIT-TOTAL TO SET-DEPOSIT-TOTAL
           MOVE WS-WITHDRAWAL-TOTAL TO SET-WITHDRAWAL-TOTAL
           MOVE WS-TRANSFER-TOTAL TO SET-TRANSFER-TOTAL
           MOVE WS-ACCEPTED-TOTAL TO SET-ACCEPTED-TOTAL
           MOVE WS-REJECTED-TOTAL TO SET-REJECTED-TOTAL
           MOVE WS-LEDGER-DEBITS TO SET-LEDGER-DEBITS
           MOVE WS-LEDGER-CREDITS TO SET-LEDGER-CREDITS
           MOVE WS-OPENING-TOTAL TO SET-OPENING-TOTAL
           MOVE WS-CLOSING-TOTAL TO SET-CLOSING-TOTAL
           MOVE WS-NET-MOVEMENT TO SET-NET-MOVEMENT
           MOVE WS-CHECK-ACCOUNT TO SET-BALANCE-STATUS
           MOVE WS-CHECK-MOVEMENT TO SET-MOVEMENT-STATUS
           MOVE WS-CHECK-COUNT TO SET-COUNT-STATUS
           MOVE WS-CHECK-LEDGER TO SET-LEDGER-STATUS
           MOVE WS-CHECK-TRANSFER TO SET-TRANSFER-STATUS
           MOVE WS-CHECK-REJECT TO SET-REJECT-STATUS
           IF WS-ALL-CHECKS-PASS = "Y" AND WS-FATAL-FLAG = "N"
               MOVE "BALANCED" TO SET-RECON-STATUS
           ELSE
               MOVE "FAILED" TO SET-RECON-STATUS
           END-IF.
