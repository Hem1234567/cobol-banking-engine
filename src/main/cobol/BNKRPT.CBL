      >>SOURCE FORMAT FREE
      *> ------------------------------------------------------------------
      *> BNKRPT - deterministic report generation from batch output files.
      *>
      *> Reports:
      *>   daily_transaction_report.txt
      *>   account_balance_report.txt
      *>   exception_report.txt
      *>   settlement_report.txt
      *>   reconciliation_report.txt
      *>
      *> The program reads only files produced by BNKMAIN and BNKSETTL. It
      *> does not perform financial arithmetic; settlement totals are rendered
      *> from settlement.dat so reports cannot disagree with reconciliation.
      *> REPORT-RESULT is nonzero when an input is missing or settlement is not
      *> BALANCED. No success marker is written here.
      *> ------------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNKRPT.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SETTLEMENT-INPUT-FILE ASSIGN TO WS-SETTLEMENT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-SETTLEMENT-FS.
           SELECT RECON-INPUT-FILE ASSIGN TO WS-RECON-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-RECON-FS.
           SELECT ACCEPTED-INPUT-FILE ASSIGN TO WS-ACCEPTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCEPTED-FS.
           SELECT ACCOUNTS-INPUT-FILE ASSIGN TO WS-ACCOUNTS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCOUNTS-FS.
           SELECT REJECTED-INPUT-FILE ASSIGN TO WS-REJECTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REJECTED-FS.
           SELECT EXCEPTIONS-INPUT-FILE ASSIGN TO WS-EXCEPTIONS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-EXCEPTIONS-FS.
           SELECT REPORT-FILE ASSIGN TO WS-REPORT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REPORT-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  SETTLEMENT-INPUT-FILE.
       01  SETTLEMENT-BUFFER          PIC X(300).
       FD  RECON-INPUT-FILE.
       01  RECON-BUFFER               PIC X(300).
       FD  ACCEPTED-INPUT-FILE.
       01  ACCEPTED-BUFFER            PIC X(100).
       FD  ACCOUNTS-INPUT-FILE.
       01  ACCOUNTS-BUFFER            PIC X(100).
       FD  REJECTED-INPUT-FILE.
       01  REJECTED-BUFFER            PIC X(124).
       FD  EXCEPTIONS-INPUT-FILE.
       01  EXCEPTIONS-BUFFER          PIC X(100).
       FD  REPORT-FILE.
       01  REPORT-BUFFER              PIC X(300).

       WORKING-STORAGE SECTION.
       COPY "ACCOUNT.cpy".
       COPY "TRANSACT.cpy".

       01  WS-SETTLEMENT-PATH         PIC X(512).
       01  WS-RECON-PATH              PIC X(512).
       01  WS-ACCEPTED-PATH           PIC X(512).
       01  WS-ACCOUNTS-PATH           PIC X(512).
       01  WS-REJECTED-PATH           PIC X(512).
       01  WS-EXCEPTIONS-PATH         PIC X(512).
       01  WS-REPORT-PATH             PIC X(512).
       01  WS-REPORT-NAME             PIC X(40).

       01  WS-SETTLEMENT-FS           PIC XX.
       01  WS-RECON-FS                PIC XX.
       01  WS-ACCEPTED-FS             PIC XX.
       01  WS-ACCOUNTS-FS             PIC XX.
       01  WS-REJECTED-FS             PIC XX.
       01  WS-EXCEPTIONS-FS           PIC XX.
       01  WS-REPORT-FS               PIC XX.

       01  WS-KEY                     PIC X(40).
       01  WS-VALUE                   PIC X(240).
       01  WS-EOF                     PIC X(01).

       01  WS-SET-INPUT               PIC X(25).
       01  WS-SET-ACCOUNTS            PIC X(25).
       01  WS-SET-EXCEPTIONS          PIC X(25).
       01  WS-SET-ACCEPTED            PIC X(25).
       01  WS-SET-REJECTED            PIC X(25).
       01  WS-SET-LEDGER              PIC X(25).
       01  WS-SET-TRANSFERS           PIC X(25).
       01  WS-SET-DEPOSITS            PIC X(25).
       01  WS-SET-WITHDRAWALS         PIC X(25).
       01  WS-SET-TRANSFER-AMOUNT     PIC X(25).
       01  WS-SET-ACCEPTED-AMOUNT     PIC X(25).
       01  WS-SET-REJECTED-AMOUNT     PIC X(25).
       01  WS-SET-LEDGER-DEBITS       PIC X(25).
       01  WS-SET-LEDGER-CREDITS      PIC X(25).
       01  WS-SET-OPENING             PIC X(25).
       01  WS-SET-CLOSING             PIC X(25).
       01  WS-SET-NET-MOVEMENT        PIC X(25).
       01  WS-SET-CONTROL-CHECK       PIC X(25).
       01  WS-SET-ACCOUNT-CHECK       PIC X(25).
       01  WS-SET-MOVEMENT-CHECK      PIC X(25).
       01  WS-SET-COUNT-CHECK         PIC X(25).
       01  WS-SET-LEDGER-CHECK        PIC X(25).
       01  WS-SET-TRANSFER-CHECK      PIC X(25).
       01  WS-SET-REJECT-CHECK        PIC X(25).
       01  WS-SET-RECON-STATUS        PIC X(25).

       01  WS-REPORT-TITLE            PIC X(50).
       01  WS-REPORT-LINE             PIC X(300).
       01  WS-TRANSACTION-COUNT       PIC 9(08) COMP.
       01  WS-ACCOUNT-LINE-COUNT      PIC 9(08) COMP.
       01  WS-EXCEPTION-LINE-COUNT    PIC 9(08) COMP.
       01  WS-COUNT-EDIT              PIC 9(8).
       01  WS-RECON-LINE-COUNT        PIC 9(08) COMP.

       LINKAGE SECTION.
       01  LK-OUTPUT-DIR              PIC X(300).
       01  LK-RUN-ID                  PIC X(10).
       01  LK-PROCESS-DATE            PIC X(10).
       01  LK-CURRENCY                PIC X(03).
       COPY "INTERFACES.cpy".

       PROCEDURE DIVISION USING LK-OUTPUT-DIR LK-RUN-ID
                                LK-PROCESS-DATE LK-CURRENCY
                                REPORT-RESULT.
       GENERATE-REPORTS.
           INITIALIZE REPORT-RESULT
           MOVE "UNKNOWN" TO WS-SET-INPUT WS-SET-ACCOUNTS WS-SET-EXCEPTIONS
                             WS-SET-ACCEPTED WS-SET-REJECTED
                             WS-SET-LEDGER WS-SET-TRANSFERS
                             WS-SET-DEPOSITS WS-SET-WITHDRAWALS
                             WS-SET-TRANSFER-AMOUNT
                             WS-SET-ACCEPTED-AMOUNT
                             WS-SET-REJECTED-AMOUNT
                             WS-SET-LEDGER-DEBITS
                             WS-SET-LEDGER-CREDITS
                             WS-SET-OPENING WS-SET-CLOSING
                             WS-SET-NET-MOVEMENT
                             WS-SET-CONTROL-CHECK
                             WS-SET-ACCOUNT-CHECK
                             WS-SET-MOVEMENT-CHECK
                             WS-SET-COUNT-CHECK
                             WS-SET-LEDGER-CHECK
                             WS-SET-TRANSFER-CHECK
                             WS-SET-REJECT-CHECK
                             WS-SET-RECON-STATUS
           MOVE ZERO TO WS-TRANSACTION-COUNT
                        WS-ACCOUNT-LINE-COUNT
                        WS-EXCEPTION-LINE-COUNT
                        WS-RECON-LINE-COUNT

           PERFORM BUILD-PATHS
           PERFORM READ-SETTLEMENT
           IF RPT-RC = 0
               PERFORM DAILY-REPORT
           END-IF
           IF RPT-RC = 0
               PERFORM ACCOUNT-REPORT
           END-IF
           IF RPT-RC = 0
               PERFORM EXCEPTION-REPORT
           END-IF
           IF RPT-RC = 0
               PERFORM SETTLEMENT-REPORT
           END-IF
           IF RPT-RC = 0
               PERFORM RECONCILIATION-REPORT
           END-IF

           IF RPT-RC = 0 AND WS-SET-RECON-STATUS NOT = "BALANCED"
               MOVE 8 TO RPT-RC
               MOVE "SETTLEMENT IS NOT BALANCED; REPORTS ARE MARKED FAILED"
                   TO RPT-ERROR
           END-IF
           GOBACK.

      *> ------------------------------------------------------------------
       BUILD-PATHS.
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/settlement.dat"
               DELIMITED BY SIZE INTO WS-SETTLEMENT-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/reconciliation.dat"
               DELIMITED BY SIZE INTO WS-RECON-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/accepted.dat"
               DELIMITED BY SIZE INTO WS-ACCEPTED-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/accounts_out.dat"
               DELIMITED BY SIZE INTO WS-ACCOUNTS-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/rejected.dat"
               DELIMITED BY SIZE INTO WS-REJECTED-PATH
           END-STRING
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/account_exceptions.dat"
               DELIMITED BY SIZE INTO WS-EXCEPTIONS-PATH
           END-STRING.

       REPORT-FAIL.
           MOVE 12 TO RPT-RC
           IF RPT-ERROR = SPACES
               MOVE "REPORT INPUT OR OUTPUT FAILURE" TO RPT-ERROR
           END-IF.

       READ-SETTLEMENT.
           OPEN INPUT SETTLEMENT-INPUT-FILE
           IF WS-SETTLEMENT-FS NOT = "00"
               MOVE "MISSING settlement.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y"
               READ SETTLEMENT-INPUT-FILE END-READ
               EVALUATE WS-SETTLEMENT-FS
                   WHEN "00"
                       PERFORM PARSE-SETTLEMENT-LINE
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "UNABLE TO READ settlement.dat"
                           TO RPT-ERROR
                       PERFORM REPORT-FAIL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE SETTLEMENT-INPUT-FILE
           IF RPT-RC = 0 AND WS-SETTLEMENT-FS NOT = "00"
               MOVE "UNABLE TO CLOSE settlement.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
           END-IF.

       PARSE-SETTLEMENT-LINE.
           MOVE SPACES TO WS-KEY WS-VALUE
           UNSTRING SETTLEMENT-BUFFER DELIMITED BY "|"
               INTO WS-KEY WS-VALUE
           END-UNSTRING
           EVALUATE FUNCTION TRIM(WS-KEY)
               WHEN "input_transactions"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-INPUT
               WHEN "accounts"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-ACCOUNTS
               WHEN "account_rejections"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-EXCEPTIONS
               WHEN "accepted_transactions"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-ACCEPTED
               WHEN "rejected_transactions"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-REJECTED
               WHEN "ledger_entries"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-LEDGER
               WHEN "transfers"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-TRANSFERS
               WHEN "deposits"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-DEPOSITS
               WHEN "withdrawals"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-WITHDRAWALS
               WHEN "transfer_amount"
                   MOVE FUNCTION TRIM(WS-VALUE)
                       TO WS-SET-TRANSFER-AMOUNT
               WHEN "accepted_amount"
                   MOVE FUNCTION TRIM(WS-VALUE)
                       TO WS-SET-ACCEPTED-AMOUNT
               WHEN "rejected_amount"
                   MOVE FUNCTION TRIM(WS-VALUE)
                       TO WS-SET-REJECTED-AMOUNT
               WHEN "ledger_debits"
                   MOVE FUNCTION TRIM(WS-VALUE)
                       TO WS-SET-LEDGER-DEBITS
               WHEN "ledger_credits"
                   MOVE FUNCTION TRIM(WS-VALUE)
                       TO WS-SET-LEDGER-CREDITS
               WHEN "opening_balance"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-OPENING
               WHEN "closing_balance"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-CLOSING
               WHEN "net_movement"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-NET-MOVEMENT
               WHEN "control_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-CONTROL-CHECK
               WHEN "account_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-ACCOUNT-CHECK
               WHEN "movement_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-MOVEMENT-CHECK
               WHEN "count_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-COUNT-CHECK
               WHEN "ledger_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-LEDGER-CHECK
               WHEN "transfer_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-TRANSFER-CHECK
               WHEN "rejected_check"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-REJECT-CHECK
               WHEN "reconciliation_status"
                   MOVE FUNCTION TRIM(WS-VALUE) TO WS-SET-RECON-STATUS
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

      *> ------------------------------------------------------------------
       DAILY-REPORT.
           MOVE "daily_transaction_report.txt" TO WS-REPORT-NAME
           PERFORM OPEN-REPORT
           IF RPT-RC NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE "DAILY TRANSACTION REPORT" TO WS-REPORT-TITLE
           PERFORM WRITE-REPORT-HEADER
           MOVE "SEQ   TRANSACTION   TYPE        SOURCE      DESTINATION AMOUNT        STATUS"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE "--------------------------------------------------------------------------------"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW

           OPEN INPUT ACCEPTED-INPUT-FILE
           IF WS-ACCEPTED-FS NOT = "00"
               MOVE "MISSING accepted.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
               PERFORM CLOSE-REPORT
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y" OR RPT-RC NOT = 0
               READ ACCEPTED-INPUT-FILE END-READ
               EVALUATE WS-ACCEPTED-FS
                   WHEN "00"
                       MOVE ACCEPTED-BUFFER TO ACCEPTED-RECORD
                       ADD 1 TO WS-TRANSACTION-COUNT END-ADD
                       MOVE SPACES TO WS-REPORT-LINE
                       STRING ACR-SEQUENCE "  " ACR-TXN-ID "  "
                              FUNCTION TRIM(ACR-TYPE) "  "
                              ACR-SOURCE "  " ACR-DEST "  "
                              ACR-AMOUNT-TEXT "  " ACR-STATUS
                           DELIMITED BY SIZE INTO WS-REPORT-LINE
                       END-STRING
                       PERFORM WRITE-REPORT-ROW
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "UNABLE TO READ accepted.dat" TO RPT-ERROR
                       PERFORM REPORT-FAIL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE ACCEPTED-INPUT-FILE
           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "ACCEPTED TRANSACTIONS: " WS-SET-ACCEPTED
                  "   TOTAL AMOUNT: " WS-SET-ACCEPTED-AMOUNT
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE "END OF DAILY TRANSACTION REPORT" TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           PERFORM CLOSE-REPORT.

       ACCOUNT-REPORT.
           MOVE "account_balance_report.txt" TO WS-REPORT-NAME
           PERFORM OPEN-REPORT
           IF RPT-RC NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE "ACCOUNT BALANCE REPORT" TO WS-REPORT-TITLE
           PERFORM WRITE-REPORT-HEADER
           MOVE "ACCOUNT     CUSTOMER       STATUS TYPE OPENING      DEBITS       CREDITS      CLOSING      TXNS"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE "--------------------------------------------------------------------------------"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW

           OPEN INPUT ACCOUNTS-INPUT-FILE
           IF WS-ACCOUNTS-FS NOT = "00"
               MOVE "MISSING accounts_out.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
               PERFORM CLOSE-REPORT
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y" OR RPT-RC NOT = 0
               READ ACCOUNTS-INPUT-FILE END-READ
               EVALUATE WS-ACCOUNTS-FS
                   WHEN "00"
                       MOVE ACCOUNTS-BUFFER TO ACCOUNT-OUT-RECORD
                       ADD 1 TO WS-ACCOUNT-LINE-COUNT END-ADD
                       MOVE SPACES TO WS-REPORT-LINE
                       STRING ACO-ID "  " ACO-CUSTOMER-REF "  "
                              ACO-STATUS "    " ACO-TYPE "   "
                              ACO-OPENING-TEXT "  " ACO-DEBITS-TEXT "  "
                              ACO-CREDITS-TEXT "  " ACO-CLOSING-TEXT "  "
                              ACO-TXN-COUNT
                           DELIMITED BY SIZE INTO WS-REPORT-LINE
                       END-STRING
                       PERFORM WRITE-REPORT-ROW
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "UNABLE TO READ accounts_out.dat"
                           TO RPT-ERROR
                       PERFORM REPORT-FAIL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE ACCOUNTS-INPUT-FILE
           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "ACCOUNTS: " WS-SET-ACCOUNTS
                  "   OPENING TOTAL: " WS-SET-OPENING
                  "   CLOSING TOTAL: " WS-SET-CLOSING
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE "END OF ACCOUNT BALANCE REPORT" TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           PERFORM CLOSE-REPORT.

       EXCEPTION-REPORT.
           MOVE "exception_report.txt" TO WS-REPORT-NAME
           PERFORM OPEN-REPORT
           IF RPT-RC NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE "EXCEPTION REPORT" TO WS-REPORT-TITLE
           PERFORM WRITE-REPORT-HEADER
           MOVE "TRANSACTION  TYPE        SOURCE      DESTINATION AMOUNT        ERROR  DETAIL"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE "--------------------------------------------------------------------------------"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW

           OPEN INPUT REJECTED-INPUT-FILE
           IF WS-REJECTED-FS NOT = "00"
               MOVE "MISSING rejected.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
               PERFORM CLOSE-REPORT
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y" OR RPT-RC NOT = 0
               READ REJECTED-INPUT-FILE END-READ
               EVALUATE WS-REJECTED-FS
                   WHEN "00"
                       MOVE REJECTED-BUFFER TO REJECTED-RECORD
                       ADD 1 TO WS-EXCEPTION-LINE-COUNT END-ADD
                       MOVE SPACES TO WS-REPORT-LINE
                       STRING REJ-TXN-ID "  " FUNCTION TRIM(REJ-TYPE)
                              "  " REJ-SOURCE "  " REJ-DEST "  "
                              REJ-AMOUNT-TEXT "  " REJ-ERROR-CODE "  "
                              FUNCTION TRIM(REJ-DETAIL)
                           DELIMITED BY SIZE INTO WS-REPORT-LINE
                       END-STRING
                       PERFORM WRITE-REPORT-ROW
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "UNABLE TO READ rejected.dat" TO RPT-ERROR
                       PERFORM REPORT-FAIL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE REJECTED-INPUT-FILE
           IF WS-EXCEPTION-LINE-COUNT = 0
               MOVE "NO TRANSACTION EXCEPTIONS" TO WS-REPORT-LINE
               PERFORM WRITE-REPORT-ROW
           END-IF

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE "ACCOUNT MASTER EXCEPTIONS" TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           OPEN INPUT EXCEPTIONS-INPUT-FILE
           IF WS-EXCEPTIONS-FS NOT = "00"
               MOVE "MISSING account_exceptions.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
               PERFORM CLOSE-REPORT
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y" OR RPT-RC NOT = 0
               READ EXCEPTIONS-INPUT-FILE END-READ
               EVALUATE WS-EXCEPTIONS-FS
                   WHEN "00"
                       MOVE EXCEPTIONS-BUFFER TO ACCOUNT-EXCEPTION-RECORD
                       ADD 1 TO WS-EXCEPTION-LINE-COUNT END-ADD
                       MOVE SPACES TO WS-REPORT-LINE
                       STRING AEX-ID "  " AEX-ERROR-CODE "  "
                              AEX-STATUS "  " FUNCTION TRIM(AEX-DETAIL)
                           DELIMITED BY SIZE INTO WS-REPORT-LINE
                       END-STRING
                       PERFORM WRITE-REPORT-ROW
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "UNABLE TO READ account_exceptions.dat"
                           TO RPT-ERROR
                       PERFORM REPORT-FAIL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE EXCEPTIONS-INPUT-FILE
           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "REJECTED TRANSACTIONS: " WS-SET-REJECTED
                  "   ACCOUNT REJECTIONS: " WS-SET-EXCEPTIONS
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE "END OF EXCEPTION REPORT" TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           PERFORM CLOSE-REPORT.

       SETTLEMENT-REPORT.
           MOVE "settlement_report.txt" TO WS-REPORT-NAME
           PERFORM OPEN-REPORT
           IF RPT-RC NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE "SETTLEMENT REPORT" TO WS-REPORT-TITLE
           PERFORM WRITE-REPORT-HEADER

           MOVE SPACES TO WS-REPORT-LINE
           STRING "INPUT TRANSACTIONS      : " WS-SET-INPUT
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "ACCEPTED TRANSACTIONS   : " WS-SET-ACCEPTED
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "REJECTED TRANSACTIONS   : " WS-SET-REJECTED
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "DEPOSITS                : " WS-SET-DEPOSITS
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "WITHDRAWALS             : " WS-SET-WITHDRAWALS
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "TRANSFERS               : " WS-SET-TRANSFERS
                  " COUNT / " WS-SET-TRANSFER-AMOUNT " AMOUNT"
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "ACCEPTED VALUE          : " WS-SET-ACCEPTED-AMOUNT
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "REJECTED VALUE          : " WS-SET-REJECTED-AMOUNT
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "LEDGER ENTRIES          : " WS-SET-LEDGER
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "LEDGER DEBITS / CREDITS : " WS-SET-LEDGER-DEBITS
                  " / " WS-SET-LEDGER-CREDITS
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "OPENING / CLOSING       : " WS-SET-OPENING
                  " / " WS-SET-CLOSING
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "NET MOVEMENT            : " WS-SET-NET-MOVEMENT
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "RECONCILIATION          : " WS-SET-RECON-STATUS
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE "END OF SETTLEMENT REPORT" TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           PERFORM CLOSE-REPORT.

       RECONCILIATION-REPORT.
           MOVE "reconciliation_report.txt" TO WS-REPORT-NAME
           PERFORM OPEN-REPORT
           IF RPT-RC NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE "RECONCILIATION REPORT" TO WS-REPORT-TITLE
           PERFORM WRITE-REPORT-HEADER
           MOVE "CHECK       RESULT  DETAIL"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE "--------------------------------------------------------------------------------"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW

           OPEN INPUT RECON-INPUT-FILE
           IF WS-RECON-FS NOT = "00"
               MOVE "MISSING reconciliation.dat" TO RPT-ERROR
               PERFORM REPORT-FAIL
               PERFORM CLOSE-REPORT
               EXIT PARAGRAPH
           END-IF
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-EOF = "Y" OR RPT-RC NOT = 0
               READ RECON-INPUT-FILE END-READ
               EVALUATE WS-RECON-FS
                   WHEN "00"
                       ADD 1 TO WS-RECON-LINE-COUNT END-ADD
                       MOVE RECON-BUFFER TO WS-REPORT-LINE
                       INSPECT WS-REPORT-LINE
                           REPLACING ALL "|" BY " "
                       PERFORM WRITE-REPORT-ROW
                   WHEN "10"
                       MOVE "Y" TO WS-EOF
                   WHEN OTHER
                       MOVE "UNABLE TO READ reconciliation.dat"
                           TO RPT-ERROR
                       PERFORM REPORT-FAIL
                       MOVE "Y" TO WS-EOF
               END-EVALUATE
           END-PERFORM
           CLOSE RECON-INPUT-FILE
           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "OVERALL RECONCILIATION: " WS-SET-RECON-STATUS
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE "END OF RECONCILIATION REPORT" TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           PERFORM CLOSE-REPORT.

      *> ------------------------------------------------------------------
       OPEN-REPORT.
           MOVE SPACES TO WS-REPORT-PATH
           STRING FUNCTION TRIM(LK-OUTPUT-DIR) "/"
                  FUNCTION TRIM(WS-REPORT-NAME)
               DELIMITED BY SIZE INTO WS-REPORT-PATH
           END-STRING
           OPEN OUTPUT REPORT-FILE
           IF WS-REPORT-FS NOT = "00"
               MOVE "UNABLE TO CREATE REPORT FILE" TO RPT-ERROR
               PERFORM REPORT-FAIL
           END-IF.

       WRITE-REPORT-HEADER.
           MOVE "COBOL ENTERPRISE BANKING AND SETTLEMENT ENGINE"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE WS-REPORT-TITLE TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "RUN ID: " FUNCTION TRIM(LK-RUN-ID)
                  "   PROCESS DATE: " LK-PROCESS-DATE
                  "   CURRENCY: " LK-CURRENCY
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE SPACES TO WS-REPORT-LINE
           STRING "RECONCILIATION STATUS: "
                  FUNCTION TRIM(WS-SET-RECON-STATUS)
               DELIMITED BY SIZE INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-REPORT-ROW
           MOVE "--------------------------------------------------------------------------------"
               TO WS-REPORT-LINE
           PERFORM WRITE-REPORT-ROW.

       WRITE-REPORT-ROW.
           MOVE WS-REPORT-LINE TO REPORT-BUFFER
           WRITE REPORT-BUFFER END-WRITE
           IF WS-REPORT-FS NOT = "00"
               MOVE "UNABLE TO WRITE REPORT FILE" TO RPT-ERROR
               PERFORM REPORT-FAIL
           END-IF.

       CLOSE-REPORT.
           CLOSE REPORT-FILE
           IF RPT-RC = 0 AND WS-REPORT-FS NOT = "00"
               MOVE "UNABLE TO CLOSE REPORT FILE" TO RPT-ERROR
               PERFORM REPORT-FAIL
           END-IF.
