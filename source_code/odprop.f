      SUBROUTINE ODPROP(MXLAM,NHAM,
     1                  Y,VL,IV,EINT,CENT,P,
     2                  U,W,Q,Y1,Y2,
     3                  RSTART,RSTOP,NSTEP,DR,NODES,
     4                  ERED,EP2RU,CM2RU,RSCALE,IPRINT)
C  Copyright (C) 2020 J. M. Hutson & C. R. Le Sueur
C  Distributed under the GNU General Public License, version 3
      USE potential
C  VERSION (1/27/93) USES /MEMORY/ ..,IVLFL, ONLY TO CHECK USE OF
C  IV ARRAY.  BETTER CODE IN LOOPS 130, 230 POSSIBLE
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
C
C  ROUTINE TO SOLVE THE SINGLE CHANNEL PROBLEM USING A
C  MODIFIED LOG-DERIVATIVE ALGORITHM. THE POTENTIAL
C  EVALUATED AT THE MIDPOINT OF EACH SECTOR IS USED AS A
C  REFERENCE POTENTIAL FOR THE SECTOR.
C
C  THIS VERSION IS WRITTEN TO VECTORISE AS MUCH AS POSSIBLE
C
C  COMMON BLOCK FOR CONTROL OF USE OF PROPAGATION SCRATCH FILE
      LOGICAL IREAD,IWRITE
      COMMON /PRPSCR/ ESHIFT,ISCRU,IREAD,IWRITE

      DIMENSION U(NSTEP+1),W(NSTEP+1),Q(NSTEP+1),Y1(NSTEP+1),
     1          Y2(NSTEP+1),IDUM1(1),
     1          P(NHAM,NSTEP+1),VL(NHAM),IV(NHAM),EINT(1),CENT(1)
C
      COMMON /VLFLAG/ IVLFL
C
      IF (IVLFL.LT.0) THEN
        WRITE(6,*) ' ERROR. IVLFL.LT.0 NOT IMPLEMENTED IN ODPROP'
        STOP
      ENDIF
C
      NODES=0
C
C  THIS VERSION USES A CONSTANT STEP SIZE, DR, THROUGHOUT THE
C  PROPAGATION RANGE, BUT IS WRITTEN SO THAT THIS MAY BE EASILY
C  CHANGED (THOUGH VECTORISATION WOULD REQUIRE EXPLICIT R ARRAYS).
      NPT=NSTEP+1
      DR6=DR/6.D0
      H=DR/2.D0
      EP2CM=EP2RU/CM2RU
C
      IF (IREAD) GOTO 400
C
C  FIRST GET POTENTIAL U AT EVEN-NUMBERED POINTS
C
      R=RSTART
      DO 100 I=1,NPT
        CALL POTENL(0,MXLAM,IDUM1,R*RSCALE,P(1,I),IDUM2,IPRINT)
        DO J=1,NCONST
          P(MXLAM+J,I)=VCONST(J)/EP2CM
        ENDDO
        CALL SCAPOT(P(1,I),MXLAM)
        CALL PERTRB(R*RSCALE,P(1,I),NHAM,0)
        DO J=1,NHAM
          P(J,I)=EP2RU*P(J,I)
        ENDDO
  100   R=R+DR

C  COMPUTE THE RADIAL CONTRIBUTION TO W
C
      EINTEP=0.D0
      IF (NCONST.EQ.0) EINTEP=EINT(1)

      DO 110 I=1,NPT
  110   U(I)=EINTEP

      DO 130 J=1,NHAM
        V=VL(J)
        IF (V.EQ.0.D0) GOTO 130
        IF (IVLFL.NE.0) THEN
          IVJ=IV(J)
        ELSE
          IVJ=J
        ENDIF
        DO 120 I=1,NPT
  120     U(I)=U(I)+V*P(IVJ,I)
  130 CONTINUE

      IF (NRSQ.EQ.0) THEN
        R=RSTART
        DO 140 I=1,NPT
          RSQ=MIN(1.D0/(R*R),1.D16)
          U(I)=U(I)+CENT(1)*RSQ
  140     R=R+DR
      ENDIF
      UBEG=U(1)
C
C  NOW GET POTENTIAL W AT ODD-NUMBERED POINTS
C
      R=RSTART+H
      DO 200 I=1,NSTEP
        CALL POTENL(0,MXLAM,IDUM1,R*RSCALE,P(1,I),IDUM2,IPRINT)
        DO J=1,NCONST
          P(MXLAM+J,I)=VCONST(J)/EP2CM
        ENDDO
        CALL SCAPOT(P(1,I),MXLAM)
        CALL PERTRB(R*RSCALE,P(1,I),NHAM,0)
        DO J=1,NHAM
          P(J,I)=EP2RU*P(J,I)
        ENDDO
  200   R=R+DR

      DO 210 I=1,NSTEP
  210   W(I)=EINTEP

      DO 230 J=1,NHAM
        V=VL(J)
        IF (V.EQ.0.D0) GOTO 230
        IF (IVLFL.NE.0) THEN
          IVJ=IV(J)
        ELSE
          IVJ=J
        ENDIF
        DO 220 I=1,NPT
  220     W(I)=W(I)+V*P(IVJ,I)
  230 CONTINUE

      IF (NRSQ.EQ.0) THEN
        R=RSTART+H
        DO 240 I=1,NSTEP
          RSQ=MIN(1.D0/(R*R),1.D16)
          W(I)=W(I)+CENT(1)*RSQ
  240     R=R+DR
      ENDIF
C
C  FORM VECTOR OF CORRECTIONS U
C
      Q(1)=0.D0
      DO 310 I=2,NPT
  310   Q(I)=U(I)-W(I-1)
      QLAST=Q(NPT)*DR6
      DO 320 I=1,NSTEP
  320   U(I)=(U(I)-W(I)+Q(I))*DR6
      IF (IWRITE) WRITE(ISCRU) CENT(1),QLAST,W,U
      GOTO 500
C
  400 READ(ISCRU) CSAV,QLAST,W,U
C
C  CORRECT THE CENTRIFUGAL TERM IF DIFFERENT FROM THAT SAVED
C
C  02-08-18 CRLS: NOT SURE WHAT TO DO WITH CORRECTIONS TO
C                 CENTRIFUGAL TERM IF NRSQ>0, SO...
      IF (NRSQ.GT.0) THEN
        WRITE(6,*) ' *** CODING WORK NEEDED IN ODPROP'
        STOP
      ENDIF
C
      DC=CENT(1)-CSAV
      IF (ABS(DC).LT.1.D-8) GOTO 500
      R=RSTART+H
      DO 410 I=1,NSTEP
        Q(I)=DC/(R*R)
        W(I)=W(I)+Q(I)
  410   R=R+DR
      R=RSTART
      U(1)=U(1)+DC/(R*R)-Q(1)
      R=R+DR
      DO 420 I=2,NSTEP
        U(I)=U(I)+((DC+DC)/(R*R)-Q(I)-Q(I-1))*DR6
  420   R=R+DR
      QLAST=QLAST+(DC/(R*R)-Q(NSTEP))*DR6
C
C  NOW GET PROPAGATORS.
C  THIS LOOP REQUIRES SPECIAL TREATMENT TO VECTORISE ON CRAY
C
  500 DO 510 I=1,NSTEP
        WREF=W(I)-ERED
        FLAM=0.5D0*SQRT(ABS(WREF))
        IF (WREF.LT.0.D0) THEN
          TN=TAN(FLAM*DR)
          Y1(I)=FLAM/TN-FLAM*TN
          Y2(I)=FLAM/TN+FLAM*TN
        ELSE
          TN=TANH(FLAM*DR)
          Y1(I)=FLAM/TN+FLAM*TN
          Y2(I)=FLAM/TN-FLAM*TN
        ENDIF
        Y2(I)=Y2(I)*Y2(I)
  510   Q(I)=Y1(I)+U(I)
C
C  FINALLY DO THE PROPAGATION. THIS LOOP IS NOT VECTORISABLE,
C  SO THE WORK IN IT IS KEPT TO AN ABSOLUTE MINIMUM.
C
      DO 700 I=1,NSTEP
  700   Y=Y1(I)-Y2(I)/(Y+Q(I))
C
      Y=Y+QLAST
      RETURN
      END
