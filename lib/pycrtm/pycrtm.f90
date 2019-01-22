module pycrtm 
contains
subroutine wrapForward( coefficientPath, sensor_id, & 
                        zenithAngle, scanAngle, azimuthAngle, solarAngle, nChan, &
                        N_LAYERS, pressureLevels, pressureLayers, temperatureLayers, humidityLayers, ozoneConcLayers, & 
                        surfaceType, surfaceTemperature, windSpeed10m, windDirection10m, & 
                        outTb )      

  ! ============================================================================
  ! STEP 1. **** ENVIRONMENT SETUP FOR CRTM USAGE ****
  !
  ! Module usage
  USE CRTM_Module
  ! Disable all implicit typing
  IMPLICIT NONE
  ! ============================================================================
  ! variables for interface
  character(1024), intent(in) :: coefficientPath
  character(len=256), intent(in) :: sensor_id(1)
  ! The scan angle is based
  ! on the default Re (earth radius) and h (satellite height)
  real, intent(in) :: zenithAngle, scanAngle, azimuthAngle, solarAngle
  integer, intent(in) :: nChan, N_Layers 
  real, intent(in), dimension(N_LAYERS) :: pressureLevels, pressureLayers, temperatureLayers, humidityLayers, ozoneConcLayers
  integer, intent(in) :: surfaceType
  real, intent(in) :: surfaceTemperature, windSpeed10m, windDirection10m
  real, dimension(nChan) :: outTb
  


  ! --------------------------
  ! Some non-CRTM-y Parameters
  ! --------------------------
  CHARACTER(*), PARAMETER :: SUBROUTINE_NAME   = 'wrapForward'
  CHARACTER(*), PARAMETER :: PROGRAM_VERSION_ID = '0.01'



  ! ============================================================================
  ! STEP 2. **** SET UP SOME PARAMETERS FOR THE CRTM RUN ****
  !
  ! Directory location of coefficients

  ! Profile dimensions
  INTEGER, PARAMETER :: N_PROFILES  = 1
  INTEGER, PARAMETER :: N_ABSORBERS = 2
  INTEGER, PARAMETER :: N_CLOUDS    = 0
  INTEGER, PARAMETER :: N_AEROSOLS  = 0
  
  ! Sensor information
  INTEGER     , PARAMETER :: N_SENSORS = 1
  !CHARACTER(len=20) :: sensor_id 
  ! ============================================================================
  


  ! ---------
  ! Variables
  ! ---------
  CHARACTER(256) :: message, version
  INTEGER :: err_stat, alloc_stat
  INTEGER :: n_channels
  INTEGER :: l, m, n, nc



  ! ============================================================================
  ! STEP 3. **** DEFINE THE CRTM INTERFACE STRUCTURES ****
  !
  ! 3a. Define the "non-demoninational" arguments
  ! ---------------------------------------------
  TYPE(CRTM_ChannelInfo_type)             :: chinfo(N_SENSORS)
  TYPE(CRTM_Geometry_type)                :: geo(N_PROFILES)


  ! 3b. Define the FORWARD variables
  ! --------------------------------
  TYPE(CRTM_Atmosphere_type)              :: atm(N_PROFILES)
  TYPE(CRTM_Surface_type)                 :: sfc(N_PROFILES)
  TYPE(CRTM_RTSolution_type), ALLOCATABLE :: rts(:,:)
  

  ! Program header
  ! --------------
  CALL CRTM_Version( Version )
  CALL Program_Message( SUBROUTINE_NAME, &
    'Running simulation.', &
    'CRTM Version: '//TRIM(Version) )

  ! ============================================================================
  ! STEP 4. **** INITIALIZE THE CRTM ****
  !
  ! 4a. Initialise all the sensors at once
  ! --------------------------------------
  WRITE( *,'(/5x,"Initializing the CRTM...")' )
  err_stat = CRTM_Init( sensor_id,  chinfo, File_Path=coefficientPath, Quiet=.TRUE.)

  IF ( err_stat /= SUCCESS ) THEN
    message = 'Error initializing CRTM'
    CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
    STOP
  END IF

  ! 4b. Output some channel information
  ! -----------------------------------
  n_channels = SUM(CRTM_ChannelInfo_n_Channels(chinfo))
  WRITE( *,'(/5x,"Processing a total of ",i0," channels...")' ) n_channels
  DO n = 1, N_SENSORS
    WRITE( *,'(7x,i0," from ",a)' ) &
      CRTM_ChannelInfo_n_Channels(chinfo(n)), TRIM(sensor_id(n))
  END DO
  ! ============================================================================



  ! Begin loop over sensors
  ! ----------------------
  Sensor_Loop: DO n = 1, N_SENSORS

  
    ! ==========================================================================
    ! STEP 5. **** ALLOCATE STRUCTURE ARRAYS ****
    !
    ! 5a. Determine the number of channels
    !     for the current sensor
    ! ------------------------------------
    n_channels = CRTM_ChannelInfo_n_Channels(chinfo(n))

    
    ! 5b. Allocate the ARRAYS
    ! -----------------------
    ALLOCATE( rts( n_channels, N_PROFILES ), STAT = alloc_stat )

    IF ( alloc_stat /= 0 ) THEN
      message = 'Error allocating structure arrays'
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF


    ! 5c. Allocate the STRUCTURE INTERNALS
    !     NOTE: Only the Atmosphere structures
    !           are allocated in this example
    ! ----------------------------------------
    ! The input FORWARD structure
    CALL CRTM_Atmosphere_Create( atm, N_LAYERS, N_ABSORBERS, N_CLOUDS, N_AEROSOLS )
    IF ( ANY(.NOT. CRTM_Atmosphere_Associated(atm)) ) THEN
      message = 'Error allocating CRTM Forward Atmosphere structure'
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF
  

    ! ==========================================================================
    ! STEP 6. **** ASSIGN INPUT DATA ****
    !
    ! 6a. Atmosphere and Surface input
    !     NOTE: that this is the hard part (in my opinion :o). The mechanism by
    !     by which the atmosphere and surface data are loaded in to their
    !     respective structures below was done purely to keep the step-by-step
    !     instructions in this program relatively "clean".
    ! ------------------------------------------------------------------------
    atm(1)%Absorber_Id(1:2)    = (/ H2O_ID                 , O3_ID /)
    atm(1)%Absorber_Units(1:2) = (/ MASS_MIXING_RATIO_UNITS, VOLUME_MIXING_RATIO_UNITS /)
    ! ...Profile data
    atm(1)%Level_Pressure = pressureLevels
    atm(1)%Pressure = pressureLayers
    atm(1)%Temperature = temperatureLayers
    atm(1)%Absorber(:,1) = humidityLayers
    atm(1)%Absorber(:,2) = ozoneConcLayers


    ! 6b. Geometry input
    ! ------------------
    ! All profiles are given the same value
    !  The Sensor_SCAN_ANGLE is optional.  !! BMK- Oh? this would be nice. Not sure if that's true though. Think you need it for FastEm?
    CALL CRTM_Geometry_SetValue( geo, &
                                 Sensor_Zenith_Angle = dble(zenithAngle), &
                                 Sensor_Scan_Angle   = dble(scanAngle) )
    ! ==========================================================================


    
    ! ==========================================================================
    ! STEP 8. **** CALL THE CRTM FUNCTIONS FOR THE CURRENT SENSOR ****
    !
    WRITE( *, '( /5x, "Calling the CRTM functions for ",a,"..." )' ) TRIM(sensor_id(n))
    
    ! 8a. The forward model
    ! ---------------------
    err_stat = CRTM_Forward( atm        , &  ! Input
                             sfc        , &  ! Input
                             geo        , &  ! Input
                             chinfo(n:n), &  ! Input
                             rts          )  ! Output
    IF ( err_stat /= SUCCESS ) THEN
      message = 'Error calling CRTM Forward Model for '//TRIM(sensor_id(n))
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF
    
    ! ============================================================================
    ! 8c. **** OUTPUT THE RESULTS TO SCREEN **** (Or transfer it into a series of arrays out of this thing!)
    !
    ! User should read the user guide or the source code of the routine
    ! CRTM_RTSolution_Inspect in the file CRTM_RTSolution_Define.f90 to
    ! select the needed variables for outputs.  These variables are contained
    ! in the structure RTSolution.
    
    outTb = rts(:,1)%Brightness_Temperature 
    
    ! ==========================================================================
    ! STEP 9. **** CLEAN UP FOR NEXT SENSOR ****
    !
    ! 9a. Deallocate the structures
    ! -----------------------------
    CALL CRTM_Atmosphere_Destroy(atm)


    ! 9b. Deallocate the arrays
    ! -------------------------
    DEALLOCATE(rts, STAT = alloc_stat)
    ! ==========================================================================

  END DO Sensor_Loop


  
  
  ! ==========================================================================
  ! 10. **** DESTROY THE CRTM ****
  !
  WRITE( *, '( /5x, "Destroying the CRTM..." )' )
  err_stat = CRTM_Destroy( chinfo )
  IF ( err_stat /= SUCCESS ) THEN
    message = 'Error destroying CRTM'
    CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
    STOP
  END IF
  ! ==========================================================================
end subroutine wrapForward


subroutine wrapKmatrix( coefficientPath, sensor_id, & 
                        zenithAngle, scanAngle, azimuthAngle, solarAngle, nChan, &
                        N_LAYERS, pressureLevels, pressureLayers, temperatureLayers, humidityLayers, ozoneConcLayers, & 
                        surfaceType, surfaceTemperature, windSpeed10m, windDirection10m, & 
                        outTb, outTransmission, & 
                        temperatureJacobian, humidityJacobian, ozoneJacobian )      

  ! ============================================================================
  ! STEP 1. **** ENVIRONMENT SETUP FOR CRTM USAGE ****
  !
  ! Module usage
  USE CRTM_Module
  ! Disable all implicit typing
  IMPLICIT NONE
  ! ============================================================================
  


  ! --------------------------
  ! Some non-CRTM-y Parameters
  ! --------------------------
  CHARACTER(*), PARAMETER :: SUBROUTINE_NAME   = 'wrapKmatrix'
  CHARACTER(*), PARAMETER :: PROGRAM_VERSION_ID = '0.01'

  ! variables for interface
  character(1024), intent(in) :: coefficientPath
  character(len=256), intent(in) :: sensor_id(1)
  ! The scan angle is based
  ! on the default Re (earth radius) and h (satellite height)
  real, intent(in) :: zenithAngle, scanAngle, azimuthAngle, solarAngle
  integer, intent(in) :: nChan, N_Layers 
  real, intent(in), dimension(N_LAYERS) :: pressureLevels, pressureLayers, temperatureLayers, humidityLayers, ozoneConcLayers
  integer, intent(in) :: surfaceType
  real, intent(in) :: surfaceTemperature, windSpeed10m, windDirection10m
  real, intent(out), dimension(nChan) :: outTb
  real, intent(out), dimension(nChan,N_LAYERS) :: outTransmission, temperatureJacobian, humidityJacobian, ozoneJacobian


  ! ============================================================================
  ! STEP 2. **** SET UP SOME PARAMETERS FOR THE CRTM RUN ****
  !
  ! Directory location of coefficients

  ! Profile dimensions
  INTEGER, PARAMETER :: N_PROFILES  = 1
  INTEGER, PARAMETER :: N_ABSORBERS = 2
  INTEGER, PARAMETER :: N_CLOUDS    = 0
  INTEGER, PARAMETER :: N_AEROSOLS  = 0
  
  ! Sensor information
  INTEGER     , PARAMETER :: N_SENSORS = 1
  ! ============================================================================
  


  ! ---------
  ! Variables
  ! ---------
  CHARACTER(256) :: message, version
  INTEGER :: err_stat, alloc_stat
  INTEGER :: n_channels
  INTEGER :: l, m, n, nc



  ! ============================================================================
  ! STEP 3. **** DEFINE THE CRTM INTERFACE STRUCTURES ****
  !
  ! 3a. Define the "non-demoninational" arguments
  ! ---------------------------------------------
  TYPE(CRTM_ChannelInfo_type)             :: chinfo(N_SENSORS)
  TYPE(CRTM_Geometry_type)                :: geo(N_PROFILES)

  ! 3b. Define the FORWARD variables
  ! --------------------------------
  TYPE(CRTM_Atmosphere_type)              :: atm(N_PROFILES)
  TYPE(CRTM_Surface_type)                 :: sfc(N_PROFILES)
  TYPE(CRTM_RTSolution_type), ALLOCATABLE :: rts(:,:)
 
  ! 3c. Define the K-MATRIX variables
  ! ---------------------------------
  TYPE(CRTM_Atmosphere_type), ALLOCATABLE :: atm_K(:,:)
  TYPE(CRTM_Surface_type)   , ALLOCATABLE :: sfc_K(:,:)
  TYPE(CRTM_RTSolution_type), ALLOCATABLE :: rts_K(:,:)
  ! ============================================================================


  ! Program header
  ! --------------
  CALL CRTM_Version( Version )
  CALL Program_Message( SUBROUTINE_NAME, &
    'Running simulation.', &
    'CRTM Version: '//TRIM(Version) )



  ! ============================================================================
  ! STEP 4. **** INITIALIZE THE CRTM ****
  !
  ! 4a. Initialise all the sensors at once
  ! --------------------------------------
  WRITE( *,'(/5x,"Initializing the CRTM...")' )
  err_stat = CRTM_Init( sensor_id, &
                        chinfo, &
                        File_Path=coefficientPath, &
                        Quiet=.TRUE.)
  IF ( err_stat /= SUCCESS ) THEN
    message = 'Error initializing CRTM'
    CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
    STOP
  END IF

  ! 4b. Output some channel information
  ! -----------------------------------
  n_channels = SUM(CRTM_ChannelInfo_n_Channels(chinfo))
  WRITE( *,'(/5x,"Processing a total of ",i0," channels...")' ) n_channels
  DO n = 1, N_SENSORS
    WRITE( *,'(7x,i0," from ",a)' ) &
      CRTM_ChannelInfo_n_Channels(chinfo(n)), TRIM(sensor_id(n))
  END DO
  ! ============================================================================

    ! 5c. Allocate the STRUCTURE INTERNALS
    !     NOTE: Only the Atmosphere structures
    !           are allocated in this example
    ! ----------------------------------------
    ! The input FORWARD structure
    CALL CRTM_Atmosphere_Create( atm, N_LAYERS, N_ABSORBERS, N_CLOUDS, N_AEROSOLS )
    IF ( ANY(.NOT. CRTM_Atmosphere_Associated(atm)) ) THEN
      message = 'Error allocating CRTM Forward Atmosphere structure'
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF
 

  ! Begin loop over sensors
  ! ----------------------
  Sensor_Loop: DO n = 1, N_SENSORS

  
    ! ==========================================================================
    ! STEP 5. **** ALLOCATE STRUCTURE ARRAYS ****
    !
    ! 5a. Determine the number of channels
    !     for the current sensor
    ! ------------------------------------
    n_channels = CRTM_ChannelInfo_n_Channels(chinfo(n))

    
    ! 5b. Allocate the ARRAYS
    ! -----------------------
    ALLOCATE( atm_K( n_channels, N_PROFILES ), &
              sfc_K( n_channels, N_PROFILES ), &
              rts_K( n_channels, N_PROFILES ), &
              STAT = alloc_stat )
    IF ( alloc_stat /= 0 ) THEN
      message = 'Error allocating structure arrays'
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF


    ! 5c. Allocate the STRUCTURE INTERNALS
    !     NOTE: Only the Atmosphere structures
    !           are allocated in this example
    ! ----------------------------------------
    ! The input FORWARD structure
    CALL CRTM_Atmosphere_Create( atm, N_LAYERS, N_ABSORBERS, N_CLOUDS, N_AEROSOLS )
    IF ( ANY(.NOT. CRTM_Atmosphere_Associated(atm)) ) THEN
      message = 'Error allocating CRTM Forward Atmosphere structure'
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF

    ! ==========================================================================
    ! STEP 6. **** ASSIGN INPUT DATA ****
    !
    ! 6a. Atmosphere and Surface input
    !     NOTE: that this is the hard part (in my opinion :o). The mechanism by
    !     by which the atmosphere and surface data are loaded in to their
    !     respective structures below was done purely to keep the step-by-step
    !     instructions in this program relatively "clean".
    ! ------------------------------------------------------------------------
    atm(1)%Absorber_Id(1:2)    = (/ H2O_ID                 , O3_ID /)
    atm(1)%Absorber_Units(1:2) = (/ MASS_MIXING_RATIO_UNITS, VOLUME_MIXING_RATIO_UNITS /)
    ! ...Profile data
    atm(1)%Level_Pressure = pressureLevels
    atm(1)%Pressure = pressureLayers
    atm(1)%Temperature = temperatureLayers
    atm(1)%Absorber(:,1) = humidityLayers
    atm(1)%Absorber(:,2) = ozoneConcLayers

    ! 6b. Geometry input
    ! ------------------
    ! All profiles are given the same value
    !  The Sensor_SCAN_ANGLE is optional.  !! BMK- Oh? this would be nice. Not sure if that's true though.
    CALL CRTM_Geometry_SetValue( geo, &
                                 Sensor_Zenith_Angle = dble(zenithAngle), &
                                 Sensor_Scan_Angle   = dble(scanAngle) )
    ! ==========================================================================




    ! ==========================================================================
    ! STEP 7. **** INITIALIZE THE K-MATRIX ARGUMENTS ****
    !
    ! 7a. Zero the K-matrix OUTPUT structures
    ! ---------------------------------------
    CALL CRTM_Atmosphere_Zero( atm_K )
    CALL CRTM_Surface_Zero( sfc_K )


    ! 7b. Inintialize the K-matrix INPUT so
    !     that the results are dTb/dx
    ! -------------------------------------
    rts_K%Radiance               = ZERO
    rts_K%Brightness_Temperature = ONE
    ! ==========================================================================



    
    ! ==========================================================================
    ! STEP 8. **** CALL THE CRTM FUNCTIONS FOR THE CURRENT SENSOR ****
    !
    ! 8b. The K-matrix model
    ! ----------------------
    err_stat = CRTM_K_Matrix( atm        , &  ! FORWARD  Input
                              sfc        , &  ! FORWARD  Input
                              rts_K      , &  ! K-MATRIX Input
                              geo        , &  ! Input
                              chinfo(n:n), &  ! Input
                              atm_K      , &  ! K-MATRIX Output
                              sfc_K      , &  ! K-MATRIX Output
                              rts          )  ! FORWARD  Output
    IF ( err_stat /= SUCCESS ) THEN
      message = 'Error calling CRTM K-Matrix Model for '//TRIM(SENSOR_ID(n))
      CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
      STOP
    END IF


    ! ==========================================================================
    ! STEP 9. **** CLEAN UP FOR NEXT SENSOR ****
    !
    ! 9a. Deallocate the structures
    ! -----------------------------
    CALL CRTM_Atmosphere_Destroy(atm)


    ! 9b. Deallocate the arrays
    ! -------------------------
    DEALLOCATE(rts_K, sfc_k, atm_k, STAT = alloc_stat)
    ! ==========================================================================

  END DO Sensor_Loop
  
  ! ==========================================================================
  ! 10. **** DESTROY THE CRTM ****
  !
  WRITE( *, '( /5x, "Destroying the CRTM..." )' )
  err_stat = CRTM_Destroy( chinfo )
  IF ( err_stat /= SUCCESS ) THEN
    message = 'Error destroying CRTM'
    CALL Display_Message( SUBROUTINE_NAME, message, FAILURE )
    STOP
  END IF
  ! ==========================================================================
end subroutine wrapKmatrix
  SUBROUTINE dataUsStandardAtmosphere(Level_Pressure, Pressure, Temperature, water_vapor, ozone )
    real, intent(out), dimension(93) :: Level_Pressure 
    real, intent(out), dimension(92) :: Pressure, Temperature, water_vapor, ozone
    ! ...Profile data
    Level_Pressure = &
    (/0.714,   0.975,   1.297,   1.687,   2.153,   2.701,   3.340,   4.077, &
      4.920,   5.878,   6.957,   8.165,   9.512,  11.004,  12.649,  14.456, &
     16.432,  18.585,  20.922,  23.453,  26.183,  29.121,  32.274,  35.650, &
     39.257,  43.100,  47.188,  51.528,  56.126,  60.990,  66.125,  71.540, &
     77.240,  83.231,  89.520,  96.114, 103.017, 110.237, 117.777, 125.646, &
    133.846, 142.385, 151.266, 160.496, 170.078, 180.018, 190.320, 200.989, &
    212.028, 223.441, 235.234, 247.409, 259.969, 272.919, 286.262, 300.000, &
    314.137, 328.675, 343.618, 358.967, 374.724, 390.893, 407.474, 424.470, &
    441.882, 459.712, 477.961, 496.630, 515.720, 535.232, 555.167, 575.525, &
    596.306, 617.511, 639.140, 661.192, 683.667, 706.565, 729.886, 753.627, &
    777.790, 802.371, 827.371, 852.788, 878.620, 904.866, 931.524, 958.591, &
    986.067,1013.948,1042.232,1070.917,1100.000/)

    Pressure = &
    (/0.838,   1.129,   1.484,   1.910,   2.416,   3.009,   3.696,   4.485, &
      5.385,   6.402,   7.545,   8.822,  10.240,  11.807,  13.532,  15.423, &
     17.486,  19.730,  22.163,  24.793,  27.626,  30.671,  33.934,  37.425, &
     41.148,  45.113,  49.326,  53.794,  58.524,  63.523,  68.797,  74.353, &
     80.198,  86.338,  92.778,  99.526, 106.586, 113.965, 121.669, 129.703, &
    138.072, 146.781, 155.836, 165.241, 175.001, 185.121, 195.606, 206.459, &
    217.685, 229.287, 241.270, 253.637, 266.392, 279.537, 293.077, 307.014, &
    321.351, 336.091, 351.236, 366.789, 382.751, 399.126, 415.914, 433.118, &
    450.738, 468.777, 487.236, 506.115, 525.416, 545.139, 565.285, 585.854, &
    606.847, 628.263, 650.104, 672.367, 695.054, 718.163, 741.693, 765.645, &
    790.017, 814.807, 840.016, 865.640, 891.679, 918.130, 944.993, 972.264, &
    999.942,1028.025,1056.510,1085.394/)

    Temperature = &
    (/256.186, 252.608, 247.762, 243.314, 239.018, 235.282, 233.777, 234.909, &
      237.889, 241.238, 243.194, 243.304, 242.977, 243.133, 242.920, 242.026, &
      240.695, 239.379, 238.252, 236.928, 235.452, 234.561, 234.192, 233.774, &
      233.305, 233.053, 233.103, 233.307, 233.702, 234.219, 234.959, 235.940, &
      236.744, 237.155, 237.374, 238.244, 239.736, 240.672, 240.688, 240.318, &
      239.888, 239.411, 238.512, 237.048, 235.388, 233.551, 231.620, 230.418, &
      229.927, 229.511, 229.197, 228.947, 228.772, 228.649, 228.567, 228.517, &
      228.614, 228.861, 229.376, 230.223, 231.291, 232.591, 234.013, 235.508, &
      237.041, 238.589, 240.165, 241.781, 243.399, 244.985, 246.495, 247.918, &
      249.073, 250.026, 251.113, 252.321, 253.550, 254.741, 256.089, 257.692, &
      259.358, 261.010, 262.779, 264.702, 266.711, 268.863, 271.103, 272.793, &
      273.356, 273.356, 273.356, 273.356/)

    water_vapor = &
    (/4.187E-03,4.401E-03,4.250E-03,3.688E-03,3.516E-03,3.739E-03,3.694E-03,3.449E-03, &
      3.228E-03,3.212E-03,3.245E-03,3.067E-03,2.886E-03,2.796E-03,2.704E-03,2.617E-03, &
      2.568E-03,2.536E-03,2.506E-03,2.468E-03,2.427E-03,2.438E-03,2.493E-03,2.543E-03, &
      2.586E-03,2.632E-03,2.681E-03,2.703E-03,2.636E-03,2.512E-03,2.453E-03,2.463E-03, &
      2.480E-03,2.499E-03,2.526E-03,2.881E-03,3.547E-03,4.023E-03,4.188E-03,4.223E-03, &
      4.252E-03,4.275E-03,4.105E-03,3.675E-03,3.196E-03,2.753E-03,2.338E-03,2.347E-03, &
      2.768E-03,3.299E-03,3.988E-03,4.531E-03,4.625E-03,4.488E-03,4.493E-03,4.614E-03, &
      7.523E-03,1.329E-02,2.468E-02,4.302E-02,6.688E-02,9.692E-02,1.318E-01,1.714E-01, &
      2.149E-01,2.622E-01,3.145E-01,3.726E-01,4.351E-01,5.002E-01,5.719E-01,6.507E-01, &
      7.110E-01,7.552E-01,8.127E-01,8.854E-01,9.663E-01,1.050E+00,1.162E+00,1.316E+00, &
      1.494E+00,1.690E+00,1.931E+00,2.226E+00,2.574E+00,2.939E+00,3.187E+00,3.331E+00, &
      3.352E+00,3.260E+00,3.172E+00,3.087E+00/)

    ozone = &
    (/3.035E+00,3.943E+00,4.889E+00,5.812E+00,6.654E+00,7.308E+00,7.660E+00,7.745E+00, &
      7.696E+00,7.573E+00,7.413E+00,7.246E+00,7.097E+00,6.959E+00,6.797E+00,6.593E+00, &
      6.359E+00,6.110E+00,5.860E+00,5.573E+00,5.253E+00,4.937E+00,4.625E+00,4.308E+00, &
      3.986E+00,3.642E+00,3.261E+00,2.874E+00,2.486E+00,2.102E+00,1.755E+00,1.450E+00, &
      1.208E+00,1.087E+00,1.030E+00,1.005E+00,1.010E+00,1.028E+00,1.068E+00,1.109E+00, &
      1.108E+00,1.071E+00,9.928E-01,8.595E-01,7.155E-01,5.778E-01,4.452E-01,3.372E-01, &
      2.532E-01,1.833E-01,1.328E-01,9.394E-02,6.803E-02,5.152E-02,4.569E-02,4.855E-02, &
      5.461E-02,6.398E-02,7.205E-02,7.839E-02,8.256E-02,8.401E-02,8.412E-02,8.353E-02, &
      8.269E-02,8.196E-02,8.103E-02,7.963E-02,7.741E-02,7.425E-02,7.067E-02,6.702E-02, &
      6.368E-02,6.070E-02,5.778E-02,5.481E-02,5.181E-02,4.920E-02,4.700E-02,4.478E-02, &
      4.207E-02,3.771E-02,3.012E-02,1.941E-02,9.076E-03,2.980E-03,5.117E-03,1.160E-02, &
      1.428E-02,1.428E-02,1.428E-02,1.428E-02/)
  end subroutine dataUsStandardAtmosphere

  SUBROUTINE dataTropical(Level_Pressure, Pressure, Temperature, water_vapor, ozone)
    real, intent(out), dimension(93) :: Level_Pressure 
    real, intent(out), dimension(92) :: Pressure, Temperature, water_vapor, ozone
    ! ...Profile data
    Level_Pressure = &
    (/0.714,   0.975,   1.297,   1.687,   2.153,   2.701,   3.340,   4.077, &
      4.920,   5.878,   6.957,   8.165,   9.512,  11.004,  12.649,  14.456, &
     16.432,  18.585,  20.922,  23.453,  26.183,  29.121,  32.274,  35.650, &
     39.257,  43.100,  47.188,  51.528,  56.126,  60.990,  66.125,  71.540, &
     77.240,  83.231,  89.520,  96.114, 103.017, 110.237, 117.777, 125.646, &
    133.846, 142.385, 151.266, 160.496, 170.078, 180.018, 190.320, 200.989, &
    212.028, 223.441, 235.234, 247.409, 259.969, 272.919, 286.262, 300.000, &
    314.137, 328.675, 343.618, 358.967, 374.724, 390.893, 407.474, 424.470, &
    441.882, 459.712, 477.961, 496.630, 515.720, 535.232, 555.167, 575.525, &
    596.306, 617.511, 639.140, 661.192, 683.667, 706.565, 729.886, 753.627, &
    777.790, 802.371, 827.371, 852.788, 878.620, 904.866, 931.524, 958.591, &
    986.067,1013.948,1042.232,1070.917,1100.000/)

    Pressure = &
    (/0.838,   1.129,   1.484,   1.910,   2.416,   3.009,   3.696,   4.485, &
      5.385,   6.402,   7.545,   8.822,  10.240,  11.807,  13.532,  15.423, &
     17.486,  19.730,  22.163,  24.793,  27.626,  30.671,  33.934,  37.425, &
     41.148,  45.113,  49.326,  53.794,  58.524,  63.523,  68.797,  74.353, &
     80.198,  86.338,  92.778,  99.526, 106.586, 113.965, 121.669, 129.703, &
    138.072, 146.781, 155.836, 165.241, 175.001, 185.121, 195.606, 206.459, &
    217.685, 229.287, 241.270, 253.637, 266.392, 279.537, 293.077, 307.014, &
    321.351, 336.091, 351.236, 366.789, 382.751, 399.126, 415.914, 433.118, &
    450.738, 468.777, 487.236, 506.115, 525.416, 545.139, 565.285, 585.854, &
    606.847, 628.263, 650.104, 672.367, 695.054, 718.163, 741.693, 765.645, &
    790.017, 814.807, 840.016, 865.640, 891.679, 918.130, 944.993, 972.264, &
    999.942,1028.025,1056.510,1085.394/)

    Temperature = &
    (/266.536, 269.608, 270.203, 264.526, 251.578, 240.264, 235.095, 232.959, &
      233.017, 233.897, 234.385, 233.681, 232.436, 231.607, 231.192, 230.808, &
      230.088, 228.603, 226.407, 223.654, 220.525, 218.226, 216.668, 215.107, &
      213.538, 212.006, 210.507, 208.883, 206.793, 204.415, 202.058, 199.718, &
      197.668, 196.169, 194.993, 194.835, 195.648, 196.879, 198.830, 201.091, &
      203.558, 206.190, 208.900, 211.736, 214.601, 217.522, 220.457, 223.334, &
      226.156, 228.901, 231.557, 234.173, 236.788, 239.410, 242.140, 244.953, &
      247.793, 250.665, 253.216, 255.367, 257.018, 258.034, 258.778, 259.454, &
      260.225, 261.251, 262.672, 264.614, 266.854, 269.159, 271.448, 273.673, &
      275.955, 278.341, 280.822, 283.349, 285.826, 288.288, 290.721, 293.135, &
      295.609, 298.173, 300.787, 303.379, 305.960, 308.521, 310.916, 313.647, &
      315.244, 315.244, 315.244, 315.244/)

    water_vapor = &
    (/3.887E-03,3.593E-03,3.055E-03,2.856E-03,2.921E-03,2.555E-03,2.392E-03,2.605E-03, &
      2.573E-03,2.368E-03,2.354E-03,2.333E-03,2.312E-03,2.297E-03,2.287E-03,2.283E-03, &
      2.282E-03,2.286E-03,2.296E-03,2.309E-03,2.324E-03,2.333E-03,2.335E-03,2.335E-03, &
      2.333E-03,2.340E-03,2.361E-03,2.388E-03,2.421E-03,2.458E-03,2.492E-03,2.523E-03, &
      2.574E-03,2.670E-03,2.789E-03,2.944E-03,3.135E-03,3.329E-03,3.530E-03,3.759E-03, &
      4.165E-03,4.718E-03,5.352E-03,6.099E-03,6.845E-03,7.524E-03,8.154E-03,8.381E-03, &
      8.214E-03,8.570E-03,9.672E-03,1.246E-02,1.880E-02,2.720E-02,3.583E-02,4.462E-02, &
      4.548E-02,3.811E-02,3.697E-02,4.440E-02,2.130E-01,6.332E-01,9.945E-01,1.073E+00, &
      1.196E+00,1.674E+00,2.323E+00,2.950E+00,3.557E+00,4.148E+00,4.666E+00,5.092E+00, &
      5.487E+00,5.852E+00,6.137E+00,6.297E+00,6.338E+00,6.234E+00,5.906E+00,5.476E+00, &
      5.176E+00,4.994E+00,4.884E+00,4.832E+00,4.791E+00,4.760E+00,4.736E+00,6.368E+00, &
      7.897E+00,7.673E+00,7.458E+00,7.252E+00/)

    ozone = &
    (/2.742E+00,3.386E+00,4.164E+00,5.159E+00,6.357E+00,7.430E+00,8.174E+00,8.657E+00, &
      8.930E+00,9.056E+00,9.077E+00,8.988E+00,8.778E+00,8.480E+00,8.123E+00,7.694E+00, &
      7.207E+00,6.654E+00,6.060E+00,5.464E+00,4.874E+00,4.299E+00,3.739E+00,3.202E+00, &
      2.688E+00,2.191E+00,1.710E+00,1.261E+00,8.835E-01,5.551E-01,3.243E-01,1.975E-01, &
      1.071E-01,7.026E-02,6.153E-02,5.869E-02,6.146E-02,6.426E-02,6.714E-02,6.989E-02, &
      7.170E-02,7.272E-02,7.346E-02,7.383E-02,7.406E-02,7.418E-02,7.424E-02,7.411E-02, &
      7.379E-02,7.346E-02,7.312E-02,7.284E-02,7.274E-02,7.273E-02,7.272E-02,7.270E-02, &
      7.257E-02,7.233E-02,7.167E-02,7.047E-02,6.920E-02,6.803E-02,6.729E-02,6.729E-02, &
      6.753E-02,6.756E-02,6.717E-02,6.615E-02,6.510E-02,6.452E-02,6.440E-02,6.463E-02, &
      6.484E-02,6.487E-02,6.461E-02,6.417E-02,6.382E-02,6.378E-02,6.417E-02,6.482E-02, &
      6.559E-02,6.638E-02,6.722E-02,6.841E-02,6.944E-02,6.720E-02,6.046E-02,4.124E-02, &
      2.624E-02,2.623E-02,2.622E-02,2.622E-02/)

  end subroutine dataTropical
end module pycrtm