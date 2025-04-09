
!! @file m_data_output.f90
!! @brief Contains module m_data_output

#:include 'macros.fpp'

!> @brief The primary purpose of this module is to output the grid and the
!!              conservative variables data at the chosen time-step interval. In
!!              addition, this module is also in charge of outputting a run-time
!!              information file which summarizes the time-dependent behavior !of
!!              the stability criteria. The latter include the inviscid Courant–
!!              Friedrichs–Lewy (ICFL), viscous CFL (VCFL), capillary CFL (CCFL)
!!              and cell Reynolds (Rc) numbers.
module m_data_output

    use m_derived_types        !< Definitions of the derived types

    use m_global_parameters    !< Definitions of the global parameters

    use m_mpi_proxy            !< Message passing interface (MPI) module proxy

    use m_variables_conversion !< State variables type conversion procedures

    use m_compile_specific

    use m_helper

    use m_sim_helpers

    use m_delay_file_access

    use m_ibm

    implicit none

    private; 
    public :: s_initialize_data_output_module, &
              s_open_run_time_information_file, &
              s_open_com_files, &
              s_open_probe_files, &
              s_write_run_time_information, &
              s_write_data_files, &
              s_write_serial_data_files, &
              s_write_parallel_data_files, &
              s_write_com_files, &
              ! s_write_probe_files, &
              s_close_run_time_information_file, &
              s_close_com_files, &
              s_close_probe_files, &
              s_finalize_data_output_module

    real(wp), allocatable, dimension(:, :, :) :: icfl_sf  !< ICFL stability criterion
    real(wp), allocatable, dimension(:, :, :) :: vcfl_sf  !< VCFL stability criterion
    real(wp), allocatable, dimension(:, :, :) :: ccfl_sf  !< CCFL stability criterion
    real(wp), allocatable, dimension(:, :, :) :: Rc_sf  !< Rc stability criterion
    real(wp), public, allocatable, dimension(:, :) :: c_mass
    !$acc declare create(icfl_sf, vcfl_sf, ccfl_sf, Rc_sf)

    real(wp) :: icfl_max_loc, icfl_max_glb !< ICFL stability extrema on local and global grids
    real(wp) :: vcfl_max_loc, vcfl_max_glb !< VCFL stability extrema on local and global grids
    real(wp) :: ccfl_max_loc, ccfl_max_glb !< CCFL stability extrema on local and global grids
    real(wp) :: Rc_min_loc, Rc_min_glb !< Rc   stability extrema on local and global grids
    !$acc declare create(icfl_max_loc, icfl_max_glb, vcfl_max_loc, vcfl_max_glb, ccfl_max_loc, ccfl_max_glb, Rc_min_loc, Rc_min_glb)

    !> @name ICFL, VCFL, CCFL and Rc stability criteria extrema over all the time-steps
    !> @{
    real(wp) :: icfl_max !< ICFL criterion maximum
    real(wp) :: vcfl_max !< VCFL criterion maximum
    real(wp) :: ccfl_max !< CCFL criterion maximum
    real(wp) :: Rc_min !< Rc criterion maximum
    !> @}

contains

    !> Write data files. Dispatch subroutine that replaces procedure pointer.
        !! @param q_cons_vf Conservative variables
        !! @param q_prim_vf Primitive variables
        !! @param t_step Current time step
    subroutine s_write_data_files(q_cons_vf, q_T_sf, q_prim_vf, t_step, beta)

        type(scalar_field), &
            dimension(sys_size), &
            intent(in) :: q_cons_vf

        type(scalar_field), &
            intent(inout) :: q_T_sf

        type(scalar_field), &
            dimension(sys_size), &
            intent(inout) :: q_prim_vf

        integer, intent(in) :: t_step

        type(scalar_field), &
            intent(inout), optional :: beta

        if (.not. parallel_io) then
            call s_write_serial_data_files(q_cons_vf, q_T_sf, q_prim_vf, t_step, beta)
        else
            call s_write_parallel_data_files(q_cons_vf, q_prim_vf, t_step, beta)
        end if

    end subroutine s_write_data_files

    !>  The purpose of this subroutine is to open a new or pre-
        !!          existing run-time information file and append to it the
        !!      basic header information relevant to current simulation.
        !!      In general, this requires generating a table header for
        !!      those stability criteria which will be written at every
        !!      time-step.
    subroutine s_open_run_time_information_file

        character(LEN=name_len), parameter :: file_name = 'run_time.inf' !<
            !! Name of the run-time information file

        character(LEN=path_len + name_len) :: file_path !<
            !! Relative path to a file in the case directory

        character(LEN=8) :: file_date !<
            !! Creation date of the run-time information file

        ! Opening the run-time information file
        file_path = trim(case_dir)//'/'//trim(file_name)

        open (3, FILE=trim(file_path), &
              FORM='formatted', &
              STATUS='replace')

        write (3, '(A)') 'Description: Stability information at '// &
            'each time-step of the simulation. This'
        write (3, '(13X,A)') 'data is composed of the inviscid '// &
            'Courant–Friedrichs–Lewy (ICFL)'
        write (3, '(13X,A)') 'number, the viscous CFL (VCFL) number, '// &
            'the capillary CFL (CCFL)'
        write (3, '(13X,A)') 'number and the cell Reynolds (Rc) '// &
            'number. Please note that only'
        write (3, '(13X,A)') 'those stability conditions pertinent '// &
            'to the physics included in'
        write (3, '(13X,A)') 'the current computation are displayed.'

        call date_and_time(DATE=file_date)

        write (3, '(A)') 'Date: '//file_date(5:6)//'/'// &
            file_date(7:8)//'/'// &
            file_date(3:4)

        write (3, '(A)') ''; write (3, '(A)') ''

        ! Generating table header for the stability criteria to be outputted
        if (cfl_dt) then
            if (viscous) then
                write (1, '(A)') '     Time-steps        dt     = Time         ICFL '// &
                    'Max      VCFL Max        Rc Min       ='
            else
                write (1, '(A)') '            Time-steps                dt       Time '// &
                    '               ICFL Max              '
            end if
        else
            if (viscous) then
                write (1, '(A)') '     Time-steps        Time         ICFL '// &
                    'Max      VCFL Max        Rc Min        '
            else
                write (1, '(A)') '            Time-steps                Time '// &
                    '               ICFL Max              '
            end if
        end if

    end subroutine s_open_run_time_information_file

    !>  This opens a formatted data file where the root processor
        !!      can write out the CoM information
    subroutine s_open_com_files()

        character(len=path_len + 3*name_len) :: file_path !<
            !! Relative path to the CoM file in the case directory
        integer :: i !< Generic loop iterator

        do i = 1, num_fluids
            ! Generating the relative path to the CoM data file
            write (file_path, '(A,I0,A)') '/fluid', i, '_com.dat'
            file_path = trim(case_dir)//trim(file_path)
            ! Creating the formatted data file and setting up its
            ! structure
            open (i + 120, file=trim(file_path), &
                  form='formatted', &
                  position='append', &
                  status='unknown')
            if (n == 0) then
                write (i + 120, '(A)') '    Non-Dimensional Time '// &
                    '    Total Mass '// &
                    '    x-loc '// &
                    '    Total Volume    '
            elseif (p == 0) then
                write (i + 120, '(A)') '    Non-Dimensional Time '// &
                    '    Total Mass '// &
                    '    x-loc '// &
                    '    y-loc '// &
                    '    Total Volume    '
            else
                write (i + 120, '(A)') '    Non-Dimensional Time '// &
                    '    Total Mass '// &
                    '    x-loc '// &
                    '    y-loc '// &
                    '    z-loc '// &
                    '    Total Volume    '
            end if
        end do
    end subroutine s_open_com_files

    !>  This opens a formatted data file where the root processor
        !!      can write out flow probe information
    subroutine s_open_probe_files

        character(LEN=path_len + 3*name_len) :: file_path !<
            !! Relative path to the probe data file in the case directory

        integer :: i !< Generic loop iterator
        logical :: file_exist

        do i = 1, num_probes
            ! Generating the relative path to the data file
            write (file_path, '(A,I0,A)') '/D/probe', i, '_prim.dat'
            file_path = trim(case_dir)//trim(file_path)

            ! Creating the formatted data file and setting up its
            ! structure
            inquire (file=trim(file_path), exist=file_exist)

            if (file_exist) then
                open (i + 30, FILE=trim(file_path), &
                      FORM='formatted', &
                      STATUS='old', &
                      POSITION='append')
            else
                open (i + 30, FILE=trim(file_path), &
                      FORM='formatted', &
                      STATUS='unknown')
            end if
        end do

        if (integral_wrt) then
            do i = 1, num_integrals
                write (file_path, '(A,I0,A)') '/D/integral', i, '_prim.dat'
                file_path = trim(case_dir)//trim(file_path)

                open (i + 70, FILE=trim(file_path), &
                      FORM='formatted', &
                      POSITION='append', &
                      STATUS='unknown')
            end do
        end if

    end subroutine s_open_probe_files

    !>  The goal of the procedure is to output to the run-time
        !!      information file the stability criteria extrema in the
        !!      entire computational domain and at the given time-step.
        !!      Moreover, the subroutine is also in charge of tracking
        !!      these stability criteria extrema over all time-steps.
        !!  @param q_prim_vf Cell-average primitive variables
        !!  @param t_step Current time step
    subroutine s_write_run_time_information(q_prim_vf, t_step)

        type(scalar_field_half), dimension(sys_size), intent(in) :: q_prim_vf
        integer, intent(in) :: t_step

        real(wp) :: rho        !< Cell-avg. density
        real(wp), dimension(num_dims) :: vel        !< Cell-avg. velocity
        real(wp) :: vel_sum    !< Cell-avg. velocity sum
        real(wp) :: pres       !< Cell-avg. pressure
        real(wp), dimension(num_fluids) :: alpha, alpha_rho, Gs   !< Cell-avg. volume fraction
        real(wp) :: gamma      !< Cell-avg. sp. heat ratio
        real(wp) :: pi_inf     !< Cell-avg. liquid stiffness function
        real(wp) :: c          !< Cell-avg. sound speed
        real(wp) :: H          !< Cell-avg. enthalpy
        real(wp) :: qv, E, G
        real(wp), dimension(2) :: Re         !< Cell-avg. Reynolds numbers
        integer :: i, j, k, l

        ! Computing Stability Criteria at Current Time-step
        !$acc parallel loop collapse(3) gang vector default(present) private(vel, alpha, Re, alpha_rho, Gs)
        do l = 0, p
            do k = 0, n
                do j = 0, m

                    !$acc loop seq
                    do i = 1, num_fluids
                        alpha_rho(i) = q_prim_vf(i)%sf(j, k, l)
                    end do

                    if(num_fluids > 1) then 
                        !$acc loop seq
                        do i = 1, num_fluids - 1
                            alpha(i) = q_prim_vf(E_idx+i)%sf(j, k, l)
                        end do
                        alpha(num_fluids) = 1._wp - sum(alpha(1:num_fluids-1))
                    else
                        if (bubbles_euler) then
                            alpha(1) = q_prim_vf(advxb)%sf(j,k,l) 
                        else
                            alpha(1) = 1._wp
                        end if
                    end if

                    if (elasticity) then
                        call s_convert_species_to_mixture_variables_acc(rho, gamma, pi_inf, qv, alpha, &
                                                                        alpha_rho, Re, j, k, l, G, Gs)
                    elseif (bubbles_euler) then
                        call s_convert_species_to_mixture_variables_bubbles_acc(rho, gamma, pi_inf, qv, alpha, alpha_rho, Re, j, k, l)
                    else
                        call s_convert_species_to_mixture_variables_acc(rho, gamma, pi_inf, qv, alpha, alpha_rho, Re, j, k, l)
                    end if

                    if(igr) then 
                        !$acc loop seq
                        do i = 1, num_dims
                            vel(i) = q_prim_vf(contxe + i)%sf(j, k, l) / rho
                        end do
                    else 
                        !$acc loop seq
                        do i = 1, num_dims
                            vel(i) = q_prim_vf(contxe + i)%sf(j, k, l)
                        end do
                    end if

                    vel_sum = 0._wp
                    !$acc loop seq
                    do i = 1, num_dims
                        vel_sum = vel_sum + vel(i)**2._wp
                    end do

                    if(igr) then 
                        E = q_prim_vf(E_idx)%sf(j, k, l)
                        pres = (E - pi_inf - qv - 5e-1_wp*rho*vel_sum)/gamma
                    else 
                        pres = q_prim_vf(E_idx)%sf(j, k, l)
                        E = gamma*pres + pi_inf + 5e-1_wp*rho*vel_sum + qv
                    end if

                    ! ENERGY ADJUSTMENTS FOR HYPERELASTIC ENERGY
                    if (hyperelasticity) then
                        E = E + G*q_prim_vf(xiend + 1)%sf(j, k, l)
                    end if

                    H = (E + pres)/rho

                    call s_compute_speed_of_sound(pres, rho, gamma, pi_inf, H, alpha, vel_sum, 0._wp, c)

                    if (viscous) then
                        call s_compute_stability_from_dt(vel, c, rho, Re, j, k, l, icfl_sf, vcfl_sf, Rc_sf)
                    else
                        call s_compute_stability_from_dt(vel, c, rho, Re, j, k, l, icfl_sf)
                    end if

                end do
            end do
        end do
        !$acc end parallel loop

        ! end: Computing Stability Criteria at Current Time-step

        ! Determining local stability criteria extrema at current time-step

#ifdef _CRAYFTN
        !$acc update host(icfl_sf)

        if (viscous) then
            !$acc update host(vcfl_sf, Rc_sf)
        end if

        icfl_max_loc = maxval(icfl_sf)

        if (viscous) then
            vcfl_max_loc = maxval(vcfl_sf)
            Rc_min_loc = minval(Rc_sf)
        end if
#else
        !$acc kernels
        icfl_max_loc = maxval(icfl_sf)
        !$acc end kernels

        if (viscous) then
            !$acc kernels
            vcfl_max_loc = maxval(vcfl_sf)
            Rc_min_loc = minval(Rc_sf)
            !$acc end kernels
        end if
#endif

        ! Determining global stability criteria extrema at current time-step
        if (num_procs > 1) then
            call s_mpi_reduce_stability_criteria_extrema(icfl_max_loc, &
                                                         vcfl_max_loc, &
                                                         ccfl_max_loc, &
                                                         Rc_min_loc, &
                                                         icfl_max_glb, &
                                                         vcfl_max_glb, &
                                                         ccfl_max_glb, &
                                                         Rc_min_glb)
        else
            icfl_max_glb = icfl_max_loc
            if (viscous) vcfl_max_glb = vcfl_max_loc
            if (viscous) Rc_min_glb = Rc_min_loc
        end if

        ! Determining the stability criteria extrema over all the time-steps
        if (icfl_max_glb > icfl_max) icfl_max = icfl_max_glb

        if (viscous) then
            if (vcfl_max_glb > vcfl_max) vcfl_max = vcfl_max_glb
            if (Rc_min_glb < Rc_min) Rc_min = Rc_min_glb
        end if

        ! Outputting global stability criteria extrema at current time-step
        if (proc_rank == 0) then
            if (viscous) then
                write (1, '(6X,I8,F10.6,6X,6X,F10.6,6X,F9.6,6X,F9.6,6X,F10.6)') &
                    t_step, dt, t_step*dt, icfl_max_glb, &
                    vcfl_max_glb, &
                    Rc_min_glb
            else
                write (1, '(13X,I8,14X,F10.6,14X,F10.6,13X,F9.6)') &
                    t_step, dt, t_step*dt, icfl_max_glb
            end if

            if (icfl_max_glb /= icfl_max_glb) then
                call s_mpi_abort('ICFL is NaN. Exiting.')
            elseif (icfl_max_glb > 1._wp) then
                print *, 'icfl', icfl_max_glb
                call s_mpi_abort('ICFL is greater than 1.0. Exiting.')
            end if

            if (viscous) then
                if (vcfl_max_glb /= vcfl_max_glb) then
                    call s_mpi_abort('VCFL is NaN. Exiting.')
                elseif (vcfl_max_glb > 1._wp) then
                    print *, 'vcfl', vcfl_max_glb
                    call s_mpi_abort('VCFL is greater than 1.0. Exiting.')
                end if
            end if
        end if

        call s_mpi_barrier()

    end subroutine s_write_run_time_information

    !>  The goal of this subroutine is to output the grid and
        !!      conservative variables data files for given time-step.
        !!  @param q_cons_vf Cell-average conservative variables
        !!  @param q_prim_vf Cell-average primitive variables
        !!  @param t_step Current time-step
    subroutine s_write_serial_data_files(q_cons_vf, q_T_sf, q_prim_vf, t_step, beta)

        type(scalar_field), dimension(sys_size), intent(in) :: q_cons_vf
        type(scalar_field), intent(inout) :: q_T_sf
        type(scalar_field), dimension(sys_size), intent(inout) :: q_prim_vf
        integer, intent(in) :: t_step
        type(scalar_field), intent(inout), optional :: beta

        character(LEN=path_len + 2*name_len) :: t_step_dir !<
            !! Relative path to the current time-step directory

        character(LEN=path_len + 3*name_len) :: file_path !<
            !! Relative path to the grid and conservative variables data files

        logical :: file_exist !<
            !! Logical used to check existence of current time-step directory

        character(LEN=15) :: FMT

        integer :: i, j, k, l, r

        real(wp) :: gamma, lit_gamma, pi_inf, qv !< Temporary EOS params

        ! Creating or overwriting the time-step root directory
        write (t_step_dir, '(A,I0,A,I0)') trim(case_dir)//'/p_all'

        ! Creating or overwriting the current time-step directory
        write (t_step_dir, '(a,i0,a,i0)') trim(case_dir)//'/p_all/p', &
            proc_rank, '/', t_step

        file_path = trim(t_step_dir)//'/.'
        call my_inquire(file_path, file_exist)
        if (file_exist) call s_delete_directory(trim(t_step_dir))
        call s_create_directory(trim(t_step_dir))

        ! Writing the grid data file in the x-direction
        file_path = trim(t_step_dir)//'/x_cb.dat'

        open (2, FILE=trim(file_path), &
              FORM='unformatted', &
              STATUS='new')
        write (2) x_cb(-1:m); close (2)

        ! Writing the grid data files in the y- and z-directions
        if (n > 0) then

            file_path = trim(t_step_dir)//'/y_cb.dat'

            open (2, FILE=trim(file_path), &
                  FORM='unformatted', &
                  STATUS='new')
            write (2) y_cb(-1:n); close (2)

            if (p > 0) then

                file_path = trim(t_step_dir)//'/z_cb.dat'

                open (2, FILE=trim(file_path), &
                      FORM='unformatted', &
                      STATUS='new')
                write (2) z_cb(-1:p); close (2)

            end if

        end if

        ! Writing the conservative variables data files
        do i = 1, sys_size
            write (file_path, '(A,I0,A)') trim(t_step_dir)//'/q_cons_vf', &
                i, '.dat'

            open (2, FILE=trim(file_path), &
                  FORM='unformatted', &
                  STATUS='new')

            write (2) q_cons_vf(i)%sf(0:m, 0:n, 0:p); close (2)
        end do

        if (qbmm .and. .not. polytropic) then
            do i = 1, nb
                do r = 1, nnode
                    write (file_path, '(A,I0,A)') trim(t_step_dir)//'/pb', &
                        sys_size + (i - 1)*nnode + r, '.dat'

                    open (2, FILE=trim(file_path), &
                          FORM='unformatted', &
                          STATUS='new')

                    write (2) pb_ts(1)%sf(0:m, 0:n, 0:p, r, i); close (2)
                end do
            end do

            do i = 1, nb
                do r = 1, nnode
                    write (file_path, '(A,I0,A)') trim(t_step_dir)//'/mv', &
                        sys_size + (i - 1)*nnode + r, '.dat'

                    open (2, FILE=trim(file_path), &
                          FORM='unformatted', &
                          STATUS='new')

                    write (2) mv_ts(1)%sf(0:m, 0:n, 0:p, r, i); close (2)
                end do
            end do
        end if

        ! Writing the IB markers
        if (ib) then
            write (file_path, '(A,I0,A)') trim(t_step_dir)//'/ib.dat'

            open (2, FILE=trim(file_path), &
                  FORM='unformatted', &
                  STATUS='new')

            write (2) ib_markers%sf; close (2)
        end if

        gamma = fluid_pp(1)%gamma
        lit_gamma = 1._wp/fluid_pp(1)%gamma + 1._wp
        pi_inf = fluid_pp(1)%pi_inf
        qv = fluid_pp(1)%qv

        if (precision == 1) then
            FMT = "(2F30.3)"
        else
            FMT = "(2F40.14)"
        end if

        ! writing an output directory
        write (t_step_dir, '(A,I0,A,I0)') trim(case_dir)//'/D'
        file_path = trim(t_step_dir)//'/.'

        inquire (FILE=trim(file_path), EXIST=file_exist)

        if (.not. file_exist) call s_create_directory(trim(t_step_dir))

        if ((prim_vars_wrt .or. (n == 0 .and. p == 0)) .and. (.not. igr)) then
            call s_convert_conservative_to_primitive_variables(q_cons_vf, q_T_sf, q_prim_vf, idwint)
            do i = 1, sys_size
                !$acc update host(q_prim_vf(i)%sf(:,:,:))
            end do
            ! q_prim_vf(bubxb) stores the value of nb needed in riemann solvers, so replace with true primitive value (=1._wp)
            if (qbmm) then
                q_prim_vf(bubxb)%sf = 1._wp
            end if
        end if

        !1D
        if (n == 0 .and. p == 0) then

            if (model_eqns == 2 .and. (.not. igr)) then
                do i = 1, sys_size
                    write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/prim.', i, '.', proc_rank, '.', t_step, '.dat'

                    open (2, FILE=trim(file_path))
                    do j = 0, m
                        ! todo: revisit change here
                        if (((i >= adv_idx%beg) .and. (i <= adv_idx%end))) then
                            write (2, FMT) x_cb(j), q_cons_vf(i)%sf(j, 0, 0)
                        else
                            write (2, FMT) x_cb(j), q_prim_vf(i)%sf(j, 0, 0)
                        end if
                    end do
                    close (2)
                end do
            end if

            do i = 1, sys_size
                write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/cons.', i, '.', proc_rank, '.', t_step, '.dat'

                open (2, FILE=trim(file_path))
                do j = 0, m
                    write (2, FMT) x_cb(j), q_cons_vf(i)%sf(j, 0, 0)
                end do
                close (2)
            end do

            if (qbmm .and. .not. polytropic) then
                do i = 1, nb
                    do r = 1, nnode
                        write (file_path, '(A,I0,A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/pres.', i, '.', r, '.', proc_rank, '.', t_step, '.dat'

                        open (2, FILE=trim(file_path))
                        do j = 0, m
                            write (2, FMT) x_cb(j), pb_ts(1)%sf(j, 0, 0, r, i)
                        end do
                        close (2)
                    end do
                end do
                do i = 1, nb
                    do r = 1, nnode
                        write (file_path, '(A,I0,A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/mv.', i, '.', r, '.', proc_rank, '.', t_step, '.dat'

                        open (2, FILE=trim(file_path))
                        do j = 0, m
                            write (2, FMT) x_cb(j), mv_ts(1)%sf(j, 0, 0, r, i)
                        end do
                        close (2)
                    end do
                end do
            end if
        end if

        if (precision == 1) then
            FMT = "(3F30.7)"
        else
            FMT = "(3F40.14)"
        end if

        ! 2D
        if ((n > 0) .and. (p == 0)) then
            do i = 1, sys_size
                write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/cons.', i, '.', proc_rank, '.', t_step, '.dat'
                open (2, FILE=trim(file_path))
                do j = 0, m
                    do k = 0, n
                        write (2, FMT) x_cb(j), y_cb(k), q_cons_vf(i)%sf(j, k, 0)
                    end do
                    write (2, *)
                end do
                close (2)
            end do

            if (present(beta)) then
                write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/beta.', i, '.', proc_rank, '.', t_step, '.dat'
                open (2, FILE=trim(file_path))
                do j = 0, m
                    do k = 0, n
                        write (2, FMT) x_cb(j), y_cb(k), beta%sf(0:m, 0:n, 0)
                    end do
                    write (2, *)
                end do
                close (2)
            end if

            if (qbmm .and. .not. polytropic) then
                do i = 1, nb
                    do r = 1, nnode
                        write (file_path, '(A,I0,A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/pres.', i, '.', r, '.', proc_rank, '.', t_step, '.dat'

                        open (2, FILE=trim(file_path))
                        do j = 0, m
                            do k = 0, n
                                write (2, FMT) x_cb(j), y_cb(k), pb_ts(1)%sf(j, k, 0, r, i)
                            end do
                        end do
                        close (2)
                    end do
                end do
                do i = 1, nb
                    do r = 1, nnode
                        write (file_path, '(A,I0,A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/mv.', i, '.', r, '.', proc_rank, '.', t_step, '.dat'

                        open (2, FILE=trim(file_path))
                        do j = 0, m
                            do k = 0, n
                                write (2, FMT) x_cb(j), y_cb(k), mv_ts(1)%sf(j, k, 0, r, i)
                            end do
                        end do
                        close (2)
                    end do
                end do
            end if

            if (prim_vars_wrt .and. (.not. igr)) then
                do i = 1, sys_size
                    write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/prim.', i, '.', proc_rank, '.', t_step, '.dat'

                    open (2, FILE=trim(file_path))

                    do j = 0, m
                        do k = 0, n
                            if (((i >= cont_idx%beg) .and. (i <= cont_idx%end)) &
                                .or. &
                                ((i >= adv_idx%beg) .and. (i <= adv_idx%end)) &
                                .or. &
                                ((i >= chemxb) .and. (i <= chemxe)) &
                                ) then
                                write (2, FMT) x_cb(j), y_cb(k), q_cons_vf(i)%sf(j, k, 0)
                            else
                                write (2, FMT) x_cb(j), y_cb(k), q_prim_vf(i)%sf(j, k, 0)
                            end if
                        end do
                        write (2, *)
                    end do
                    close (2)
                end do
            end if
        end if

        if (precision == 1) then
            FMT = "(4F30.7)"
        else
            FMT = "(4F40.14)"
        end if

        ! 3D
        if (p > 0) then
            do i = 1, sys_size
                write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/cons.', i, '.', proc_rank, '.', t_step, '.dat'
                open (2, FILE=trim(file_path))
                do j = 0, m
                    do k = 0, n
                        do l = 0, p
                            write (2, FMT) x_cb(j), y_cb(k), z_cb(l), q_cons_vf(i)%sf(j, k, l)
                        end do
                        write (2, *)
                    end do
                    write (2, *)
                end do
                close (2)
            end do

            if (present(beta)) then
                write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/beta.', i, '.', proc_rank, '.', t_step, '.dat'
                open (2, FILE=trim(file_path))
                do j = 0, m
                    do k = 0, n
                        do l = 0, p
                            write (2, FMT) x_cb(j), y_cb(k), z_cb(l), beta%sf(j, k, l)
                        end do
                        write (2, *)
                    end do
                    write (2, *)
                end do
                close (2)
            end if

            if (qbmm .and. .not. polytropic) then
                do i = 1, nb
                    do r = 1, nnode
                        write (file_path, '(A,I0,A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/pres.', i, '.', r, '.', proc_rank, '.', t_step, '.dat'

                        open (2, FILE=trim(file_path))
                        do j = 0, m
                            do k = 0, n
                                do l = 0, p
                                    write (2, FMT) x_cb(j), y_cb(k), z_cb(l), pb_ts(1)%sf(j, k, l, r, i)
                                end do
                            end do
                        end do
                        close (2)
                    end do
                end do
                do i = 1, nb
                    do r = 1, nnode
                        write (file_path, '(A,I0,A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/mv.', i, '.', r, '.', proc_rank, '.', t_step, '.dat'

                        open (2, FILE=trim(file_path))
                        do j = 0, m
                            do k = 0, n
                                do l = 0, p
                                    write (2, FMT) x_cb(j), y_cb(k), z_cb(l), mv_ts(1)%sf(j, k, l, r, i)
                                end do
                            end do
                        end do
                        close (2)
                    end do
                end do
            end if

            if (prim_vars_wrt .and. (.not. igr)) then
                do i = 1, sys_size
                    write (file_path, '(A,I0,A,I2.2,A,I6.6,A)') trim(t_step_dir)//'/prim.', i, '.', proc_rank, '.', t_step, '.dat'

                    open (2, FILE=trim(file_path))

                    do j = 0, m
                        do k = 0, n
                            do l = 0, p
                                if (((i >= cont_idx%beg) .and. (i <= cont_idx%end)) &
                                    .or. &
                                    ((i >= adv_idx%beg) .and. (i <= adv_idx%end)) &
                                    .or. &
                                    ((i >= chemxb) .and. (i <= chemxe)) &
                                    ) then
                                    write (2, FMT) x_cb(j), y_cb(k), z_cb(l), q_cons_vf(i)%sf(j, k, l)
                                else
                                    write (2, FMT) x_cb(j), y_cb(k), z_cb(l), q_prim_vf(i)%sf(j, k, l)
                                end if
                            end do
                            write (2, *)
                        end do
                        write (2, *)
                    end do
                    close (2)
                end do
            end if
        end if

    end subroutine s_write_serial_data_files

    !>  The goal of this subroutine is to output the grid and
        !!      conservative variables data files for given time-step.
        !!  @param q_cons_vf Cell-average conservative variables
        !!  @param q_prim_vf Cell-average primitive variables
        !!  @param t_step Current time-step
        !!  @param beta Eulerian void fraction from lagrangian bubbles
    subroutine s_write_parallel_data_files(q_cons_vf, q_prim_vf, t_step, beta)

        type(scalar_field), dimension(sys_size), intent(in) :: q_cons_vf
        type(scalar_field), dimension(sys_size), intent(inout) :: q_prim_vf
        integer, intent(in) :: t_step
        type(scalar_field), intent(inout), optional :: beta

#ifdef MFC_MPI

        integer :: ifile, ierr, data_size
        integer, dimension(MPI_STATUS_SIZE) :: status
        integer(kind=MPI_OFFSET_kind) :: disp
        integer(kind=MPI_OFFSET_kind) :: m_MOK, n_MOK, p_MOK
        integer(kind=MPI_OFFSET_kind) :: WP_MOK, var_MOK, str_MOK
        integer(kind=MPI_OFFSET_kind) :: NVARS_MOK
        integer(kind=MPI_OFFSET_kind) :: MOK

        character(LEN=path_len + 2*name_len) :: file_loc
        logical :: file_exist, dir_check
        character(len=10) :: t_step_string

        integer :: i !< Generic loop iterator

        integer :: alt_sys !< Altered system size for the lagrangian subgrid bubble model

        if (present(beta)) then
            alt_sys = sys_size + 1
        else
            alt_sys = sys_size
        end if

        if (file_per_process) then

            call s_int_to_str(t_step, t_step_string)

            ! Initialize MPI data I/O

            if (ib) then
                call s_initialize_mpi_data(q_cons_vf, ib_markers, levelset, levelset_norm)
            else
                call s_initialize_mpi_data(q_cons_vf)
            end if

            if (proc_rank == 0) then
                file_loc = trim(case_dir)//'/restart_data/lustre_'//trim(t_step_string)
                call my_inquire(file_loc, dir_check)
                if (dir_check .neqv. .true.) then
                    call s_create_directory(trim(file_loc))
                end if
                call s_create_directory(trim(file_loc))
            end if
            call s_mpi_barrier()
            call DelayFileAccess(proc_rank)

            ! Initialize MPI data I/O
            call s_initialize_mpi_data(q_cons_vf)

            ! Open the file to write all flow variables
            write (file_loc, '(I0,A,i7.7,A)') t_step, '_', proc_rank, '.dat'
            file_loc = trim(case_dir)//'/restart_data/lustre_'//trim(t_step_string)//trim(mpiiofs)//trim(file_loc)
            inquire (FILE=trim(file_loc), EXIST=file_exist)
            if (file_exist .and. proc_rank == 0) then
                call MPI_FILE_DELETE(file_loc, mpi_info_int, ierr)
            end if
            call MPI_FILE_OPEN(MPI_COMM_SELF, file_loc, ior(MPI_MODE_WRONLY, MPI_MODE_CREATE), &
                               mpi_info_int, ifile, ierr)

            ! Size of local arrays
            data_size = (m + 1)*(n + 1)*(p + 1)

            ! Resize some integers so MPI can write even the biggest files
            m_MOK = int(m_glb + 1, MPI_OFFSET_KIND)
            n_MOK = int(n_glb + 1, MPI_OFFSET_KIND)
            p_MOK = int(p_glb + 1, MPI_OFFSET_KIND)
            WP_MOK = int(8._wp, MPI_OFFSET_KIND)
            MOK = int(1._wp, MPI_OFFSET_KIND)
            str_MOK = int(name_len, MPI_OFFSET_KIND)
            NVARS_MOK = int(sys_size, MPI_OFFSET_KIND)

            if (bubbles_euler) then
                ! Write the data for each variable
                do i = 1, sys_size
                    var_MOK = int(i, MPI_OFFSET_KIND)

                    call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(i)%sf, data_size, &
                                            mpi_p, status, ierr)
                end do
                !Write pb and mv for non-polytropic qbmm
                if (qbmm .and. .not. polytropic) then
                    do i = sys_size + 1, sys_size + 2*nb*nnode
                        var_MOK = int(i, MPI_OFFSET_KIND)

                        call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(i)%sf, data_size, &
                                                mpi_p, status, ierr)
                    end do
                end if
            else
                do i = 1, sys_size !TODO: check if correct (sys_size
                    var_MOK = int(i, MPI_OFFSET_KIND)

                    call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(i)%sf, data_size, &
                                            mpi_p, status, ierr)
                end do
            end if

            call MPI_FILE_CLOSE(ifile, ierr)
        else
            ! Initialize MPI data I/O

            if (ib) then
                call s_initialize_mpi_data(q_cons_vf, ib_markers, levelset, levelset_norm)
            elseif (present(beta)) then
                call s_initialize_mpi_data(q_cons_vf, beta=beta)
            else
                call s_initialize_mpi_data(q_cons_vf)
            end if

            write (file_loc, '(I0,A)') t_step, '.dat'
            file_loc = trim(case_dir)//'/restart_data'//trim(mpiiofs)//trim(file_loc)
            inquire (FILE=trim(file_loc), EXIST=file_exist)
            if (file_exist .and. proc_rank == 0) then
                call MPI_FILE_DELETE(file_loc, mpi_info_int, ierr)
            end if
            call MPI_FILE_OPEN(MPI_COMM_WORLD, file_loc, ior(MPI_MODE_WRONLY, MPI_MODE_CREATE), &
                               mpi_info_int, ifile, ierr)

            ! Size of local arrays
            data_size = (m + 1)*(n + 1)*(p + 1)

            ! Resize some integers so MPI can write even the biggest files
            m_MOK = int(m_glb + 1, MPI_OFFSET_KIND)
            n_MOK = int(n_glb + 1, MPI_OFFSET_KIND)
            p_MOK = int(p_glb + 1, MPI_OFFSET_KIND)
            WP_MOK = int(8._wp, MPI_OFFSET_KIND)
            MOK = int(1._wp, MPI_OFFSET_KIND)
            str_MOK = int(name_len, MPI_OFFSET_KIND)
            NVARS_MOK = int(alt_sys, MPI_OFFSET_KIND)

            if (bubbles_euler) then
                ! Write the data for each variable
                do i = 1, sys_size
                    var_MOK = int(i, MPI_OFFSET_KIND)

                    ! Initial displacement to skip at beginning of file
                    disp = m_MOK*max(MOK, n_MOK)*max(MOK, p_MOK)*WP_MOK*(var_MOK - 1)

                    call MPI_FILE_SET_VIEW(ifile, disp, mpi_p, MPI_IO_DATA%view(i), &
                                           'native', mpi_info_int, ierr)
                    call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(i)%sf, data_size, &
                                            mpi_p, status, ierr)
                end do
                !Write pb and mv for non-polytropic qbmm
                if (qbmm .and. .not. polytropic) then
                    do i = sys_size + 1, sys_size + 2*nb*nnode
                        var_MOK = int(i, MPI_OFFSET_KIND)

                        ! Initial displacement to skip at beginning of file
                        disp = m_MOK*max(MOK, n_MOK)*max(MOK, p_MOK)*WP_MOK*(var_MOK - 1)

                        call MPI_FILE_SET_VIEW(ifile, disp, mpi_p, MPI_IO_DATA%view(i), &
                                               'native', mpi_info_int, ierr)
                        call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(i)%sf, data_size, &
                                                mpi_p, status, ierr)
                    end do
                end if
            else
                do i = 1, sys_size !TODO: check if correct (sys_size
                    var_MOK = int(i, MPI_OFFSET_KIND)

                    ! Initial displacement to skip at beginning of file
                    disp = m_MOK*max(MOK, n_MOK)*max(MOK, p_MOK)*WP_MOK*(var_MOK - 1)

                    call MPI_FILE_SET_VIEW(ifile, disp, mpi_p, MPI_IO_DATA%view(i), &
                                           'native', mpi_info_int, ierr)
                    call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(i)%sf, data_size, &
                                            mpi_p, status, ierr)
                end do
            end if

            ! Correction for the lagrangian subgrid bubble model
            if (present(beta)) then
                var_MOK = int(sys_size + 1, MPI_OFFSET_KIND)

                ! Initial displacement to skip at beginning of file
                disp = m_MOK*max(MOK, n_MOK)*max(MOK, p_MOK)*WP_MOK*(var_MOK - 1)

                call MPI_FILE_SET_VIEW(ifile, disp, mpi_p, MPI_IO_DATA%view(sys_size + 1), &
                                       'native', mpi_info_int, ierr)
                call MPI_FILE_WRITE_ALL(ifile, MPI_IO_DATA%var(sys_size + 1)%sf, data_size, &
                                        mpi_p, status, ierr)
            end if

            call MPI_FILE_CLOSE(ifile, ierr)
        end if

#endif

    end subroutine s_write_parallel_data_files

    !>  This writes a formatted data file where the root processor
    !!      can write out the CoM information
    !!  @param t_step Current time-step
    !!  @param q_com Center of mass information
    !!  @param moments Higher moment information
    subroutine s_write_com_files(t_step, c_mass)

        integer, intent(in) :: t_step
        real(wp), dimension(num_fluids, 5), intent(in) :: c_mass
        integer :: i, j !< Generic loop iterator
        real(wp) :: nondim_time !< Non-dimensional time

        ! Non-dimensional time calculation
        if (t_step_old /= dflt_int) then
            nondim_time = real(t_step + t_step_old, wp)*dt
        else
            nondim_time = real(t_step, wp)*dt
        end if

        if (proc_rank == 0) then
            if (n == 0) then ! 1D simulation
                do i = 1, num_fluids ! Loop through fluids
                    write (i + 120, '(6X,4F24.12)') &
                        nondim_time, &
                        c_mass(i, 1), &
                        c_mass(i, 2), &
                        c_mass(i, 5)
                end do
            elseif (p == 0) then ! 2D simulation
                do i = 1, num_fluids ! Loop through fluids
                    write (i + 120, '(6X,5F24.12)') &
                        nondim_time, &
                        c_mass(i, 1), &
                        c_mass(i, 2), &
                        c_mass(i, 3), &
                        c_mass(i, 5)
                end do
            else ! 3D simulation
                do i = 1, num_fluids ! Loop through fluids
                    write (i + 120, '(6X,6F24.12)') &
                        nondim_time, &
                        c_mass(i, 1), &
                        c_mass(i, 2), &
                        c_mass(i, 3), &
                        c_mass(i, 4), &
                        c_mass(i, 5)
                end do
            end if
        end if

    end subroutine s_write_com_files


    !>  The goal of this subroutine is to write to the run-time
        !!      information file basic footer information applicable to
        !!      the current computation and to close the file when done.
        !!      The footer contains the stability criteria extrema over
        !!      all of the time-steps and the simulation run-time.
    subroutine s_close_run_time_information_file

        real(wp) :: run_time !< Run-time of the simulation

        ! Writing the footer of and closing the run-time information file
        write (3, '(A)') '    '
        write (3, '(A)') ''

        write (3, '(A,F9.6)') 'ICFL Max: ', icfl_max
        if (viscous) write (3, '(A,F9.6)') 'VCFL Max: ', vcfl_max
        if (viscous) write (3, '(A,F10.6)') 'Rc Min: ', Rc_min

        call cpu_time(run_time)

        write (3, '(A)') ''
        write (3, '(A,I0,A)') 'Run-time: ', int(anint(run_time)), 's'
        write (3, '(A)') '    '
        close (3)

    end subroutine s_close_run_time_information_file

    !> Closes communication files
    subroutine s_close_com_files()

        integer :: i !< Generic loop iterator
        do i = 1, num_fluids
            close (i + 120)
        end do

    end subroutine s_close_com_files

    !> Closes probe files
    subroutine s_close_probe_files

        integer :: i !< Generic loop iterator

        do i = 1, num_probes
            close (i + 30)
        end do

    end subroutine s_close_probe_files

    !>  The computation of parameters, the allocation of memory,
        !!      the association of pointers and/or the execution of any
        !!      other procedures that are necessary to setup the module.
    subroutine s_initialize_data_output_module

        ! Allocating/initializing ICFL, VCFL, CCFL and Rc stability criteria
        if(run_time_info)then 
            @:ALLOCATE(icfl_sf(0:m, 0:n, 0:p))
            icfl_max = 0._wp
        end if

        if (probe_wrt) then
            @:ALLOCATE(c_mass(num_fluids,5))
        end if

        if(run_time_info) then 
            if (viscous) then
                @:ALLOCATE(vcfl_sf(0:m, 0:n, 0:p))
                @:ALLOCATE(Rc_sf  (0:m, 0:n, 0:p))

                vcfl_max = 0._wp
                Rc_min = 1e3_wp
            end if
        end if

    end subroutine s_initialize_data_output_module

    !> Module deallocation and/or disassociation procedures
    subroutine s_finalize_data_output_module

        if (probe_wrt) then
            @:DEALLOCATE(c_mass)
        end if

        if(run_time_info) then 
            ! Deallocating the ICFL, VCFL, CCFL, and Rc stability criteria
            @:DEALLOCATE(icfl_sf)
            if (viscous) then
                @:DEALLOCATE(vcfl_sf, Rc_sf)
            end if
        end if

    end subroutine s_finalize_data_output_module

end module m_data_output
