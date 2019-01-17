      DOUBLE PRECISION FUNCTION DRCALC(RSTART,RSTOP,KSTEP,NSTEP,POW)
      IMPLICIT NONE
C  Copyright (C) 2019 J. M. Hutson & C. R. Le Sueur
C  Distributed under the GNU General Public License, version 3

C  CR LeSueur Jan 2019
C
C  THIS FUNCTION CALCULATES THE NEXT STEP SIZE WHEN STEPS ARE RELATED BY
C  AN ARITHMETIC SERIES IN R**(1/POW)
C
C  NOTE THAT, FOR POW=1, THIS REDUCES TO CONSTANT STEP SIZE
C
      DOUBLE PRECISION, INTENT(IN) :: RSTART, RSTOP, POW
      INTEGER,          INTENT(IN) :: KSTEP, NSTEP

      DOUBLE PRECISION :: POWINV, ZSTART, ZSTOP, DZ, RNOW, RLAST

      POWINV=1.D0/POW
      ZSTART=RSTART**POWINV
      ZSTOP=RSTOP**POWINV
      DZ=(ZSTOP-ZSTART)/DBLE(NSTEP)

      RNOW=(ZSTART+DBLE(KSTEP+1)*DZ)**POW
      RLAST=(ZSTART+DBLE(KSTEP)*DZ)**POW
      DRCALC=RNOW-RLAST

      RETURN
      END