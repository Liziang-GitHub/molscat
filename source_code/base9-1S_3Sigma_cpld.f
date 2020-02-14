      SUBROUTINE BAS9IN(PRTP,IBOUND,IPRINT)
C  Copyright (C) 2020 J. M. Hutson & C. R. Le Sueur
C  Distributed under the GNU General Public License, version 3
      USE efvs
      USE potential
      USE basis_data
      USE physical_constants
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      SAVE
C----------------------------------------------------------------------
C  LMIN ADDED BY ALISDAIR WALLIS 30/10/07                             /
C----------------------------------------------------------------------
C  DATE (LAST UPDATE): 19/09/07        STATUS: FINISHED               |
C  AUTHORS: MAYKEL LEONARDO GONZALEZ MARTINEZ                         |
C           JEREMY M. HUTSON                                          |
C----------------------------------------------------------------------
C    THIS SUBROUTINE & ITS ENTRIES SET THE BASIS SET (I.E. QUANTUM    |
C    NUMBERS, COUPLING MATRIX ELEMENTS...) FOR THE INTERACTION TYPE:  |
C       ATOM(1S) + DIATOMIC(3SIGMA) IN EXTERNAL MAGNETIC FIELD        |
C          USING A COUPLED BASIS SET:  |(n, s)j mj> |L ML>            |
C----------------------------------------------------------------------
C  USES (DIAG, ODD), PARSGN
      CHARACTER(8) PRTP(4),QNAME(10)
      LOGICAL LEVIN,EIN,LCOUNT,DIAG,ODD
      DIMENSION JSTATE(1),VL(1),IV(1),JSINDX(1),L(1),CENT(1),LAM(1)
      DIMENSION DGVL(*)
      DIMENSION MONQN(3)
C
      COMMON /EXPVAL/ IPERTN,NPOWN,DELTAN
C
C  ALTERED TO USE ARRAY SIZES FROM MODULE sizes ON 23-06-17 BY CRLS
C
      NAMELIST/BASIS9/IS,LMAX,LMIN,IBSFLG,MLREQ
C  G FACTOR & BOHR'S MAGNETON (IN CM-1.GAUSS-1)
C     DATA GS/2.00231930436153D0/, BM/0.466864515D-4/
C
C  20-09-2016: UPDATED TO USE MODULE (physical_constants) THAT CONTAINS
C              CONSISTENT AND UP-TO-DATE VALUES
      PARAMETER (GS=-g_e, BM=bohr_magneton)

C
C  BAS9IN IS CALLED ONCE FOR EACH SCATTERING SYSTEM (USUALLY ONCE
C  PER RUN) AND CAN READ IN ANY BASIS SET INFORMATION NOT CONTAINED
C  IN NAMELIST BLOCK &BASIS. IT MUST ALSO HANDLE THE FOLLOWING
C  VARIABLES AND ARRAYS:
C
C  PRTP   SHOULD BE RETURNED AS A CHARACTER STRING DESCRIBING THE
C         INTERACTION TYPE
C  IDENT  CAN BE SET>0 IF AN INTERACTION OF IDENTICAL PARTICLES IS
C         BEING CONSIDERED AND SYMMETRISATION IS REQUIRED.
C         HOWEVER, THIS WOULD REQUIRE EXTRA CODING IN IDPART.
C  IBOUND CAN BE SET>0 IF THE CENTRIFUGAL POTENTIAL IS NOT OF THE
C         FORM L(L+1)/R**2; IF IBOUND>0, THE CENT ARRAY MUST BE
C         RETURNED FROM ENTRY CPL9
C
C  STATEMENT FUNCTIONS TO CHECK:
C  (1) WHETHER CERTAIN 'DIAGONALITY' CONDITION IS FULFILLED
      DIAG(J1,K1,L1,M1,N1,J2,K2,L2,M2,N2)=J1.EQ.J2 .AND. K1.EQ.K2 .AND.
     &                                    L1.EQ.L2 .AND. M1.EQ.M2 .AND.
     &                                    N1.EQ.N2
C  (2) WHETHER A NUMBER IS ODD
      ODD(NMBR)=2*(NMBR/2).NE.NMBR
C
      PRTP(1)='ATOM + 3'
      PRTP(2)='SIGMA IN'
      PRTP(3)=' MAGNETI'
      PRTP(4)='C FIELD '
      IBOUND=0
      NRSQ=0
C  STATES JTOT IS NOT USED FOR WHAT IT'S INTENDED TO BE
      JHALF=0
C  INITIALISES VARIABLES IN NAMELIST BASIS9 & READS IT
      IS=1
      LMAX=0
      MLREQ=999
C  DEFAULT BASIS SET IS <COUPLED> ( |(nS)j mj> |L ML> )
C  INCLUDING BOTH DIAGONAL AND OFF-DIAGONAL TERMS
      IBSFLG=2
      READ(5,BASIS9)
      IF (IPRINT.GE.1) WRITE(6,107) IS,JMAX,LMAX
 107  FORMAT(/'  BASIS SETS USE DIATOM SPIN =',I3/
     1       24X,'NMAX =',I3/24X,'LMAX =',I3)
C  COMMON FACTOR IN S-R AND S-Z ELEMENTS
      FACTOR=SQRT(DBLE(IS*(IS+1)*(2*IS+1)))
C  ARE ONLY DIAGONAL TERMS IN HINT REQUESTED?
      IF (IBSFLG.EQ.1) THEN
C  ONLY DIAGONAL ELEMENTS ARE TO BE USED (TAKEN FROM EINT)
         NCONST=0
         MAPEFV=1
         NDGVL=1
         IF (IPRINT.GE.1) WRITE(6,108)
 108     FORMAT(/'  BASIS SET IS <COUPLED> & ONLY DIAGONAL TERMS USED')
         GOTO 111
      ELSEIF (IBSFLG.GT.2) THEN
         WRITE(6,109) IBSFLG
 109     FORMAT(/' *** ERROR IN BAS9IN. IBSFLG =',I2,' CASE IS NOT ',
     &          'IMPLEMENTED IN THIS VERSION (IBSFLG .LE. 2!!)')
         STOP
      ENDIF
      IF (IPRINT.GE.1) WRITE(6,110)
 110  FORMAT(/'  BASIS SET IS <COUPLED>, OFF-DIAGONAL TERMS INCLUDED')
C  USES THE NEW MECHANISM IN WAVMAT (AUG 06) TO HANDLE NON-DIAGONAL HINT
C  DEFAULT IS OFF DIAGONAL TERMS INCLUDED & CENTRIFUGAL TERMS FROM CENT ARRAY
      NCONST=4
      MAPEFV=4
C  VCONST(I=1,4) :
C  I = 1,  PREFACTOR FOR MONOMER ROTATION TERMS
C  I = 2,  PREFACTOR FOR SPIN-ROTATION TERMS
C  I = 3,  PREFACTOR FOR SPIN-SPIN TERMS
C  I = 4,  PREFACTOR FOR SPIN ZEEMAN TERMS
 111  VCONST(1)=ROTI(1)
      VCONST(2)=ROTI(2)*FACTOR
      VCONST(3)=ROTI(3)*2.D0*SQRT(30.D0)/3.D0
C      VCONST(4)=FIELD ! IT'S SET UP IN DRIVER...
C  FOR EINT, IF ONLY DIAGONAL IS REQUESTED
      FR=VCONST(2)
      FS=VCONST(3)
      FZ=GS*BM*FACTOR

C  SET UP ELEMENTS OF efvs MODULE
      NEFV=1
      EFVNAM(1)='MAGNETIC Z FIELD'
      EFVUNT(1)='GAUSS'

      RETURN
C========================================================== END OF BAS9IN
      ENTRY SET9(LEVIN,EIN,NSTATE,JSTATE,NQN,QNAME,MXPAR,NLABV,IPRINT)
C
C  SET9 IS CALLED ONCE FOR EACH SCATTERING SYSTEM. IT SETS UP:
C  MXPAR, THE NUMBER OF DIFFERENT SYMMETRY BLOCKS
C  NLABV, THE NUMBER OF INDICES NEEDED TO DESCRIBE EACH TERM
C         IN THE POTENTIAL EXPANSION
C  NLEVEL AND JLEVEL, UNLESS LEVIN IS .TRUE.;
C  JSTATE AND NSTATE;
C  ELEVEL, UNLESS EIN IS .TRUE.
C  IF THE LOGICAL VARIABLES ARE .TRUE. ON ENTRY, THE CORRESPONDING
C  QUANTITIES WERE INPUT EXPLICITLY IN NAMELIST BLOCK &BASIS.
C  IF EIN IS .FALSE., THE MOLECULAR CONSTANTS MUST HAVE BEEN SUPPLIED
C  IN THE &BASIS ARRAY ROTI: THE PROGRAMMER MAY USE THESE IN ANY WAY
C  HE OR SHE LIKES, BUT SHOULD OUTPUT THEM HERE FOR CHECKING.
C  NOTE THAT JLEVEL CONTAINS JUST THE QUANTUM NUMBERS NECESSARY TO
C  SPECIFY THE THRESHOLD ENERGY (AND ELEVEL CONTAINS THE CORRESPONDING
C  ENERGIES) WHEREAS JSTATE CONTAINS ALL THE CHANNEL QUANTUM NUMBERS EXCEPT
C  THE ORBITAL L, WHICH MAY BE A SUPERSET. THE LAST COLUMN OF THE JSTATE
C  ARRAY CONTAINS A POINTER TO THE ENERGY IN THE ELEVEL ARRAY.
C
      MXPAR=2
      NLABV=1
      QNAME(1)='     N  '
      QNAME(2)='     J  '
      QNAME(3)='    MJ  '
      IF (LEVIN) GOTO 220
      NLEVEL=0
      NSTATE=0
      DO 210 NN=JMIN,JMAX,JSTEP
      DO 210 JJ=ABS(NN-IS),NN+IS,1
      DO 210 MM=-JJ,JJ,1
        JLEVEL(3*NLEVEL+1)=NN
        JLEVEL(3*NLEVEL+2)=JJ
        JLEVEL(3*NLEVEL+3)=MM
        NLEVEL=NLEVEL+1
C  NL IS NUMBER OF SETS OF INTERNAL QUANTUM NUMBERS FOR THIS LEVEL
        NL=1
        NSTATE=NSTATE+NL
  210 CONTINUE
      GOTO 230
  220 IF (IPRINT.GE.1) WRITE(6,602)
  602 FORMAT(/'  BASIS FUNCTIONS TAKEN FROM JLEVEL INPUT')
C
C  IF NSTATE AND NLEVEL ARE DIFFERENT, IT MAY BE NECESSARY TO BUILD UP JSTATE
C  IN A DIFFERENT ORDER AND REARRANGE IT LATER - SEE SET3 CODING IN SETBAS
C  NQN IS NUMBER OF QUANTUM NUMBERS PER THRESHOLD+1
C  QNAME(1) TO (NQN-1) ARE NAMES OF QUANTUM NUMBERS
C  LOOP OVER LEVELS AGAIN, THIS TIME SETTING UP JSTATE
C
  230 NL=1
      NSTATE=NLEVEL
      NQN=4
      II=0
      DO 250 I=1,NSTATE
         II=II+1
      DO 250 K=1,NL
         INDX=(NQN-1)*(I-1)
         JSTATE(I)         =JLEVEL(INDX+1)
         JSTATE(I+NSTATE)  =JLEVEL(INDX+2)
         JSTATE(I+NSTATE*2)=JLEVEL(INDX+3)
         JSTATE(I+NSTATE*3)=II
  250 CONTINUE

      IF (IPRINT.GE.1) THEN
         IF (EIN) THEN
            WRITE(6,605)
  605       FORMAT(/'  ENERGY LEVELS TAKEN FROM ELEVEL INPUT')
         ELSE
            WRITE(6,604) (ROTI(I),I=1,3)
  604       FORMAT(/'  ENERGY LEVELS CALCULATED FROM:'/'  Bv     =',
     &              F10.5/'  GAMMA  =',F10.5/'  LAMBDA =',F10.5)
         ENDIF
      ENDIF
      DO 270 I=1,NLEVEL
         NN=JSTATE(I)
         JJ=JSTATE(I+NSTATE)
         MM=JSTATE(I+NSTATE*2)
         IF (EIN) GOTO 270
C  MONOMER ROTATION
         DIAGR=ROTI(1)*DBLE(NN*(NN+1))
C  SPIN-ROTATION
         DIAGSR=FR*SQRT(DBLE(NN*(NN+1)*(2*NN+1)))*SIXJ(IS,NN,IS,NN,JJ,1)
         IF (ODD(NN+JJ+IS)) DIAGSR=-DIAGSR
C  SPIN-SPIN
         DIAGSS=FS*DBLE(2*NN+1)*SIXJ(IS,NN,IS,NN,JJ,2)*THREEJ(NN,2,NN)
         IF (ODD(JJ+IS)) DIAGSS=-DIAGSS
C
         ELEVEL(I)=DIAGR+DIAGSR+DIAGSS
C
  270 CONTINUE
      RETURN
C======================================================== END OF SET9
      ENTRY BASE9(LCOUNT,N,JTOT,IBLOCK,JSTATE,NSTATE,NQN,JSINDX,L,
     1            IPRINT)
C
C  BASE9 IS CALLED EITHER TO COUNT THE ACTUAL NUMBER OF CHANNEL BASIS
C  FUNCTIONS OR ACTUALLY TO SET THEM UP (IN THE JSINDX AND L ARRAYS).
C  IT IS CALLED FOR EACH TOTAL J (JTOT) AND SYMMETRY BLOCK (IBLOCK).
C  IF LCOUNT IS .TRUE. ON ENTRY, JUST COUNT THE BASIS FUNCTIONS. OTHERWISE,
C  SET UP JSINDX (POINTER TO JSTATE) AND L (ORBITAL ANGULAR MOMENTUM) FOR EACH
C  CHANNEL.  THIS MUST TAKE INTO ACCOUNT JTOT AND IBLOCK.
C
C  THIS VERSION USES JTOT FOR |CURLY M| (BEING THE PROJECTION OF CURLY J)
C  AND IBLOCK = 1/2 FOR NEGATIVE/POSITIVE PARITY
C  SIGN OF CURLY M NOT NEEDED BECAUSE FIELD CAN BE SET TO NEGATIVE
C
      M=JTOT
      N=0
      DO 320 I=1,NSTATE
         NN=JSTATE(I)
         MM=JSTATE(2*NSTATE+I)
         LMINN=ABS(M-MM)
         DO 310 LL=LMINN,LMAX
            IF (LL.LT.LMIN) GOTO 310 ! ADDED BY AW 30/10/07
            IF (MLREQ.NE.999 .AND. M-MM.NE.MLREQ) GOTO 310
C  PARITY CHECK
            IF (ODD(IBLOCK+NN+LL+1)) GOTO 310
            N=N+1
            IF (LCOUNT) GOTO 310
            JSINDX(N)=I
            L(N)=LL
  310    CONTINUE
  320 CONTINUE
C
      IF (LCOUNT .AND. IPRINT.GE.1) WRITE(6,608) M,IBLOCK-1
 608  FORMAT(/'  BASIS SET FOR MTOT = ',I2,', PARITY = (-1)**',I1)
C
      RETURN
C============================================================ END OF BASE9
      ENTRY CPL9(N,IBLOCK,NHAM,LAM,MXLAM,NSTATE,JSTATE,JSINDX,L,JTOT,
     1           VL,IV,CENT,DGVL,IBOUND,IEXCH,IPRINT)
C
C  CPL9 IS CALLED AFTER BASE9 FOR EACH JTOT AND IBLOCK, TO SET UP THE
C  POTENTIAL COUPLING COEFFICIENTS VL.
C
C  THIS VERSION USES JTOT FOR |CURLY M| (BEING THE PROJECTION OF CURLY J)
C  AND IBLOCK = 1/2 FOR NEGATIVE/POSITIVE PARITY
C
      MXLAMM=MXLAM
      M=JTOT
!     NHAM=MXLAM+NCONST+NRSQ
      MXLL=MXLAM+NCONST+NRSQ
      IF (IBSFLG.EQ.1) THEN
!       NHAM=MXLAM+NRSQ
        MXLL=MXLAM+NRSQ
        DO I=1,N
          NN=JSTATE(JSINDX(I))
          JJ=JSTATE(JSINDX(I)+NSTATE)
          MM=JSTATE(JSINDX(I)+NSTATE*2)
          DJJ=DBLE(JJ)
          DMM=DBLE(MM)
          DGVL(I)=FZ*(2*JJ+1)*
     1            THRJ(DJJ,1.D0,DJJ,-DMM,0.D0,DMM)*
     2            SIXJ(JJ,JJ,IS,IS,1,NN)
          IF (ODD(NN+IS+1-MM)) DGVL(I)=-DGVL(I)
        ENDDO
      ENDIF

      DO 550 LL=1,MXLL
        IF (LL.LE.MXLAM) LAMB=LAM(LL)
        NNZ=0
        I=LL
        DO 540 ICOL=1,N
          NCOL= JSTATE(JSINDX(ICOL))
          JCOL= JSTATE(JSINDX(ICOL)+NSTATE)
          MJCOL=JSTATE(JSINDX(ICOL)+NSTATE*2)
          LCOL= L(ICOL)
          MLCOL=M-MJCOL
          DO 530 IROW=1,ICOL
            NROW= JSTATE(JSINDX(IROW))
            JROW= JSTATE(JSINDX(IROW)+NSTATE)
            MJROW=JSTATE(JSINDX(IROW)+NSTATE*2)
            LROW= L(IROW)
            MLROW=M-MJROW
            VL(I)=0.D0
C  CONVENTION HERE IS COLUMN -> "NO PRIME", ROW -> "PRIME"
C  INCLUDES HINT'S DIAGONAL AND OFF-DIAGONAL TERMS
C  SETS UP MONOMER ROTATION TERMS (ARE DIAGONAL ONLY)
            IF (LL.EQ.MXLAM+1) THEN
              IF (ICOL.EQ.IROW) VL(I)=DBLE(NCOL*(NCOL+1))
C  SETS UP SPIN-ROTATION TERMS (ARE DIAGONAL ONLY)
            ELSEIF (LL.EQ.MXLAM+2) THEN
              IF (ICOL.EQ.IROW)
     &          VL(I)=PARSGN(NCOL+JCOL+IS)*
     &                SQRT(DBLE(NCOL*(NCOL+1)*(2*NCOL+1)))*
     &                SIXJ(IS,NCOL,IS,NCOL,JCOL,1)
C  SETS UP ALL ELECTRON SPIN-SPIN TERMS
            ELSEIF (LL.EQ.MXLAM+3) THEN
              IF (DIAG(1,JCOL,MJCOL,LCOL,MLCOL,
     &                 1,JROW,MJROW,LROW,MLROW) .AND.
     &                 .NOT.ODD(NCOL+NROW)) THEN
                VL(I)=PARSGN(JCOL+IS)* ! AS (NCOL + NROW) IS ALREADY EVEN!!
     &                SQRT(DBLE((2*NCOL+1)*(2*NROW+1)))*
     &                SIXJ(IS,NROW,IS,NCOL,JCOL,2)*THREEJ(NCOL,2,NROW)
              ENDIF
C  SETS UP ALL ELECTRON SPIN-ZEEMAN TERMS
            ELSEIF (LL.EQ.MXLAM+4) THEN
              IF (DIAG(NCOL,1,MJCOL,LCOL,MLCOL,
     &                 NROW,1,MJROW,LROW,MLROW)) THEN
                VL(I)=FZ*PARSGN(NCOL+IS+1-MJCOL)*
     &                SQRT(DBLE((2*JCOL+1)*(2*JROW+1)))*
     &                SIXJ(IS,JROW,IS,JCOL,NCOL,1)*
     &                THRJ(DBLE(JCOL),1.D0,DBLE(JROW),
     &                     DBLE(-MJCOL),0.D0,DBLE(MJCOL))
              ENDIF
C  INCLUDES LEGENDRE POLYNOMIALS COUPLING ELEMENTS
            ELSE
              MLAMB=MLROW-MLCOL
C  NEXT IF EXPLOITS SOME 3-J SYMBOLS PROPERTIES
              IF (ABS(MLAMB).GT.LAMB .OR. MLAMB.NE.(MJCOL-MJROW) .OR.
     &            ODD(NCOL+LAMB+NROW) .OR. ODD(LCOL+LAMB+LROW)) GOTO 520
              FAC1=SQRT(DBLE((2*NCOL+1)*(2*NROW+1)*
     &                       (2*LCOL+1)*(2*LROW+1)))
              FAC2=THREEJ(NCOL,LAMB,NROW)*THREEJ(LCOL,LAMB,LROW)*
     &             THRJ(DBLE(LCOL),DBLE(LAMB),DBLE(LROW),
     &                  DBLE(-MLCOL),DBLE(-MLAMB),DBLE(MLROW))
              FAC3=SQRT(DBLE((2*JCOL+1)*(2*JROW+1)))*
     &             SIXJ(JCOL,JROW,NCOL,NROW,LAMB,IS)*
     &             THRJ(DBLE(JCOL),DBLE(LAMB),DBLE(JROW),
     &                  DBLE(-MJCOL),DBLE(MLAMB),DBLE(MJROW))
              VL(I)=PARSGN(IS+JCOL+JROW+LAMB+MLAMB-M)*FAC1*FAC2*FAC3
            ENDIF
            IF (VL(I).NE.0.D0) NNZ=NNZ+1
  520       I=I+NHAM
  530     CONTINUE
  540   CONTINUE
        IF (NNZ.EQ.0) WRITE(6,612) JTOT,LL
  612   FORMAT('  * * * NOTE.  FOR JTOT =',I4,',  ALL COUPLING',
     1         ' COEFFICIENTS ARE 0.0 FOR POTENTIAL SYMMETRY',I4)
  550 CONTINUE
      RETURN
C=============================================================== END OF CPL9
      ENTRY THRSH9(JREF,MONQN,NQN1,EREF,IPRINT)
C
C  THIS CALCULATES THRESHOLDS FOR A TRIPLET-SIGMA MOLECULE INTERACTING
C  WITH A STRUCTURELESS ATOM (WHICH CONTRIBUTES NOTHING).
C  THE MONOMER QUANUM NUMBERS ARE SPECIFIED IN THE ARRAY MONQN, AND ARE:
C     MONQN(1): n
C     MONQN(2): j
C     MONQN(3): m_j
C
      BFIELD=EFV(1)
      IF (NDGVL.GT.0 .AND. IPERTN.EQ.-1) BFIELD=BFIELD+DELTAN
      IF (NDGVL.EQ.0 .AND. IPERTN.EQ.MXLAMM+4) BFIELD=BFIELD+DELTAN
      IF (JREF.GT.0) THEN
        WRITE(6,*) ' *** ERROR - THRSH9 CALLED WITH POSITIVE IREF'
        STOP
      ENDIF
C
      IF (MONQN(1).EQ.-99999) THEN
        WRITE(6,*) ' *** ERROR - THRSH9 CALLED WITH MONQN UNSET'
        STOP
      ENDIF
C
      NN=MONQN(1)
      JJ=MONQN(2)
      MM=MONQN(3)
      DJJ=DBLE(JJ)
      DMM=DBLE(MM)
C  IN THE FOLLOWING, THE 3 CONDITIONS ARE
C     - REQUESTED NEGLECT OF OFF-DIAGONAL TERMS
C     - NO OFF-DIAGONAL TERMS EXIST
C     - UPPER ROTATIONAL FUNCTION EXISTS BUT EXCLUDED BY BASIS SET SIZE
      IF (IBSFLG.EQ.1 .OR. NN.EQ.JJ .OR. JJ.GE.JMAX) THEN
C  MONOMER ROTATION
         DIAGR=ROTI(1)*DBLE(NN*(NN+1))
C  SPIN-ROTATION
         DIAGSR=FR*SQRT(DBLE(NN*(NN+1)*(2*NN+1)))*SIXJ(IS,NN,IS,NN,JJ,1)
         IF (ODD(NN+JJ+IS)) DIAGSR=-DIAGSR
C  SPIN-SPIN
         DIAGSS=FS*(2*NN+1)*SIXJ(IS,NN,IS,NN,JJ,2)*THREEJ(NN,2,NN)
         IF (ODD(JJ+IS)) DIAGSS=-DIAGSS
         DIAGB=BFIELD*FZ*(2*JJ+1)*
     1         THRJ(DJJ,1.D0,DJJ,-DMM,0.D0,DMM)*
     2         SIXJ(JJ,JJ,IS,IS,1,NN)
         IF (ODD(NN+IS+1-MM)) DIAGB=-DIAGB
         EREF=DIAGR+DIAGSR+DIAGSS+DIAGB
      ELSE
C       2X2 MATRIX WITH n = j-1 AND j+1
         NN=JJ-1
         DIAGR=ROTI(1)*DBLE(NN*(NN+1))
         DIAGSR=FR*SQRT(DBLE(NN*(NN+1)*(2*NN+1)))*SIXJ(IS,NN,IS,NN,JJ,1)
         IF (ODD(NN+JJ+IS)) DIAGSR=-DIAGSR
         DIAGSS=FS*DBLE(2*NN+1)*SIXJ(IS,NN,IS,NN,JJ,2)*THREEJ(NN,2,NN)
         IF (ODD(JJ+IS)) DIAGSS=-DIAGSS
         DIAGB=BFIELD*FZ*(2*JJ+1)*
     1         THRJ(DJJ,1.D0,DJJ,-DMM,0.D0,DMM)*
     2         SIXJ(JJ,JJ,IS,IS,1,NN)
         IF (ODD(NN+IS+1-MM)) DIAGB=-DIAGB
         EM=DIAGR+DIAGSR+DIAGSS+DIAGB
         NN=JJ+1
         DIAGR=ROTI(1)*DBLE(NN*(NN+1))
         DIAGSR=FR*SQRT(DBLE(NN*(NN+1)*(2*NN+1)))*SIXJ(IS,NN,IS,NN,JJ,1)
         IF (ODD(NN+JJ+IS)) DIAGSR=-DIAGSR
         DIAGSS=FS*DBLE(2*NN+1)*SIXJ(IS,NN,IS,NN,JJ,2)*THREEJ(NN,2,NN)
         IF (ODD(JJ+IS)) DIAGSS=-DIAGSS
         DIAGB=BFIELD*FZ*(2*JJ+1)*
     1         THRJ(DJJ,1.D0,DJJ,-DMM,0.D0,DMM)*
     2         SIXJ(JJ,JJ,IS,IS,1,NN)
         IF (ODD(NN+IS+1-MM)) DIAGB=-DIAGB
         EP=DIAGR+DIAGSR+DIAGSS+DIAGB
         ODSS=FS*SQRT(DBLE(2*NN+1)*(2*NN-3))*SIXJ(IS,JJ-1,IS,JJ+1,JJ,2)*
     1         THREEJ(JJ-1,2,JJ+1)
C  SOLVE 2X2 WITH DIAGONAL ELEMENTS EM AND EP AND OFF-DIAGONAL ODSS
         DIF=SQRT((EM-EP)**2+4.D0*ODSS**2)
C  PICK EITHER UPPER OR LOWER EIGENVALUE DEPENDING ON REQUIRED N
         EREF=0.5D0*(EM+EP+SIGN(DIF,DBLE(MONQN(1)-JJ)))
      ENDIF
      RETURN
      END
