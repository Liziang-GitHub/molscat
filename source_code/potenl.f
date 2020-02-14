      SUBROUTINE POTENL(ICNTRL, MXLMB, LAM, R, P, ITYPE, IPRINT)
C  Copyright (C) 2020 J. M. Hutson & C. R. Le Sueur
C  Distributed under the GNU General Public License, version 3
      USE angles
      USE potential, ONLY: LAMBDA, MXLMDA, EPNAME, RMNAME
C
C  -----------------------------------------------------------------
C  * GENERAL POTENL ROUTINE; DESCRIPTION OF FUNCTIONS:
C  -----------------------------------------------------------------
C  VERSION 14 IMPLEMENTS THREE OPTIONS FOR DESCRIBING THE POT'L
C    1. POT'L EXPANDED IN ANGULAR FUNCTIONS - SYMMETRIES DESCRIBED
C       BY MXLAM,LAMBDA INPUT, RADIAL COEFFS DESCRIBED BY INPUT
C       POWERS AND EXPONENTIALS *OR* VSTAR MECHANISM.
C       THIS IS THE ORIGINAL MOLSCAT OPTION.
C       MXLAM.GT.0 MUST BE INPUT AND LVRTP MUST BE .FALSE. (DEFAULT)
C    2. POT'L EXPANDED IN ANGULAR FUNCTIONS - PROJECTED VIA VRTP
C       MECHANISM.  SYMMETRIES MAY BE DESCRIBED *EITHER* BY
C       A.) SYMMETRY DESCRIPTIONS INPUT VIA LAMBDA ARRAY
C           MXLAM.GT.0 AND LVRTP=.TRUE. *MUST* BE INPUT
C       B.) SYMMETRY DESCRIPTIONS GENERATED FROM LMAX (MMAX)
C           MXLAM.LE.0 (DEFAULT) AND  LMAX.GE.0 MUST BE INPUT
C       IF BOTH ARE SPECIFIED (MXLAM.GT.0 .AND. LMAX.GE.0) LMAX IS
C           IGNORED, I.E., CASE (2-A) TAKES PRECEDENCE
C       ALLOWED ONLY FOR NON-IOS CASES (ITYPE.LT.100)
C    3. POT'L IS NOT EXPANDED IN ANGULAR FUNCTIONS (SUITABLE FOR
C       IOS CALCULATIONS ONLY) AND IS OBTAINED VIA THE VRTP MECHANISM
C       MXLAM.LE.0 MUST BE SPECIFIED (AND ITYPE.GT.100 IN &BASIS)
C
C  ----------------------------------------------------------------------
C  * NOTES ON HISTORY OF ROUTINE:
C  ----------------------------------------------------------------------
C  AUG 2018 CR Le Sueur: SUBSTANTIALLY REARRANGED
C                        CODE RELATING TO NHAM MOVED TO ROUTINE GNPOTL
C                        AND NHAM REMOVED FROM ARGUMENT LIST.
C                        IPRINT ADDED TO ARGUMENT LIST
C
C  *INTRODUCES XPT(MXPT,MXDIM), XWT(MXPT,MXDIM), INX(MXDIM),*
C  *    NPTS(MXDIM); NPTS IS IN NAMELIST /BASIN/            *
C  *    TO ALLOW GENERAL, MULTI-DIMENSIONAL PROJECTIONS     *
C  **********************************************************
C  PROJECTION FOR ITYP=3 ADDED 20 JUL 94
C  CODE FOR ITYP=4 ADDED BY SG 30 JUN 94 (FOLLOWING TRP CODE)
C           ITYP=9 INTERFACE ADDED BY JMH 15 AUG 94
C  PREVIOUS REVISION DATES 1 FEB 1994 (SG); 3 JAN 1994 (JMH).
C  -----------------------------------------------------------------
C
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      SAVE
C
C  -----------------------------------------------------------------
C  * NOTES FOR PROGRAMS OTHER THAN MOLSCAT (STORAGE CONSIDERATIONS):
C  -----------------------------------------------------------------
C  THE X() ARRAY CAN BE DEFINED INTERNALLY OR, IF THIS ROUTINE
C  IS USED WITH THE MOLSCAT/BOUND/FIELD CODE, IT IS TAKEN FROM THE
C  /MEMORY/...,X()  STORAGE MECHANISM IN THOSE PROGRAMS.
C  THIS DECK SHOULD BE MODIFIED ACCORDINGLY IN THE STATEMENTS BELOW
C  AND THE STATEMENTS WHICH FOLLOW STATEMENT NUMBER 2000
C  -----------------------------------------------------------------
C  ----- NEXT TWO STATEMENTS ARE USED FOR INTERNAL X() STORAGE -----
C  ----- ALSO, "X" MUST BE ADDED TO THE "SAVE" STATEMENT ABOVE -----
C     PARAMETER (MXX=30000)
C     DIMENSION X(MXX)
C  ----- NEXT TWO STATEMENTS ARE FOR /MEMORY/ MECHANISM-----
      DIMENSION X(1)
      COMMON /MEMORY/ MX,IXNEXT,NIPR,IDUMMY,X
C
C  -----------------------------------------------------------------
C  * SPECIFICATION STATEMENTS:
C  -----------------------------------------------------------------C
C  MXDIM IS MAX NUMBER OF DIMENSIONS FOR PROJECTION
C  MXPT LIMITS POINTS PER DIMENSION FOR PROJECTION
C  MXHERM LIMITS HERMITE POLYNOMIALS FOR VIBRATIONAL PROJECTION
      PARAMETER (MXPT=96, MXDIM=3, MXHERM=20)
C  DIMENSIONS FOR LAMBDA AND POWER/EXPONENTIAL TERMS
      PARAMETER (IXMX=200, IEXMX=200, NPXMX=20) !, MXLMDA=2000) 16-08-2018
      INTEGER CFLAG,PCASE
      LOGICAL QOUT,LVRTP, XLAM
      CHARACTER(8) QNAME(10), QTYPE(12)
C     CHARACTER*6 PNAMES
C     DIMENSION PNAMES(25),LOCN(25),INDX(25)
      DIMENSION P(MXLMB), LAM(MXLMB)
      DIMENSION NTERM(MXLMDA),NPOWER(IXMX),NPUNI(NPXMX) !,LAMBDA(MXLMDA) 16-08-2018
      DIMENSION A(IXMX), E(IEXMX)
      DIMENSION H(MXHERM),TOTAL(1)
      DIMENSION XPT(MXPT,MXDIM),XWT(MXPT,MXDIM),INX(MXDIM),NPTS(MXDIM)
      EQUIVALENCE (NPT,NPTS(1)), (NPS,NPTS(2))
C
      EQUIVALENCE (MXLAM,MXSYM),(LMAX,L1MAX)

C  COMMON BLOCK FOR COMMUNICATING WITH SURBAS
C     COMMON /NPOT  / NVLP

C  COMMON BLOCK FOR COMMUNICATING WITH POTENTIAL ROUTINES
C  CHANGED TO USE ANGLES MODULE ON 16-08-2018
C     COMMON /ANGLES/ COSANG(MXANG),FACTOR,IHOMO,ICNSYM,IHOMO2,ICNSY2
      logical :: inolls=.false.
C
C     include common block for data received via pvm
C
cINOLLS include 'all/pvmdat1.f'
cINOLLS include 'all/pvmdat.f'
C
C  -----------------------------------------------------------------
C  * NAMELIST SPECIFICATION (AND DESCRIPTION OF PARAMETERS):
C  -----------------------------------------------------------------
      NAMELIST/POTL/ A,      CFLAG,  E,     EPNAME, EPSIL,
     1               ICNSYM, ICNSY2, IHOMO, IHOMO2, IVMIN,
     2               IVMAX,  LAMBDA, LMAX,   L1MAX, L2MAX,
     3               LVRTP,  MMAX,   MXLAM,  MXSYM, NHAM,
     4               NPOWER, NPS,    NPTS,   NPT,   NTERM,
     5               RM,     RMNAME
C
C  RM     - LENGTH SCALING FACTOR; VALUE IN ANGSTROMS
C  EPSIL  - ENERGY SCALING FACTOR; VALUE IN WAVENUMBERS (CM-1)
C  MXLAM  - NUMBER OF POTENTIAL TERMS RETURNED
C  MXSYM  - A SYNONYM FOR MXLAM, RETAINED FOR COMPATIBILITY
C  LAMBDA - SYMMETRY INDICES FOR POTENTIAL
C  NHAM   - NO LONGER A RELEVANT INPUT PARAMETER
C  -------- BELOW DESCRIBE TERMS AS EXPONENTIALS OR POWERS OF R
C  NTERM  - ARRAY: NTERM(I) IS NUMBER OF TERMS CONTRIBUTING TO P(I)
C           NTERM(I) .LT. 0 CALLS VINIT/VSTAR FOR POTENTIAL TERM I
C  A      - ARRAY OF PRE-EXPONENTIAL (OR PRE-POWER) FACTORS
C           FIRST NTERM(1) ELEMENTS REFER TO P(1),
C           NEXT  NTERM(2) ELEMENTS REFER TO P(2) ETC.
C  NPOWER - ARRAY OF POWERS FOR POTENTIAL TERMS
C           NPOWER HAS SAME ORDERING AS A
C           NPOWER(J) .EQ. 0 INDICATES EXPONENTIAL
C  E      - ARRAY OF EXPONENTS: EACH ELEMENT OF THIS ARRAY
C           CORRESPONDS TO A ZERO IN THE NPOWER ARRAY,
C           IE E(1) CORRESPONDS TO FIRST ZERO, E(2) TO SECOND ETC.
C  CFLAG  - FLAG FOR SCALING POTENTIAL FOR ITYP = 5 OR 6:
C           SET CFLAG=1 IF INPUT A COEFFICIENTS OR VSTAR ARE FOR AN
C           EXPANSION IN C_LM INSTEAD OF Y_LM
C  -------- BELOW ARE FOR POTENTIALS PROJECTION VIA VRTP MECHANISM
C  LVRTP  - LOGICAL FLAG FOR NON-EXPANDED POTENTIAL:
C           MXLAM.LE.0 (DEFAULT) FORCES LVRTP=.TRUE.
C  NPTS   - NUMBERS OF GAUSS POINTS FOR PROJECTING POTENTIAL
C  NPT    - EQUIVALENT TO NPTS(1)
C  NPS    - EQUIVALENT TO NPTS(2)
C  IHOMO  - 2 IF POTENTIAL IS SYMMETRIC ABOUT THETA=90, 1 OTHERWISE
C  ICNSYM - ORDER OF ROTATIONAL SYMMETRY ABOUT PRINCIPAL AXIS
C           ALSO USED FOR 2ND MOLECULE (I.E., IHOMO2) IN ITYP=3
C           (NOTE: IHOMO & ICNSYM ARE NORMALLY COMPUTED
C            AUTOMATICALLY OR SET BY THE SUPPLIED VRTP ROUTINE)
C  -------- BELOW ARE FOR AUTOMATIC GENERATION OF LAMBDA ARRAY;
C           ONLY FOR PROJECTED  POT'LS (LVRTP = TRUE) IF LMAX.GE.0
C  LMAX   - INCLUDE ALL TERMS FROM 0 TO LMAX IN STEPS OF IHOMO
C  L1MAX  - MAX L1 VALUE FOR MOLECULE-1 (ITYP=3)
C  L2MAX  - MAX L2 VALUE FOR MOLECULE-2 (ITYP=3)
C  MMAX   - FOR ITYP = 5 OR 6, EXCLUDE TERMS WITH M.GT.MMAX
C  IVMIN, IVMAX - FOR ITYP = 2, V LOOPS FROM IVMIN TO IVMAX
C
      DIMENSION NPLABS(9),NQDIM(9)
      DATA NPLABS /1,3,3,4,2,2,5,2,0/
      DATA NQDIM  /1,2,3,0,2,2,2,0,0/

      DATA QTYPE/'LAMBDA','ABS(KAP)','MU','LAM1',
     1           'LAM2','LAM','V','V-PRIME',
     2           'J','J-PRIME','G1','G2'/
C
C  STATEMENT FUNCTION ...
      F(I)=DBLE(I+I+1)

      IF (ICNTRL.LT.-1 .OR. ICNTRL.GT.2) THEN
        WRITE(6,999) ICNTRL,R
  999   FORMAT(/'  *** ERROR IN POTENL, ICNTRL =',I6,'  R =',E16.8)
        STOP
      ELSEIF (ICNTRL.EQ.-1) THEN
        GOTO 1000
      ENDIF

C
C  ******************************************************************
C  **                                                              **
C  **    CODE BELOW IS FOR AN EVALUATION CALL - CALCULATES P()     **
C  **                                                              **
C  ******************************************************************
      IF (LVRTP) GOTO 200
C
C  ----- CASE 1 -----
C  EVALUATE RADIAL COEFFICIENTS AS POWERS, EXPONENTIALS OR VSTAR
      IX=0
      IEX=0
      DO 10 I=1,MXLMB
        TOTAL1=0.D0
        NT=NTERM(I)
        IF (NT.EQ.0) GOTO 10
        IF (NT.LT.0) GOTO 20
        DO 40 IT=1,NT
          IX=IX+1
          NP=NPOWER(IX)
          IF (NP.EQ.0) GOTO 30
C  PROTECT AGAINST OVERFLOW AT ORIGIN. VALUE USED BALANCED WITH WAVMAT
          RR=R
          IF (NP.LT.0 .AND. ABS(R).LT.1.D-8) RR=1.D-8
          TERM=RR**NP
          IF (ICNTRL.EQ.1) TERM=DBLE(NP)*TERM/RR
          IF (ICNTRL.EQ.2) TERM=DBLE(NP*(NP-1))*TERM/(RR*RR)
          GOTO 40
C
   30     IEX=IEX+1
          TERM=EXP(E(IEX)*R)
          IF (ICNTRL.GT.0) TERM=TERM*E(IEX)**ICNTRL
   40     TOTAL1=TOTAL1+A(IX)*TERM
        GOTO 10
   20   IF (ICNTRL.EQ.0) CALL VSTAR (I,R,CONTR)
        IF (ICNTRL.EQ.1) CALL VSTAR1(I,R,CONTR)
        IF (ICNTRL.EQ.2) CALL VSTAR2(I,R,CONTR)
        IF (CFLAG.EQ.1) CONTR=CONTR
     1                        *SQRT(4.D0*PI/DBLE(2*LAMBDA(I+I-1)+1))
        TOTAL1=TOTAL1+CONTR
   10   P(I)=TOTAL1
      IF (IPRINT.GE.30) THEN
        WRITE(6,100) 'P(I) = ',(P(I),I=1,MXLMB)
      ENDIF
      RETURN
C
  200 IF (PCASE.EQ.3) GOTO 300
C
C  ----- CASE 2 -----
C  EXPLICIT PROJECTION OF LEGENDRE COMPONENTS VIA VRTP
      DO I=1,MXLMB
        P(I)=0.D0
      ENDDO
      DO ID=1,NDIM
        INX(ID)=1
      ENDDO
C  START YPT() INDEX = IX;
C  IX COUNTS DOWN LAMBDA THEN 1ST DIMENSION, 2ND DIMENSION, ...
      IX=IXFAC
      DO 230 I=1,NTOT
        WEIGHT=1.D0
        DO ID=1,NDIM
          COSANG(ID)=XPT(INX(ID),ID)
          WEIGHT=WEIGHT*XWT(INX(ID),ID)
        ENDDO
        CALL VRTP(ICNTRL,R,TOTAL)
        TOTAL(1)=TOTAL(1)*WEIGHT
C  ACCUMULATE CONTRIBUTIONS TO EACH P()
        DO IL=1,MXLMB
          IX=IX+1
          P(IL)=P(IL)+TOTAL(1)*X(IX)
        ENDDO
C  INCREMENT THE INDICES FOR EACH DIMENSION, INX(ID), STARTING W/ 1ST
        ID=1
  260   INX(ID)=INX(ID)+1
        IF (INX(ID).LE.NPTS(ID)) GOTO 230
C  WE REACH HERE IF WE'VE HIT MAX FOR THIS DIMENSION; START NEXT,
        INX(ID)=1
        ID=ID+1
        IF (ID.LE.NDIM) GOTO 260
C  IF WE REACH HERE WE SHOULD HAVE COUNTED ALL NTOT ELEMENTS
        IF (I.EQ.NTOT) GOTO 230
        WRITE(6,*) ' POTENL. ERROR IN PROJECTION. NO. TERMS',I
        STOP
  230 CONTINUE

      IF (IPRINT.GE.30) THEN
        WRITE(6,100) 'P(I) = ',(P(I),I=1,MXLMB)
      ENDIF
  100 FORMAT(2X,A,1P,6(G12.4,1X))

      RETURN
C
C  ----- CASE 3 -----
C  UNEXPANDED POT'L AS FUNCTION OF ANGLES, FROM VRTP
  300 CALL VRTP(ICNTRL,R,P)
      RETURN
C ================================================== END OF EVALUATION =
C
C  ******************************************************************
C  **                                                              **
C  **    CODE BELOW IS FOR AN INITIALIZATION CALL                  **
C  **                                                              **
C  ******************************************************************
C
 1000 PI=ACOS(-1.D0)
      IF (IPRINT.GE.1)
     1  WRITE(6,9010) 'GENERAL-PURPOSE POTENL ROUTINE (MAY 18)'
 9010 FORMAT(2X,A)
C  INITIALIZE NAMELIST VARIABLES BEFORE READ
      CFLAG=0
      EPSIL=1.D0
      FACTOR=1.D0
      ICNSYM=1
      ICNSY2=1
      IHOMO=1
      IHOMO2=1
      IVMAX=-1
      IVMIN=-1
      LAMBDA=0
      LMAX=-1
      L2MAX=-1
      LVRTP=.FALSE.
      MMAX=-1
      MXLAM=0
      DO ID=1,MXLMDA
        NTERM(ID)=-1
      ENDDO
      DO ID=1,MXDIM
        NPTS(ID)=0
      ENDDO
      NHAM=-1
      RM=-1.D0
      QOUT=(MOD(ITYPE,10).NE.9)
      if (.not.inolls) READ(5,POTL)
C
cINOLLS include 'all/rpotl-v15.f'
C
C
      IF (NHAM.NE.-1) WRITE(6,9020) NHAM
 9020 FORMAT(/'  *** POTENL.  CURRENT CODE IGNORES INPUT &POTL NHAM =',
     1        I6)
      ITYP=MOD(ITYPE,10)
      IADD=ITYPE-ITYP
C
C  FOR ITYP=9, POTIN9 MUST EITHER RESET ITYP TO ONE OF THE
C  RECOGNISED VALUES OR MUST DO ALL THE REST OF THE SETUP WORK.
C  CALLING SEQUENCE OF POTIN9 EXTENDED BY JMH, 2 NOV 95.
C
      IF (ITYP.EQ.9) THEN
        JTYPE=ITYPE
        CALL POTIN9(JTYPE,LAM,MXLAM,NPTS,NDIM,XPT,XWT,
     1              MXPT,IVMIN,IVMAX,L1MAX,L2MAX,
     2              MXLMB,X,MX,IXFAC)
        ITYP=MOD(JTYPE,10)
        NQDIM(9)=NDIM
      ENDIF
      NPQL=NPLABS(ITYP)
      NDIM=NQDIM(ITYP)
C
C  NOTE THAT EVEN IF POTIN9 WAS CALLED, ITYP MAY NOT BE 9 NOW.
C  IN THAT CASE, SKIP OVER ALL CHECKING OF EXPANSION TERM LABELS
C  AND QUADRATURE, AND GO STRAIGHT TO INITIALISATION OF POTENTIAL
C  OR EXPANSION COEFFICIENTS

      IF (ITYP.EQ.9) GOTO 5000

C  CHECK CFLAG
      IF (CFLAG.EQ.1 .AND. .NOT.(ITYP.EQ.5 .OR. ITYP.EQ.6)) THEN
        WRITE(6,9030) CFLAG,ITYP
 9030   FORMAT(/'  *** '/'  *** POTENL. INPUT &POTL CFLAG =',I2,
     1         ' NOT CONSISTENT WITH ITYP =',I4/
     2         '  ***',9X,'CFLAG RESET TO 0'/'  ***')
        CFLAG=0
      ENDIF
C
C  CHECK FOR LVRTP OR MXLAM.LE.0, ("UNEXPANDED" POTENTIAL CASE).
C
      IF (LMAX.GE.0 .AND. (MXLAM.GT.0 .OR.
     1                    (MXLAM.LT.0 .AND. IADD.EQ.100 .AND. LVRTP)))
     2THEN
        IF (IPRINT.GE.1) THEN
          WRITE(6,9010) 'BOTH MXLAM AND LMAX SET'
          WRITE(6,9010) 'MXLAM TAKES PRECEDENCE.  IGNORING LMAX'
        ENDIF
        LMAX=-1
      ENDIF
      IF (MXLAM.LT.0 .AND. IADD.NE.100) THEN
        IF (IPRINT.GE.1)
     1    WRITE(6,9010) '*** POTENL.  WARNING: MXLAM SET NEGATIVE.'
        IF (LMAX.LT.0) THEN
          IF (IPRINT.GE.1)
     1      WRITE(6,9040) 'ATTEMPTING TO CONTINUE USING |MXLAM|'
 9040     FORMAT(22X,A)
          MXLAM=-MXLAM
        ELSE
          IF (IPRINT.GE.1) WRITE(6,9040) 'USING LMAX INSTEAD'
          MXLAM=0
        ENDIF
      ENDIF
      IF (MXLAM.LE.0 .AND. LMAX.LT.0) THEN
        IF (IADD.NE.100) THEN
          WRITE(6,9050)
 9050     FORMAT(1X,' *** POTENL.  ERROR: POTENTIAL EXPANSION ',
     1           'TERMS MUST BE GIVEN BY SETTING EITHER',
     2           /22X,'MXLAM > 0 OR LMAX >= 0')
          STOP
        ENDIF
        IF (IPRINT.GE.1 .AND. .NOT.LVRTP)
     1    WRITE(6,9010) 'LVRTP CHANGED FROM FALSE TO TRUE'
        LVRTP=.TRUE.
      ENDIF
      IF (.NOT.LVRTP) PCASE=1
      IF (LVRTP .AND. IADD.NE.100) PCASE=2
      IF (LVRTP .AND. IADD.EQ.100) PCASE=3
      IF (LVRTP .AND. IADD.EQ.100 .AND. MXLAM.GT.0) PCASE=4

      IF (LVRTP) THEN
        IF (IPRINT.GE.1) WRITE(6,9060)
 9060   FORMAT(/'  UNEXPANDED POTENTIAL IS OBTAINED FROM VRTP ROUTINE.',
     1         //'  A SUITABLE VRTP ROUTINE MUST BE SUPPLIED.')
        CALL VRTP(ICNTRL,RM,P)
        EPSIL=P(1)
        IF (PCASE.EQ.4) THEN
          IF (IPRINT.GE.1) WRITE(6,9070)
 9070     FORMAT(/'  *** NOTE *** REQUESTED PROJECTED EXPANSION IS '
     1           ,'GENERALLY NOT DESIRABLE FOR '/
     2            '               IOS CALCULATIONS.  STANDARD IOS/',
     3            'VRTP PROCESSING CAN BE OBTAINED'/
     4            '               BY SETTING MXLAM=0 IN &POTL'/)
        ENDIF
      ENDIF

      IF (PCASE.EQ.3) THEN
C  IOS APPROXIMATION BEING USED.  PROPAGATIONS PERFORMED AT FIXED
C  ORIENTATIONS

        IF (ITYP.EQ.2 .AND. MXLAM.LT.0) THEN
C  CODE FOR ATOM-VIBRATING DIATOM IOS, IE., CLARY'S VCC-IOS
C  WHERE THE ANGLE DEPENDENCE OF POTENTIAL IS NOT EXPANDED.
C>>IT WOULD MAKE GOOD SENSE TO USE IVMIN,IVMAX TO GENERATE HERE.
          MXLAM=ABS(MXLAM)
          IF (IPRINT.GE.1) WRITE(6,3010) MXLAM
 3010     FORMAT(/'  POTENL, ITYPE=102.  NEGATIVE MXLAM REQUESTS',I3,
     1           ' TERMS'//
     2           '    INDEX     LAMBDA     VIB1      VIB2')
          DO I=1,MXLAM
            IF (LAMBDA(3*I-2).NE.0 .AND. IPRINT.GE.1) WRITE(6,3020)
 3020       FORMAT('  *** WARNING.  INPUT ORDER OF LEGENDRE POLYNOMIAL',
     1             ' > ZERO BELOW.  ORDER WILL BE IGNORED AND SET TO',
     2             ' ZERO.')
            LAM(3*I-2)=0
            IF (IPRINT.GE.1)
     1        WRITE(6,3030) I,LAMBDA(3*I-2),LAMBDA(3*I-1),LAMBDA(3*I)
 3030         FORMAT(1X,I8,I9,2I10)
          ENDDO
        ELSE
          DO I=1,NPQL
            LAM(I)=0
            LAMBDA(I)=0
          ENDDO
          MXLAM=1
        ENDIF
        GOTO 6000
      ENDIF

C  CHECK SYMMETRIES (IHOMO ETC, ALSO L2MAX=-1)
      IF (IHOMO.NE.1 .AND. IHOMO.NE.2) THEN
        WRITE(6,9080) 'IHOMO',IHOMO
 9080   FORMAT(/'  *** POTENL. ILLEGAL ',A,' =',I6,
     1         ' FROM &POTL INPUT OR VRTP')
        STOP
      ENDIF

      IF (IHOMO.EQ.2) THEN
        IF (ITYP.NE.3 .AND. IPRINT.GE.1) WRITE(6,9090) 'IHOMO','.'
 9090   FORMAT(2X,A,' = 2 SPECIFIES HOMONUCLEAR SYMMETRY',A)
        IF (ITYP.EQ.3 .AND. IPRINT.GE.1) WRITE(6,9090) 'IHOMO ',
     1                                                 ' FOR ROTOR 1.'
      ENDIF

      IF (ITYP.EQ.2 .AND. LMAX.GE.0) THEN
        IF (IVMIN.LT.0) THEN
          WRITE(6,*) ' *** POTENL. IVMIN MUST BE SPECIFIED IN &POTL'
          WRITE(6,*) '             TO GENERATE SYMMETRIES AS '//
     1               ' REQUESTED BY &POTL LMAX',LMAX
          STOP
        ENDIF
        IF (IVMAX.LT.IVMIN) THEN
          IF (IPRINT.GE.1)
     1      WRITE(6,*) ' *** POTENL. IVMAX < IVMIN; INCREASED TO IVMIN'
          IVMAX=IVMIN
        ENDIF
      ENDIF

      IF (ITYP.EQ.3) THEN
        IF (ICNSYM.EQ.2 .AND. IHOMO2.EQ.1) THEN
          IHOMO2=ICNSYM
        ENDIF
        IF (IHOMO2.NE.1 .AND. IHOMO2.NE.2) THEN
          WRITE(6,9080) 'IHOMO2',IHOMO2
          STOP
        ENDIF
        IF (IHOMO2.EQ.2 .AND. IPRINT.GE.1) WRITE(6,9090) 'IHOMO2',
     1                                                   ' FOR ROTOR 2.'
        IF (L2MAX.LT.0) L2MAX=LMAX
      ENDIF

      IF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
        IF (MMAX.EQ.-1) MMAX=LMAX
        IF (ICNSYM.GT.1 .AND. IPRINT.GE.1) THEN
          WRITE(6,*) ' ICNSYM INPUT OR FROM VRTP SPECIFIES'//
     1               ' AXIAL SYMMETRY, ICNSYM =',ICNSYM
        ENDIF
      ENDIF

C  SET UP LAMBDA IF REQUIRED
      IF (LMAX.GE.0) THEN
        MXLAM=0
        IF (ITYP.EQ.1) THEN
          DO L=0,LMAX,IHOMO
            MXLAM=MXLAM+1
            IF (MXLAM.GT.MXLMB) GOTO 9995
            LAMBDA(MXLAM)=L
          ENDDO

        ELSEIF (ITYP.EQ.2) THEN
C  NEED TO CHECK IVMIN,IVMAX
          DO L=0,LMAX,IHOMO
          DO IV=IVMIN,IVMAX
          DO JV=IVMIN,IV
            MXLAM=MXLAM+1
            IF (3*MXLAM.GT.MXLMB) GOTO 9995
            LAMBDA(3*MXLAM-2)=L
            LAMBDA(3*MXLAM-1)=IV
            LAMBDA(3*MXLAM)  =JV
          ENDDO
          ENDDO
          ENDDO

        ELSEIF (ITYP.EQ.3) THEN
          DO L1=0,LMAX,IHOMO
          DO L2=0,L2MAX,ICNSYM
          DO L=ABS(L1-L2),L1+L2,2
            MXLAM=MXLAM+1
            IF (3*MXLAM.GT.MXLMB) GOTO 9995
            LAMBDA(3*MXLAM-2)=L1
            LAMBDA(3*MXLAM-1)=L2
            LAMBDA(3*MXLAM)  =L
          ENDDO
          ENDDO
          ENDDO

        ELSEIF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
          DO L=0,LMAX
          DO M=0,MIN(L,MMAX),ICNSYM
            IF (MOD(L+M,IHOMO).NE.0) CYCLE
            MXLAM=MXLAM+1
            IF (2*MXLAM.GT.MXLMB) GOTO 9995
            LAMBDA(2*MXLAM-1)=L
            LAMBDA(2*MXLAM)  =M
          ENDDO
          ENDDO

        ELSE
          WRITE(6,9110) ITYP
 9110     FORMAT(' **** POTENL.  ERROR: MXLAM MUST BE SET > 0 AND ',
     1           'EXPANSION TERMS MUST BE'/22X,'GIVEN EXPLICITLY ',
     2           'FOR ITYP =',I2)
          STOP
        ENDIF
      ENDIF

C  COPY LAMBDA ARRAY INTO LAM
      DO ILAM=1,NPQL*ABS(MXLAM)
        LAM(ILAM)=LAMBDA(ILAM)
        IF (MOD(ILAM-1,NPQL).EQ.0) THEN
          MAXL=MAX(MAXL,LAM(ILAM))
        ENDIF
      ENDDO

C  FIND MAXIMA OF QUANTUM LABELS
      IF (ITYP.EQ.2 .OR. ITYP.EQ.7) THEN
        MAXV=0
        MAXVP=0
        DO I=1,MXLAM
          MAXV=MAX(MAXV,LAM(NPQL*(I-1)+2))
          IF (ITYP.EQ.2) MAXVP=MAX(MAXVP,LAM(NPQL*(I-1)+3))
          IF (ITYP.EQ.7) MAXVP=MAX(MAXVP,LAM(NPQL*(I-1)+4))
        ENDDO
        MAXV=MAX(MAXV,MAXVP)

      ELSEIF (ITYP.EQ.3) THEN
        MAXL2=0
        DO I=1,MXLAM
          MAXL2=MAX(MAXL2,LAM(NPQL*(I-1)+2))
        ENDDO
        MAXM=MIN(MAXL,MAXL2)

      ELSEIF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
        MAXK=0
        DO I=1,MXLAM
          MAXK=MAX(MAXK,LAM(NPQL*I))
        ENDDO
      ENDIF

C  CHECK SYMMETRIES
      IF (MOD(ITYPE,10).NE.9) THEN
      IF (ITYP.EQ.1 .OR. ITYP.EQ.2) THEN
        DO IL=1,MXLAM
          L=LAM(IL)
          IF (MOD(L,IHOMO).NE.0) THEN
            WRITE(6,9910) IL,IHOMO,ICNSYM,L
            STOP
          ENDIF
        ENDDO

      ELSEIF (ITYP.EQ.3) THEN
        DO IL=1,MXLAM
          L1=LAM((IL-1)*NPQL+1)
          L2=LAM((IL-1)*NPQL+2)
          L3=LAM(IL*NPQL)
          IF (MOD(L1,IHOMO).NE.0 .OR. MOD(L2,ICNSYM).NE.0 .OR.
     1        MOD(L1+L2+L3,2).NE.0) THEN
            WRITE(6,9910) I,IHOMO,ICNSYM,L1,L2,L3
            STOP
          ENDIF
        ENDDO

      ELSEIF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
        DO IL=1,MXLAM
          L=LAM((IL-1)*NPQL+1)
          M=LAM((IL-1)*NPQL+2)
          IF (MOD(L+M,IHOMO).NE.0 .OR. MOD(M,ICNSYM).NE.0) THEN
            WRITE(6,9910) I,IHOMO,ICNSYM,L,M
 9910       FORMAT(/'  *** POTENL.  TERM',I4,' IS INCONSISTENT ',
     1             'WITH IHOMO =',I2,' OR ICNSYM =',I2,'  INDICES:',
     2             3I4)
            STOP
          ENDIF
        ENDDO
      ENDIF
      ENDIF
C
      IF (LVRTP) THEN
C  CALCULATE NUMBER OF QUADRATURE POINTS REQUIRED FOR EACH SEPARATE DEGREE
C  OF FREEDOM AND GET THE POINTS AND WEIGHTS
        IF (ITYP.NE.1 .AND. ITYP.NE.2 .AND. ITYP.NE.3 .AND.
     1      ITYP.NE.5 .AND. ITYP.NE.6) THEN
          WRITE(6,9920) ITYP
 9920     FORMAT(/'  *** POTENL.  ERROR: POTENTIAL EXPANSION BY ',
     1           'QUADRATURE IS NOT SUPPORTED'/22X,'FOR ITYP =',I6)
          STOP
        ENDIF

        IF (NPT.GT.0 .AND. MAXL+1.GT.NPT .AND. IPRINT.GE.10)
     1    WRITE(6,*) 'NOT ENOUGH POINTS'
        NPT=MAX(NPT,MAXL+1)
        IF (NPT.GT.MXPT) GOTO 9993
        CALL GAUSSP(-1.D0,1.D0,NPT,XPT(1,1),XWT(1,1))
        IF (IPRINT.GE.1) WRITE(6,9200) NPT,'THETA-1'
 9200   FORMAT(2X,'USING ',I3,'-POINT QUADRATURE FOR ',A)
        IF (IHOMO.EQ.2) THEN
          DO IPT=1,NPT/2
            XWT(IPT,1)=2.D0*XWT(IPT,1)
          ENDDO
          NPT=(NPT+1)/2
          IF (IPRINT.GE.1) WRITE(6,9210)
 9210     FORMAT(2X,'HOMONUCLEAR SYMMETRY: ONLY HALF OF THE THETA-1 ',
     1           'POINTS WILL BE USED')
        ENDIF

        IF (ITYP.EQ.2) THEN
          IF (NPS.GT.0 .AND. 2*MAXV+1.GT.NPS .AND. IPRINT.GE.10)
     1      WRITE(6,*) 'NOT ENOUGH POINTS'
          NPS=MAX(NPS,2*MAXV+1)
          IF (NPS.GT.MXPT) GOTO 9993
          CALL GAUSHP(NPS,XPT(1,2),XWT(1,2))
          IF (IPRINT.GE.1) WRITE(6,9200) NPS,'VIBRATIONS'

        ELSEIF (ITYP.EQ.3) THEN
          IF (NPS.GT.0 .AND. MAXL2+1.GT.NPS .AND. IPRINT.GE.10)
     1      WRITE(6,*) 'NOT ENOUGH POINTS'
          NPS=MAX(NPS,MAXL2+1)
          IF (NPS.GT.MXPT) GOTO 9993
          CALL GAUSSP(-1.D0,1.D0,NPS,XPT(1,2),XWT(1,2))
          IF (IPRINT.GE.1) WRITE(6,9200) NPS,'THETA-2'
          IF (ICNSYM.EQ.2) THEN
            DO IPT=1,NPS/2
              XWT(IPT,2)=2.D0*XWT(IPT,2)
            ENDDO
            NPS=(NPS+1)/2
            IF (IPRINT.GE.1) WRITE(6,9220)
 9220       FORMAT(2X,'HOMONUCLEAR MOLECULE 2: ONLY HALF OF THE ',
     1             'THETA-2 POINTS WILL BE USED')
          ENDIF
          IF (NPTS(3).GT.0 .AND. NPTS(3).LT.MAXM+1 .AND. IPRINT.GE.10)
     1      WRITE(6,*)'NOT ENOUGH POINTS'
          NPTS(3)=MAX(NPTS(3),MAXM+1)
          IF (NPTS(3).GT.MXPT) GOTO 9993
          IF (IPRINT.GE.1) WRITE(6,9200) NPTS(3),'PHI'
          FACTL=PI/DBLE(NPTS(3))
          TH=-FACTL/2.D0
          DO IX=1,NPTS(3)
            TH=TH+FACTL
            XWT(IX,3)=(2.D0*FACTL)
            XPT(IX,3)=TH
          ENDDO

        ELSEIF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
          IF (NPS.GT.0 .AND. (NPS.LT.1+(MAXK+ICNSYM-1)/ICNSYM) .AND.
     1        IPRINT.GE.10) WRITE(6,*) 'NOT ENOUGH POINTS'
          NPS=MAX(NPS,1+(MAXK+ICNSYM-1)/ICNSYM)
          IF (NPS.GT.MXPT) GOTO 9993
          IF (IPRINT.GE.1) WRITE(6,9200) NPS,'PHI'
          DO IPX=1,NPS
            XPT(IPX,2)=PI*DBLE(2*IPX-1)/DBLE(2*ICNSYM*NPS)
            XWT(IPX,2)=SQRT(PI+PI)/DBLE(NPS)
          ENDDO
        ENDIF

C  CHECK THAT FUNCTIONS AT QUADRATURE POINTS CAN BE FITTED INTO MEMORY
C  (THEY ARE STORED AT THE VERY END OF THE X ARRAY)
        NTOT=1
        DO IDIM=1,NDIM
          NTOT=NTOT*NPTS(IDIM)
        ENDDO
        IXFAC=MX-MXLAM*NTOT
        MX=IXFAC
        IF (MX+1.LT.IXNEXT) GOTO 9600
        IX=IXFAC

C  CALCULATE FUNCTIONS AT EACH QUADRATURE POINT
        IF (ITYP.EQ.1) THEN
          DO IP=1,NPT
          DO IL=1,MXLAM
            L=LAM(NPQL*(IL-1)+1)
            IX=IX+1
            X(IX)=SQRT(DBLE(L)+0.5D0)*PLM(L,0,XPT(IP,1))
          ENDDO
          ENDDO

        ELSEIF (ITYP.EQ.2) THEN
          DO IP2=1,NPS
            CALL HERM(H,MAXV+1,XPT(IP2,2))
            TOTAL1=SQRT(PI)
            DO IV=1,MAXV+1
              H(IV)=H(IV)/SQRT(TOTAL1)
              TOTAL1=TOTAL1*DBLE(2*IV)
            ENDDO
            DO IP1=1,NPT
            DO IL=1,MXLAM
              L=LAM(NPQL*(IL-1)+1)
              IX=IX+1
              X(IX)=SQRT(DBLE(L)+0.5D0)*PLM(L,0,XPT(IP1,1))*
     1              H(1+LAM(3*IL-1))*H(1+LAM(3*IL))
            ENDDO
            ENDDO
          ENDDO

        ELSEIF (ITYP.EQ.3) THEN
C  N.B. USE OF YRR MIGHT BE EXPENSIVE; CODE COULD BE MODIFIED
C  SIMILARLY TO THAT IN IOSB1
          PI8=8.D0*PI*PI
          DO IP3=1,NPTS(3)
          DO IPX=1,NPTS(2)
          DO IPT=1,NPTS(1)
          DO IL=1,MXLAM
            L1=LAM(NPQL*(IL-1)+1)
            L2=LAM(NPQL*(IL-1)+2)
            LL=LAM(NPQL*IL)
            IX=IX+1
            X(IX)=YRR(L1,L2,LL,XPT(IPT,1),XPT(IPX,2),XPT(IP3,3))
     1            *PI8/F(LL)
          ENDDO
          ENDDO
          ENDDO
          ENDDO

        ELSEIF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
          DO IPX=1,NPS
          DO IPT=1,NPT
          DO IL=1,MXLAM
            L=LAM(2*IL-1)
            M=LAM(2*IL)
            IX=IX+1
            X(IX)=PLM(L,M,XPT(IPT,1))*COS(DBLE(M)*XPT(IPX,2))
          ENDDO
          ENDDO
          ENDDO
        ENDIF

      ENDIF

C  WRITE MESSAGES...
      IF (IPRINT.GE.1 .AND. QOUT) THEN
        WRITE(6,9300)
 9300 FORMAT(/'  ANGULAR DEPENDENCE OF POTENTIAL EXPANDED IN TERMS OF')

        IF (ITYP.EQ.1) THEN
          QNAME(1)=QTYPE(1)
          IF (IPRINT.GE.1) WRITE(6,9310)
 9310     FORMAT('  LEGENDRE POLYNOMIALS, P(LAMBDA).')
          IF (LMAX.GE.0 .AND. IPRINT.GE.1) WRITE(6,9311) LMAX,IHOMO
 9311     FORMAT('  POTENTIAL TERMS GENERATED FROM LMAX =',I3,
     1           ' AND IHOMO =',I2)

        ELSEIF (ITYP.EQ.2 .OR. ITYP.EQ.7) THEN
          QNAME(1)=QTYPE(1)
          QNAME(2)=QTYPE(7)
          IF (ITYP.EQ.2) THEN
            QNAME(3)=QTYPE(8)
          ELSE
            QNAME(3)=QTYPE(9)
            QNAME(4)=QTYPE(8)
            QNAME(5)=QTYPE(10)
          ENDIF
          IF (IPRINT.GE.1) THEN
            WRITE(6,9310)
            WRITE(6,9320)
          ENDIF
 9320     FORMAT('  INTEGRATED OVER DIATOM VIBRATIONAL FUNCTIONS')
          IF (ITYP.EQ.2) THEN
            IF (LMAX.GE.0 .AND. IPRINT.GE.1)
     1        WRITE(6,9321) LMAX,IHOMO,IVMIN,IVMAX
 9321         FORMAT('  POTENTIAL TERMS GENERATED FROM LMAX =',I3,
     1               ' AND IHOMO =',I2/'  WITH V FROM',I2,' TO',I2)
          ELSEIF (ITYP.EQ.7) THEN
            IF (IPRINT.GE.1) WRITE(6,9370)
 9370       FORMAT('  FOR EACH PAIR OF V,J LEVELS')
          ENDIF

        ELSEIF (ITYP.EQ.3) THEN
          QNAME(1)=QTYPE(4)
          QNAME(2)=QTYPE(5)
          QNAME(3)=QTYPE(6)
          IF (IPRINT.GE.1) WRITE(6,9330)
 9330     FORMAT('  CONTRACTED NORMALISED SPHERICAL HARMONICS,'/'  SUM',
     1           '(M1,M2,M) C(L1,M1,L2,M2,L,M) Y(L1,M1) Y(L2,M2) Y(L,M)'
     2           /'  SEE GREEN, J. CHEM. PHYS. 62, 2271 (1975)')
          IF (LMAX.GE.0 .AND. IPRINT.GE.1) THEN
            WRITE(6,*) ' FOR MOLECULE - 1'
            WRITE(6,9311) LMAX,IHOMO
            WRITE(6,*) ' FOR MOLECULE - 2'
            WRITE(6,9311) L2MAX,IHOMO2
          ENDIF

        ELSEIF (ITYP.EQ.4) THEN
          QNAME(1)=QTYPE(4)
          QNAME(2)=QTYPE(3)
          QNAME(3)=QTYPE(5)
          QNAME(4)=QTYPE(6)
          IF (IPRINT.GE.1) WRITE(6,9340)
 9340     FORMAT('  CONTRACTION OF SPHERICAL HARMONICS AND ROTATION',
     1           ' MATRICES'/
     2           '     SEE T.R. PHILLIPS ET AL. JCP 101, 5824 (1994)'/
     3           '     (NOTATION OF WHICH USES MU RATHER THAN KAPPA)')

        ELSEIF (ITYP.EQ.5 .OR. ITYP.EQ.6) THEN
          QNAME(1)=QTYPE(1)
          QNAME(2)=QTYPE(2)
          IF (IPRINT.GE.1) THEN
            WRITE(6,9350)
 9350     FORMAT('  NORMALISED SPHERICAL HARMONICS: (Y(LAM,KAP) + ',
     1           '(-1)**KAP Y(LAM,-KAP))'/34X,'/ (1+DELTA(KAP,0))')
            IF (LMAX.GE.0) WRITE(6,9351) LMAX,IHOMO,MMAX,ICNSYM
 9351     FORMAT('  POTENTIAL TERMS GENERATED FROM LMAX =',I3,
     1           ', IHOMO =',I2,', MMAX =',I3,' AND ICNSYM =',I2)
            IF (CFLAG.EQ.1) THEN
              IF (LVRTP) THEN
                WRITE(6,9352)
 9352           FORMAT('  *** WARNING. SETTING CFLAG=1 IS NOT NEEDED',
     1                 ' WHEN THE POTENTIAL IS SUPPLIED POINTWISE')
              ELSE
                WRITE(6,9353)
 9353           FORMAT(/'  COEFFICIENTS IN POTENTIAL WILL BE ',
     1                 'MULTIPLIED BY SQRT(4*PI/(2*LAM+1)) TO BRING ',
     2                 'POTENTIAL INTO CORRECT FORM')
              ENDIF
            ENDIF
          ENDIF

        ELSEIF (ITYP.EQ.8) THEN
          QNAME(1)=QTYPE(11)
          QNAME(2)=QTYPE(12)
        ENDIF

      ELSE
        IF (IPRINT.GE.1) WRITE(6,9390) ITYPE
 9390   FORMAT(/'  *** POTENL. ITYPE =',I4,' CANNOT BE PROCESSED TO',
     1         ' DETERMINE THE POTENTIAL EXPANSION LABELS')
      ENDIF

C  PROCESS EXPRESSIONS FOR EXPANSION COEFFICIENTS
 5000 IX=0
      IEX=0
      DO I=1,MXLAM
        IF (IPRINT.GE.1) THEN
          WRITE(6,9410) I
 9410     FORMAT(/'  INTERACTION POTENTIAL FOR EXPANSION TERM NUMBER',
     1           I4)
          IF (QOUT) WRITE(6,9420) (TRIM(QNAME(J)),LAMBDA((I-1)*NPQL+J),
     1                             J=1,NPQL)
 9420     FORMAT('  WHICH HAS ',6(A,' = ',I3:,',',2X))
          WRITE(6,*)
        ENDIF

        IF (LVRTP) CYCLE

        NT=NTERM(I)
        IF (NT.LT.0) CALL VINIT(I,RM,EPSIL)
        DO IT=1,NT
          IX=IX+1
          IF (IX.GT.IXMX) THEN
            WRITE(6,9997) 'IX',IXMX
 9997       FORMAT(/'  *** POTENL.  DIMENSION ',A,' EXCEEDED',I6)
            STOP
          ENDIF
C  POSITIVE POWER OF R ALLOWED FROM VERSION 2019.0, DEC 2018
C  BUT JUST COMMENT OUT THE CODE FOR NOW
C         IF (NPOWER(IX).GT.0) THEN
C           WRITE(6,9510) IX,NPOWER(IX)
C9510       FORMAT(/'  * * * WARNING - POSITIVE POWER OF R ILLEGAL',
C    1             2I6/'  NEGATIVE OF SUPPLIED VALUE SUBSTITUTED')
C           IF (NPOWER(IX).GT.12 .OR. NPOWER(IX).LT.3) STOP
C           NPOWER(IX)=-NPOWER(IX)
C         ENDIF
          IF (NPOWER(IX).EQ.0) THEN
            IEX=IEX+1
            IF (IEX.GT.IEXMX) THEN
              WRITE(6,9997) 'IEX',IEXMX
              STOP
            ENDIF
            IF (E(IEX).GE.0.D0) WRITE(6,9520) E(IEX)
 9520       FORMAT(/'  * * * WARNING - POTENTIAL CONTAINS INCREASING',
     1             ' EXPONENTIAL =',E16.8)
            IF (IPRINT.GE.1) WRITE(6,9530) A(IX), E(IEX)
 9530       FORMAT(15X,1PE16.8,' * EXP(',0PF10.4,' * R )')
            IF (CFLAG.EQ.1) A(IX)=A(IX)*SQRT(4.D0*PI
     1                            /DBLE(2*LAMBDA(IQ-NQPL+1)+1))
          ELSE
            IF (IPRINT.GE.1) WRITE(6,9540) A(IX), NPOWER(IX)
 9540       FORMAT(15X,1PE16.8,' * R **',I3)
            IF (CFLAG.EQ.1) A(IX)=A(IX)*SQRT(4.D0*PI
     1                            /DBLE(2*LAMBDA(IQ-NQPL+1)+1))
          ENDIF
        ENDDO
      ENDDO

 6000 CONTINUE
C
      IF (RM.GT.0.D0) R=RM
      P(1)=EPSIL
      IF (EPSIL.EQ.1.D0) EPNAME='CM-1'
      IF (RM.EQ.1.D0)    RMNAME='ANGSTROM'
      MXLMB=MXLAM

      IF (IPRINT.GE.1) WRITE(6,9989) EPSIL
 9989 FORMAT(/'  POTENL PROCESSING FINISHED.'//
     1        '  POTENTIAL RETURNED IN UNITS OF EPSIL  =',1PG15.8,
     2        ' CM-1')
      IF (IPRINT.GE.1 .AND. R.GT.0.D0) WRITE(6,9990) R
 9990 FORMAT('        CODED WITH R IN UNITS OF RM     =',1PG15.8,
     1       ' ANGSTROM')
C
      RETURN
C
C  ********** ERROR CONDITIONS **********
C
 9991 WRITE(6,9992) NDIM,MXDIM
 9992 FORMAT(/'  *** POTENL. PROJECTED POTENTIAL HAS',I3,
     1       ' DIMENSIONS, BUT MXDIM=',I3)
      STOP
 9993 WRITE(6,9994) NPT,NPS,MXPT
 9994 FORMAT(/'  *** POTENL. EITHER NPT OR NPS EXCEEDS MXPT'
     2       /'  NPT =',I6,'  NPS =',I6/'  MXPT=',I7)
      STOP
 9995 WRITE(6,9996) MXLMB,MXLAM
 9996 FORMAT(/'  *** POTENL. DIMENSION OF EXTERNAL LAM ARRAY EXCEEDED'/
     1       '  SIZE PASSED FROM CALLING PROGRAM (MXLMB) =',I8/
     2       '  OFFENDING VALUE OF MXLAM =',I8)
      STOP
C
C  BELOW IS REACHED IF THERE WAS NOT ENOUGH ROOM IN THE X ARRAY TO
C  STORE THE PROJECTION COEFFS.  IF USING /MEMORY/...X, IT IS
C  POSSIBLE FOR THE CODE HERE TO OVERWRITE THE LAM ARRAY WITH
C  COEFFS.  HOWEVER, THE PROGRAM SHOULD THEN TERMINATE WHEN CHKSTR
C  IS CALLED FROM DRIVER AFTER RETURN FROM POTENL INITIALIZATION.
 9600 NREQ=MXLAM*(NPT+NPS)
      MXSTRT=MX+NREQ
      WRITE(6,9601) NPT,NPS,MXLAM,NREQ,MXSTRT,MXSTRT-IXNEXT+1
 9601 FORMAT('  *** POTENL. NOT ENOUGH ROOM FOR PROJECTION COEFFICIENTS'
     1      /'      REQUIRES (',I4,' +',I4,') * ',I4,' =',I8/
     2       '      OF',I8,' ORIGINALLY SUPPLIED IN X(), ONLY',I8,
     3       '  WERE AVAILABLE.')
      STOP
      END
