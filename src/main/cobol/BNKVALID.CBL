      >>SOURCE FORMAT FREE
      *> ------------------------------------------------------------------
      *> BNKVALID - deterministic transaction validation engine.
      *>
      *> Inputs (CALL ... USING):
      *>   TRANSACTION-FILE-RECORD  parsed 80-byte input record
      *>   ACCOUNT-TABLE             loaded active/closed account master
      *>   LK-ACCOUNT-COUNT          number of loaded accounts
      *>   ID-HISTORY                previously reserved transaction ids
      *>   LK-ID-COUNT               number of reserved transaction ids
      *>
      *> Output:
      *>   VALIDATION-RESULT         status, stable error code, canonical amount,
      *>                             type and account indexes
      *>
      *> The program performs no file I/O and changes neither account balances
      *> nor the identifier history. The caller reserves the id after this call.
      *> Validation order is: id, duplicate, type, amount, required accounts,
      *> account existence/status, self-transfer, available funds.
      *> ------------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNKVALID.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TYPE-TRIMMED           PIC X(10).
       01  WS-IDX                    PIC 9(04) COMP.
       01  WS-FOUND                  PIC X(01).

       LINKAGE SECTION.
       COPY "TRANSACT.cpy".
       COPY "ACCOUNT.cpy".
       COPY "INTERFACES.cpy".

       01  LK-ACCOUNT-COUNT          PIC 9(04) COMP.
       01  LK-ID-COUNT               PIC 9(04) COMP.

       PROCEDURE DIVISION USING TRANSACTION-FILE-RECORD
                                ACCOUNT-TABLE
                                LK-ACCOUNT-COUNT
                                ID-HISTORY
                                LK-ID-COUNT
                                VALIDATION-RESULT.
       VALIDATE-TRANSACTION.
           INITIALIZE VALIDATION-RESULT
           MOVE "Y" TO VLR-OK
           MOVE SPACES TO WS-TYPE-TRIMMED
           MOVE ZERO TO VAL-SRC-INDEX VAL-DST-INDEX
           MOVE FUNCTION TRIM(TXF-TYPE) TO WS-TYPE-TRIMMED

           PERFORM VALIDATE-ID
           IF VLR-OK = "Y"
               PERFORM VALIDATE-TYPE
           END-IF
           IF VLR-OK = "Y"
               PERFORM VALIDATE-AMOUNT
           END-IF
           IF VLR-OK = "Y"
               PERFORM VALIDATE-ACCOUNTS
           END-IF

           GOBACK.

      *> ------------------------------------------------------------------
       VALIDATE-ID.
           IF TXF-ID(1:3) NOT = "TXN"
               OR TXF-ID(4:9) IS NOT NUMERIC
               MOVE "E0002" TO VAL-ERROR-CODE
               MOVE "TRANSACTION ID MUST BE TXN + 9 DIGITS"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF

           MOVE 1 TO WS-IDX
           PERFORM UNTIL WS-IDX > LK-ID-COUNT
               IF ID-HISTORY-ENTRY(WS-IDX) = TXF-ID
                   MOVE "E0003" TO VAL-ERROR-CODE
                   MOVE "DUPLICATE TRANSACTION ID" TO VAL-ERROR-DETAIL
                   PERFORM REJECT-VALIDATION
                   EXIT PERFORM
               END-IF
               ADD 1 TO WS-IDX END-ADD
           END-PERFORM.

      *> ------------------------------------------------------------------
       VALIDATE-TYPE.
           EVALUATE WS-TYPE-TRIMMED
               WHEN "DEPOSIT"
                   MOVE "DEPOSIT" TO VAL-TYPE
               WHEN "WITHDRAWAL"
                   MOVE "WITHDRAWAL" TO VAL-TYPE
               WHEN "TRANSFER"
                   MOVE "TRANSFER" TO VAL-TYPE
               WHEN OTHER
                   MOVE "E0004" TO VAL-ERROR-CODE
                   MOVE "UNSUPPORTED TRANSACTION TYPE" TO VAL-ERROR-DETAIL
                   PERFORM REJECT-VALIDATION
           END-EVALUATE.

      *> ------------------------------------------------------------------
       VALIDATE-AMOUNT.
           IF TXF-AMOUNT-TEXT(1:1) NOT = "+"
               AND TXF-AMOUNT-TEXT(1:1) NOT = "-"
               MOVE "E0005" TO VAL-ERROR-CODE
               MOVE "AMOUNT MUST MATCH [+-]DDDDDDDDD.DD"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           IF TXF-AMOUNT-TEXT(2:9) IS NOT NUMERIC
               OR TXF-AMOUNT-TEXT(11:1) NOT = "."
               OR TXF-AMOUNT-TEXT(12:2) IS NOT NUMERIC
               MOVE "E0005" TO VAL-ERROR-CODE
               MOVE "AMOUNT MUST MATCH [+-]DDDDDDDDD.DD"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF

           COMPUTE VAL-AMOUNT =
               FUNCTION NUMVAL(TXF-AMOUNT-TEXT) END-COMPUTE
           MOVE TXF-AMOUNT-TEXT TO VAL-AMOUNT-TEXT

           IF VAL-AMOUNT <= 0
               MOVE "E0006" TO VAL-ERROR-CODE
               MOVE "AMOUNT MUST BE STRICTLY POSITIVE" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           IF VAL-AMOUNT > 999999999.99
               MOVE "E0016" TO VAL-ERROR-CODE
               MOVE "AMOUNT EXCEEDS SUPPORTED MAXIMUM" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
           END-IF.

      *> ------------------------------------------------------------------
       VALIDATE-ACCOUNTS.
           EVALUATE VAL-TYPE
               WHEN "DEPOSIT"
                   PERFORM VALIDATE-DEPOSIT
               WHEN "WITHDRAWAL"
                   PERFORM VALIDATE-WITHDRAWAL
               WHEN "TRANSFER"
                   PERFORM VALIDATE-TRANSFER
           END-EVALUATE.

       VALIDATE-DEPOSIT.
           IF TXF-SOURCE = SPACES
               MOVE "E0007" TO VAL-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS REQUIRED" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           IF TXF-DEST NOT = SPACES
               MOVE "E0008" TO VAL-ERROR-CODE
               MOVE "DESTINATION MUST BE BLANK FOR THIS TYPE"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           PERFORM FIND-SOURCE
           IF VLR-OK = "Y"
               PERFORM CHECK-SOURCE-STATUS
           END-IF.

       VALIDATE-WITHDRAWAL.
           IF TXF-SOURCE = SPACES
               MOVE "E0007" TO VAL-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS REQUIRED" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           IF TXF-DEST NOT = SPACES
               MOVE "E0008" TO VAL-ERROR-CODE
               MOVE "DESTINATION MUST BE BLANK FOR THIS TYPE"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           PERFORM FIND-SOURCE
           IF VLR-OK = "Y"
               PERFORM CHECK-SOURCE-STATUS
           END-IF
           IF VLR-OK = "Y"
               PERFORM CHECK-FUNDS
           END-IF.

       VALIDATE-TRANSFER.
           IF TXF-SOURCE = SPACES
               MOVE "E0007" TO VAL-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS REQUIRED" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           IF TXF-DEST = SPACES
               MOVE "E0011" TO VAL-ERROR-CODE
               MOVE "DESTINATION ACCOUNT IS REQUIRED"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF
           IF TXF-SOURCE = TXF-DEST
               MOVE "E0015" TO VAL-ERROR-CODE
               MOVE "SOURCE AND DESTINATION MUST DIFFER"
                   TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
               EXIT PARAGRAPH
           END-IF

           PERFORM FIND-SOURCE
           IF VLR-OK = "Y"
               PERFORM CHECK-SOURCE-STATUS
           END-IF
           IF VLR-OK = "Y"
               PERFORM FIND-DEST
           END-IF
           IF VLR-OK = "Y"
               PERFORM CHECK-DEST-STATUS
           END-IF
           IF VLR-OK = "Y"
               PERFORM CHECK-FUNDS
           END-IF.

      *> ------------------------------------------------------------------
       FIND-SOURCE.
           MOVE "N" TO WS-FOUND
           MOVE 1 TO WS-IDX
           PERFORM UNTIL WS-IDX > LK-ACCOUNT-COUNT
               IF ACT-ID(WS-IDX) = TXF-SOURCE
                   MOVE WS-IDX TO VAL-SRC-INDEX
                   MOVE "Y" TO WS-FOUND
                   EXIT PERFORM
               END-IF
               ADD 1 TO WS-IDX END-ADD
           END-PERFORM
           IF WS-FOUND = "N"
               MOVE "E0009" TO VAL-ERROR-CODE
               MOVE "SOURCE ACCOUNT NOT FOUND" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
           END-IF.

       FIND-DEST.
           MOVE "N" TO WS-FOUND
           MOVE 1 TO WS-IDX
           PERFORM UNTIL WS-IDX > LK-ACCOUNT-COUNT
               IF ACT-ID(WS-IDX) = TXF-DEST
                   MOVE WS-IDX TO VAL-DST-INDEX
                   MOVE "Y" TO WS-FOUND
                   EXIT PERFORM
               END-IF
               ADD 1 TO WS-IDX END-ADD
           END-PERFORM
           IF WS-FOUND = "N"
               MOVE "E0012" TO VAL-ERROR-CODE
               MOVE "DESTINATION ACCOUNT NOT FOUND" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
           END-IF.

       CHECK-SOURCE-STATUS.
           IF ACT-STATUS(VAL-SRC-INDEX) NOT = "A"
               MOVE "E0010" TO VAL-ERROR-CODE
               MOVE "SOURCE ACCOUNT IS CLOSED" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
           END-IF.

       CHECK-DEST-STATUS.
           IF ACT-STATUS(VAL-DST-INDEX) NOT = "A"
               MOVE "E0013" TO VAL-ERROR-CODE
               MOVE "DESTINATION ACCOUNT IS CLOSED" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
           END-IF.

       CHECK-FUNDS.
           IF VAL-AMOUNT > ACT-BALANCE(VAL-SRC-INDEX)
               MOVE "E0014" TO VAL-ERROR-CODE
               MOVE "INSUFFICIENT AVAILABLE FUNDS" TO VAL-ERROR-DETAIL
               PERFORM REJECT-VALIDATION
           END-IF.

       REJECT-VALIDATION.
           MOVE "N" TO VLR-OK.
