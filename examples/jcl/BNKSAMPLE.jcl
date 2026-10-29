//* ==================================================================
//* ILLUSTRATIVE ONLY - NOT EXECUTED LOCALLY - NOT TESTED ON z/OS
//*
//* The local COBOL code uses GnuCOBOL dynamic ASSIGN and LINE SEQUENTIAL
//* ASCII files. This JCL shows the shape of a z/OS compile/link/run job
//* after the file-control portability work described in README.md.
//* Replace HLQ, accounting, class, and site compiler procedures.
//* ==================================================================
//BANKBAT  JOB (ACCT),'COBOL BANK BATCH',CLASS=A,MSGCLASS=X,
//             NOTIFY=&SYSUID
//*
//* ------------------------------------------------------------------
//* COMPILE ONE PROGRAM (repeat for BNKVALID, BNKPROC, BNKSETTL, BNKRPT)
//* ------------------------------------------------------------------
//COMPILE  EXEC PGM=IGYCRCTL,REGION=0M,
//             PARM='LIB,SOURCE,FREE'
//SYSPRINT DD SYSOUT=*
//SYSLIB   DD DISP=SHR,DSN=&HLQ..COPYLIB
//SYSIN    DD DISP=SHR,DSN=&HLQ..COBSRC(BNKMAIN)
//SYSLIN   DD DSN=&&OBJ,DISP=(NEW,PASS),
//             SPACE=(TRK,(20,20)),UNIT=SYSDA
//*
//* ------------------------------------------------------------------
//* LINK EDIT
//* ------------------------------------------------------------------
//LINK     EXEC PGM=IEWL,COND=(4,LT,COMPILE),REGION=0M
//SYSLIB   DD DISP=SHR,DSN=&HLQ..LOADLIB
//SYSLIN   DD DISP=(OLD,DELETE),DSN=&&OBJ
//SYSLMOD  DD DISP=SHR,DSN=&HLQ..LOADLIB(BNKMAIN)
//SYSPRINT DD SYSOUT=*
//*
//* ------------------------------------------------------------------
//* LOCAL-STYLE BUSINESS STEP - DD NAMES ARE ILLUSTRATIVE
//* BNKMAIN must be changed from dynamic ASSIGN to these DD names.
//* ------------------------------------------------------------------
//RUN      EXEC PGM=BNKMAIN,COND=(4,LT,LINK),REGION=0M
//STEPLIB  DD DISP=SHR,DSN=&HLQ..LOADLIB
//ACCOUNT  DD DISP=SHR,DSN=&HLQ..BANK.ACCOUNT.MASTER
//TRANS    DD DISP=SHR,DSN=&HLQ..BANK.TRANSACTIONS
//ACCPT    DD DSN=&HLQ..BANK.ACCEPTED(+1),DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(1,1)),UNIT=SYSDA
//REJECT   DD DSN=&HLQ..BANK.REJECTED(+1),DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(1,1)),UNIT=SYSDA
//LEDGER   DD DSN=&HLQ..BANK.LEDGER(+1),DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(1,1)),UNIT=SYSDA
//ACCTOUT  DD DSN=&HLQ..BANK.ACCOUNT.OUT(+1),DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(1,1)),UNIT=SYSDA
//CONTROL  DD DSN=&HLQ..BANK.CONTROL(+1),DISP=(NEW,CATLG,DELETE),
//             SPACE=(TRK,(1,1)),UNIT=SYSDA
//SYSOUT   DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
//*
//* ------------------------------------------------------------------
//* The conditional step below is illustrative: a real installation
//* would point to its reconciliation program and report distribution.
//* ------------------------------------------------------------------
//RECON    EXEC PGM=BNKSETTL,COND=(0,NE,RUN),REGION=0M
//STEPLIB  DD DISP=SHR,DSN=&HLQ..LOADLIB
//SYSOUT   DD SYSOUT=*
//*
