!====================================================================!
!                                                                    !
! Copyright 2002-2017,2018                                           !
! Mikael Granvik, Jenni Virtanen, Karri Muinonen, Teemu Laakso,      !
! Dagmara Oszkiewicz, Lauri Siltala                                  !
!                                                                    !
! This file is part of OpenOrb.                                      !
!                                                                    !
! OpenOrb is free software: you can redistribute it and/or modify it !
! under the terms of the GNU General Public License as published by  !
! the Free Software Foundation, either version 3 of the License, or  !
! (at your option) any later version.                                !
!                                                                    !
! OpenOrb is distributed in the hope that it will be useful, but     !
! WITHOUT ANY WARRANTY; without even the implied warranty of         !
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  !
! General Public License for more details.                           !
!                                                                    !
! You should have received a copy of the GNU General Public License  !
! along with OpenOrb. If not, see <http://www.gnu.org/licenses/>.    !
!                                                                    !
!====================================================================!
!
!! *Module*description*:
!!
!! Defines parameters relating to planets and minor planets in the
!! solar system, and contains the routines for using planetary
!! ephemerides provided by JPL and IMCCE.
!!
!! This software is partly based on <i>jplsub.f</i> (by JPL) and a
!! Fortran 90 compilation of the same software by Hannu Karttunen
!! (Tuorla Observatory, Turku, Finland).
!!
!! *Example*:
!!
!!<pre>
!!program myprog
!!
!! use planetary_data
!! implicit none
!! real(8), dimension(6) :: crtcrd
!! real(8) :: t
!! logical :: error
!!
!! crtcrd = JPL_ephemeris(t, 3, 11, error)
!! if (error) stop 'Error 2'
!!
!!end program myprog
!!</pre>
!!
!! @author  MG, TL
!! @version 2018-06-12
!!
MODULE planetary_data

  USE parameters
  USE linal
  USE sort
  USE utilities
  IMPLICIT NONE
  PRIVATE
  CHARACTER(len=FNAME_LEN), PARAMETER :: EPH_FNAME = 'de430.dat'
  INTEGER, PARAMETER            :: min_lu = 10
  INTEGER, PARAMETER            :: max_lu = 99
  INTEGER, PARAMETER            :: RECORD_LENGTH = 4
  INTEGER, PARAMETER            :: RECORD_SIZE_405 =  2036
  INTEGER, PARAMETER            :: RECORD_SIZE_406 =  1456
  INTEGER, PARAMETER            :: RECORD_SIZE_430 =  2036
  INTEGER, PARAMETER            :: RECORD_SIZE_431 =  2036
  INTEGER, PARAMETER            :: RECORD_SIZE_INPOP10B =  1876
  INTEGER, PARAMETER            :: NCOEFF_405 = 1018
  INTEGER, PARAMETER            :: NCOEFF_406 = 728
  INTEGER, PARAMETER            :: NCOEFF_430 = 1018
  INTEGER, PARAMETER            :: NCOEFF_431 = 1018
  INTEGER, PARAMETER            :: NCOEFF_INPOP10B = 938
  INTEGER, PARAMETER            :: NRECORD_MAX = 250000 ! Fits all of de40x and de43x
  REAL(rprec8), PARAMETER       :: kgm3_smau3 = (1.4959787066e8_rprec8)**3/1.989100e30

  ! Planets' GMs are read from the ephemeris file
  ! Unit: AU^3 day^(-2)
  REAL(rprec8), DIMENSION(17), PUBLIC :: planetary_mu
  !! Masses are computed based on above GMs
  REAL(rprec8), DIMENSION(17), PUBLIC :: planetary_masses


  CHARACTER(len=23), DIMENSION(13), PARAMETER, PUBLIC :: planetary_locations = (/ &
       "Mercury                ", &
       "Venus                  ", &
       "Earth                  ", &
       "Mars                   ", &
       "Jupiter                ", &
       "Saturn                 ", &
       "Uranus                 ", &
       "Neptune                ", &
       "Pluto                  ", &
       "Moon                   ", &
       "Sun                    ", &
       "solar-system_barycenter", &
       "Earth-Moon_barycenter  " /)

  ! Unit: AU
  REAL(rprec8), DIMENSION(17), PARAMETER, PUBLIC :: planetary_radii = (/ &
       1.63037e-5_rprec8, &   !!  (1) Mercury,
       4.04551e-5_rprec8, &   !!  (2) Venus,
       4.25641e-5_rprec8, &   !!  (3) Earth,
       2.26491e-5_rprec8, &   !!  (4) Mars,
       4.62908e-4_rprec8, &   !!  (5) Jupiter,
       3.81021e-4_rprec8, &   !!  (6) Saturn,
       1.72128e-4_rprec8, &   !!  (7) Uranus,
       1.60096e-4_rprec8, &   !!  (8) Neptune,
       8.17191e-6_rprec8, &   !!  (9) Pluto,
       1.16178e-5_rprec8, &   !! (10) Moon,
       4.65424e-3_rprec8, &   !! (11) Sun,
       0.e0_rprec8,       &   !! (12) solar system barycenter,
       0.e0_rprec8,       &   !! (13) Earth-Moon barycenter,
       0.e0_rprec8,       &   !! (14) Asteroid,
       3.05151e-6_rprec8, &   !! (15) Ceres,
       1.74802e-6_rprec8, &   !! (16) Pallas,
       1.67449e-6_rprec8  /)  !! (17) Vesta

  ! Data from http://nssdc.gsfc.nasa.gov/planetary/planetfact.html
  ! Unit: M_sol AU^(-3)
  REAL(rprec8), DIMENSION(17), PARAMETER, PUBLIC :: planetary_densities = (/ &
       5427.0_rprec8*kgm3_smau3, &               !!  (1) Mercury,
       5243.0_rprec8*kgm3_smau3, &               !!  (2) Venus,
       5515.0_rprec8*kgm3_smau3, &               !!  (3) Earth,
       3933.0_rprec8*kgm3_smau3, &               !!  (4) Mars,
       1326.0_rprec8*kgm3_smau3, &               !!  (5) Jupiter,
       687.0_rprec8*kgm3_smau3, &                !!  (6) Saturn,
       1270.0_rprec8*kgm3_smau3, &               !!  (7) Uranus,
       1632.0_rprec8*kgm3_smau3, &               !!  (8) Neptune,
       1750.0_rprec8*kgm3_smau3, &               !!  (9) Pluto,
       3340.0_rprec8*kgm3_smau3, &               !! (10) Moon,
       1408.0_rprec8*kgm3_smau3, &               !! (11) Sun,
       -1.0_rprec8, &                            !! (12) solar system barycenter,
       -1.0_rprec8, &                            !! (13) Earth-Moon barycenter,
       2500.0_rprec8*kgm3_smau3, &               !! (14) Asteroid,
       0.0_rprec8, &                             !! (15) Ceres,
       0.0_rprec8, &                             !! (16) Pallas,
       0.0_rprec8  /)                            !! (17) Vesta

  CHARACTER(len=6), DIMENSION(14,3)         :: ttl
  CHARACTER(len=6), DIMENSION(400)          :: cnam
  REAL(rprec8), DIMENSION(:,:), ALLOCATABLE :: buf
  REAL(rprec8), DIMENSION(400)              :: cval
  REAL(rprec8), DIMENSION(3)                :: ss
  REAL(rprec8)                              :: au, emrat
  INTEGER, DIMENSION(3,13)                  :: ipt
  INTEGER                                   :: numde, ncon, rec_size, eph_size
  LOGICAL                                   :: first = .TRUE.
  LOGICAL                                   :: first_bc = .TRUE.
  LOGICAL                                   :: kilometres = .FALSE.
  LOGICAL                                   :: barycenter = .TRUE.

  ! BC430 asteroid ephemeris data
  REAL(rprec8), DIMENSION(:,:,:), ALLOCATABLE   :: asteroid_ephemerides
  REAL(rprec8), DIMENSION(3653)                 :: asteroid_epochs
  REAL(rprec8), DIMENSION(:), ALLOCATABLE       :: asteroid_masses
  LOGICAL, DIMENSION(300)                       :: asteroid_masks = .TRUE.
  CHARACTER(len=10), DIMENSION(300)             :: asteroid_indices

  PUBLIC :: JPL_ephemeris_init
  PUBLIC :: JPL_ephemeris
  PUBLIC :: JPL_ephemeris_nullify
  PUBLIC :: BC_ephemeris
  PUBLIC :: BC_ephemeris_init
  PUBLIC :: BC_masses
  PUBLIC :: Hill_radius

  INTERFACE JPL_ephemeris
     MODULE PROCEDURE JPL_ephemeris_r8
     MODULE PROCEDURE JPL_ephemeris_perturbers_r8
     MODULE PROCEDURE JPL_ephemeris_r16
     MODULE PROCEDURE JPL_ephemeris_perturbers_r16
  END INTERFACE JPL_ephemeris

  INTERFACE BC_ephemeris
     MODULE PROCEDURE BC_ephemeris_r8
  END INTERFACE BC_ephemeris

  INTERFACE BC_masses
     MODULE PROCEDURE BC_masses_r8
  END INTERFACE BC_masses
CONTAINS


  !! *Description*:
  !!
  !! Returns the radius of the Hill sphere
  !!
  !!    r_H ~ a_1(1-e_1) * (mass_1/3mass_2)^(1/3))
  !!
  !! where M_1 and M_2 are the masses of the object whose Hill-sphere
  !! radius is sought (e.g., the Earth) and the object around which
  !! the previous revolves (e.g., the Sun), respectively. The
  !! semimajor axis a_1 and eccentricity e_1 refer to the previous
  !! object. The default values for a_1 (= 1.0 AU) and e_1 (= 0) will
  !! be used if they are not explicitly given.
  !!
  REAL(rprec8) FUNCTION Hill_radius(mass_1, mass_2, a_1, e_1)

    IMPLICIT NONE
    REAL(rprec8), INTENT(in) :: mass_1, mass_2
    REAL(rprec8), OPTIONAL, INTENT(in) :: a_1, e_1

    REAL(rprec8) :: a_, e_

    IF (PRESENT(a_1)) THEN
       a_ = a_1
    ELSE
       a_ = 1.0_rprec8
    END IF
    IF (PRESENT(e_1)) THEN
       e_ = e_1
    ELSE
       e_ = 0.0_rprec8
    END IF

    Hill_radius =  a_*(1.0_rprec8-e_) * (mass_1/(3*mass_2))**(1.0_rprec8/3)

  END FUNCTION Hill_radius





  !! *Description*:
  !!
  !! If used for the first time during execution, this routine reads
  !! the JPL Planetary Ephemerides from a given file (e.g., de405.dat
  !! at JPL) and stores the data in an array.
  !!
  !! Returns error.
  !!
  SUBROUTINE JPL_ephemeris_init(error, filename)

    IMPLICIT NONE
    LOGICAL, INTENT(inout)                 :: error
    CHARACTER(len=*), OPTIONAL, INTENT(in) :: filename
    CHARACTER(len=FNAME_LEN)               :: fname, OORB_DATA_DIR
    CHARACTER(len=3)                       :: dtype
    REAL(rprec8), DIMENSION(:,:), ALLOCATABLE :: tmp
    INTEGER                                :: err, i, lu, count, fnstart
    LOGICAL                                :: done, used

    ! Make sure this is the first call to this routine
    IF (.NOT.first) THEN
       RETURN
    END IF

    IF (PRESENT(filename) .AND. LEN_TRIM(filename) <= FNAME_LEN) THEN
       fname = TRIM(filename)
    ELSE
       ! only use with gfortran
       !CALL get_environment_variable("OORB_DATA", OORB_DATA_DIR)
       ! only use with g95
       CALL getenv("OORB_DATA", OORB_DATA_DIR)
       IF (LEN_TRIM(OORB_DATA_DIR) == 0) THEN
          OORB_DATA_DIR = "."
       END IF
       fname = TRIM(OORB_DATA_DIR) // "/" // TRIM(EPH_FNAME)
    END IF

    ! Find a free logical unit:
    done = .FALSE.
    count = min_lu
    lu = min_lu
    DO WHILE (.NOT. done)
       ! Figure out whether this unit is taken or not:
       INQUIRE(unit=lu, opened=used, iostat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "JPL_ephemeris_init(): Error when inquiring for status of logical unit."
          RETURN
       END IF
       IF (used) THEN
          count = count + 1
          ! If more than max_lu units have been tried,
          ! every available unit has been tried at least once.
          ! A free unit could not be found:
          IF (count > max_lu) THEN
             error = .TRUE.
             WRITE(0,*) "JPL_ephemeris_init(): Could not find a free logical unit."
             RETURN
          END IF
          lu = lu + 1
          ! Back to beginning if top is reached:
          IF (lu > max_lu) lu = min_lu
       ELSE
          done = .TRUE.
       END IF
    END DO

    ! Read deXXX.dat (or whatever you call the JPL Planetary Ephemeris file):
    !WRITE(0,"(A,1X,A)") "Using ephemeris file ", TRIM(fname)
    fnstart = INDEX(fname,"/",back=.TRUE.)
    IF (INDEX(fname,"405",back=.TRUE.) .GT. fnstart) THEN
       dtype = "405"
       OPEN(unit=lu, file=TRIM(fname), status='OLD', access='DIRECT', &
            recl=RECORD_LENGTH*RECORD_SIZE_405, action='READ', iostat=err)
    ELSE IF (INDEX(fname,"406",back=.TRUE.) .GT. fnstart) THEN
       dtype = "406"
       OPEN(unit=lu, file=TRIM(fname), status='OLD', access='DIRECT', &
            recl=RECORD_LENGTH*RECORD_SIZE_406, action='READ', iostat=err)
    ELSE IF (INDEX(fname,"430",back=.TRUE.) .GT. fnstart) THEN
       dtype = "430"
       OPEN(unit=lu, file=TRIM(fname), status='OLD', access='DIRECT', &
            recl=RECORD_LENGTH*RECORD_SIZE_430, action='READ', iostat=err)
    ELSE IF (INDEX(fname,"431",back=.TRUE.) .GT. fnstart) THEN
       dtype = "431"
       OPEN(unit=lu, file=TRIM(fname), status='OLD', access='DIRECT', &
            recl=RECORD_LENGTH*RECORD_SIZE_431, action='READ', iostat=err)
    ELSE IF (INDEX(fname,"inpop10b",back=.TRUE.) .GT. fnstart) THEN
       dtype = "10b"
       OPEN(unit=lu, file=TRIM(fname), status='OLD', access='DIRECT', &
            recl=RECORD_LENGTH*RECORD_SIZE_INPOP10B, action='READ', iostat=err)
    ELSE
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not select correct record length for file '" &
            // TRIM(fname) // "'."
       RETURN
    END IF
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not open file '" // TRIM(fname) // "'."
       RETURN
    END IF

    READ(lu, rec=1, iostat=err) ttl, cnam, ss, ncon, &
         au, emrat, ipt(1:3,1:12), numde, ipt(1:3,13)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not read record #1."
       RETURN
    END IF

    READ(lu, rec=2, iostat=err) cval
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not read record #2."
       RETURN
    END IF

    IF (dtype == "405") THEN
       ALLOCATE(tmp(NCOEFF_405,NRECORD_MAX), stat=err)
    ELSE IF (dtype == "406") THEN
       ALLOCATE(tmp(NCOEFF_406,NRECORD_MAX), stat=err)
    ELSE IF (dtype == "430") THEN
       ALLOCATE(tmp(NCOEFF_430,NRECORD_MAX), stat=err)
    ELSE IF (dtype == "431") THEN
       ALLOCATE(tmp(NCOEFF_431,NRECORD_MAX), stat=err)
    ELSE IF (dtype == "10b") THEN
       ALLOCATE(tmp(NCOEFF_INPOP10B,NRECORD_MAX), stat=err)
    ELSE
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could select correct amount of memory for file '" &
            // TRIM(fname) // "'."
       RETURN
    END IF
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not allocate memory (5)."
       DEALLOCATE(tmp, stat=err)
       RETURN
    END IF
    i = 1
    DO
       READ(lu, rec=i+2, iostat=err) tmp(:,i)
       IF (err /= 0) THEN
          i = i - 1
          EXIT
       ELSE
          i = i + 1
          IF (i+2 > NRECORD_MAX) THEN
             error = .TRUE.
             WRITE(0,*) "JPL_ephemeris_init(): NRECORD_MAX too small."
             DEALLOCATE(tmp, stat=err)
             RETURN
          END IF
       END IF
    END DO

    ! Planets' and Moon's GMs
    planetary_mu = 0.0_rprec8
    IF (dtype == "405" .OR. dtype == "406") THEN

       !  (1) Mercury,
       !  (2) Venus,
       !  (3) Earth,
       !  (4) Mars,
       !  (5) Jupiter,
       !  (6) Saturn,
       !  (7) Uranus,
       !  (8) Neptune,
       !  (9) Pluto,
       planetary_mu(1:9) = cval(9:17)
       ! remove Moon from EMS's GM to get Earth's GM
       emrat = cval(8)
       planetary_mu(3) = planetary_mu(3)/(1.0_rprec8 + 1.0_rprec8/emrat)
       ! (10) Moon,
       planetary_mu(10) = planetary_mu(3)/emrat
       ! (11) Sun,
       planetary_mu(11) = cval(18)
       ! (12) solar system barycenter,
       planetary_mu(12) = SUM(planetary_mu(1:11))
       ! (13) Earth-Moon barycenter,
       planetary_mu(13) = cval(11)

    ELSE IF (dtype == "430" .OR. dtype == "431") THEN

       !  (1) Mercury,
       !  (2) Venus,
       !  (3) Earth,
       !  (4) Mars,
       !  (5) Jupiter,
       !  (6) Saturn,
       !  (7) Uranus,
       !  (8) Neptune,
       !  (9) Pluto,
       planetary_mu(1:9) = cval(12:20)
       ! remove Moon from EMS's GM to get Earth's GM
       emrat = cval(11)
       planetary_mu(3) = planetary_mu(3)/(1.0_rprec8 + 1.0_rprec8/emrat)
       ! (10) Moon,
       planetary_mu(10) = planetary_mu(3)/emrat
       ! (11) Sun,
       planetary_mu(11) = cval(21)
       ! (12) solar system barycenter,
       planetary_mu(12) = SUM(planetary_mu(1:11))
       ! (13) Earth-Moon barycenter,
       planetary_mu(13) = cval(14)

    ELSE IF (dtype == "10b") THEN

       !  (1) Mercury,
       !  (2) Venus,
       !  (3) Earth,
       !  (4) Mars,
       !  (5) Jupiter,
       !  (6) Saturn,
       !  (7) Uranus,
       !  (8) Neptune,
       !  (9) Pluto,
       planetary_mu(1:9) = cval(7:15)
       ! remove Moon from EMS's GM to get Earth's GM
       planetary_mu(3) = planetary_mu(3)/(1.0_rprec8 + 1.0_rprec8/emrat)
       ! (10) Moon,
       planetary_mu(10) = planetary_mu(3)/emrat
       ! (11) Sun,
       planetary_mu(11) = cval(16)
       ! (12) solar system barycenter,
       planetary_mu(12) = SUM(planetary_mu(1:11))
       ! (13) Earth-Moon barycenter,
       planetary_mu(13) = cval(9)

    END IF

    ! Planets' and Moon's mass
    ! Unit: M_sol
    planetary_masses = planetary_mu/planetary_mu(11)

    ALLOCATE(buf(SIZE(tmp,dim=1),i), stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not allocate memory (10)."
       DEALLOCATE(tmp, stat=err)
       RETURN
    END IF
    buf(1:SIZE(tmp,dim=1),1:i) = tmp(1:SIZE(tmp,dim=1),1:i)
    DEALLOCATE(tmp, stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_init(): Could not deallocate memory."
       RETURN
    END IF
    CLOSE(lu)
    first = .FALSE.

  END SUBROUTINE JPL_ephemeris_init





  !! *Description*:
  !!
  !! Deallocates memory used by the planetary ephemerides. Should be
  !! used at the very end of an executable.
  !!
  !! Returns error.
  !!
  SUBROUTINE JPL_ephemeris_nullify()

    IMPLICIT NONE
    INTEGER :: err

    DEALLOCATE(buf, stat=err)

  END SUBROUTINE JPL_ephemeris_nullify





  !! *Description*:
  !!
  !! Reads the JPL Planetary Ephemeris and gives the position and
  !! velocity of the point 'ntarget' with respect to 'ncenter'.
  !!
  !! ntarget = integer number of target point.
  !!
  !! ncentet = integer number of center point.
  !!
  !! The numbering convention for 'ntarget' and 'ncenter' is:
  !!
  !!<pre>
  !!         1 = Mercury            8 = Neptune
  !!         2 = Venus              9 = Pluto
  !!         3 = Earth             10 = Moon
  !!         4 = Mars              11 = Sun
  !!         5 = Jupiter          (12 = solar-system barycenter)
  !!         6 = Saturn           (13 = earth-moon barycenter)
  !!         7 = Uranus           (14 = nutations (longitude and obliq))
  !!                              (15 = librations, if on eph file)
  !!<pre>
  !!  Additional: -10 = 9 planets + Moon
  !!
  !! If nutations are wanted, set ntarget = 14, and for librations,
  !! set ntarget = 15. Set ncenter = 0.
  !!
  !! Output is a 6-vector containing position and velocity of point
  !! 'ntarget' relative to 'ncenter' in an equatorial reference
  !! frame. The units are AU and AU/day.  For librations the units are
  !! radians and radians per day.
  !!
  !! Returns error.
  !!
  !! ntarget=-10 and ncenter=11 tested to produce correct results.
  !! ntarget=-10 and ncenter=12 tested to produce correct results.
  !!
  ! In the case
  ! of nutations the first four words of rrd will be set to nutations and
  ! rates, having units of radians and radians/day.
  !!
  !! Known errors:
  !!
  !!  ntarget  ncenter
  !!    13       11        (note that 11 13 works?!?)
  !!    -9       11
  !!    -9       12
  !!
  FUNCTION JPL_ephemeris_r8(mjd_tt, ntarget, ncenter, error, km)

    IMPLICIT NONE
    REAL(rprec8), INTENT(in)              :: mjd_tt
    INTEGER, INTENT(in)                   :: ntarget, ncenter
    LOGICAL, INTENT(inout)                :: error
    LOGICAL, OPTIONAL, INTENT(in)         :: km
    REAL(rprec8), DIMENSION(:,:), POINTER :: JPL_ephemeris_r8

    REAL(rprec8), DIMENSION(13,6) :: celements
    REAL(rprec8), DIMENSION(6)    :: celements_
    REAL(rprec8), DIMENSION(2)    :: tt2
    INTEGER, DIMENSION(12)        :: list
    INTEGER                       :: i, k, err
    LOGICAL                       :: tmp_barycenter

    celements = 0.0_rprec8

    IF (first) THEN
       CALL JPL_ephemeris_init(error)
       IF (error) THEN
          WRITE(0,*) "JPL_ephemeris_r8(): Error when calling JPL_ephemeris_init()."
          RETURN
       END IF
    END IF

    IF (ntarget == ncenter) THEN
       ALLOCATE(JPL_ephemeris_r8(1,6), stat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "JPL_ephemeris_r8(): Could not allocate memory for output (1)."
          RETURN
       END IF
       JPL_ephemeris_r8(1,1:6) = 0.0_rprec8
       RETURN
    END IF

    IF (PRESENT(km)) THEN
       kilometres = km
    END IF

    tt2(1) = mjd_tt + 2400000.5_rprec8 ! convert to Julian date
    tt2 = split(tt2(1))
    IF (tt2(2) < 0.5_rprec8) THEN
       tt2(1) = tt2(1) - 0.5_rprec8
       tt2(2) = tt2(2) + 0.5_rprec8
    ELSE
       tt2(1) = tt2(1) + 0.5_rprec8
       tt2(2) = tt2(2) - 0.5_rprec8
    END IF
    list = 0

    !  check for librations
    IF (ntarget == 15) THEN
       IF (ipt(2,13) > 0) THEN
          list(12) = 2
          celements(1:12,1:6) = states(tt2, list, error)
          IF (error) THEN
             WRITE(0,*) 'JPL_ephemeris_r8(): Target object and center object are the same.'
             RETURN
          ELSE
             !state = celements(11,:)
             RETURN
          END IF
       ELSE
          error = .TRUE.
          WRITE(0,*) 'JPL_ephemeris_r8(): No librations available on the ephemeris file.'
          RETURN
       END IF
    END IF

    ! Force barycentric output from states()
    tmp_barycenter = barycenter
    barycenter = .TRUE.

    !  set up proper entries in 'list' array for state call
    IF (ntarget > 0) THEN
       DO i=1, 2
          IF (i == 1) THEN
             k = ntarget
          ELSE IF (i == 2) THEN
             k = ncenter
          END IF
          IF (k <= 10) THEN
             list(k)  = 2 ! If k:th planet wanted, k:th is needed
          END IF
          IF (k == 3) THEN
             list(10) = 2 ! If Earth wanted, Moon is needed
          END IF
          IF (k == 10) THEN
             list(3)  = 2 ! If Moon wanted, Earth is needed
          END IF
          IF (k == 13) THEN
             list(3)  = 2 ! If barycentric Earth-Moon wanted, Earth is needed
          END IF
       END DO
    ELSE IF (ntarget == -9 .OR. ntarget == -10) THEN
       list(1:10) = 2
    END IF

    !  make call to state
    celements(1:12,1:6) = states(tt2, list, error)
    IF (error) THEN
       WRITE(0,*) 'JPL_ephemeris_r8(): Error when calling states() (1).'
       RETURN
    END IF

    ! If the target or the center is the Sun,
    ! change it to the Solar System barycenter:
    IF (ntarget == 11 .OR. ncenter == 11 .OR. ntarget < 0) THEN
       celements(11,:) = celements(12,1:6)
    END IF

    ! If the target or the center is the Solar System barycenter,
    ! set its coordinates to zero:
    IF (ntarget == 12 .OR. ncenter == 12) THEN
       celements(12,:) = 0.0_rprec8
    END IF

    ! If the target or the center is the Earth-Moon barycenter,
    ! set it initially equal to the coordinates of the Earth:
    IF (ntarget == 13 .OR. ncenter == 13 .OR. ntarget == -9) THEN
       celements(13,:) = celements(3,:)
    END IF

    ! If Earth to Moon (or vice versa) coordinates are needed, use
    ! geocentric coordinates for the Moon:
    IF (ntarget * ncenter == 30 .AND. ntarget + ncenter == 13) THEN
       celements(3,:) = 0.0_rprec8
       celements(ntarget,:) = celements(ntarget,:) - celements(ncenter,:)
       ALLOCATE(JPL_ephemeris_r8(1,6), stat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "JPL_ephemeris_r8(): Could not allocate memory for output (2)."
          RETURN
       END IF
       JPL_ephemeris_r8(1,1:6) = celements(ntarget,1:6)
       barycenter = tmp_barycenter
       RETURN
    END IF

    ! If the target or the center is the Moon or the Earth-Moon barycenter,
    ! compute Earth coordinates using coordinates for the barycentric Earth-Moon
    ! system and geocentric coordinates for the Moon:
    IF (list(3) == 2) THEN
       celements(3,:) = celements(3,:) - celements(10,:)/(1.0_rprec8 + emrat)
    END IF

    ! If the target or the center is the Moon, compute Moon's
    ! coordinates using coordinates for the Earth and geocentric
    ! coordinates for the Moon:
    IF (list(10) == 2) THEN
       celements(10,:) = celements(3,:) + celements(10,:)
    END IF

    celements_ = celements(ncenter,1:6)
    barycenter = tmp_barycenter
    DO i=1,12
       celements(i,1:6) = celements(i,1:6) - celements_
    END DO
    IF (ntarget == -9) THEN ! use Earth-Moon barycenter
       ALLOCATE(JPL_ephemeris_r8(9,6), stat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "JPL_ephemeris_r8(): Could not allocate memory for output (3)."
          RETURN
       END IF
       DO i=1,9
          JPL_ephemeris_r8(i,1:6) = celements(i,1:6)
       END DO
       !JPL_ephemeris_r8(3,1:6) = celements(13,1:6)
    ELSE IF (ntarget == -10) THEN ! separate Earth and Moon
       ALLOCATE(JPL_ephemeris_r8(10,6), stat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "JPL_ephemeris_r8(): Could not allocate memory for output (4)."
          RETURN
       END IF
       DO i=1,10
          JPL_ephemeris_r8(i,1:6) = celements(i,1:6)
       END DO
    ELSE IF (ntarget >= 1 .AND. ntarget <= 13) THEN
       ALLOCATE(JPL_ephemeris_r8(1,6), stat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "JPL_ephemeris_r8(): Could not allocate memory for output (5)."
          RETURN
       END IF
       JPL_ephemeris_r8(1,1:6) = celements(ntarget,1:6)
    ELSE
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_r8(): Could not decide what kind of output caller requested."
       RETURN
    END IF

  END FUNCTION JPL_ephemeris_r8





  !! *Description*:
  !!
  !! Same as JPL_ephemeris_r8, but with digits allowing greater
  !! numerical accuracy, i.e., the accuracy of values is the same
  !! as for JPL_ephemeris_r8.
  !!
  FUNCTION JPL_ephemeris_r16(mjd_tt, ntarget, ncenter, error, km)

    IMPLICIT NONE
    REAL(rprec16), INTENT(in)              :: mjd_tt
    INTEGER, INTENT(in)                    :: ntarget, ncenter
    LOGICAL, INTENT(inout)                 :: error
    LOGICAL, OPTIONAL, INTENT(in)          :: km
    REAL(rprec16), DIMENSION(:,:), POINTER :: JPL_ephemeris_r16

    REAL(rprec8), DIMENSION(:,:), POINTER  :: tmp => NULL()
    INTEGER :: err

    IF (PRESENT(km)) THEN
       tmp => JPL_ephemeris(REAL(mjd_tt,rprec8), ntarget, ncenter, error, km)
    ELSE
       tmp => JPL_ephemeris(REAL(mjd_tt,rprec8), ntarget, ncenter, error)
    END IF
    IF (error) THEN
       WRITE(0,*) "JPL_ephemeris_r16(): Error when calling JPL_ephemeris_r8()."
       RETURN
    END IF
    ALLOCATE(JPL_ephemeris_r16(SIZE(tmp,dim=1),SIZE(tmp,dim=2)), stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_r16(): Could not allocate memory."
       DEALLOCATE(tmp, stat=err)
       RETURN
    END IF
    JPL_ephemeris_r16 = REAL(tmp,rprec16)
    DEALLOCATE(tmp, stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_r16(): Could not deallocate memory."
       RETURN
    END IF

  END FUNCTION JPL_ephemeris_r16





  !! *Description*:
  !!
  !! Reads the JPL Planetary Ephemeris and gives the position and
  !! velocity of the point 'ntarget' with respect to 'ncenter'.
  !!
  !! ntarget = integer number of target point.
  !!
  !! ncentet = integer number of center point.
  !!
  !! The numbering convention for 'ntarget' and 'ncenter' is:
  !!
  !!<pre>
  !!         1 = Mercury            8 = Neptune
  !!         2 = Venus              9 = Pluto
  !!         3 = Earth             10 = Moon
  !!         4 = Mars              11 = Sun
  !!         5 = Jupiter          (12 = solar-system barycenter)
  !!         6 = Saturn           (13 = earth-moon barycenter)
  !!         7 = Uranus           (14 = nutations (longitude and obliq))
  !!                              (15 = librations, if on eph file)
  !!<pre>
  !!  Additional: -10 = 9 planets + Moon
  !!
  !! If nutations are wanted, set ntarget = 14, and for librations,
  !! set ntarget = 15. Set ncenter = 0.
  !!
  !! Output is a CartesianCoordinates object (crtcrd) containing position and velocity
  !! of point 'ntarget' relative to 'ncenter'. the units are AU and AU/day.
  !! For librations the units are radians and radians per day.
  !!
  !! Returns error.
  !!
  !! ntarget=-10 and ncenter=11 tested to produce correct results.
  !! ntarget=-10 and ncenter=12 tested to produce correct results.
  !!
  ! In the case
  ! of nutations the first four words of rrd will be set to nutations and
  ! rates, having units of radians and radians/day.
  !!
  !! Known errors:
  !!
  !!  ntarget  ncenter
  !!    13       11
  !!    -9       11
  !!    -9       12
  !!
  FUNCTION JPL_ephemeris_perturbers_r8(mjd_tt, ntargets, ncenter, error, km)

    IMPLICIT NONE
    REAL(rprec8), INTENT(in)              :: mjd_tt
    LOGICAL, DIMENSION(:), INTENT(in)     :: ntargets
    INTEGER, INTENT(in)                   :: ncenter
    LOGICAL, INTENT(inout)                :: error
    LOGICAL, OPTIONAL, INTENT(in)         :: km
    REAL(rprec8), DIMENSION(:,:), POINTER :: JPL_ephemeris_perturbers_r8

    REAL(rprec8), DIMENSION(13,6) :: celements
    REAL(rprec8), DIMENSION(6)    :: celements_
    REAL(rprec8), DIMENSION(2)    :: tt2
    INTEGER, DIMENSION(12)        :: list
    INTEGER                       :: i, j, err
    LOGICAL                       :: tmp_barycenter

    IF (first) THEN
       CALL JPL_ephemeris_init(error)
       IF (error) THEN
          WRITE(0,*) "JPL_ephemeris_perturbers_r8(): Could not initialize ephemerides."
          RETURN
       END IF
    END IF

    IF (PRESENT(km)) THEN
       kilometres = km
    END IF

    tt2(1) = mjd_tt + 2400000.5_rprec8 ! convert to Julian date
    tt2 = split(tt2(1))
    IF (tt2(2) < 0.5_rprec8) THEN
       tt2(1) = tt2(1) - 0.5_rprec8
       tt2(2) = tt2(2) + 0.5_rprec8
    ELSE
       tt2(1) = tt2(1) + 0.5_rprec8
       tt2(2) = tt2(2) - 0.5_rprec8
    END IF
    list = 0

    ! Force barycentric output from states()
    tmp_barycenter = barycenter
    barycenter = .TRUE.

    !  set up proper entries in 'list' array for state call
    list(1:10) = 2

    !  make call to state
    celements(1:12,1:6) = states(tt2, list, error)
    IF (error) THEN
       WRITE(0,*) "JPL_ephemeris_perturbers_r8(): Error when calling states() (1)."
       RETURN
    END IF

    ! If the target or the center is the Sun,
    ! change it to the Solar System barycenter:
    celements(11,:) = celements(12,1:6)

    ! If the target or the center is the Earth-Moon barycenter,
    ! set it initially equal to the coordinates of the Earth:
    IF (ntargets(3) .AND. .NOT.ntargets(10)) THEN
       celements(13,:) = celements(3,:)
    END IF

    ! If the target or the center is the Moon or the Earth-Moon barycenter,
    ! compute Earth coordinates using coordinates for the barycentric Earth-Moon
    ! system and geocentric coordinates for the Moon:
    celements(3,:) = celements(3,:) - celements(10,:)/(1.0_rprec8 + emrat)

    ! If the target or the center is the Moon, compute Moon's
    ! coordinates using coordinates for the Earth and geocentric
    ! coordinates for the Moon:
    celements(10,:) = celements(3,:) + celements(10,:)

    celements_ = celements(ncenter,1:6)
    barycenter = tmp_barycenter
    DO i=1,12
       celements(i,1:6) = celements(i,1:6) - celements_
    END DO
    ALLOCATE(JPL_ephemeris_perturbers_r8(COUNT(ntargets),6), stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_perturbers_r8(): Could not allocate memory."
       RETURN
    END IF
    j = 0
    DO i=1,10
       IF (ntargets(i)) THEN
          j = j + 1
          JPL_ephemeris_perturbers_r8(j,1:6) = celements(i,1:6)
       END IF
    END DO

  END FUNCTION JPL_ephemeris_perturbers_r8





  !! *Description*:
  !!
  !! Same as JPL_ephemeris_r8, but with digits allowing greater
  !! numerical accuracy, i.e., the accuracy of values is the same
  !! as for JPL_ephemeris_r8.
  !!
  FUNCTION JPL_ephemeris_perturbers_r16(mjd_tt, ntargets, ncenter, error, km)

    IMPLICIT NONE
    REAL(rprec16), INTENT(in)              :: mjd_tt
    LOGICAL, DIMENSION(:), INTENT(in)      :: ntargets
    INTEGER, INTENT(in)                    :: ncenter
    LOGICAL, INTENT(inout)                 :: error
    LOGICAL, OPTIONAL, INTENT(in)          :: km
    REAL(rprec16), DIMENSION(:,:), POINTER :: JPL_ephemeris_perturbers_r16

    REAL(rprec8), DIMENSION(:,:), POINTER  :: tmp => NULL()
    INTEGER :: err

    IF (PRESENT(km)) THEN
       tmp => JPL_ephemeris(REAL(mjd_tt,rprec8), ntargets, ncenter, error, km)
    ELSE
       tmp => JPL_ephemeris(REAL(mjd_tt,rprec8), ntargets, ncenter, error)
    END IF
    IF (error) THEN
       WRITE(0,*) "JPL_ephemeris_perturbers_r16(): Error when calling JPL_ephemeris_perturbers_r8()."
       RETURN
    END IF
    ALLOCATE(JPL_ephemeris_perturbers_r16(SIZE(tmp,dim=1),SIZE(tmp,dim=2)), stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_perturbers_r16(): Could not allocate memory."
       DEALLOCATE(tmp, stat=err)
       RETURN
    END IF
    JPL_ephemeris_perturbers_r16 = REAL(tmp,rprec16)
    DEALLOCATE(tmp, stat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "JPL_ephemeris_perturbers_r16(): Could not deallocate memory."
       RETURN
    END IF

  END FUNCTION JPL_ephemeris_perturbers_r16





  !! *Description*:
  !!
  !! Reads the jpl planetary ephemeris and gives the position and
  !! velocity of the point 'ntarget' with respect to 'ncenter'.
  !!
  !! ntarget = integer number of target point.
  !!
  !! ncentet = integer number of center point.
  !!
  !! The numbering convention for 'ntarget' and 'ncenter' is:
  !!
  !!<pre>
  !!         1 = mercury           8 = neptune
  !!         2 = venus             9 = pluto
  !!         3 = earth            10 = moon
  !!         4 = mars             11 = sun
  !!         5 = jupiter          (12 = solar-system barycenter)
  !!         6 = saturn           (13 = earth-moon barycenter)
  !!         7 = uranus           (14 = nutations (longitude and obliq))
  !!                              (15 = librations, if on eph file)
  !!<pre>
  !!
  !! If nutations are wanted, set ntarget = 14, and for librations,
  !! set ntarget = 15. Set ncenter = 0.
  !!
  !! Output is a CartesianCoordinates object (crtcrd) containing position and velocity
  !! of point 'ntarget' relative to 'ncenter'. the units are AU and AU/day.
  !! For librations the units are radians and radians per day.
  !!
  !! Returns error.
  !!
  ! In the case
  ! of nutations the first four words of rrd will be set to nutations and
  ! rates, having units of radians and radians/day.
  !!
  FUNCTION nutations(t, error)

    IMPLICIT NONE
    REAL(rprec8), INTENT(in)   :: t
    LOGICAL, INTENT(inout) :: error
    REAL(rprec8), DIMENSION(4) :: nutations
    REAL(rprec8), DIMENSION(6) :: tmp
    REAL(rprec8), DIMENSION(4) :: pjd
    REAL(rprec8), DIMENSION(2) :: tt2, tt
    REAL(rprec8)               :: s
    INTEGER, DIMENSION(12) :: list
    INTEGER                :: record_nr

    IF (first) THEN
       CALL JPL_ephemeris_init(error)
       IF (error) THEN
          WRITE(0,*) "nutations(): Could not initialize ephemerides."
          RETURN
       END IF
    END IF

    tt2(1) = t
    tt2 = split(tt2(1))
    IF (tt2(2) < 0.5_rprec8) THEN
       tt2(1) = tt2(1) - 0.5_rprec8
       tt2(2) = tt2(2) + 0.5_rprec8
    ELSE
       tt2(1) = tt2(1) + 0.5_rprec8
       tt2(2) = tt2(2) - 0.5_rprec8
    END IF
    list = 0

    IF (ipt(2,12) > 0) THEN
       list(11) = 2

       IF (tt2(1) == 0.0_rprec8) THEN
          error = .TRUE.
          WRITE(0,*) 'nutations(): Input Julian date is zero.'
          RETURN
       END IF

       s = tt2(1) - 0.5_rprec8
       pjd(1:2) = split(s)
       pjd(3:4) = split(tt2(2))
       pjd(1) = pjd(1) + pjd(3) + 0.5_rprec8
       pjd(2) = pjd(2) + pjd(4)
       pjd(3:4) = split(pjd(2))
       pjd(1) = pjd(1) + pjd(3)

       IF (pjd(1) + pjd(4) < ss(1) .OR. &
            pjd(1) + pjd(4) > ss(2)) THEN
          error = .TRUE.
          WRITE(0,*) 'nutations(): Requested Julian ET not within limits.'
          RETURN
       END IF

       ! Calculate record number and relative time in interval:
       record_nr = INT((pjd(1) - ss(1))/ss(3)) + 1
       IF (pjd(1) == ss(2)) record_nr = record_nr - 1
       tt(1) = ((pjd(1) - (REAL(record_nr-1, rprec8) * ss(3) + ss(1))) + &
            pjd(4)) / ss(3)

       ! Read correct record if not in core:
       !IF (record_nr < 1 .OR. record_nr > SIZE(buf,dim=1)) THEN
       IF (record_nr < 1 .OR. record_nr > SIZE(buf,dim=2)) THEN
          error = .TRUE.
          WRITE(0,*) 'Requested Julian ET not within limits.'
          RETURN
       END IF

       ! Do nutations if requested (and if on file)
       IF (list(11) > 0 .AND. ipt(2,12) > 0) THEN
          !CALL interpolate(buf(record_nr,:), ipt(1,12), tt, &
          !     ipt(2,12), 2, ipt(3,12), tmp, error)
          CALL interpolate(buf(:,record_nr), ipt(1,12), tt, &
               ipt(2,12), 2, ipt(3,12), tmp, error)
          IF (error) THEN
             RETURN
          END IF
          nutations = tmp(1:4)
       ELSE
          nutations = 0.0_rprec8
       END IF
       IF (error) THEN
          WRITE(0,*) 'nutations(): No nutations on the ephemeris file.'
          RETURN
       END IF
    END IF

  END FUNCTION nutations





  !!
  !! Returns error.
  !!
  FUNCTION states(tt2, list, error)

    ! this subroutine reads and interpolates the jpl planetary ephemeris file
    !
    ! calling sequence parameters:
    !
    ! input:
    !
    ! tt2   rprec8 2-word julian ephemeris epoch at which interpolation
    ! is wanted.  any combination of tt2(1)+tt2(2) which falls
    ! within the time span on the file is a permissible epoch.
    !
    ! a. for ease in programming, the user may put the
    ! entire epoch in tt2(1) and set tt2(2)=0.
    !
    ! b. for maximum interpolation accuracy, set tt2(1) =
    ! the most recent midnight at or before interpolation
    ! epoch and set tt2(2) = fractional part of a day
    ! elapsed between tt2(1) and epoch.
    !
    ! c. as an alternative, it may prove convenient to set
    ! tt2(1) = some fixed epoch, such as start of integration,
    ! and tt2(2) = elapsed interval between then and epoch.
    !
    ! list   12-word integer array specifying what interpolation
    ! is wanted for each of the bodies on the file.
    !
    ! list(i)=0, no interpolation for body i
    ! =1, position only
    ! =2, position and velocity
    !
    ! the designation of the astronomical bodies by i is:
    !
    ! i =  1: mercury
    !   =  2: venus
    !   =  3: earth-moon barycenter
    !   =  4: mars
    !   =  5: jupiter
    !   =  6: saturn
    !   =  7: uranus
    !   =  8: neptune
    !   =  9: pluto
    !   = 10: geocentric moon
    !   = 11: nutations in longitude and obliquity
    !   = 12: lunar librations (if on file)
    !
    !
    ! output:
    !
    ! s_array   rprec8 6 x 11 array that will contain requested interpolated
    ! quantities.  the body specified by list(i) will have its
    ! state in the array starting at s_array(1,i).  (on any given
    ! call, only those words in 's_array' which are affected by the
    ! first 10 'list' entries (and by list(12) if librations are
    ! on the file) are set.  the rest of the 's_array' array
    ! is untouched.)  the order of components starting in
    ! s_array(1,i) is: x,y,z,dx,dy,dz.
    !
    ! all output vectors are referenced to the earth mean
    ! equator and equinox of j2000 if the de number is 200 or
    ! greater; of b1950 if the de number is less than 200.
    !
    ! the moon state is always geocentric; the other nine states
    ! are either heliocentric or solar-system barycentric,
    ! depending on the setting of common flags (see below).
    !
    ! lunar librations, if on file, are put into s_array(k,11) if
    ! list(12) is 1 or 2.
    !
    ! nut   rprec8 4-word array that will contain nutations and rates,
    ! depending on the setting of list(11).  the order of
    ! quantities in nut is:
    !
    ! d psi  (nutation in longitude)
    ! d epsilon (nutation in obliquity)
    ! d psi dot
    ! d epsilon dot
    !
    ! *   statement # for error return, in case of epoch out of
    ! range or i/o errors.
    !
    !
    ! common area stcomx:
    !
    ! kilometres   logical flag defining physical units of the output
    ! states. kilometres = .true., km and km/sec
    ! = .false., au and au/day
    ! default value = .false.  (kilometres determines time unit
    ! for nutations and librations.  angle unit is always radians.)
    !
    ! bary   logical flag defining output center.
    ! only the 9 planets are affected.
    ! bary = .true. =\ center is solar-system barycenter
    ! = .false. =\ center is sun
    ! default value = .false.
    !
    ! celements(1:6,12) rprec8 6-word array containing the barycentric position and
    ! velocity of the sun.

    IMPLICIT NONE
    REAL(rprec8), DIMENSION(2), INTENT(in) :: tt2
    INTEGER, DIMENSION(12), INTENT(in)     :: list
    LOGICAL, INTENT(inout)                 :: error
    REAL(rprec8), DIMENSION(12,6)          :: states
    REAL(rprec8), DIMENSION(2)             :: t
    REAL(rprec8), DIMENSION(4)             :: pjd
    REAL(rprec8)                           :: s, aufac
    INTEGER                                :: record_nr, i

    states = 0.0_rprec8

    IF (ABS(tt2(1)) < EPSILON(tt2(1))) THEN
       error = .TRUE.
       WRITE(0,*) 'states(): Input Julian date is zero.'
       RETURN
    END IF

    s = tt2(1) - 0.5_rprec8
    pjd(1:2) = split(s)
    pjd(3:4) = split(tt2(2))
    pjd(1) = pjd(1) + pjd(3) + 0.5_rprec8
    pjd(2) = pjd(2) + pjd(4)
    pjd(3:4) = split(pjd(2))
    pjd(1) = pjd(1) + pjd(3)

    IF (pjd(1) + pjd(4) < ss(1) .OR. &
         pjd(1) + pjd(4) > ss(2)) THEN
       error = .TRUE.
       WRITE(0,*) 'states(): Requested Julian ET not within limits:'
       WRITE(0,*) tt2, ss
       RETURN
    END IF

    ! Calculate record number and relative time in interval:
    record_nr = INT((pjd(1) - ss(1))/ss(3)) + 1
    IF (pjd(1) == ss(2)) THEN
       record_nr = record_nr - 1
    END IF
    t(1) = ((pjd(1) - (REAL(record_nr-1, rprec8) * ss(3) + ss(1))) + &
         pjd(4)) / ss(3)

    ! Read correct record if not in core:
    IF (record_nr < 1 .OR. record_nr > SIZE(buf,dim=2)) THEN
       error = .TRUE.
       WRITE(0,*) 'states(): Requested Julian ephemeris date not within limits.'
       RETURN
    END IF

    IF (kilometres) THEN
       t(2) = ss(3)*86400.0_rprec8
       aufac = 1.0_rprec8
    ELSE
       t(2) = ss(3)
       aufac = 1.0_rprec8/au
    ENDIF

    ! Interpolate ssbary sun:
    CALL interpolate(buf(:,record_nr), ipt(1,11), t, ipt(2,11), &
         3, ipt(3,11), states(12,1:6), error)
    IF (error) THEN
       WRITE(0,*) "states(): Error when calling interpolate() (1)."
       RETURN
    END IF
    states(12,1:6) = states(12,1:6)*aufac
    ! Check and interpolate whichever bodies are requested:
    DO i=1, 10
       IF (list(i) == 0) CYCLE
       CALL interpolate(buf(:,record_nr), ipt(1,i), t, ipt(2,i), &
            3, ipt(3,i), states(i,:), error)
       IF (error) THEN
          WRITE(0,*) "states(): Error when calling interpolate() (2)."
          RETURN
       END IF
       IF (i <= 9 .AND. .NOT.barycenter) THEN
          states(i,:) = states(i,:) * aufac - states(12,:)
       ELSE
          states(i,:) = states(i,:) * aufac
       END IF
    END DO
    ! Get librations if requested (and if on file)
    IF (list(12) > 0 .AND. ipt(2,13) > 0) THEN
       CALL interpolate(buf(:,record_nr), ipt(1,13), t, ipt(2,13), &
            3, ipt(3,13), states(11,:), error)
       IF (error) THEN
          WRITE(0,*) "states(): Error when calling interpolate() (3)."
          RETURN
       END IF
    ELSE
       states(11,1) = 0.0_rprec8
    END IF

  END FUNCTION states





  !!
  !! Returns error.
  !!
  SUBROUTINE interpolate(inbuf, ind, time, ncf, ncm, na, svector, error)

    ! this subroutine differentiates and interpolates a
    ! set of chebyshev coefficients to give position and velocity
    !
    ! calling sequence parameters:
    !
    ! input:
    !
    ! buf   1st location of array of d.p. chebyshev coefficients of position
    !
    ! t   t(1) is rprec8 fractional time in interval covered by
    ! coefficients at which interpolation is wanted
    ! (0 <= t(1) <= 1).  t(2) is rprec8 length of whole
    ! interval in input time units.
    !
    ! ncf   # of coefficients per component
    !
    ! ncm   # of components per set of coefficients
    !
    ! na   # of sets of coefficients in full array
    ! (i.e., # of sub-intervals in full interval)
    !
    ! flag  integer flag: =1 for positions only
    ! =2 for pos and vel
    !
    !
    ! output:
    !
    ! svector   interpolated quantities requested.  dimension
    ! expected is svector(ncm,flag), rprec8.
    !
    IMPLICIT NONE
    INTEGER, INTENT(in)                 :: ncf, ncm, na, ind
    SAVE
    REAL(rprec8), DIMENSION(:), INTENT(in)  :: inbuf
    REAL(rprec8), DIMENSION(2), INTENT(in)  :: time
    REAL(rprec8), DIMENSION(6), INTENT(out) :: svector
    LOGICAL, INTENT(inout)              :: error
    REAL(rprec8), DIMENSION(ncf,ncm,na)     :: buf
    REAL(rprec8), DIMENSION(18)             :: pc, vc
    REAL(rprec8), DIMENSION(6)              :: pos, vel
    REAL(rprec8)                            :: twot, tmp, tc, vfac, dna
    INTEGER                             :: npos, nvel, dt1, i, j, k, l, l2

    npos = 2
    nvel = 3
    twot = 0.0_rprec8
    pc(1:2) = (/ 1.0_rprec8, 0.0_rprec8 /)
    vc(2) = 1.0_rprec8

    l = ind
    l2 = l

    ! Get correct sub-interval number for this set of coefficients and
    ! then get normalized Chebyshev time within that subinterval.
    dna = REAL(na,rprec8)
    dt1 = INT(time(1))
    tmp = dna * time(1)
    l = INT(tmp - dt1) + 1

    ! tc is the normalized chebyshev time (-1 <= tc <= 1)
    tc = 2.0_rprec8 * (MOD(tmp,1.0_rprec8) + dt1) - 1.0_rprec8

    ! check to see whether chebyshev time has changed,
    ! and compute new polynomial values if it has.
    ! (the element pc(2) is the value of t1(tc) and hence
    ! contains the value of tc on the previous call.)
    IF(tc /= pc(2)) THEN
       npos = 2
       nvel = 3
       pc(2) = tc
       twot = tc + tc
    END IF

    ! be sure that at least 'ncf' polynomials have been evaluated
    ! and are stored in the array 'pc'.
    IF(npos < ncf) THEN
       DO i=npos+1,ncf
          pc(i) = twot * pc(i-1) - pc(i-2)
       END DO
       npos = ncf
    END IF

    ! if velocity interpolation is wanted, be sure enough
    ! derivative polynomials have been generated and stored.

    IF (ABS(time(2)) < EPSILON(time(2))) THEN
       error = .TRUE.
       WRITE(0,*) 'interpolate(): Attempted division by zero.'
       RETURN
    END IF
    vfac = (dna + dna)/time(2)
    vc(3) = twot + twot
    IF (nvel < ncf) THEN
       DO i=nvel+1, ncf
          vc(i) = twot * vc(i-1) + pc(i-1) + pc(i-1) - vc(i-2)
       END DO
       nvel = ncf
    ENDIF

    ! interpolate to get position and velocity for each component
    l2 = l2 + (l-1)* ncm *ncf
    pos = 0.0_rprec8
    vel = 0.0_rprec8
    DO i=1,ncm
       l2 = l2 + ncf
       DO j=ncf,2,-1 ! Velocity is only computed down to j=2, while pos to j=1
          l2 = l2 - 1
          pos(i) = pos(i) + pc(j) * inbuf(l2)
          vel(i) = vel(i) + vc(j) * inbuf(l2)
       END DO
       l2 = l2 - 1
       pos(i) = pos(i) + pc(1) * inbuf(l2)
       vel(i) = vel(i) * vfac
       l2 = l2 + ncf
    END DO

    svector = (/ pos(1:3), vel(1:3) /)

  END SUBROUTINE interpolate





  !!
  !!
  FUNCTION split(in)

    ! this subroutine breaks a rprec8 number into a rprec8 integer
    ! and a rprec8 fractional part.
    !
    ! calling sequence parameters:
    !
    !   in = input number
    !
    !   out = output array.
    !        split(1) contains integer part
    !        split(2) contains fractional part
    !
    !        for negative input numbers, split(1) contains the next
    !        more negative integer; split(2) contains a positive fraction.

    IMPLICIT NONE
    REAL(rprec8), INTENT(in)   :: in
    REAL(rprec8), DIMENSION(2) :: split

    !  main entry -- get integer and fractional parts
    split(1) = 1.0_rprec8*AINT(in)
    split(2) = 1.0_rprec8*in - 1.0_rprec8*split(1)

    IF (in < 0.0_rprec8 .AND. split(2) /= 0.0_rprec8) THEN
       !  make adjustments for negative input number
       split(1) = 1.0_rprec8*split(1) - 1.0_rprec8
       split(2) = 1.0_rprec8*split(2) + 1.0_rprec8
    END IF

  END FUNCTION split





  !! *Description*:
  !!
  !! The Roche limit 'd' for a fluid satellite where
  !!
  !!    d ~ 2.44 * r_planet * (rho_planet/rho_satellite)^(1/3))
  !!
  !! and r_planet and rho_planet are the radius and bulk density of
  !! the planet, and rho_satellite is the bulk density of the
  !! satellite.
  !!
  REAL(rprec8) FUNCTION Roche_limit(radius_1, density_1, density_2)

    IMPLICIT NONE
    REAL(rprec8), INTENT(in) :: radius_1, density_1, density_2

    Roche_limit =  2.44_rprec8 * radius_1 * (density_1/density_2)**(1.0_rprec8/3)

  END FUNCTION Roche_limit





  !! *Description*:
  !!
  !! If used for the first time during execution, this routine reads
  !! the BC430 asteroid ephemerides from a given file and stores the
  !! data in an array.
  !!
  !! Returns error.
  !!
  SUBROUTINE BC_ephemeris_init(nastpert, error)

    IMPLICIT NONE
    LOGICAL, INTENT(inout)                     :: error
    INTEGER, INTENT(inout)                     :: nastpert

    CHARACTER(len=1024) :: fname, OORB_DATA_DIR
    REAL(rprec8), DIMENSION(:), ALLOCATABLE :: fbuffer
    REAL(rprec8) :: mjd_0
    INTEGER :: i, j, k, to_include, count, lu, err
    LOGICAL :: done, used

    mjd_0 = 2378495.0_rprec8 - 2400000.5_rprec8
    ALLOCATE(fbuffer(6575400))

    ! Find a free logical unit:
    done = .FALSE.
    count = min_lu
    lu = min_lu
    DO WHILE (.NOT. done)
       ! Figure out whether this unit is taken or not:
       INQUIRE(unit=lu, opened=used, iostat=err)
       IF (err /= 0) THEN
          error = .TRUE.
          WRITE(0,*) "BC_ephemeris_init(): Error when inquiring for status of logical unit."
          RETURN
       END IF
       IF (used) THEN
          count = count + 1
          ! If more than max_lu units have been tried,
          ! every available unit has been tried at least once.
          ! A free unit could not be found:
          IF (count > max_lu) THEN
             error = .TRUE.
             WRITE(0,*) "BC_ephemeris_init(): Could not find a free logical unit."
             RETURN
          END IF
          lu = lu + 1
          ! Back to beginning if top is reached:
          IF (lu > max_lu) lu = min_lu
       ELSE
          done = .TRUE.
       END IF
    END DO

    OORB_DATA_DIR = resolveDirectory("share/oorb", "OORB_DATA")

    IF (LEN_TRIM(OORB_DATA_DIR) == 0) THEN
       OORB_DATA_DIR = "."
    END IF

    fname = TRIM(OORB_DATA_DIR) // "/asteroid_indices.txt"
    OPEN(unit=lu, file=TRIM(fname), status='OLD', action='READ', iostat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "BC_ephemeris_init(): Could not open file '" // TRIM(fname) // "'."
       RETURN
    END IF
    to_include = nastpert
    DO i=1,nastpert
       READ(lu,*) asteroid_indices(i)
       IF (asteroid_indices(i)(1:1) == "#") THEN
          asteroid_masks(i) = .FALSE.
          to_include = to_include - 1
       END IF
    END DO
    CLOSE(unit=lu)
    ALLOCATE(asteroid_ephemerides(to_include,3653,6), asteroid_masses(to_include))

    fname = TRIM(OORB_DATA_DIR) // "/asteroid_ephemeris.txt"
    OPEN(unit=lu, file=TRIM(fname), status='OLD', action='READ', iostat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "BC_ephemeris_init(): Could not open file '" // TRIM(fname) // "'."
       RETURN
    END IF
    DO i=1,SIZE(fbuffer) ! Read asteroid_ephemeris into fbuffer
       READ(lu,*) fbuffer(i)
    END DO
    CLOSE(unit=lu)

    fname = TRIM(OORB_DATA_DIR) // "/asteroid_masses.txt"
    OPEN(unit=lu, file=TRIM(fname), status='OLD', action='READ', iostat=err)
    IF (err /= 0) THEN
       error = .TRUE.
       WRITE(0,*) "BC_ephemeris_init(): Could not open file '" // TRIM(fname) // "'."
       RETURN
    END IF
    k=1
    DO i=1,nastpert
       IF (asteroid_masks(i)) THEN
          READ(lu,*) asteroid_masses(k)
          k = k + 1
        ELSE ! This happens if an asteroid has been commented out. This read statement's purpose
          READ(lu,*)  ! is to advance to a new line without storing the mass anywhere.
       END IF
    END DO
    CLOSE(unit=lu)

    k = 1
    DO i=1,nastpert ! Parse fbuffer into asteroid_ephemerides
       IF (asteroid_masks(i)) THEN
          DO j=1,3653
             asteroid_ephemerides(k,j,1) = fbuffer(1800*(j-1) + 6*(i-1) + 1)
             asteroid_ephemerides(k,j,2) = fbuffer(1800*(j-1) + 6*(i-1) + 2)
             asteroid_ephemerides(k,j,3) = fbuffer(1800*(j-1) + 6*(i-1) + 3)
             asteroid_ephemerides(k,j,5) = fbuffer(1800*(j-1) + 6*(i-1) + 4)
             asteroid_ephemerides(k,j,4) = fbuffer(1800*(j-1) + 6*(i-1) + 5)
             asteroid_ephemerides(k,j,6) = fbuffer(1800*(j-1) + 6*(i-1) + 6)
          END DO
          k = k + 1
       END IF
    END DO
    DEALLOCATE(fbuffer)
    DO i=1,3653
       asteroid_epochs(i) = mjd_0 + 40*(i-1)
    END DO

    nastpert = to_include

  END SUBROUTINE BC_ephemeris_init





  ! Returns the BC430 masses for nastpert asteroids.
  FUNCTION BC_masses_r8(nastpert)

    IMPLICIT NONE

    INTEGER, INTENT(IN) :: nastpert
    REAL(rprec8), DIMENSION(:), POINTER :: BC_masses_r8

    ALLOCATE(BC_masses_r8(nastpert))

    BC_masses_r8(:) = asteroid_masses(1:nastpert)

  END FUNCTION BC_masses_r8





  !! *Description*:
  !!
  !! Reads the BC430 asteroid Ephemeris and gives the position and
  !! velocity of the nastpert most massive asteroids at epoch mjd_tt.
  !!
  !! nastpert = integer amount of asteroids wanted. Starts from
  !! most massive ones -> need a better scheme later. 300 = everything.
  !! Output is a 6-vector containing position and velocity of point
  !! 'nastpert' relative to 'ncenter' in an equatorial reference
  !! frame. The units are AU and AU/day.
  !!
  !! Returns error.
  !!
  FUNCTION BC_ephemeris_r8(mjd_tt, nastpert, error, km)

    IMPLICIT NONE
    REAL(rprec8), INTENT(in)              :: mjd_tt
    INTEGER, INTENT(inout)                :: nastpert
    LOGICAL, INTENT(inout)                :: error
    LOGICAL, OPTIONAL, INTENT(in)         :: km
    REAL(rprec8), DIMENSION(:,:), POINTER :: BC_ephemeris_r8

    REAL(rprec8), PARAMETER :: kk = 0.85
    REAL(rprec8), PARAMETER :: tol = 1.0e-15
    INTEGER, PARAMETER      :: nmax = 10000

    REAL(rprec8), DIMENSION(:,:,:), ALLOCATABLE :: R
    REAL(rprec8), DIMENSION(:,:), ALLOCATABLE :: tmp_elements, &
         mean_motion, ea, ma, sigma, x, esinx, ecosx, f, cea, sea, &
         b, dot_ea, celements, R2, sin_angles, cos_angles, v, r3, h
    REAL(rprec8), DIMENSION(2) :: tt2
    REAL(rprec8) :: eph_epoch, dt, two_pi, fp, fpp, fppp, dx, eps
    INTEGER, DIMENSION(12) :: list
    INTEGER :: i, j,k, err, ind
    LOGICAL :: tmp_barycenter

    IF (first_bc) THEN
       CALL BC_ephemeris_init(nastpert,error)
       IF (error) THEN
          WRITE(0,*) "BC_ephemeris_r8(): Error when calling BC_ephemeris_init()."
          RETURN
       END IF
       first_bc = .FALSE.
    END IF

    two_pi = 8*ATAN(1.0_rprec8)
    ! Fixed obliquity of ecliptic which may be different from the
    ! value used elsewhere in OpenOrb (see classes/Base_class.f90)
    eps = 23.43929111111111_rprec8*two_pi/360.0_rprec8
    ALLOCATE(BC_ephemeris_r8(nastpert,6), tmp_elements(nastpert,6), &
         mean_motion(nastpert,1), R2(3,3), ea(nastpert,1), &
         ma(nastpert,1), sigma(nastpert,1), x(nastpert,1), &
         esinx(nastpert,1), f(nastpert,1), ecosx(nastpert,1), &
         cea(nastpert,1), sea(nastpert,1), b(nastpert,1), &
         dot_ea(nastpert,1), celements(nastpert,6), v(nastpert,1), &
         r3(nastpert,1), h(nastpert,1), r(nastpert,3,3), &
         sin_angles(nastpert,3), cos_angles(nastpert,3))

    ! First, find the ephemeris with the closest MJD to
    ! what we want.
    ind = findLocation(mjd_tt, asteroid_epochs)!+1
    eph_epoch = asteroid_epochs(ind)
    dt = mjd_tt - eph_epoch
    tmp_elements(:,:) = asteroid_ephemerides(1:nastpert,ind,1:6)
    mean_motion(:,1) = SQRT(planetary_mu(11)/tmp_elements(:,1)**3)
    tmp_elements(:,6) = MODULO(tmp_elements(:,6) + mean_motion(:,1)*dt, two_pi)

    ! Convert Keplerian elements of input orbits to Cartesian like in
    ! the Orbit class.
    ma(:,1) = tmp_elements(:,6)
    ma(:,1) = MODULO(ma(:,1),two_pi)
    sigma(:,1) = SIGN(1.0_rprec8,SIN(ma(:,1)))
    x(:,1) = ma(:,1) + sigma(:,1)*kk*tmp_elements(:,2)

    ! Solve Kepler's equation iteratively using Newton's accelerated
    ! method:
    esinx(:,1) = tmp_elements(:,2)*SIN(x(:,1))
    f(:,1) = x(:,1) - esinx(:,1) - ma(:,1)
    DO j=1, nastpert
       i = 1
       DO WHILE (ABS(f(j,1)) >= tol)
          IF (i > nmax) THEN
             error = .TRUE.
             RETURN
          END IF
          ecosx(j,1) = tmp_elements(j,2)*COS(x(j,1))
          fp         = 1.0d0 - ecosx(j,1)
          fpp        = esinx(j,1)
          fppp       = ecosx(j,1)
          dx         = -f(j,1)/fp
          dx         = -f(j,1)/(fp+0.5d0*dx*fpp)
          dx         = -f(j,1)/(fp+0.5d0*dx*fpp+dx*dx*fppp/6.0d0)
          x(j,1)     = x(j,1) + dx
          esinx(j,1) = tmp_elements(j,2)*SIN(x(j,1))
          f(j,1)     = x(j,1) - esinx(j,1) - ma(j,1)
          i          = i + 1
       END DO
    END DO
    ea(:,1) = MODULO(x(:,1),two_pi)

    cea(:,1) = COS(ea(:,1))
    sea(:,1) = SIN(ea(:,1))
    b(:,1) = tmp_elements(:,1) * SQRT(1.0_rprec8 - tmp_elements(:,2)**2)
    dot_ea(:,1) = SQRT(planetary_mu(11)/tmp_elements(:,1)**3) / &
         (1.0_rprec8 - tmp_elements(:,2)*cea(:,1))

    !! Keplerian elements to polar Cartesian elements:
    !! -positions:
    celements(:,1) = tmp_elements(:,1)*(cea(:,1) - tmp_elements(:,2))
    celements(:,2) = b(:,1)*sea(:,1)
    celements(:,3) = 0.0_rprec8
    !! -velocities:
    celements(:,4) = -1*tmp_elements(:,1)*dot_ea(:,1)*sea(:,1)
    celements(:,5) = b(:,1)*dot_ea(:,1)*cea(:,1)
    celements(:,6) = 0.0_rprec8
    sin_angles(:,:) = SIN(tmp_elements(:,3:5))
    cos_angles(:,:) = COS(tmp_elements(:,3:5))

    R(:,1,1) = cos_angles(:,2)*cos_angles(:,3) - &
         sin_angles(:,2)*sin_angles(:,3)*cos_angles(:,1)
    R(:,1,2) = -(cos_angles(:,2)*sin_angles(:,3) + &
         sin_angles(:,2)*cos_angles(:,3)*cos_angles(:,1))
    R(:,1,3) = sin_angles(:,2)*sin_angles(:,1)

    R(:,2,1) = sin_angles(:,2)*cos_angles(:,3) + &!
         cos_angles(:,2)*sin_angles(:,3)*cos_angles(:,1)
    R(:,2,2) = -(sin_angles(:,2)*sin_angles(:,3) - &
         cos_angles(:,2)*cos_angles(:,3)*cos_angles(:,1))
    R(:,2,3) = -cos_angles(:,2)*sin_angles(:,1)

    R(:,3,1) = sin_angles(:,3)*sin_angles(:,1)
    R(:,3,2) = cos_angles(:,3)*sin_angles(:,1)
    R(:,3,3) = cos_angles(:,1)
    DO i=1,nastpert
       celements(i,1:3) = MATMUL(R(i,:,:),celements(i,1:3))
       celements(i,4:6) = MATMUL(R(i,:,:),celements(i,4:6))
    END DO

    ! Rotate polar Cartesian to equatorial Cartesian
    R2(1,:) = (/ 1.0d0,   0.0d0,    0.0d0 /)
    R2(2,:) = (/ 0.0d0, COS(eps), -SIN(eps) /)
    R2(3,:) = (/ 0.0d0, SIN(eps),  COS(eps) /)
    DO i=1,nastpert
       celements(i,1:3) = MATMUL(r2,celements(i,1:3))
       celements(i,4:6) = MATMUL(r2,celements(i,4:6))
    END DO
    BC_ephemeris_r8(:,:) = celements(:,:)

  END FUNCTION BC_ephemeris_r8




END MODULE planetary_data
