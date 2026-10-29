      *> Daily transaction input plus accepted/rejected output records.
      *>
      *> Transaction input record (80):
      *>   1-12  transaction id      TXN#########
      *>   13-22 transaction type    DEPOSIT / WITHDRAWAL / TRANSFER (space padded)
      *>   23-32 source account id
      *>   33-42 destination account id (blank except TRANSFER)
      *>   43-55 signed amount       [+-]ddddddddd.dd  (13 bytes; + is required
      *>                             for a positive value, - denotes a negative)
      *>   56-80 filler
       01  TRANSACTION-FILE-RECORD.
           05  TXF-ID                 PIC X(12).
           05  TXF-TYPE               PIC X(10).
           05  TXF-SOURCE             PIC X(10).
           05  TXF-DEST               PIC X(10).
           05  TXF-AMOUNT-TEXT        PIC X(13).
           05  FILLER                 PIC X(25).

       01  TRANSACTION-LINE           PIC X(4096).

      *> Accepted transaction record (100).
       01  ACCEPTED-RECORD.
           05  ACR-TXN-ID             PIC X(12).
           05  ACR-SEQUENCE           PIC 9(06).
           05  ACR-TYPE               PIC X(10).
           05  ACR-SOURCE             PIC X(10).
           05  ACR-DEST               PIC X(10).
           05  ACR-AMOUNT-TEXT        PIC X(13).
           05  ACR-STATUS             PIC X(08).
           05  ACR-SRC-BALANCE        PIC X(12).
           05  ACR-DST-BALANCE        PIC X(12).
           05  FILLER                 PIC X(07).

      *> Rejected transaction record (124).
       01  REJECTED-RECORD.
           05  REJ-TXN-ID             PIC X(12).
           05  REJ-TYPE               PIC X(10).
           05  REJ-SOURCE             PIC X(10).
           05  REJ-DEST               PIC X(10).
           05  REJ-AMOUNT-TEXT        PIC X(13).
           05  REJ-ERROR-CODE         PIC X(06).
           05  REJ-STATUS             PIC X(08).
           05  REJ-SEQUENCE           PIC 9(06).
           05  REJ-DETAIL             PIC X(48).
           05  FILLER                 PIC X(01).

      *> At most 5000 transaction identifiers are accepted by a batch. The
      *> identifiers are reserved at first appearance, including rejected
      *> attempts, so replaying an identifier can never apply funds twice.
       01  ID-HISTORY.
           05  ID-HISTORY-ENTRY OCCURS 5000 TIMES PIC X(12).
