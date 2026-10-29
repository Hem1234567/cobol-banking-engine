      *> Account master input/output records and the in-memory account table.
      *> All fixed records are 80 bytes on disk (LINE SEQUENTIAL adds newlines).
      *>
      *> Account input record (80):
      *>   1-10  account id          ACC#######
      *>   11-22 customer reference  non-blank text
      *>   23    status              A = active, C = closed
      *>   24-25 account type        CH = checking, SV = savings
      *>   26-37 opening balance     999999999.99 (nine digits, dot, two digits)
      *>   38-80 filler
       01  ACCOUNT-FILE-RECORD.
           05  ACF-ID                 PIC X(10).
           05  ACF-CUSTOMER-REF       PIC X(12).
           05  ACF-STATUS             PIC X(01).
           05  ACF-TYPE               PIC X(02).
           05  ACF-BALANCE-TEXT       PIC X(12).
           05  FILLER                 PIC X(43).

      *> End-of-day account summary (100):
      *>   opening, closing, debit and credit movement totals are text so the
      *>   report and reconciliation steps can consume the file without binary
      *>   or platform-specific numeric encoding.
       01  ACCOUNT-OUT-RECORD.
           05  ACO-ID                 PIC X(10).
           05  ACO-CUSTOMER-REF       PIC X(12).
           05  ACO-STATUS             PIC X(01).
           05  ACO-TYPE               PIC X(02).
           05  ACO-OPENING-TEXT       PIC X(12).
           05  ACO-CLOSING-TEXT       PIC X(12).
           05  ACO-DEBITS-TEXT        PIC X(12).
           05  ACO-CREDITS-TEXT       PIC X(12).
           05  ACO-TXN-COUNT          PIC 9(06).
           05  FILLER                 PIC X(21).

      *> Rejected account master record (100).
       01  ACCOUNT-EXCEPTION-RECORD.
           05  AEX-ID                 PIC X(10).
           05  AEX-CUSTOMER-REF       PIC X(12).
           05  AEX-ERROR-CODE         PIC X(06).
           05  AEX-STATUS             PIC X(08).
           05  AEX-DETAIL             PIC X(48).
           05  FILLER                 PIC X(16).

      *> In-memory account table. COMP-3 keeps decimal money exact; no
      *> binary floating point is used anywhere in the financial path.
       01  ACCOUNT-TABLE.
           05  ACCOUNT-ENTRY OCCURS 1000 TIMES.
               10  ACT-ID             PIC X(10).
               10  ACT-CUSTOMER-REF   PIC X(12).
               10  ACT-STATUS         PIC X(01).
               10  ACT-TYPE           PIC X(02).
               10  ACT-OPENING-BAL    PIC S9(9)V99 COMP-3.
               10  ACT-BALANCE        PIC S9(9)V99 COMP-3.
               10  ACT-DEBITS         PIC S9(9)V99 COMP-3.
               10  ACT-CREDITS        PIC S9(9)V99 COMP-3.
               10  ACT-TXN-COUNT      PIC 9(06) COMP.

      *> A 4096-byte line buffer lets the batch detect over-long records
      *> before truncating them into the 80-byte logical record.
       01  ACCOUNT-LINE               PIC X(4096).
