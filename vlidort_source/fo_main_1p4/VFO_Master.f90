! ###########################################################
! #                                                         #
! #                    THE LIDORT FAMILY                    #
! #                                                         #
! #      (LInearized Discrete Ordinate Radiative Transfer)  #
! #       --         -        -        -         -          #
! #                                                         #
! ###########################################################

! ###########################################################
! #                                                         #
! #  Author :      Robert. J. D. Spurr                      #
! #                                                         #
! #  Address :     RT Solutions, Inc.                       #
! #                9 Channing Street                        #
! #                Cambridge, MA 02138, USA                 #
! #                                                         #
! #  Tel:          (617) 492 1183                           #
! #  Email :        rtsolutions@verizon.net                 #
! #                                                         #
! ###########################################################

! ###########################################################
! #                                                         #
! #              FIRST-ORDER VECTOR MODEL                   #
! #     (EXACT SINGLE-SCATTERING and DIRECT-THERMAL)        #
! #                                                         #
! #  This Version :   1.4 F90                               #
! #  Release Date :   August 2013                           #
! #                                                         #
! #   Version 1.1,  13 February 2012, First Code            #
! #   Version 1.2,  01 June     2012, Modularization        #
! #   Version 1.3a, 29 October  2012, Obsgeom Multi-geom.   #
! #   Version 1.3b, 24 January  2013, BRDF/SL Supplements   #
! #   Version 1.4,  31 July     2013, Lattice Multi-geom.   #
! #                                                         #
! ###########################################################

! ##########################################################
! #                                                        #
! #   This Version of FIRST_ORDER comes with a GNU-style   #
! #   license. Please read the license carefully.          #
! #                                                        #
! ##########################################################

!  This module prepared for VLIDORT ingestion, R.Spurr 3/19/15

module VFO_Master_m

!  All subroutines public

public

contains

subroutine VFO_MASTER &
       ( maxgeoms, maxszas, maxvzas, maxazms,                                & ! Input max dims
         maxlayers, maxfine, maxmoments_input, max_user_levels,              & ! Input max dims
         ngeoms, nszas, nvzas, nazms, nlayers, nfine,                        & ! Input dims
         nmoments_input, n_user_levels, nstokes,                             & ! Input dims
         do_solar_sources, do_thermal_emission, do_surface_emission,         & ! Input flags
         do_planpar, do_regular_ps, do_enhanced_ps, do_deltam_scaling,       & ! Input flags
         do_upwelling, do_dnwelling, do_lambertian, do_sunlight, do_obsgeom, & ! Input flags
         dtr, Pie, doCrit, Acrit, eradius, heights, user_levels,             & ! Input general
         obsgeom_boa, alpha_boa, theta_boa, phi_boa,                         & ! Input geometry
         flux, fluxvec, extinction, deltaus, omega, greekmat, truncfac,      & ! Input atmos optical
         bb_input, reflec, surfbb, emiss,                                    & ! Input surf optical
         fo_stokes_ss, fo_stokes_db, fo_stokes_dta, fo_stokes_dts,           & ! Output
         fo_stokes, Master_fail, message, trace_1, trace_2 )                   ! Output

!  Use modules

   USE FO_SSGeometry_Master_m
   USE FO_DTGeometry_Master_m

   USE FO_VectorSS_spherfuncs_m
   USE FO_VectorSS_RTCalcs_I_m

   USE FO_Thermal_RTCalcs_I_m

   implicit none

!  parameter arguments

   integer, parameter :: ffp = selected_real_kind(15),&
                         maxstokes = 4, max_directions = 2,&
                         upidx = 1, dnidx = 2

!  Subroutine inputs
!  =================

!  Max dimensions
!  --------------

   integer, intent(in)  :: maxgeoms, maxszas, maxvzas, maxazms
   integer, intent(in)  :: maxlayers, maxfine, maxmoments_input, max_user_levels

!  Dimensions
!  ----------

!  Layer and geometry control. Finelayer divisions may be changed

   integer, intent(in)    :: ngeoms, nszas, nvzas, nazms, nlayers, nfine
   integer, intent(in)    :: nmoments_input
   integer, intent(in)    :: n_user_levels

!  Number of Stokes components

   integer, intent(in)    :: nstokes

!  Configuration inputs
!  --------------------

!  Sources control, including thermal

   logical, intent(in)  :: do_solar_sources
   logical, intent(in)  :: do_thermal_emission
   logical, intent(in)  :: do_surface_emission

!  Flags (sphericity flags should be mutually exclusive)

   logical, intent(in)  :: do_planpar
   logical, intent(in)  :: do_regular_ps
   logical, intent(in)  :: do_enhanced_ps

!  deltam scaling flag

   logical, intent(in)  :: do_deltam_scaling

!  Directional Flags

   logical, intent(in)  :: do_upwelling, do_dnwelling

!  Lambertian surface flag

   logical, intent(in)  :: do_lambertian

!  Vector sunlight flag

   logical, intent(in)  :: do_sunlight

!  Obsgeom flag

   logical, intent(in)     :: do_Obsgeom

!  General inputs
!  --------------

!  dtr = degrees-to-Radians. Pie = 3.14159...

   real(ffp), intent(in) :: dtr, Pie

!  Critical adjustment for cloud layers

   logical, intent(inout)  :: doCrit
   real(ffp),   intent(in) :: Acrit

!  Earth radius + heights

   real(ffp), intent(in) :: eradius, heights (0:maxlayers)

!  Output levels

   integer, intent(in)   :: user_levels ( max_user_levels )

!  Geometry inputs
!  ---------------

!  input angles (Degrees). Enough information for Lattice or Obsgeom.
!   Convention for ObsGeom = same as VLIDORT/LIDORT (1=sza,2=vza,3=azm)
!    In both cases, the Phi angle may be changed.....

   real(ffp), intent(inout)  :: Obsgeom_boa(maxgeoms,3)
   real(ffp), intent(inout)  :: alpha_boa(maxvzas), theta_boa(maxszas), phi_boa(maxazms)

!  optical inputs
!  --------------

!  Solar flux

   real(ffp), intent(in) :: flux, fluxvec(maxstokes)

!  Atmosphere

   real(ffp), intent(in) :: extinction  ( maxlayers )
   real(ffp), intent(in) :: deltaus     ( maxlayers )
   real(ffp), intent(in) :: omega       ( maxlayers )
   real(ffp), intent(in) :: greekmat    ( maxlayers, 0:maxmoments_input, maxstokes, maxstokes )

!  For TMS correction

   real(ffp), intent(in) :: truncfac ( maxlayers )

!  Thermal inputs

   real(ffp), intent(in) :: bb_input ( 0:maxlayers )

!  Surface properties - reflective (could be the albedo)

   real(ffp), intent(in) :: reflec(maxstokes,maxstokes,maxgeoms)

!  Surface properties - emissive

   real(ffp), intent(in) :: surfbb
   real(ffp), intent(in) :: emiss ( maxvzas )

!  Subroutine outputs
!  ==================

!  Solar

   real(ffp), intent(out) :: fo_stokes_ss ( max_user_levels,maxgeoms,maxstokes,max_directions )
   real(ffp), intent(out) :: fo_stokes_db ( max_user_levels,maxgeoms,maxstokes )

!  Thermal

   real(ffp), intent(out) :: fo_stokes_dta ( max_user_levels,maxgeoms,maxstokes,max_directions )
   real(ffp), intent(out) :: fo_stokes_dts ( max_user_levels,maxgeoms,maxstokes )

!  Composite

   real(ffp), intent(out) :: fo_stokes     ( max_user_levels,maxgeoms,maxstokes,max_directions )

!  Exception handling

   logical, intent(out)           :: Master_fail
   character (len=*), intent(out) :: message
   character (len=*), intent(out) :: trace_1, trace_2


!  Other variables
!  ===============

!  Geometry routine outputs
!  ------------------------

!  VSIGN = +1 (Up); -1(Down)

   real(ffp)  :: vsign

!  LOSPATHS flag has been removed now.  8/1/13

!  Flag for the Nadir case

   logical    :: doNadir(maxgeoms)
  
!  Alphas,  Cotangents, Radii, Ray constant. 

   real(ffp)  :: radii    (0:maxlayers)
   real(ffp)  :: Raycon   (maxgeoms)
   real(ffp)  :: alpha    (0:maxlayers,maxgeoms)
   real(ffp)  :: cota     (0:maxlayers,maxgeoms)

!  Critical layer

   integer    :: Ncrit(maxgeoms)
   real(ffp)  :: RadCrit(maxgeoms), CotCrit(maxgeoms)

!  solar paths 

   integer    :: ntraverse  (0:maxlayers,maxgeoms)
   real(ffp)  :: sunpaths   (0:maxlayers,maxlayers,maxgeoms)

   integer    :: ntraversefine (maxlayers,maxfine,maxgeoms)
   real(ffp)  :: sunpathsfine  (maxlayers,maxlayers,maxfine,maxgeoms)
   real(ffp)  :: Chapfacs      (maxlayers,maxlayers,maxgeoms)

!  Cosine scattering angle, other cosines

   real(ffp)  :: cosscat (maxgeoms)
   real(ffp)  :: Mu0     (maxgeoms)
   real(ffp)  :: Mu1     (maxgeoms)

!  LOS Quadratures for Enhanced PS

   integer    :: nfinedivs(maxlayers,maxgeoms)
   real(ffp)  :: xfine   (maxlayers,maxfine,maxgeoms)
   real(ffp)  :: wfine   (maxlayers,maxfine,maxgeoms)
   real(ffp)  :: csqfine (maxlayers,maxfine,maxgeoms)
   real(ffp)  :: cotfine (maxlayers,maxfine,maxgeoms)

!  Fine layering output

   real(ffp)  :: alphafine (maxlayers,maxfine,maxgeoms)
   real(ffp)  :: radiifine (maxlayers,maxfine,maxgeoms)

!  Spherfunc routine outputs
!  -------------------------

!  Spherical functions, rotation angles

   real(ffp)  :: rotations_up(4,maxgeoms)
   real(ffp)  :: genspher_up(0:maxmoments_input,4,maxgeoms)
   real(ffp)  :: rotations_dn(4,maxgeoms)
   real(ffp)  :: genspher_dn(0:maxmoments_input,4,maxgeoms)
   real(ffp)  :: gshelp(7,0:maxmoments_input)

!  RT calculation outputs
!  ----------------------

!  Solar routines

   real(ffp)  :: stokes_up    ( max_user_levels,maxstokes,maxgeoms )
   real(ffp)  :: stokes_dn    ( max_user_levels,maxstokes,maxgeoms )
   real(ffp)  :: stokes_db    ( max_user_levels,maxstokes,maxgeoms )

!  Thermal routines (Scalar, no polarization). SEE LOS VARIALBES (THERMAL), below
!   real(ffp)  :: intensity_dta_up ( max_user_levels,maxgeoms )
!   real(ffp)  :: intensity_dta_dn ( max_user_levels,maxgeoms )
!   real(ffp)  :: intensity_dts    ( max_user_levels,maxgeoms )

!  Intermediate RT products
!  ------------------------

!  Composite

   real(ffp)  :: fo_stokes_atmos ( max_user_levels,maxgeoms,maxstokes,max_directions )
   real(ffp)  :: fo_stokes_surf  ( max_user_levels,maxgeoms,maxstokes )

!  LOS VARIABLES (THERMAL SOLUTION)
!  --------------------------------

   real(ffp)  :: intensity_dta_up_LOS ( max_user_levels,maxvzas )
   real(ffp)  :: intensity_dta_dn_LOS ( max_user_levels,maxvzas )
   real(ffp)  :: intensity_dts_LOS    ( max_user_levels,maxvzas )
   real(ffp)  :: cumsource_up_LOS     ( 0:maxlayers,maxvzas )
   real(ffp)  :: cumsource_dn_LOS     ( 0:maxlayers,maxvzas )

   logical    :: doNadir_LOS (maxvzas)
   real(ffp)  :: Raycon_LOS   (maxvzas)
   real(ffp)  :: alpha_LOS    (0:maxlayers,maxvzas)
   real(ffp)  :: cota_LOS     (0:maxlayers,maxvzas)
   integer    :: Ncrit_LOS(maxvzas)
   real(ffp)  :: RadCrit_LOS(maxvzas), CotCrit_LOS(maxvzas)
   real(ffp)  :: Mu1_LOS(maxvzas)
   integer    :: nfinedivs_LOS(maxlayers,maxvzas)
   real(ffp)  :: xfine_LOS   (maxlayers,maxfine,maxvzas)
   real(ffp)  :: wfine_LOS   (maxlayers,maxfine,maxvzas)
   real(ffp)  :: csqfine_LOS (maxlayers,maxfine,maxvzas)
   real(ffp)  :: cotfine_LOS (maxlayers,maxfine,maxvzas)
   real(ffp)  :: alphafine_LOS (maxlayers,maxfine,maxvzas)
   real(ffp)  :: radiifine_LOS (maxlayers,maxfine,maxvzas)

!  Other products
!  --------------

!  Thermal setup

   real(ffp)  :: tcom1(maxlayers,2)

!  Dummies

   real(ffp)  :: SScumsource_up ( 0:maxlayers,maxstokes,maxgeoms )
   real(ffp)  :: SScumsource_dn ( 0:maxlayers,maxstokes,maxgeoms )
!   real(ffp)  :: DTcumsource_up ( 0:maxlayers,maxgeoms )
!   real(ffp)  :: DTcumsource_dn ( 0:maxlayers,maxgeoms )

!  LOCAL HELP VARIABLES
!  --------------------

!  numbers

   real(ffp), parameter :: zero = 0.0_ffp

!  help variables

   integer   :: ns, nv, na, g, lev, o1, nv_offset(maxszas), na_offset(maxszas,maxvzas)
   logical   :: STARTER, do_Thermset, fail, do_Chapman

!  Initialize output

   fo_stokes_ss  = zero
   fo_stokes_db  = zero
   fo_stokes_dta = zero
   fo_stokes_dts = zero
   fo_stokes     = zero

   Master_fail = .false.
   message = ' '
   trace_1 = ' '
   trace_2 = ' '

!  Flags to be set for each calculation (safety)

   do_Chapman  = .false.
   do_Thermset = .true.
   starter     = .true.
!mick fix 3/25/2015 - added initialization
   doNadir     = .false.

!  Offsets

   na_offset = 0 ; nv_offset = 0
   if ( .not. do_obsgeom ) then
     do ns = 1, nszas
       nv_offset(ns) = nvzas * nazms * (ns - 1) 
       do nv = 1, nvzas
         na_offset(ns,nv) = nv_offset(ns) + nazms * (nv - 1)
       enddo
     enddo
   endif

!  Solar sources run (NO THERMAL)
!  ------------------------------

   if ( do_solar_sources ) then

!  Upwelling

     if ( do_upwelling ) then
       vsign =  1.0_ffp

!  Geometry call

       call FO_SSGeometry_Master &
       ( maxgeoms, maxszas, maxvzas, maxazms, maxlayers, maxfine,            & ! Input dimensions
         do_obsgeom, do_Chapman, do_planpar, do_enhanced_ps,                 & ! Input flags
         ngeoms, nszas, nvzas, nazms, nlayers, nfine, dtr, Pie, vsign,       & ! Input control and constants
         eradius, heights, obsgeom_boa, alpha_boa, theta_boa, phi_boa,       & ! Input
         doNadir, doCrit, Acrit, extinction, Raycon, radii, alpha, cota,     & ! Input/Output(level)
         nfinedivs, xfine, wfine, csqfine, cotfine, alphafine, radiifine,    & ! Output(Fine)
         NCrit, RadCrit, CotCrit, Mu0, Mu1, cosscat, chapfacs,               & ! Output(Crit/scat)
         sunpaths, ntraverse, sunpathsfine, ntraversefine,                   & ! Output(Sunpaths)
         fail, message, trace_1 )                                                ! Output(Status)

!   do lev = 1,nlayers
!      write(555,*)lev,sunpaths(lev,1:lev,1)
!      do ns = 1,nfinedivs(lev,1)
!         write(555,*)lev,ns,sunpathsfine(lev,1:lev,ns,1)
!      enddo
!   enddo
!   pause

       if ( fail ) then
         trace_2 = 'Failure from FO_SSGeometry_Master, Solar Sources, Upwelling calculation'
         Master_fail = .true. ; return
       endif

!  Spherical functions call. Updated 3/19/15 for Lattice option

       Call FO_VectorSS_spherfuncs &
        ( MAXMOMENTS_INPUT, MAXGEOMS, MAXSZAS, MAXVZAS, MAXAZMS, & ! Inputs
          NMOMENTS_INPUT, NGEOMS, NSZAS, NVZAS, NAZMS, NSTOKES,  & ! Inputs
          STARTER, DO_OBSGEOM, DO_SUNLIGHT, NA_OFFSET,           & ! Inputs
          DTR, THETA_BOA, ALPHA_BOA, PHI_BOA, COSSCAT, VSIGN,    & ! Inputs
          ROTATIONS_UP, GSHELP, GENSPHER_UP )                      ! Outputs

!  RT Call Solar only

       Call SSV_Integral_I_UP &
      ( maxgeoms, maxlayers, maxfine, maxmoments_input, max_user_levels,            & ! Inputs (dimensioning)
        do_sunlight, do_deltam_scaling, do_lambertian,                              & ! Inputs (Flags)
        do_PlanPar, do_regular_ps, do_enhanced_ps, doNadir, nstokes,                & ! Inputs (Flags)
        ngeoms, nlayers, nfinedivs, nmoments_input, n_user_levels, user_levels,     & ! Inputs (control output)
        reflec, extinction, deltaus, omega, truncfac, greekmat, flux, fluxvec,      & ! Inputs (Optical)
        Mu0, Mu1, GenSpher_up, Rotations_up, NCrit, xfine, wfine, csqfine, cotfine, & ! Inputs (Geometry)
        Raycon, cota, sunpaths, ntraverse, sunpathsfine, ntraversefine,             & ! Inputs (Geometry)
        stokes_up, stokes_db, SScumsource_up )                                        ! Outputs

!  Save results

       do o1 = 1, nstokes
         do g = 1, ngeoms
           do lev=1,n_user_levels
             fo_stokes_ss(lev,g,o1,upidx) = stokes_up(lev,o1,g)
             fo_stokes_db(lev,g,o1)       = stokes_db(lev,o1,g)
             fo_stokes(lev,g,o1,upidx)    = fo_stokes_ss(lev,g,o1,upidx) &
                                          + fo_stokes_db(lev,g,o1)
           enddo
         enddo
       enddo

!  End upwelling

     endif

!  Donwelling

     if ( do_dnwelling ) then
       vsign =  -1.0_ffp

!  Geometry call

       call FO_SSGeometry_Master &
       ( maxgeoms, maxszas, maxvzas, maxazms, maxlayers, maxfine,            & ! Input dimensions
         do_obsgeom, do_Chapman, do_planpar, do_enhanced_ps,                 & ! Input flags
         ngeoms, nszas, nvzas, nazms, nlayers, nfine, dtr, Pie, vsign,       & ! Input control and constants
         eradius, heights, obsgeom_boa, alpha_boa, theta_boa, phi_boa,       & ! Input
         doNadir, doCrit, Acrit, extinction, Raycon, radii, alpha, cota,     & ! Input/Output(level)
         nfinedivs, xfine, wfine, csqfine, cotfine, alphafine, radiifine,    & ! Output(Fine)
         NCrit, RadCrit, CotCrit, Mu0, Mu1, cosscat, chapfacs,               & ! Output(Crit/scat)
         sunpaths, ntraverse, sunpathsfine, ntraversefine,                   & ! Output(Sunpaths)
         fail, message, trace_1 )                                                ! Output(Status)

       if ( fail ) then
         trace_2 = 'Failure from FO_SSGeometry_Master, Solar Sources, Downwelling calculation'
         Master_fail = .true. ; return
       endif

!  Spherical functions call. Updated 3/19/15 for Lattice option

       Call FO_VectorSS_spherfuncs &
        ( MAXMOMENTS_INPUT, MAXGEOMS, MAXSZAS, MAXVZAS, MAXAZMS, & ! Inputs
          NMOMENTS_INPUT, NGEOMS, NSZAS, NVZAS, NAZMS, NSTOKES,  & ! Inputs
          STARTER, DO_OBSGEOM, DO_SUNLIGHT, NA_OFFSET,           & ! Inputs
          DTR, THETA_BOA, ALPHA_BOA, PHI_BOA, COSSCAT, VSIGN,    & ! Inputs
          ROTATIONS_DN, GSHELP, GENSPHER_DN )                      ! Outputs

!  RT Call Solar only

       Call SSV_Integral_I_DN &
      ( maxgeoms, maxlayers, maxfine, maxmoments_input, max_user_levels, do_sunlight,    & ! Inputs (dimension)
        do_deltam_scaling, do_PlanPar, do_regular_ps, do_enhanced_ps, doNadir,           & ! Inputs (Flags)
        ngeoms, nstokes, nlayers, nfinedivs, nmoments_input, n_user_levels, user_levels, & ! Inputs (control)
        extinction, deltaus, omega, truncfac, greekmat, flux, fluxvec,                   & ! Inputs (Optical)
        Mu1, GenSpher_dn, Rotations_dn, NCrit, RadCrit, CotCrit,                         & ! Inputs (Geometry)
        xfine, wfine, csqfine, cotfine, Raycon, radii, cota,                             & ! Inputs (Geometry)
        sunpaths, ntraverse, sunpathsfine, ntraversefine,                                & ! Inputs (Geometry)
        stokes_dn, SScumsource_dn )                                                        ! Outputs

       !Save results

       do o1 = 1, nstokes
         do g = 1, ngeoms
           do lev=1,n_user_levels
             fo_stokes_ss(lev,g,o1,dnidx) = stokes_dn(lev,o1,g)
             fo_stokes(lev,g,o1,dnidx)    = fo_stokes_ss(lev,g,o1,dnidx)
           enddo
         enddo
       enddo

!  End downwelling

     endif

!  End solar only

   endif

!  Thermal sources run
!  -------------------

   if ( do_thermal_emission.and.do_surface_emission ) then

!  DT Geometry call

     call FO_DTGeometry_Master  &
          ( maxvzas, maxlayers, maxfine, do_planpar, do_enhanced_ps,  & ! Input dimensions/flags
            nvzas, nlayers, nfine, dtr, eradius, heights, alpha_boa,  & ! Inputs
            doNadir_LOS, doCrit, Acrit, extinction,                   & ! Input/Output(level)
            Raycon_LOS, radii, alpha_LOS, cota_LOS,                   & ! Input/Output(level)
            nfinedivs_LOS, xfine_LOS, wfine_LOS, csqfine_LOS,         & ! Output(Fine)
            cotfine_LOS, alphafine_LOS, radiifine_LOS,                & ! Output(Fine)
            NCrit_LOS, RadCrit_LOS, CotCrit_LOS, Mu1_LOS,             & ! Output(Critical/Cos)
            fail, message, trace_1 )                                    ! Output(Status)

     if ( fail ) then
       trace_2 = 'Failure from FO_DTGeometry_Master'
       Master_fail = .true. ; return
     endif

!  Upwelling
!  ---------

     if ( do_upwelling ) then

!  Direct thermal, calculate

       call DTE_Integral_I_UP &
         ( maxvzas, maxlayers, maxfine, max_user_levels,                & ! Inputs (dimensioning)
           Do_Thermset, do_deltam_scaling, do_PlanPar,                  & ! Inputs (Flags)
           do_regular_ps, do_enhanced_ps, doNadir,                      & ! Inputs (Flags)
           nvzas, nlayers, nfinedivs_LOS, n_user_levels, user_levels,   & ! Inputs (control output)
           bb_input, surfbb, emiss,                                     & ! Inputs (Thermal)
           extinction, deltaus, omega, truncfac,                        & ! Inputs (Optical)
           Mu1_LOS, NCrit_LOS, Raycon_LOS, cota_LOS,                    & ! Inputs (Geometry)
           xfine_LOS, wfine_LOS, csqfine_LOS, cotfine_LOS,              & ! Inputs (Geometry)
           intensity_dta_up_LOS, intensity_dts_LOS,                     & ! Output
           cumsource_up_LOS, tcom1 )                                      ! Outputs

!  Save results

       o1=1
       if ( do_obsgeom ) then
         do g = 1, nvzas
           do lev=1,n_user_levels
             fo_stokes_dta(lev,g,o1,upidx) = intensity_dta_up_LOS(lev,g)
             fo_stokes_dts(lev,g,o1)       = intensity_dts_LOS(lev,g)
             fo_stokes(lev,g,o1,upidx)     = fo_stokes_dta(lev,g,o1,upidx) + fo_stokes_dts(lev,g,o1)
           enddo
         enddo
       else
         do nv = 1, nvzas
           do ns = 1, nszas
             do na = 1, nazms
               g = na_offset(ns,nv) + na
               do lev=1,n_user_levels
                 fo_stokes_dta(lev,g,o1,upidx) = intensity_dta_up_LOS(lev,nv)
                 fo_stokes_dts(lev,g,o1)       = intensity_dts_LOS(lev,nv)
                 fo_stokes(lev,g,o1,upidx)     = fo_stokes_dta(lev,g,o1,upidx) + fo_stokes_dts(lev,g,o1)
               enddo
             enddo
           enddo
         enddo
       endif

!  End upwelling

     endif

!  Downwelling
!  -----------

     if ( do_dnwelling ) then

!  Direct thermal, calculate

       call DTE_Integral_I_DN &
         ( maxvzas, maxlayers, maxfine, max_user_levels,               & ! Inputs (dimensioning)
           Do_Thermset, do_deltam_scaling, do_PlanPar,                 & ! Inputs (Flags)
           do_regular_ps, do_enhanced_ps, doNadir,                     & ! Inputs (Flags)
           nvzas, nlayers, nfinedivs_LOS, n_user_levels, user_levels,  & ! Inputs (control output)
           BB_input, extinction, deltaus, omega, truncfac,             & ! Inputs (Optical)
           Mu1_LOS, NCrit_LOS, RadCrit_LOS, CotCrit_LOS, Raycon_LOS, radii,  & ! Inputs (Geometry)
           cota_LOS, xfine_LOS, wfine_LOS, csqfine_LOS, cotfine_LOS,         & ! Inputs (Geometry)
           intensity_dta_dn_LOS, cumsource_dn_LOS, tcom1 )                     ! Outputs

!  Save results

       o1=1
       if ( do_obsgeom ) then
         do g = 1, nvzas
           do lev=1,n_user_levels
             fo_stokes_dta(lev,g,o1,dnidx) = intensity_dta_dn_LOS(lev,g)
             fo_stokes(lev,g,o1,dnidx)     = fo_stokes_dta(lev,g,o1,dnidx)
           enddo
         enddo
       else
         do nv = 1, nvzas
           do ns = 1, nszas
             do na = 1, nazms
               g = na_offset(ns,nv) + na
               do lev=1,n_user_levels
                 fo_stokes_dta(lev,g,o1,dnidx) = intensity_dta_dn_LOS(lev,nv)
                 fo_stokes(lev,g,o1,dnidx)     = fo_stokes_dta(lev,g,o1,dnidx)
               enddo
             enddo
           enddo
         enddo
       endif

!  end downwelling

     endif

!  End thermal run

   endif

!  Solar and Thermal sources run
!  -----------------------------

! Add solar and thermal components

   if ( do_solar_sources.and.(do_thermal_emission.and.do_surface_emission)  ) then

     if ( do_upwelling ) then
       o1=1
       do g = 1, ngeoms
         do lev=1,n_user_levels
           fo_stokes_atmos(lev,g,o1,upidx) = fo_stokes_ss(lev,g,o1,upidx) + fo_stokes_dta(lev,g,o1,upidx)
           fo_stokes_surf(lev,g,o1)        = fo_stokes_db(lev,g,o1)       + fo_stokes_dts(lev,g,o1)
           fo_stokes(lev,g,o1,upidx)       = fo_stokes_atmos(lev,g,o1,upidx) + fo_stokes_surf(lev,g,o1)
         enddo
       enddo
     endif

     if ( do_dnwelling ) then
       o1=1
       do g = 1, ngeoms
         do lev=1,n_user_levels
           fo_stokes_atmos(lev,g,o1,dnidx) = fo_stokes_ss(lev,g,o1,dnidx) + fo_stokes_dta(lev,g,o1,dnidx)
           fo_stokes(lev,g,o1,dnidx)       = fo_stokes_atmos(lev,g,o1,dnidx)
         enddo
       enddo
     endif

!  End solar+thermal

   endif

!  Finish

   return
end subroutine VFO_MASTER

end module VFO_Master_m
