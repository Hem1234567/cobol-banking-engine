      >>SOURCE FORMAT FREE
      *> ------------------------------------------------------------------
      *> BNKMAIN - batch control for the COBOL banking and settlement engine.
      *>
      *> Responsibilities:
      *>   * read account master and daily transaction files sequentially
      *>   * reject malformed or duplicate account records
      *>   * call BNKVALID for transaction validation
      *>   * call BNKPROC to apply accepted transactions and build ledger rows
      *>   * write accepted, rejected, account-summary, ledger and control files
      *>   * call BNKSETTL for independent settlement/reconciliation
      *>   * call BNKRPT for deterministic reports
      *>   * publish a success marker only after reconciliation and reports pass
      *>
      *> Configuration is supplied through environment variables so no bank
      *> credentials, paths or dates are compiled into the program:
      *>   BNK_ACCOUNTS_FILE, BNK_TRANSACTIONS_FILE, BNK_OUTPUT_DIR,
      *>   BNK_RUN_ID, BNK_PROCESS_DATE, BNK_CURRENCY
      *>
      *> Exit codes: 0 success, 8 reconciliation/integrity failure,
      *> 12 fatal configuration, file, capacity or processing failure.
      *> ------------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNKMAIN.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCOUNT-FILE ASSIGN TO WS-ACCOUNT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCOUNT-FS.
           SELECT TRANSACTION-FILE ASSIGN TO WS-TRANSACTION-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-TRANSACTION-FS.
           SELECT ACCOUNT-EXCEPTION-FILE
               ASSIGN TO WS-ACCOUNT-EXCEPTION-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCOUNT-EXCEPTION-FS.
           SELECT ACCEPTED-FILE ASSIGN TO WS-ACCEPTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCEPTED-FS.
           SELECT REJECTED-FILE ASSIGN TO WS-REJECTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REJECTED-FS.
           SELECT LEDGER-FILE ASSIGN TO WS-LEDGER-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-LEDGER-FS.
           SELECT ACCOUNT-OUT-FILE ASSIGN TO WS-ACCOUNT-OUT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ACCOUNT-OUT-FS.
           SELECT CONTROL-FILE ASSIGN TO WS-CONTROL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-CONTROL-FS.
           SELECT LOCK-FILE ASSIGN TO WS-LOCK-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-LOCK-FS.
           SELECT STATUS-FILE ASSIGN TO WS-STATUS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-STATUS-FS.
           SELECT FAILURE-FILE ASSIGN TO WS-FAILURE-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FAILURE-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ACCOUNT-FILE.
       01  ACCOUNT-FILE-BUFFER        PIC X(4096).
       FD  TRANSACTION-FILE.
       01  TRANSACTION-FILE-BUFFER    PIC X(4096).
       FD  ACCOUNT-EXCEPTION-FILE.
       01  ACCOUNT-EXCEPTION-BUFFER   PIC X(100).
       FD  ACCEPTED-FILE.
       01  ACCEPTED-BUFFER            PIC X(100).
       FD  REJECTED-FILE.
       01  REJECTED-BUFFER            PIC X(124).
       FD  LEDGER-FILE.
       01  LEDGER-BUFFER              PIC X(100).
       FD  ACCOUNT-OUT-FILE.
       01  ACCOUNT-OUT-BUFFER         PIC X(100).
       FD  CONTROL-FILE.
       01  CONTROL-BUFFER             PIC X(300).
       FD  LOCK-FILE.
       01  LOCK-BUFFER                PIC X(300).
       FD  STATUS-FILE.
       01  STATUS-BUFFER              PIC X(300).
       FD  FAILURE-FILE.
       01  FAILURE-BUFFER             PIC X(300).

       WORKING-STORAGE SECTION.
       COPY "ACCOUNT.cpy".
       COPY "TRANSACT.cpy".
       COPY "LEDGER.cpy".
       COPY "INTERFACES.cpy".

       01  WS-ENV-ACCOUNTS           PIC X(512).
       01  WS-ENV-TRANSACTIONS       PIC X(512).
       01  WS-ENV-OUTPUT-DIR         PIC X(400).
       01  WS-ENV-RUN-ID             PIC X(50).
       01  WS-ENV-DATE               PIC X(20).
       01  WS-ENV-CURRENCY           PIC X(10).

       01  WS-ACCOUNT-PATH           PIC X(512).
       01  WS-TRANSACTION-PATH       PIC X(512).
       01  WS-ACCOUNT-EXCEPTION-PATH PIC X(512).
       01  WS-ACCEPTED-PATH          PIC X(512).
       01  WS-REJECTED-PATH          PIC X(512).
       01  WS-LEDGER-PATH            PIC X(512).
       01  WS-ACCOUNT-OUT-PATH       PIC X(512).
       01  WS-CONTROL-PATH           PIC X(512).
       01  WS-LOCK-PATH              PIC X(512).
       01  WS-STATUS-PATH            PIC X(512).
       01  WS-FAILURE-PATH           PIC X(512).

       01  WS-OUTPUT-DIR             PIC X(300).
       01  WS-RUN-ID                 PIC X(10).
       01  WS-PROCESS-DATE           PIC X(10).
       01  WS-CURRENCY               PIC X(03).

       01  WS-ACCOUNT-COUNT          PIC 9(04) COMP.
       01  WS-ID-COUNT               PIC 9(04) COMP.
       01  WS-ACCOUNT-INPUT-COUNT    PIC 9(06) COMP.
       01  WS-ACCOUNT-REJECT-COUNT   PIC 9(06) COMP.
       01  WS-INPUT-COUNT            PIC 9(06) COMP.
       01  WS-ACCEPTED-COUNT         PIC 9(06) COMP.
       01  WS-REJECTED-COUNT         PIC 9(06) COMP.
       01  WS-LEDGER-COUNT           PIC 9(08) COMP.
       01  WS-LEDGER-SEQ             PIC 9(09) COMP.

       01  WS-ACCOUNT-FS             PIC XX.
       01  WS-TRANSACTION-FS         PIC XX.
       01  WS-ACCOUNT-EXCEPTION-FS   PIC XX.
       01  WS-ACCEPTED-FS            PIC XX.
       01  WS-REJECTED-FS            PIC XX.
       01  WS-LEDGER-FS              PIC XX.
       01  WS-ACCOUNT-OUT-FS         PIC XX.
       01  WS-CONTROL-FS             PIC XX.
       01  WS-LOCK-FS                PIC XX.
       01  WS-STATUS-FS              PIC XX.
       01  WS-FAILURE-FS             PIC XX.

       01  WS-ACCOUNT-EOF            PIC X(01).
       01  WS-TRANSACTION-EOF        PIC X(01).
       01  WS-LINE-LENGTH            PIC 9(04) COMP.
       01  WS-IDX                    PIC 9(04) COMP.
       01  WS-LEDGER-IDX             PIC 9(01) COMP.
       01  WS-DUP-FOUND              PIC X(01).
       01  WS-BAL-FORMAT-OK          PIC X(01).
       01  WS-BAL-NUM                PIC 9(9)V99 COMP-3.
       01  WS-BAL-EDIT               PIC 9(9).99.
       01  WS-COUNT-EDIT             PIC 9(08).
       01  WS-SEQ-EDIT               PIC 9(06).
       01  WS-ID-FORMAT-OK           PIC X(01).

       01  WS-REJECT-CODE            PIC X(06).
       01  WS-REJECT-DETAIL          PIC X(48).
       01  WS-PROCESS-RC             PIC 9(02) COMP.
       01  WS-FAILURE-RC             PIC 9(02) COMP.
       01  WS-ERROR-CODE             PIC X(06).
       01  WS-ERROR-DETAIL           PIC X(200).
       01  WS-CONTROL-LINE           PIC X(300).
       01  WS-FAILURE-LINE           PIC X(300).
       01  WS-LOCK-LINE              PIC X(300).

       01  WS-YEAR                   PIC 9(04).
       01  WS-MONTH                  PIC 9(02).
       01  WS-DAY                    PIC 9(02).
       01  WS-MAX-DAY                PIC 9(02).
       01  WS-LEAP                   PIC X(01).
       01  WS-LEN                    PIC 9(04) COMP.
       01  WS-BAD-PIPE               PIC 9(04) COMP.

       PROCEDURE DIVISION.
       MAIN.
           PERFORM LOAD-CONFIGURATION
           PERFORM PREPARE-PATHS
           PERFORM VALIDATE-CONFIGURATION
           PERFORM CHECK-EXISTING-RUN
           PERFORM CREATE-RUN-LOCK
           PERFORM OPEN-OUTPUT-FILES
           PERFORM LOAD-ACCOUNTS
           PERFORM CLOSE-ACCOUNT-INPUT
           PERFORM PROCESS-TRANSACTIONS
           PERFORM CLOSE-TRANSACTION-INPUT
           PERFORM WRITE-ACCOUNT-SUMMARY
           PERFORM WRITE-BATCH-CONTROL
           PERFORM CLOSE-OUTPUT-FILES
           PERFORM RUN-SETTLEMENT
           PERFORM RUN-REPORTS
           PERFORM WRITE-SUCCESS-STATUS

           DISPLAY "BATCH|SUCCESS|RUN=" FUNCTION TRIM(WS-RUN-ID)
                   "|ACCEPTED=" WS-ACCEPTED-COUNT
                   "|REJECTED=" WS-REJECTED-COUNT
                   "|LEDGER=" WS-LEDGER-COUNT
               END-DISPLAY
           STOP RUN.

      *> ------------------------------------------------------------------
       LOAD-CONFIGURATION.
           INITIALIZE WS-ENV-ACCOUNTS WS-ENV-TRANSACTIONS
                      WS-ENV-OUTPUT-DIR WS-ENV-RUN-ID
                      WS-ENV-DATE WS-ENV-CURRENCY

           ACCEPT WS-ENV-ACCOUNTS FROM ENVIRONMENT "BNK_ACCOUNTS_FILE"
               END-ACCEPT
           ACCEPT WS-ENV-TRANSACTIONS FROM ENVIRONMENT
                  "BNK_TRANSACTIONS_FILE"
               END-ACCEPT
           ACCEPT WS-ENV-OUTPUT-DIR FROM ENVIRONMENT "BNK_OUTPUT_DIR"
               END-ACCEPT
           ACCEPT WS-ENV-RUN-ID FROM ENVIRONMENT "BNK_RUN_ID"
               END-ACCEPT
           ACCEPT WS-ENV-DATE FROM ENVIRONMENT "BNK_PROCESS_DATE"
               END-ACCEPT
           ACCEPT WS-ENV-CURRENCY FROM ENVIRONMENT "BNK_CURRENCY"
               END-ACCEPT

           IF WS-ENV-ACCOUNTS = SPACES
               MOVE "data/sample/accounts.dat" TO WS-ACCOUNT-PATH
           ELSE
               MOVE FUNCTION TRIM(WS-ENV-ACCOUNTS) TO WS-ACCOUNT-PATH
           END-IF
           IF WS-ENV-TRANSACTIONS = SPACES
               MOVE "data/sample/transactions.dat"
                   TO WS-TRANSACTION-PATH
           ELSE
               MOVE FUNCTION TRIM(WS-ENV-TRANSACTIONS)
                   TO WS-TRANSACTION-PATH
           END-IF
           IF WS-ENV-OUTPUT-DIR = SPACES
               MOVE "output/demo" TO WS-OUTPUT-DIR
           ELSE
               MOVE FUNCTION TRIM(WS-ENV-OUTPUT-DIR) TO WS-OUTPUT-DIR
           END-IF
           IF WS-ENV-RUN-ID = SPACES
               MOVE "DEMORUN001" TO WS-RUN-ID
           ELSE
               MOVE FUNCTION TRIM(WS-ENV-RUN-ID) TO WS-RUN-ID
           END-IF
           IF WS-ENV-DATE = SPACES
               MOVE "2026-01-15" TO WS-PROCESS-DATE
           ELSE
               MOVE FUNCTION TRIM(WS-ENV-DATE) TO WS-PROCESS-DATE
           END-IF
           IF WS-ENV-CURRENCY = SPACES
               MOVE "USD" TO WS-CURRENCY
           ELSE
               MOVE FUNCTION TRIM(WS-ENV-CURRENCY) TO WS-CURRENCY
           END-IF.

       VALIDATE-CONFIGURATION.
           MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-ENV-OUTPUT-DIR))
               TO WS-LEN
           IF WS-ENV-OUTPUT-DIR NOT = SPACES AND WS-LEN > 280
               MOVE "C0001" TO WS-ERROR-CODE
               MOVE "BNK_OUTPUT_DIR IS TOO LONG" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           IF WS-OUTPUT-DIR = SPACES
               MOVE "C0001" TO WS-ERROR-CODE
               MOVE "BNK_OUTPUT_DIR IS REQUIRED" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF

           MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-ENV-RUN-ID))
               TO WS-LEN
           IF WS-ENV-RUN-ID NOT = SPACES AND
               (WS-LEN < 1 OR WS-LEN > 10)
               MOVE "C0002" TO WS-ERROR-CODE
               MOVE "BNK_RUN_ID MUST BE 1-10 CHARACTERS"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           IF WS-RUN-ID = SPACES
               MOVE "C0002" TO WS-ERROR-CODE
               MOVE "BNK_RUN_ID IS REQUIRED" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           MOVE ZERO TO WS-BAD-PIPE
           INSPECT WS-RUN-ID TALLYING WS-BAD-PIPE FOR ALL "|"
           IF WS-BAD-PIPE > 0
               MOVE "C0002" TO WS-ERROR-CODE
               MOVE "BNK_RUN_ID MUST NOT CONTAIN A PIPE"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF

           MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-ENV-DATE))
               TO WS-LEN
           IF WS-ENV-DATE NOT = SPACES AND WS-LEN NOT = 10
               MOVE "C0003" TO WS-ERROR-CODE
               MOVE "BNK_PROCESS_DATE MUST BE YYYY-MM-DD"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           IF WS-PROCESS-DATE(5:1) NOT = "-"
               OR WS-PROCESS-DATE(8:1) NOT = "-"
               OR WS-PROCESS-DATE(1:4) IS NOT NUMERIC
               OR WS-PROCESS-DATE(6:2) IS NOT NUMERIC
               OR WS-PROCESS-DATE(9:2) IS NOT NUMERIC
               MOVE "C0003" TO WS-ERROR-CODE
               MOVE "BNK_PROCESS_DATE MUST BE YYYY-MM-DD"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           MOVE WS-PROCESS-DATE(1:4) TO WS-YEAR
           MOVE WS-PROCESS-DATE(6:2) TO WS-MONTH
           MOVE WS-PROCESS-DATE(9:2) TO WS-DAY
           IF WS-YEAR < 1900
               MOVE "C0003" TO WS-ERROR-CODE
               MOVE "BNK_PROCESS_DATE YEAR MUST BE 1900 OR LATER"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           IF WS-MONTH < 1 OR WS-MONTH > 12
               MOVE "C0003" TO WS-ERROR-CODE
               MOVE "BNK_PROCESS_DATE HAS AN INVALID MONTH"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           EVALUATE WS-MONTH
               WHEN 1 WHEN 3 WHEN 5 WHEN 7 WHEN 8 WHEN 10 WHEN 12
                   MOVE 31 TO WS-MAX-DAY
               WHEN 4 WHEN 6 WHEN 9 WHEN 11
                   MOVE 30 TO WS-MAX-DAY
               WHEN 2
                   MOVE "N" TO WS-LEAP
                   IF FUNCTION MOD(WS-YEAR, 4) = 0
                       IF FUNCTION MOD(WS-YEAR, 100) NOT = 0
                           MOVE "Y" TO WS-LEAP
                       ELSE
                           IF FUNCTION MOD(WS-YEAR, 400) = 0
                               MOVE "Y" TO WS-LEAP
                           END-IF
                       END-IF
                   END-IF
                   IF WS-LEAP = "Y"
                       MOVE 29 TO WS-MAX-DAY
                   ELSE
                       MOVE 28 TO WS-MAX-DAY
                   END-IF
           END-EVALUATE
           IF WS-DAY < 1 OR WS-DAY > WS-MAX-DAY
               MOVE "C0003" TO WS-ERROR-CODE
               MOVE "BNK_PROCESS_DATE HAS AN INVALID DAY"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF

           MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-ENV-CURRENCY))
               TO WS-LEN
           IF WS-ENV-CURRENCY NOT = SPACES AND WS-LEN NOT = 3
               MOVE "C0004" TO WS-ERROR-CODE
               MOVE "BNK_CURRENCY MUST BE THREE LETTERS"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           IF WS-CURRENCY = SPACES
               OR WS-CURRENCY(1:1) IS NOT ALPHABETIC
               OR WS-CURRENCY(2:1) IS NOT ALPHABETIC
               OR WS-CURRENCY(3:1) IS NOT ALPHABETIC
               MOVE "C0004" TO WS-ERROR-CODE
               MOVE "BNK_CURRENCY MUST BE THREE LETTERS"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

       PREPARE-PATHS.
           INITIALIZE WS-ACCOUNT-EXCEPTION-PATH WS-ACCEPTED-PATH
                      WS-REJECTED-PATH WS-LEDGER-PATH
                      WS-ACCOUNT-OUT-PATH WS-CONTROL-PATH
                      WS-LOCK-PATH WS-STATUS-PATH WS-FAILURE-PATH
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/account_exceptions.dat"
               DELIMITED BY SIZE INTO WS-ACCOUNT-EXCEPTION-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/accepted.dat"
               DELIMITED BY SIZE INTO WS-ACCEPTED-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/rejected.dat"
               DELIMITED BY SIZE INTO WS-REJECTED-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/ledger.dat"
               DELIMITED BY SIZE INTO WS-LEDGER-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/accounts_out.dat"
               DELIMITED BY SIZE INTO WS-ACCOUNT-OUT-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/batch_control.dat"
               DELIMITED BY SIZE INTO WS-CONTROL-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/run.lock"
               DELIMITED BY SIZE INTO WS-LOCK-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/run_status.dat"
               DELIMITED BY SIZE INTO WS-STATUS-PATH
           END-STRING
           STRING FUNCTION TRIM(WS-OUTPUT-DIR) "/run_failure.dat"
               DELIMITED BY SIZE INTO WS-FAILURE-PATH
           END-STRING.

      *> ------------------------------------------------------------------
       CHECK-EXISTING-RUN.
           OPEN INPUT STATUS-FILE
           EVALUATE WS-STATUS-FS
               WHEN "00"
                   CLOSE STATUS-FILE
                   DISPLAY "BATCH|REFUSED|RUN_STATUS_ALREADY_EXISTS"
                       END-DISPLAY
                   MOVE 12 TO RETURN-CODE
                   STOP RUN
               WHEN "35"
                   CONTINUE
               WHEN OTHER
                   MOVE "F0001" TO WS-ERROR-CODE
                   MOVE "UNABLE TO CHECK EXISTING RUN STATUS"
                       TO WS-ERROR-DETAIL
                   PERFORM FATAL-ERROR
           END-EVALUATE

           OPEN INPUT FAILURE-FILE
           EVALUATE WS-FAILURE-FS
               WHEN "00"
                   CLOSE FAILURE-FILE
                   DISPLAY "BATCH|REFUSED|RUN_FAILURE_ALREADY_EXISTS"
                       END-DISPLAY
                   MOVE 12 TO RETURN-CODE
                   STOP RUN
               WHEN "35"
                   CONTINUE
               WHEN OTHER
                   MOVE "F0006" TO WS-ERROR-CODE
                   MOVE "UNABLE TO CHECK EXISTING FAILURE MARKER"
                       TO WS-ERROR-DETAIL
                   PERFORM FATAL-ERROR
           END-EVALUATE

           OPEN INPUT LOCK-FILE
           EVALUATE WS-LOCK-FS
               WHEN "00"
                   CLOSE LOCK-FILE
                   DISPLAY "BATCH|REFUSED|RUN_LOCK_ALREADY_EXISTS"
                       END-DISPLAY
                   MOVE 12 TO RETURN-CODE
                   STOP RUN
               WHEN "35"
                   CONTINUE
               WHEN OTHER
                   MOVE "F0002" TO WS-ERROR-CODE
                   MOVE "UNABLE TO CHECK EXISTING RUN LOCK"
                       TO WS-ERROR-DETAIL
                   PERFORM FATAL-ERROR
           END-EVALUATE.

       CREATE-RUN-LOCK.
           OPEN OUTPUT LOCK-FILE
           IF WS-LOCK-FS NOT = "00"
               MOVE "F0003" TO WS-ERROR-CODE
               MOVE "UNABLE TO CREATE RUN LOCK (OUTPUT DIRECTORY?)"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           MOVE SPACES TO WS-LOCK-LINE
           STRING "LOCKED|run_id=" FUNCTION TRIM(WS-RUN-ID)
                  "|process_date=" FUNCTION TRIM(WS-PROCESS-DATE)
                  "|status=IN_PROGRESS"
               DELIMITED BY SIZE INTO WS-LOCK-LINE
           END-STRING
           MOVE WS-LOCK-LINE TO LOCK-BUFFER
           WRITE LOCK-BUFFER END-WRITE
           IF WS-LOCK-FS NOT = "00"
               MOVE "F0004" TO WS-ERROR-CODE
               MOVE "UNABLE TO WRITE RUN LOCK" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           CLOSE LOCK-FILE
           IF WS-LOCK-FS NOT = "00"
               MOVE "F0005" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE RUN LOCK" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

       OPEN-OUTPUT-FILES.
           OPEN OUTPUT ACCOUNT-EXCEPTION-FILE
           IF WS-ACCOUNT-EXCEPTION-FS NOT = "00"
               MOVE "F0010" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN account_exceptions.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           OPEN OUTPUT ACCEPTED-FILE
           IF WS-ACCEPTED-FS NOT = "00"
               MOVE "F0011" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN accepted.dat" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           OPEN OUTPUT REJECTED-FILE
           IF WS-REJECTED-FS NOT = "00"
               MOVE "F0012" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN rejected.dat" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           OPEN OUTPUT LEDGER-FILE
           IF WS-LEDGER-FS NOT = "00"
               MOVE "F0013" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN ledger.dat" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           OPEN OUTPUT ACCOUNT-OUT-FILE
           IF WS-ACCOUNT-OUT-FS NOT = "00"
               MOVE "F0014" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN accounts_out.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

      *> ------------------------------------------------------------------
       LOAD-ACCOUNTS.
           INITIALIZE ACCOUNT-TABLE
           MOVE ZERO TO WS-ACCOUNT-COUNT WS-ACCOUNT-INPUT-COUNT
                        WS-ACCOUNT-REJECT-COUNT
           MOVE "N" TO WS-ACCOUNT-EOF
           OPEN INPUT ACCOUNT-FILE
           IF WS-ACCOUNT-FS NOT = "00"
               MOVE "F0020" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN ACCOUNT MASTER FILE"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF

           PERFORM UNTIL WS-ACCOUNT-EOF = "Y"
               READ ACCOUNT-FILE END-READ
               EVALUATE WS-ACCOUNT-FS
                   WHEN "00"
                       PERFORM PROCESS-ACCOUNT-RECORD
                   WHEN "04"
                       PERFORM PROCESS-ACCOUNT-RECORD
                   WHEN "10"
                       MOVE "Y" TO WS-ACCOUNT-EOF
                   WHEN OTHER
                       MOVE "F0021" TO WS-ERROR-CODE
                       MOVE "ACCOUNT MASTER READ FAILED"
                           TO WS-ERROR-DETAIL
                       PERFORM FATAL-ERROR
               END-EVALUATE
           END-PERFORM.

       CLOSE-ACCOUNT-INPUT.
           CLOSE ACCOUNT-FILE
           IF WS-ACCOUNT-FS NOT = "00"
               MOVE "F0022" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE ACCOUNT MASTER FILE"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

       PROCESS-ACCOUNT-RECORD.
           ADD 1 TO WS-ACCOUNT-INPUT-COUNT END-ADD
           MOVE ACCOUNT-FILE-BUFFER TO ACCOUNT-LINE
           MOVE FUNCTION LENGTH(FUNCTION TRIM(ACCOUNT-LINE))
               TO WS-LINE-LENGTH
           IF WS-LINE-LENGTH = 0 OR WS-LINE-LENGTH > 80
               MOVE ACCOUNT-LINE(1:80) TO ACCOUNT-FILE-RECORD
               MOVE "A0001" TO WS-REJECT-CODE
               MOVE "MALFORMED OR OVER-LONG ACCOUNT RECORD"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           IF WS-LINE-LENGTH < 37
               MOVE ACCOUNT-LINE(1:80) TO ACCOUNT-FILE-RECORD
               MOVE "A0001" TO WS-REJECT-CODE
               MOVE "ACCOUNT RECORD IS TOO SHORT" TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF

           MOVE ACCOUNT-LINE(1:80) TO ACCOUNT-FILE-RECORD
           PERFORM VALIDATE-ACCOUNT.

       VALIDATE-ACCOUNT.
           IF ACF-ID(1:3) NOT = "ACC" OR ACF-ID(4:7) IS NOT NUMERIC
               MOVE "A0002" TO WS-REJECT-CODE
               MOVE "ACCOUNT ID MUST BE ACC + 7 DIGITS"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           IF ACF-CUSTOMER-REF = SPACES
               MOVE "A0007" TO WS-REJECT-CODE
               MOVE "CUSTOMER REFERENCE IS REQUIRED"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           IF ACF-STATUS NOT = "A" AND ACF-STATUS NOT = "C"
               MOVE "A0004" TO WS-REJECT-CODE
               MOVE "ACCOUNT STATUS MUST BE A OR C"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           IF ACF-TYPE NOT = "CH" AND ACF-TYPE NOT = "SV"
               MOVE "A0005" TO WS-REJECT-CODE
               MOVE "ACCOUNT TYPE MUST BE CH OR SV"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           PERFORM PARSE-ACCOUNT-BALANCE
           IF WS-BAL-FORMAT-OK NOT = "Y"
               MOVE "A0006" TO WS-REJECT-CODE
               MOVE "OPENING BALANCE MUST BE 9 DIGITS + . + 2 DIGITS"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           IF WS-BAL-NUM > 999999999.99
               MOVE "A0006" TO WS-REJECT-CODE
               MOVE "OPENING BALANCE EXCEEDS SUPPORTED MAXIMUM"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF

           MOVE "N" TO WS-DUP-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-ACCOUNT-COUNT
               IF ACT-ID(WS-IDX) = ACF-ID
                   MOVE "Y" TO WS-DUP-FOUND
               END-IF
           END-PERFORM
           IF WS-DUP-FOUND = "Y"
               MOVE "A0003" TO WS-REJECT-CODE
               MOVE "DUPLICATE ACCOUNT ID" TO WS-REJECT-DETAIL
               PERFORM REJECT-ACCOUNT
               EXIT PARAGRAPH
           END-IF
           IF WS-ACCOUNT-COUNT >= 1000
               MOVE "F0023" TO WS-ERROR-CODE
               MOVE "ACCOUNT TABLE CAPACITY EXCEEDED"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF

           ADD 1 TO WS-ACCOUNT-COUNT END-ADD
           MOVE ACF-ID TO ACT-ID(WS-ACCOUNT-COUNT)
           MOVE ACF-CUSTOMER-REF TO ACT-CUSTOMER-REF(WS-ACCOUNT-COUNT)
           MOVE ACF-STATUS TO ACT-STATUS(WS-ACCOUNT-COUNT)
           MOVE ACF-TYPE TO ACT-TYPE(WS-ACCOUNT-COUNT)
           MOVE WS-BAL-NUM TO ACT-OPENING-BAL(WS-ACCOUNT-COUNT)
           MOVE WS-BAL-NUM TO ACT-BALANCE(WS-ACCOUNT-COUNT)
           MOVE ZERO TO ACT-DEBITS(WS-ACCOUNT-COUNT)
                        ACT-CREDITS(WS-ACCOUNT-COUNT)
                        ACT-TXN-COUNT(WS-ACCOUNT-COUNT).

       PARSE-ACCOUNT-BALANCE.
           MOVE "N" TO WS-BAL-FORMAT-OK
           IF ACF-BALANCE-TEXT(1:9) IS NUMERIC
               AND ACF-BALANCE-TEXT(10:1) = "."
               AND ACF-BALANCE-TEXT(11:2) IS NUMERIC
               COMPUTE WS-BAL-NUM =
                   FUNCTION NUMVAL(ACF-BALANCE-TEXT)
               END-COMPUTE
               MOVE "Y" TO WS-BAL-FORMAT-OK
           END-IF.

       REJECT-ACCOUNT.
           ADD 1 TO WS-ACCOUNT-REJECT-COUNT END-ADD
           MOVE ACF-ID TO AEX-ID
           MOVE ACF-CUSTOMER-REF TO AEX-CUSTOMER-REF
           MOVE WS-REJECT-CODE TO AEX-ERROR-CODE
           MOVE "REJECTED" TO AEX-STATUS
           MOVE WS-REJECT-DETAIL TO AEX-DETAIL
           MOVE ACCOUNT-EXCEPTION-RECORD TO ACCOUNT-EXCEPTION-BUFFER
           WRITE ACCOUNT-EXCEPTION-BUFFER END-WRITE
           IF WS-ACCOUNT-EXCEPTION-FS NOT = "00"
               MOVE "F0024" TO WS-ERROR-CODE
               MOVE "UNABLE TO WRITE ACCOUNT EXCEPTION"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

      *> ------------------------------------------------------------------
       PROCESS-TRANSACTIONS.
           MOVE ZERO TO WS-INPUT-COUNT WS-ACCEPTED-COUNT
                        WS-REJECTED-COUNT WS-LEDGER-COUNT
                        WS-LEDGER-SEQ WS-ID-COUNT
           INITIALIZE ID-HISTORY
           MOVE "N" TO WS-TRANSACTION-EOF
           OPEN INPUT TRANSACTION-FILE
           IF WS-TRANSACTION-FS NOT = "00"
               MOVE "F0030" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN TRANSACTION FILE"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF

           PERFORM UNTIL WS-TRANSACTION-EOF = "Y"
               READ TRANSACTION-FILE END-READ
               EVALUATE WS-TRANSACTION-FS
                   WHEN "00"
                       PERFORM PROCESS-TRANSACTION-RECORD
                   WHEN "04"
                       PERFORM PROCESS-TRANSACTION-RECORD
                   WHEN "10"
                       MOVE "Y" TO WS-TRANSACTION-EOF
                   WHEN OTHER
                       MOVE "F0031" TO WS-ERROR-CODE
                       MOVE "TRANSACTION READ FAILED"
                           TO WS-ERROR-DETAIL
                       PERFORM FATAL-ERROR
               END-EVALUATE
           END-PERFORM.

       CLOSE-TRANSACTION-INPUT.
           CLOSE TRANSACTION-FILE
           IF WS-TRANSACTION-FS NOT = "00"
               MOVE "F0032" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE TRANSACTION FILE"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

       PROCESS-TRANSACTION-RECORD.
           ADD 1 TO WS-INPUT-COUNT END-ADD
           IF WS-INPUT-COUNT > 5000
               MOVE "F0033" TO WS-ERROR-CODE
               MOVE "TRANSACTION CAPACITY OF 5000 EXCEEDED"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           MOVE WS-INPUT-COUNT TO WS-SEQ-EDIT
           MOVE TRANSACTION-FILE-BUFFER TO TRANSACTION-LINE
           MOVE TRANSACTION-LINE(1:80) TO TRANSACTION-FILE-RECORD
           MOVE FUNCTION LENGTH(FUNCTION TRIM(TRANSACTION-LINE))
               TO WS-LINE-LENGTH

           PERFORM CHECK-ID-FORMAT
           IF WS-LINE-LENGTH = 0 OR WS-LINE-LENGTH > 80
               MOVE "E0001" TO WS-REJECT-CODE
               MOVE "MALFORMED OR OVER-LONG TRANSACTION RECORD"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-TRANSACTION
               PERFORM RESERVE-ID
               EXIT PARAGRAPH
           END-IF
           IF WS-LINE-LENGTH < 55
               MOVE "E0001" TO WS-REJECT-CODE
               MOVE "TRANSACTION RECORD IS TOO SHORT"
                   TO WS-REJECT-DETAIL
               PERFORM REJECT-TRANSACTION
               PERFORM RESERVE-ID
               EXIT PARAGRAPH
           END-IF

           CALL "BNKVALID" USING TRANSACTION-FILE-RECORD
                                  ACCOUNT-TABLE
                                  WS-ACCOUNT-COUNT
                                  ID-HISTORY
                                  WS-ID-COUNT
                                  VALIDATION-RESULT
           END-CALL

           IF VLR-OK = "Y"
               CALL "BNKPROC" USING TRANSACTION-FILE-RECORD
                                     ACCOUNT-TABLE
                                     VALIDATION-RESULT
                                     PROCESS-RESULT
               END-CALL
           END-IF

           IF VLR-OK = "Y" AND PROC-STATUS = "Y"
               PERFORM WRITE-LEDGER-ENTRIES
               PERFORM WRITE-ACCEPTED
           ELSE
               IF VLR-OK = "N"
                   MOVE VAL-ERROR-CODE TO WS-REJECT-CODE
                   MOVE VAL-ERROR-DETAIL TO WS-REJECT-DETAIL
               ELSE
                   MOVE PROC-ERROR-CODE TO WS-REJECT-CODE
                   MOVE PROC-ERROR-DETAIL TO WS-REJECT-DETAIL
               END-IF
               PERFORM REJECT-TRANSACTION
           END-IF
           PERFORM RESERVE-ID.

       CHECK-ID-FORMAT.
           IF TXF-ID(1:3) = "TXN" AND TXF-ID(4:9) IS NUMERIC
               MOVE "Y" TO WS-ID-FORMAT-OK
           ELSE
               MOVE "N" TO WS-ID-FORMAT-OK
           END-IF.

       RESERVE-ID.
           IF WS-ID-FORMAT-OK = "Y"
               IF WS-ID-COUNT >= 5000
                   MOVE "F0034" TO WS-ERROR-CODE
                   MOVE "TRANSACTION ID HISTORY CAPACITY EXCEEDED"
                       TO WS-ERROR-DETAIL
                   PERFORM FATAL-ERROR
               END-IF
               ADD 1 TO WS-ID-COUNT END-ADD
               MOVE TXF-ID TO ID-HISTORY-ENTRY(WS-ID-COUNT)
           END-IF.

       WRITE-LEDGER-ENTRIES.
           PERFORM VARYING WS-LEDGER-IDX FROM 1 BY 1
                   UNTIL WS-LEDGER-IDX > PROC-LEDGER-COUNT
               ADD 1 TO WS-LEDGER-SEQ END-ADD
               MOVE WS-LEDGER-SEQ TO LEDGER-SEQUENCE-TEXT
               MOVE SPACES TO LEDGER-FILE-RECORD
               STRING "LED" LEDGER-SEQUENCE-TEXT
                   DELIMITED BY SIZE INTO LGR-ID
               END-STRING
               MOVE TXF-ID TO LGR-TXN-ID
               MOVE PLE-ENTRY-TYPE(WS-LEDGER-IDX) TO LGR-ENTRY-TYPE
               MOVE PLE-ACCOUNT-ID(WS-LEDGER-IDX) TO LGR-ACCOUNT-ID
               MOVE PLE-COUNTERPARTY(WS-LEDGER-IDX)
                   TO LGR-COUNTERPARTY
               MOVE PLE-AMOUNT-TEXT(WS-LEDGER-IDX)
                   TO LGR-AMOUNT-TEXT
               MOVE WS-PROCESS-DATE TO LGR-DATE
               MOVE WS-RUN-ID TO LGR-RUN-ID
               MOVE LEDGER-FILE-RECORD TO LEDGER-BUFFER
               WRITE LEDGER-BUFFER END-WRITE
               IF WS-LEDGER-FS NOT = "00"
                   MOVE "F0035" TO WS-ERROR-CODE
                   MOVE "UNABLE TO WRITE LEDGER ENTRY"
                       TO WS-ERROR-DETAIL
                   PERFORM FATAL-ERROR
               END-IF
               ADD 1 TO WS-LEDGER-COUNT END-ADD
           END-PERFORM.

       WRITE-ACCEPTED.
           MOVE TXF-ID TO ACR-TXN-ID
           MOVE WS-SEQ-EDIT TO ACR-SEQUENCE
           MOVE VAL-TYPE TO ACR-TYPE
           MOVE TXF-SOURCE TO ACR-SOURCE
           IF VAL-TYPE = "TRANSFER"
               MOVE TXF-DEST TO ACR-DEST
           ELSE
               MOVE SPACES TO ACR-DEST
           END-IF
           MOVE VAL-AMOUNT-TEXT TO ACR-AMOUNT-TEXT
           MOVE "ACCEPTED" TO ACR-STATUS

           MOVE ACT-BALANCE(VAL-SRC-INDEX) TO WS-BAL-EDIT
           MOVE WS-BAL-EDIT TO ACR-SRC-BALANCE
           IF VAL-TYPE = "TRANSFER"
               MOVE ACT-BALANCE(VAL-DST-INDEX) TO WS-BAL-EDIT
               MOVE WS-BAL-EDIT TO ACR-DST-BALANCE
           ELSE
               MOVE SPACES TO ACR-DST-BALANCE
           END-IF
           MOVE ACCEPTED-RECORD TO ACCEPTED-BUFFER
           WRITE ACCEPTED-BUFFER END-WRITE
           IF WS-ACCEPTED-FS NOT = "00"
               MOVE "F0036" TO WS-ERROR-CODE
               MOVE "UNABLE TO WRITE ACCEPTED TRANSACTION"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           ADD 1 TO WS-ACCEPTED-COUNT END-ADD.

       REJECT-TRANSACTION.
           MOVE TXF-ID TO REJ-TXN-ID
           MOVE TXF-TYPE TO REJ-TYPE
           MOVE TXF-SOURCE TO REJ-SOURCE
           MOVE TXF-DEST TO REJ-DEST
           MOVE TXF-AMOUNT-TEXT TO REJ-AMOUNT-TEXT
           MOVE WS-REJECT-CODE TO REJ-ERROR-CODE
           MOVE "REJECTED" TO REJ-STATUS
           MOVE WS-SEQ-EDIT TO REJ-SEQUENCE
           MOVE WS-REJECT-DETAIL TO REJ-DETAIL
           MOVE REJECTED-RECORD TO REJECTED-BUFFER
           WRITE REJECTED-BUFFER END-WRITE
           IF WS-REJECTED-FS NOT = "00"
               MOVE "F0037" TO WS-ERROR-CODE
               MOVE "UNABLE TO WRITE REJECTED TRANSACTION"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           ADD 1 TO WS-REJECTED-COUNT END-ADD.

      *> ------------------------------------------------------------------
       WRITE-ACCOUNT-SUMMARY.
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-ACCOUNT-COUNT
               MOVE ACT-ID(WS-IDX) TO ACO-ID
               MOVE ACT-CUSTOMER-REF(WS-IDX) TO ACO-CUSTOMER-REF
               MOVE ACT-STATUS(WS-IDX) TO ACO-STATUS
               MOVE ACT-TYPE(WS-IDX) TO ACO-TYPE
               MOVE ACT-OPENING-BAL(WS-IDX) TO WS-BAL-EDIT
               MOVE WS-BAL-EDIT TO ACO-OPENING-TEXT
               MOVE ACT-BALANCE(WS-IDX) TO WS-BAL-EDIT
               MOVE WS-BAL-EDIT TO ACO-CLOSING-TEXT
               MOVE ACT-DEBITS(WS-IDX) TO WS-BAL-EDIT
               MOVE WS-BAL-EDIT TO ACO-DEBITS-TEXT
               MOVE ACT-CREDITS(WS-IDX) TO WS-BAL-EDIT
               MOVE WS-BAL-EDIT TO ACO-CREDITS-TEXT
               MOVE ACT-TXN-COUNT(WS-IDX) TO ACO-TXN-COUNT
               MOVE ACCOUNT-OUT-RECORD TO ACCOUNT-OUT-BUFFER
               WRITE ACCOUNT-OUT-BUFFER END-WRITE
               IF WS-ACCOUNT-OUT-FS NOT = "00"
                   MOVE "F0040" TO WS-ERROR-CODE
                   MOVE "UNABLE TO WRITE ACCOUNT SUMMARY"
                       TO WS-ERROR-DETAIL
                   PERFORM FATAL-ERROR
               END-IF
           END-PERFORM.

       WRITE-BATCH-CONTROL.
           OPEN OUTPUT CONTROL-FILE
           IF WS-CONTROL-FS NOT = "00"
               MOVE "F0041" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN batch_control.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "run_id|" FUNCTION TRIM(WS-RUN-ID)
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE SPACES TO WS-CONTROL-LINE
           STRING "process_date|" WS-PROCESS-DATE
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE SPACES TO WS-CONTROL-LINE
           STRING "currency|" WS-CURRENCY
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-ACCOUNT-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "accounts_loaded|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-ACCOUNT-REJECT-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "account_rejections|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-ACCOUNT-INPUT-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "account_records|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-INPUT-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "input_transactions|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-ACCEPTED-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "accepted_transactions|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-REJECTED-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "rejected_transactions|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           MOVE WS-LEDGER-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "ledger_entries|" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-CONTROL-ROW

           CLOSE CONTROL-FILE
           IF WS-CONTROL-FS NOT = "00"
               MOVE "F0042" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE batch_control.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

       WRITE-CONTROL-ROW.
           MOVE WS-CONTROL-LINE TO CONTROL-BUFFER
           WRITE CONTROL-BUFFER END-WRITE
           IF WS-CONTROL-FS NOT = "00"
               MOVE "F0043" TO WS-ERROR-CODE
               MOVE "UNABLE TO WRITE batch_control.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

       CLOSE-OUTPUT-FILES.
           CLOSE ACCOUNT-EXCEPTION-FILE
           IF WS-ACCOUNT-EXCEPTION-FS NOT = "00"
               MOVE "F0050" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE account_exceptions.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           CLOSE ACCEPTED-FILE
           IF WS-ACCEPTED-FS NOT = "00"
               MOVE "F0051" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE accepted.dat" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           CLOSE REJECTED-FILE
           IF WS-REJECTED-FS NOT = "00"
               MOVE "F0052" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE rejected.dat" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           CLOSE LEDGER-FILE
           IF WS-LEDGER-FS NOT = "00"
               MOVE "F0053" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE ledger.dat" TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF
           CLOSE ACCOUNT-OUT-FILE
           IF WS-ACCOUNT-OUT-FS NOT = "00"
               MOVE "F0054" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE accounts_out.dat"
                   TO WS-ERROR-DETAIL
               PERFORM FATAL-ERROR
           END-IF.

      *> ------------------------------------------------------------------
       RUN-SETTLEMENT.
           CALL "BNKSETTL" USING WS-OUTPUT-DIR
                                 WS-RUN-ID
                                 WS-PROCESS-DATE
                                 WS-CURRENCY
                                 SETTLEMENT-RESULT
           END-CALL
           IF SET-RC NOT = 0
               MOVE SET-ERROR-CODE TO WS-ERROR-CODE
               MOVE SET-ERROR-DETAIL TO WS-ERROR-DETAIL
               MOVE SET-RC TO WS-FAILURE-RC
               PERFORM FAILURE-EXIT
           END-IF
           IF SET-RECON-STATUS NOT = "BALANCED"
               MOVE "E9001" TO WS-ERROR-CODE
               MOVE "SETTLEMENT DID NOT REPORT BALANCED"
                   TO WS-ERROR-DETAIL
               MOVE 8 TO WS-FAILURE-RC
               PERFORM FAILURE-EXIT
           END-IF.

       RUN-REPORTS.
           CALL "BNKRPT" USING WS-OUTPUT-DIR
                             WS-RUN-ID
                             WS-PROCESS-DATE
                             WS-CURRENCY
                             REPORT-RESULT
           END-CALL
           IF RPT-RC NOT = 0
               MOVE "F0060" TO WS-ERROR-CODE
               MOVE RPT-ERROR TO WS-ERROR-DETAIL
               MOVE 12 TO WS-FAILURE-RC
               PERFORM FAILURE-EXIT
           END-IF.

       WRITE-SUCCESS-STATUS.
           OPEN OUTPUT STATUS-FILE
           IF WS-STATUS-FS NOT = "00"
               MOVE "F0070" TO WS-ERROR-CODE
               MOVE "UNABLE TO OPEN run_status.dat" TO WS-ERROR-DETAIL
               MOVE 12 TO WS-FAILURE-RC
               PERFORM FAILURE-EXIT
           END-IF
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "status=SUCCESS|run_id=" FUNCTION TRIM(WS-RUN-ID)
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-STATUS-ROW

           MOVE SPACES TO WS-CONTROL-LINE
           STRING "process_date=" WS-PROCESS-DATE
               "|currency=" WS-CURRENCY
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-STATUS-ROW

           MOVE WS-ACCEPTED-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "accepted_count=" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-STATUS-ROW

           MOVE WS-REJECTED-COUNT TO WS-COUNT-EDIT
           MOVE SPACES TO WS-CONTROL-LINE
           STRING "rejected_count=" WS-COUNT-EDIT
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-STATUS-ROW

           MOVE SPACES TO WS-CONTROL-LINE
           STRING "reconciliation_status=BALANCED"
               DELIMITED BY SIZE INTO WS-CONTROL-LINE
           END-STRING
           PERFORM WRITE-STATUS-ROW

           CLOSE STATUS-FILE
           IF WS-STATUS-FS NOT = "00"
               MOVE "F0071" TO WS-ERROR-CODE
               MOVE "UNABLE TO CLOSE run_status.dat"
                   TO WS-ERROR-DETAIL
               MOVE 12 TO WS-FAILURE-RC
               PERFORM FAILURE-EXIT
           END-IF.

       WRITE-STATUS-ROW.
           MOVE WS-CONTROL-LINE TO STATUS-BUFFER
           WRITE STATUS-BUFFER END-WRITE
           IF WS-STATUS-FS NOT = "00"
               MOVE "F0072" TO WS-ERROR-CODE
               MOVE "UNABLE TO WRITE run_status.dat"
                   TO WS-ERROR-DETAIL
               MOVE 12 TO WS-FAILURE-RC
               PERFORM FAILURE-EXIT
           END-IF.

      *> ------------------------------------------------------------------
       FATAL-ERROR.
           MOVE 12 TO WS-FAILURE-RC
           PERFORM FAILURE-EXIT.

       FAILURE-EXIT.
           PERFORM WRITE-FAILURE-MARKER
           PERFORM CLOSE-ALL-ON-FAILURE
           DISPLAY "BATCH|FAILED|CODE=" FUNCTION TRIM(WS-ERROR-CODE)
                   "|DETAIL=" FUNCTION TRIM(WS-ERROR-DETAIL)
               END-DISPLAY
           MOVE WS-FAILURE-RC TO RETURN-CODE
           STOP RUN.

       CLOSE-ALL-ON-FAILURE.
           CLOSE ACCOUNT-FILE
           CLOSE TRANSACTION-FILE
           CLOSE ACCOUNT-EXCEPTION-FILE
           CLOSE ACCEPTED-FILE
           CLOSE REJECTED-FILE
           CLOSE LEDGER-FILE
           CLOSE ACCOUNT-OUT-FILE
           CLOSE CONTROL-FILE
           CLOSE LOCK-FILE
           CLOSE STATUS-FILE.

       WRITE-FAILURE-MARKER.
           IF WS-ERROR-CODE = SPACES
               MOVE "E9999" TO WS-ERROR-CODE
           END-IF
           IF WS-ERROR-DETAIL = SPACES
               MOVE "UNSPECIFIED BATCH FAILURE" TO WS-ERROR-DETAIL
           END-IF
           OPEN OUTPUT FAILURE-FILE
           IF WS-FAILURE-FS = "00"
               MOVE SPACES TO WS-FAILURE-LINE
               STRING "status=FAILED|run_id=" FUNCTION TRIM(WS-RUN-ID)
                      "|process_date=" FUNCTION TRIM(WS-PROCESS-DATE)
                      "|error_code=" FUNCTION TRIM(WS-ERROR-CODE)
                      "|detail=" FUNCTION TRIM(WS-ERROR-DETAIL)
                   DELIMITED BY SIZE INTO WS-FAILURE-LINE
               END-STRING
               MOVE WS-FAILURE-LINE TO FAILURE-BUFFER
               WRITE FAILURE-BUFFER END-WRITE
               IF WS-FAILURE-FS NOT = "00"
                   DISPLAY "FATAL|UNABLE TO WRITE run_failure.dat"
                       END-DISPLAY
               END-IF
               CLOSE FAILURE-FILE
               IF WS-FAILURE-FS NOT = "00"
                   DISPLAY "FATAL|UNABLE TO CLOSE run_failure.dat"
                       END-DISPLAY
               END-IF
           ELSE
               DISPLAY "FATAL|UNABLE TO OPEN run_failure.dat|STATUS="
                       WS-FAILURE-FS
                   END-DISPLAY
           END-IF.
