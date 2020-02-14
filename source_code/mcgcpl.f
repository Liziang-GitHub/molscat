      SUBROUTINE MCGCPL(N,MXLAM,NHAM,LAM,NSTATE,JSTATE,JSINDX,L,MVALUE,
     1                  ITYPE,IEX,VL,IV,IPRINT,ATAU)
C  Copyright (C) 2020 J. M. Hutson & C. R. Le Sueur
C  Distributed under the GNU General Public License, version 3
C
C  THIS SUBROUTINE CALLS VARIOUS COUPLING SUBROUTINES TO WORK OUT
C  THE COUPLING MATRIX ELEMENTS FOR VARIOUS DIFFERENT ITYPES USING THE
C  COUPLED STATES APPROXIMATION (IADD=20)
C
C  MODIFIED FOR ITYPE=4 BY S Green 29 JUN 94
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      SAVE LFIRST
      INTEGER IPRINT
      INTEGER LAM(2),JSTATE(NSTATE,3),JSINDX(2),L(2),IV(1)
      DIMENSION VL(2),ATAU(*)
      LOGICAL LFIRST
C
      COMMON /VLFLAG/ IVLFL
C
      DATA SQRTHF /.70710678118654753D0/, Z0 /0.D0/
C  STATEMENT FUNCTION DEFINITION . . .
      Z(I)=DBLE(I+I+1)
C
      IF (ITYPE.EQ.21) GOTO 1000
      IF (ITYPE.EQ.22) GOTO 2000
      IF (ITYPE.EQ.23) GOTO 3000
      IF (ITYPE.EQ.24) GOTO 4000
      IF (ITYPE.EQ.25) GOTO 5000
      IF (ITYPE.EQ.26) GOTO 6000
      IF (ITYPE.EQ.27) GOTO 7000
      STOP
C
 1000 IF (IVLFL.NE.0) GOTO 9999
      CALL CPL21(N,MXLAM,LAM,NSTATE,JSTATE,JSINDX,MVALUE,
     1           VL,IPRINT,LFIRST)
      RETURN
C
 2000 IF (IVLFL.LE.0) GOTO 9999
      CALL CPL22(N,MXLAM,NHAM,LAM,NSTATE,JSTATE,JSINDX,MVALUE,IV,
     1           VL,IPRINT,LFIRST)
      RETURN
C
 3000 IF (IVLFL.NE.0) GOTO 9999
      CALL CPL23(N,MXLAM,LAM,NSTATE,JSTATE,JSINDX,L,MVALUE,IEX,
     1           VL,IPRINT,LFIRST)
      RETURN
C
 4000 CALL CPL24(N,MXLAM,LAM,NSTATE,JSTATE,JSINDX,MVALUE,ATAU,
     1           VL,IPRINT,LFIRST)
      RETURN
C
 5000 IF (IVLFL.NE.0) GOTO 9999
      CALL CPL25(N,MXLAM,LAM,NSTATE,JSTATE,JSINDX,MVALUE,
     1           VL,IPRINT,LFIRST)
      RETURN
C
 6000 CALL CPL26(N,MXLAM,LAM,NSTATE,JSTATE,JSINDX,MVALUE,ATAU,
     1           VL,IPRINT,LFIRST)
      RETURN
C
 7000 IF (IVLFL.LE.0) GOTO 9999
      XM=DBLE(MVALUE)
      NZERO=NHAM*N*(N+1)/2
      DO 1547 I=1,NZERO
        IV(I)=0
 1547   VL(I)=0.D0
      NZERO=0
      DO 1517 LL=1,MXLAM
        LLL=LAM(5*LL-4)
        NV=LAM(5*LL-3)
        NJ=LAM(5*LL-2)
        NV1=LAM(5*LL-1)
        NJ1=LAM(5*LL)
        NNZ=0
        II=0
        DO 1507 ICOL=1,N
          NVC=JSTATE(JSINDX(ICOL),2)
          NJC=JSTATE(JSINDX(ICOL),1)
        DO 1507 IROW=1,ICOL
          NVR=JSTATE(JSINDX(IROW),2)
          NJR=JSTATE(JSINDX(IROW),1)
          II=II+1
          IF (.NOT.((NV.EQ.NVC .AND. NJ.EQ.NJC .AND.
     1               NV1.EQ.NVR .AND. NJ1.EQ.NJR) .OR.
     2              (NV.EQ.NVR .AND. NJ.EQ.NJR .AND.
     3               NV1.EQ.NVC .AND. NJ1.EQ.NJC))) GOTO 1507
          I=(II-1)*NHAM+LLL+1
          VL(I)=PARSGN(MVALUE)*SQRT(Z(NJR)*Z(NJC))*
     1          THREEJ(NJR,LLL,NJC)*
     2          THRJ(DBLE(NJR),DBLE(LLL),DBLE(NJC),-XM,Z0,XM)
          IV(I)=LL
          IF (VL(I).NE.0.D0) NNZ=NNZ+1
 1507   CONTINUE
        IF (NNZ.GT.0) GOTO 1517
        IF (IPRINT.GE.14) WRITE(6,612) MVALUE,LL
        NZERO=NZERO+1
 1517 CONTINUE

      IF (NZERO.GT.0 .AND. IPRINT.GE.10 .AND. IPRINT.LT.14)
     1  WRITE(6,620) MVALUE,NZERO
      RETURN
C
 9999 WRITE(6,699) IVLFL,ITYPE
  699 FORMAT(/'  MCGCPL (JAN 93).  IVLFL =',I6,
     1        '  INCONSISTENT WITH ITYPE =',I6)
      STOP
C
  612 FORMAT(/'  * * * NOTE.  FOR MVALUE, LAM =',2I4,'   ALL COUPLING ',
     1       'COEFFICIENTS ARE ZERO.')
  620 FORMAT(/'  * * * NOTE.  FOR MVALUE =',I4,'   ALL COUPLING ',
     1      'COEFFICIENTS ARE ZERO FOR',I5,' POTENTIAL SYMMETRY TYPES.')
C
      ENTRY MCGCPX
      LFIRST=.TRUE.
      RETURN
      END
