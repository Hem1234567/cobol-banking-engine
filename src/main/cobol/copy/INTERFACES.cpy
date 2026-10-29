      *> CALL interfaces shared by the modular COBOL programs.

       01  VALIDATION-RESULT.
           05  VLR-OK             PIC X(01).
           05  VAL-ERROR-CODE         PIC X(06).
           05  VAL-ERROR-DETAIL       PIC X(48).
           05  VAL-TYPE               PIC X(10).
           05  VAL-AMOUNT             PIC S9(9)V99 COMP-3.
           05  VAL-AMOUNT-TEXT        PIC X(13).
           05  VAL-SRC-INDEX          PIC 9(04) COMP.
           05  VAL-DST-INDEX          PIC 9(04) COMP.

       01  PROCESS-RESULT.
           05  PROC-STATUS            PIC X(01).
           05  PROC-ERROR-CODE        PIC X(06).
           05  PROC-ERROR-DETAIL      PIC X(48).
           05  PROC-LEDGER-COUNT      PIC 9(01) COMP.
           05  PROC-LEDGER-ENTRY OCCURS 2 TIMES.
               10  PLE-ENTRY-TYPE     PIC X(06).
               10  PLE-ACCOUNT-ID     PIC X(10).
               10  PLE-COUNTERPARTY   PIC X(10).
               10  PLE-AMOUNT-TEXT    PIC X(13).

       01  SETTLEMENT-RESULT.
           05  SET-RC                 PIC 9(02) COMP.
           05  SET-STATUS             PIC X(08).
           05  SET-ERROR-CODE         PIC X(06).
           05  SET-ERROR-DETAIL       PIC X(120).
           05  SET-ACCOUNT-COUNT      PIC 9(04) COMP.
           05  SET-INPUT-COUNT        PIC 9(06) COMP.
           05  SET-ACCEPTED-COUNT     PIC 9(06) COMP.
           05  SET-REJECTED-COUNT     PIC 9(06) COMP.
           05  SET-LEDGER-COUNT       PIC 9(08) COMP.
           05  SET-TRANSFER-COUNT     PIC 9(06) COMP.
           05  SET-DEPOSIT-TOTAL      PIC S9(13)V99 COMP-3.
           05  SET-WITHDRAWAL-TOTAL   PIC S9(13)V99 COMP-3.
           05  SET-TRANSFER-TOTAL     PIC S9(13)V99 COMP-3.
           05  SET-ACCEPTED-TOTAL     PIC S9(13)V99 COMP-3.
           05  SET-REJECTED-TOTAL     PIC S9(13)V99 COMP-3.
           05  SET-LEDGER-DEBITS      PIC S9(13)V99 COMP-3.
           05  SET-LEDGER-CREDITS     PIC S9(13)V99 COMP-3.
           05  SET-OPENING-TOTAL      PIC S9(13)V99 COMP-3.
           05  SET-CLOSING-TOTAL      PIC S9(13)V99 COMP-3.
           05  SET-NET-MOVEMENT       PIC S9(13)V99 COMP-3.
           05  SET-BALANCE-STATUS     PIC X(04).
           05  SET-MOVEMENT-STATUS    PIC X(04).
           05  SET-COUNT-STATUS       PIC X(04).
           05  SET-LEDGER-STATUS      PIC X(04).
           05  SET-TRANSFER-STATUS    PIC X(04).
           05  SET-REJECT-STATUS      PIC X(04).
           05  SET-RECON-STATUS       PIC X(08).

       01  REPORT-RESULT.
           05  RPT-RC                 PIC 9(02) COMP.
           05  RPT-ERROR              PIC X(100).
