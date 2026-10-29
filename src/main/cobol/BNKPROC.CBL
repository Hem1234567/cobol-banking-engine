      >>SOURCE FORMAT FREE
      *> ------------------------------------------------------------------
      *> BNKPROC - applies a validated transaction to in-memory accounts.
      *>
      *> Inputs (CALL ... USING):
      *>   TRANSACTION-FILE-RECORD  original transaction record
      *>   ACCOUNT-TABLE             loaded account master
      *>   VALIDATION-RESULT         output of BNKVALID
      *>
      *> Output:
      *>   PROCESS-RESULT            status, error, and 1-2 ledger entries
      *>
      *> Invariants:
      *>   * Funds are checked before any account field is changed.
      *>   * A rejected transaction performs no assignments to ACCOUNT-TABLE.
      *>   * A transfer produces equal DEBIT and CREDIT entries.
      *>   * COMP-3 decimal arithmetic is used for every monetary update.
      *> The program performs no file I/O.
      *> ------------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNKPROC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC-AFTER              PIC S9(13)V99 COMP-3.
       01  WS-DST-AFTER              PIC S9(13)V99 COMP-3.

       LINKAGE SECTION.
       COPY "TRANSACT.cpy".
       COPY "ACCOUNT.cpy".
       COPY "INTERFACES.cpy".

       PROCEDURE DIVISION USING TRANSACTION-FILE-RECORD
                                ACCOUNT-TABLE
                                VALIDATION-RESULT
                                PROCESS-RESULT.
       APPLY-TRANSACTION.
           INITIALIZE PROCESS-RESULT
           MOVE "N" TO PROC-STATUS

           IF VLR-OK NOT = "Y"
               MOVE "E0017" TO PROC-ERROR-CODE
               MOVE "TRANSACTION DID NOT PASS VALIDATION"
                   TO PROC-ERROR-DETAIL
               GOBACK
           END-IF
           IF VAL-AMOUNT <= 0
               MOVE "E0006" TO PROC-ERROR-CODE
               MOVE "AMOUNT MUST BE STRICTLY POSITIVE"
                   TO PROC-ERROR-DETAIL
               GOBACK
           END-IF
           IF VAL-SRC-INDEX < 1 OR VAL-SRC-INDEX > 1000
               MOVE "E0018" TO PROC-ERROR-CODE
               MOVE "SOURCE INDEX OUT OF RANGE" TO PROC-ERROR-DETAIL
               GOBACK
           END-IF

           EVALUATE VAL-TYPE
               WHEN "DEPOSIT"
                   PERFORM PROCESS-DEPOSIT
               WHEN "WITHDRAWAL"
                   PERFORM PROCESS-WITHDRAWAL
               WHEN "TRANSFER"
                   PERFORM PROCESS-TRANSFER
               WHEN OTHER
                   MOVE "E0004" TO PROC-ERROR-CODE
                   MOVE "UNSUPPORTED TRANSACTION TYPE" TO PROC-ERROR-DETAIL
           END-EVALUATE

           GOBACK.

      *> ------------------------------------------------------------------
       PROCESS-DEPOSIT.
           IF ACT-STATUS(VAL-SRC-INDEX) NOT = "A"
               MOVE "E0010" TO PROC-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS CLOSED" TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-SRC-AFTER =
               ACT-BALANCE(VAL-SRC-INDEX) + VAL-AMOUNT
           END-COMPUTE
           IF WS-SRC-AFTER > 999999999.99
               MOVE "E0016" TO PROC-ERROR-CODE
               MOVE "BALANCE EXCEEDS SUPPORTED MAXIMUM"
                   TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF

           ADD VAL-AMOUNT TO ACT-BALANCE(VAL-SRC-INDEX) END-ADD
           ADD VAL-AMOUNT TO ACT-CREDITS(VAL-SRC-INDEX) END-ADD
           ADD 1 TO ACT-TXN-COUNT(VAL-SRC-INDEX) END-ADD

           MOVE 1 TO PROC-LEDGER-COUNT
           MOVE "CREDIT" TO PLE-ENTRY-TYPE(1)
           MOVE ACT-ID(VAL-SRC-INDEX) TO PLE-ACCOUNT-ID(1)
           MOVE SPACES TO PLE-COUNTERPARTY(1)
           MOVE VAL-AMOUNT-TEXT TO PLE-AMOUNT-TEXT(1)
           MOVE "Y" TO PROC-STATUS.

       PROCESS-WITHDRAWAL.
           IF ACT-STATUS(VAL-SRC-INDEX) NOT = "A"
               MOVE "E0010" TO PROC-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS CLOSED" TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF
           IF VAL-AMOUNT > ACT-BALANCE(VAL-SRC-INDEX)
               MOVE "E0014" TO PROC-ERROR-CODE
               MOVE "INSUFFICIENT AVAILABLE FUNDS" TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF

           SUBTRACT VAL-AMOUNT FROM ACT-BALANCE(VAL-SRC-INDEX) END-SUBTRACT
           ADD VAL-AMOUNT TO ACT-DEBITS(VAL-SRC-INDEX) END-ADD
           ADD 1 TO ACT-TXN-COUNT(VAL-SRC-INDEX) END-ADD

           MOVE 1 TO PROC-LEDGER-COUNT
           MOVE "DEBIT" TO PLE-ENTRY-TYPE(1)
           MOVE ACT-ID(VAL-SRC-INDEX) TO PLE-ACCOUNT-ID(1)
           MOVE SPACES TO PLE-COUNTERPARTY(1)
           MOVE VAL-AMOUNT-TEXT TO PLE-AMOUNT-TEXT(1)
           MOVE "Y" TO PROC-STATUS.

       PROCESS-TRANSFER.
           IF VAL-DST-INDEX < 1 OR VAL-DST-INDEX > 1000
               MOVE "E0019" TO PROC-ERROR-CODE
               MOVE "DESTINATION INDEX OUT OF RANGE"
                   TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF
           IF VAL-SRC-INDEX = VAL-DST-INDEX
               MOVE "E0015" TO PROC-ERROR-CODE
               MOVE "SOURCE AND DESTINATION MUST DIFFER"
                   TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF
           IF ACT-STATUS(VAL-SRC-INDEX) NOT = "A"
               MOVE "E0010" TO PROC-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS CLOSED" TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF
           IF ACT-STATUS(VAL-DST-INDEX) NOT = "A"
               MOVE "E0013" TO PROC-ERROR-CODE
               MOVE "DESTINATION ACCOUNT IS CLOSED"
                   TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF
           IF VAL-AMOUNT > ACT-BALANCE(VAL-SRC-INDEX)
               MOVE "E0014" TO PROC-ERROR-CODE
               MOVE "INSUFFICIENT AVAILABLE FUNDS" TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF

           COMPUTE WS-DST-AFTER =
               ACT-BALANCE(VAL-DST-INDEX) + VAL-AMOUNT
           END-COMPUTE
           IF WS-DST-AFTER > 999999999.99
               MOVE "E0016" TO PROC-ERROR-CODE
               MOVE "BALANCE EXCEEDS SUPPORTED MAXIMUM"
                   TO PROC-ERROR-DETAIL
               EXIT PARAGRAPH
           END-IF

           SUBTRACT VAL-AMOUNT FROM ACT-BALANCE(VAL-SRC-INDEX) END-SUBTRACT
           ADD VAL-AMOUNT TO ACT-BALANCE(VAL-DST-INDEX) END-ADD
           ADD VAL-AMOUNT TO ACT-DEBITS(VAL-SRC-INDEX) END-ADD
           ADD VAL-AMOUNT TO ACT-CREDITS(VAL-DST-INDEX) END-ADD
           ADD 1 TO ACT-TXN-COUNT(VAL-SRC-INDEX) END-ADD
           ADD 1 TO ACT-TXN-COUNT(VAL-DST-INDEX) END-ADD

           MOVE 2 TO PROC-LEDGER-COUNT
           MOVE "DEBIT" TO PLE-ENTRY-TYPE(1)
           MOVE ACT-ID(VAL-SRC-INDEX) TO PLE-ACCOUNT-ID(1)
           MOVE ACT-ID(VAL-DST-INDEX) TO PLE-COUNTERPARTY(1)
           MOVE VAL-AMOUNT-TEXT TO PLE-AMOUNT-TEXT(1)
           MOVE "CREDIT" TO PLE-ENTRY-TYPE(2)
           MOVE ACT-ID(VAL-DST-INDEX) TO PLE-ACCOUNT-ID(2)
           MOVE ACT-ID(VAL-SRC-INDEX) TO PLE-COUNTERPARTY(2)
           MOVE VAL-AMOUNT-TEXT TO PLE-AMOUNT-TEXT(2)
           MOVE "Y" TO PROC-STATUS.
