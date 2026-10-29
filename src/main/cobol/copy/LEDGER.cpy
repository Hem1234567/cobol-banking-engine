      *> Auditable double-sided ledger for every accepted financial movement.
      *> A transfer produces two records under the same transaction id: DEBIT
      *> on the source account and CREDIT on the destination account. Deposits
      *> and withdrawals produce one record because they represent an external
      *> cash movement rather than an internal account-to-account settlement.
      *>
      *> Ledger record (100):
      *>   1-12  ledger id        LED#########
      *>   13-24 transaction id
      *>   25-30 entry type       DEBIT / CREDIT
      *>   31-40 account id
      *>   41-50 counterparty account id (blank for external cash movements)
      *>   51-63 signed amount
      *>   64-73 processing date  YYYY-MM-DD
      *>   74-83 run id
      *>   84-100 filler
       01  LEDGER-FILE-RECORD.
           05  LGR-ID                 PIC X(12).
           05  LGR-TXN-ID             PIC X(12).
           05  LGR-ENTRY-TYPE         PIC X(06).
           05  LGR-ACCOUNT-ID         PIC X(10).
           05  LGR-COUNTERPARTY       PIC X(10).
           05  LGR-AMOUNT-TEXT        PIC X(13).
           05  LGR-DATE               PIC X(10).
           05  LGR-RUN-ID             PIC X(10).
           05  FILLER                 PIC X(17).

      *> Ledger lines are materialised by BNKMAIN after BNKPROC returns the
      *> financial effect. Keeping identifiers and output formatting in the
      *> driver leaves BNKPROC responsible for money movement, not file I/O.
       01  LEDGER-SEQUENCE-TEXT       PIC 9(09).
