!>
!! @file m_boundary_conditions.fpp
!! @brief Contains module m_boundary_conditions

#:include 'macros.fpp'
#:include 'inline_boundary_conditions.fpp'

!> @brief The purpose of the module is to apply noncharacteristic and processor
!! boundary condiitons
module m_boundary_conditions

    use m_derived_types        !< Definitions of the derived types

    use m_global_parameters    !< Definitions of the global parameters

    use m_mpi_proxy

    use m_constants

    use m_variables_conversion

    implicit none

    type(scalar_field), dimension(:,:), allocatable :: bc_buffers
    !$acc declare create(bc_buffers)

    real(wp) :: bcxb, bcxe, bcyb, bcye, bczb, bcze

    private; public :: s_populate_variables_buffers, &
              s_populate_capillary_buffers, &
              s_initialize_boundary_conditions_module, &
              s_read_boundary_condition_files, &
              s_finalize_boundary_conditions_module

contains

    subroutine s_initialize_boundary_conditions_module()

        bcxb = bc_x%beg; bcxe = bc_x%end; bcyb = bc_y%beg; bcye = bc_y%end; bczb = bc_z%beg; bcze = bc_z%end

        @:ALLOCATE(bc_buffers(1:num_dims, -1:1))

        @:ALLOCATE(bc_buffers(1, -1)%sf(1:sys_size, 0:n, 0:p))
        @:ALLOCATE(bc_buffers(1, 1)%sf(1:sys_size, 0:n, 0:p))
        @:ACC_SETUP_SFs(bc_buffers(1,-1), bc_buffers(1,1))
        if (n > 0) then
            @:ALLOCATE(bc_buffers(2,-1)%sf(-buff_size:m+buff_size,1:sys_size,0:p))
            @:ALLOCATE(bc_buffers(2,1)%sf(-buff_size:m+buff_size,1:sys_size,0:p))
            @:ACC_SETUP_SFs(bc_buffers(2,-1), bc_buffers(2,1))
            if (p > 0) then
                @:ALLOCATE(bc_buffers(3,-1)%sf(-buff_size:m+buff_size,-buff_size:n+buff_size,1:sys_size))
                @:ALLOCATE(bc_buffers(3,1)%sf(-buff_size:m+buff_size,-buff_size:n+buff_size,1:sys_size))
                @:ACC_SETUP_SFs(bc_buffers(3,-1), bc_buffers(3,1))
            end if
        end if

    end subroutine s_initialize_boundary_conditions_module

    subroutine s_populate_variables_buffers(q_prim_vf, pb, mv, bc_type)

        type(scalar_field), dimension(sys_size), intent(inout) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1), intent(in) :: bc_type
        real(wp), dimension(startx:, starty:, startz:, 1:, 1:), intent(inout) :: pb, mv

        integer :: i, j, k, l, q

        !< x-direction
        if (bcxb >= 0) then
            call s_mpi_sendrecv_variables_buffers(q_prim_vf, pb, mv, 1, -1)
        else
            !$acc parallel loop collapse(2) gang vector default(present)
            do l = 0, p
                do k = 0, n
                    if (bc_type(1,-1)%sf(0,k,l) >= -13 .and. bc_type(1,-1)%sf(0,k,l) <= -3) then
                        ${PRIM_GHOST_CELL_EXTRAPOLATION_BC("-j,k,l","0,k,l")}$
                    elseif (bc_type(1,-1)%sf(0,k,l) == -2) then
                        ${PRIM_SYMMETRY_BC(1,"-j,k,l","j-1,k,l")}$
                    elseif (bc_type(1,-1)%sf(0,k,l) == -1) then
                        ${PRIM_PERIODIC_BC("-j,k,l","m-(j-1),k,l")}$
                    elseif (bc_type(1,-1)%sf(0,k,l) == -15) then
                        ${PRIM_SLIP_WALL_BC("x","L")}$
                    elseif (bc_type(1,-1)%sf(0,k,l) == -16) then
                        ${PRIM_NO_SLIP_WALL_BC("x","L")}$
                    elseif (bc_type(1,-1)%sf(0,k,l) == -17) then
                        ${PRIM_DIRICHLET_BC(1,-1,"-j,k,l","i,k,l")}$
                    end if
                end do
            end do
        end if

        if (bcxe >= 0) then
            call s_mpi_sendrecv_variables_buffers(q_prim_vf, pb, mv, 1, 1)
        else
            !$acc parallel loop collapse(2) gang vector default(present)
            do l = 0, p
                do k = 0, n
                    if (bc_type(1,1)%sf(0,k,l) >= -13 .and. bc_type(1,1)%sf(0,k,l) <= -3) then
                        ${PRIM_GHOST_CELL_EXTRAPOLATION_BC("m+j,k,l","m,k,l")}$
                    elseif (bc_type(1,1)%sf(0,k,l) == -2) then
                        ${PRIM_SYMMETRY_BC(1,"m+j,k,l","m - (j-1),k,l")}$
                    elseif (bc_type(1,1)%sf(0,k,l) == -1) then
                        ${PRIM_PERIODIC_BC("m+j,k,l","j-1,k,l")}$
                    elseif (bc_type(1,1)%sf(0,k,l) == -15) then
                        ${PRIM_SLIP_WALL_BC("x","R")}$
                    elseif (bc_type(1,1)%sf(0,k,l) == -16) then
                        ${PRIM_NO_SLIP_WALL_BC("x","R")}$
                    elseif (bc_type(1,1)%sf(0,k,l) == -17) then
                        ${PRIM_DIRICHLET_BC(1,1,"m+j,k,l","i,k,l")}$
                    end if
                end do
            end do
        end if

        if (qbmm .and. (.not. polytropic)) then
            if (bcxb < 0) then
                !$acc parallel loop collapse(2) gang vector default(present)
                do l = 0, p
                    do k = 0, n
                        if (bc_type(1,-1)%sf(0,k,l) >= -13 .and. bc_type(1,-1)%sf(0,k,l) <= -3) then
                            ${QBMM_BC("-j,k,l,q,i","0,k,l,q,i")}$
                        elseif (bc_type(1,-1)%sf(0,k,l) == -2) then
                            ${QBMM_BC("-j,k,l,q,i","j-1,k,l,q,i")}$
                        elseif (bc_type(1,-1)%sf(0,k,l) == -1) then
                            ${QBMM_BC("-j,k,l,q,i","m - (j-1),k,l,q,i")}$
                        end if
                    end do
                end do
            end if

            if (bcxe < 0) then
                !$acc parallel loop collapse(2) gang vector default(present)
                do l = 0, p
                    do k = 0, n
                        if (bc_type(1,1)%sf(0,k,l) >= -13 .and. bc_type(1,1)%sf(0,k,l) <= -3) then
                            ${QBMM_BC("m+j,k,l,q,i","m,k,l,q,i")}$
                        elseif (bc_type(1,1)%sf(0,k,l) == -2) then
                            ${QBMM_BC("m+j,k,l,q,i","m - (j-1),k,l,q,i")}$
                        elseif (bc_type(1,1)%sf(0,k,l) == -1) then
                            ${QBMM_BC("m+j,k,l,q,i","j-1,k,l,q,i")}$
                        end if
                    end do
                end do
            end if
        end if

        if (n == 0) return
        print*, bcyb, bcye
        !< y-direction
        if (bcyb >= 0) then
            call s_mpi_sendrecv_variables_buffers(q_prim_vf, pb, mv, 2, -1)
        elseif (bcyb == -14) then
            !$acc parallel loop collapse(3) gang vector default(present)
            do k = 0, p
                do j = 1, buff_size
                    do l = -buff_size, m + buff_size
                        if (z_cc(k) < pi) then
                            !$acc loop seq
                            do i = 1, momxb
                                q_prim_vf(i)%sf(l, -j, k) = &
                                    q_prim_vf(i)%sf(l, j - 1, k + ((p + 1)/2))
                            end do

                            q_prim_vf(momxb + 1)%sf(l, -j, k) = &
                                -q_prim_vf(momxb + 1)%sf(l, j - 1, k + ((p + 1)/2))

                            q_prim_vf(momxe)%sf(l, -j, k) = &
                                -q_prim_vf(momxe)%sf(l, j - 1, k + ((p + 1)/2))

                            !$acc loop seq
                            do i = E_idx, sys_size
                                q_prim_vf(i)%sf(l, -j, k) = &
                                    q_prim_vf(i)%sf(l, j - 1, k + ((p + 1)/2))
                            end do
                        else
                            !$acc loop seq
                            do i = 1, momxb
                                q_prim_vf(i)%sf(l, -j, k) = &
                                    q_prim_vf(i)%sf(l, j - 1, k - ((p + 1)/2))
                            end do

                            q_prim_vf(momxb + 1)%sf(l, -j, k) = &
                                -q_prim_vf(momxb + 1)%sf(l, j - 1, k - ((p + 1)/2))

                            q_prim_vf(momxe)%sf(l, -j, k) = &
                                -q_prim_vf(momxe)%sf(l, j - 1, k - ((p + 1)/2))

                            !$acc loop seq
                            do i = E_idx, sys_size
                                q_prim_vf(i)%sf(l, -j, k) = &
                                    q_prim_vf(i)%sf(l, j - 1, k - ((p + 1)/2))
                            end do
                        end if
                    end do
                end do
            end do
        else
            !$acc parallel loop collapse(2) gang vector default(present)
            do l = 0, p
                do k = -buff_size, m + buff_size
                    if (bc_type(2,-1)%sf(k,0,l) >= -13 .and. bc_type(2,-1)%sf(k,0,l) <= -3) then
                        ${PRIM_GHOST_CELL_EXTRAPOLATION_BC("k,-j,l","k,0,l")}$
                    elseif (bc_type(2,-1)%sf(k,0,l) == -2) then
                        ${PRIM_SYMMETRY_BC(2,"k,-j,l","k,j-1,l")}$
                    elseif (bc_type(2,-1)%sf(k,0,l) == -1) then
                        ${PRIM_PERIODIC_BC("k,-j,l","k,n-(j-1),l")}$
                    elseif (bc_type(2,-1)%sf(k,0,l) == -15) then
                        ${PRIM_SLIP_WALL_BC("y","L")}$
                    elseif (bc_type(2,-1)%sf(k,0,l) == -16) then
                        ${PRIM_NO_SLIP_WALL_BC("y","L")}$
                    elseif (bc_type(2,-1)%sf(k,0,l) == -17) then
                        ${PRIM_DIRICHLET_BC(2,-1,"k,-j,l","k,i,l")}$
                    end if
                end do
            end do
        end if

        if (bcye >= 0) then
            call s_mpi_sendrecv_variables_buffers(q_prim_vf, pb, mv, 2, 1)
        else
            !$acc parallel loop collapse(2) gang vector default(present)
            do l = 0, p
                do k = -buff_size, m + buff_size
                    if (bc_type(2,1)%sf(k,0,l) >= -13 .and. bc_type(2,1)%sf(k,0,l) <= -3) then
                        ${PRIM_GHOST_CELL_EXTRAPOLATION_BC("k,n+j,l","k,n,l")}$
                    elseif (bc_type(2,1)%sf(k,0,l) == -2) then
                        ${PRIM_SYMMETRY_BC(2,"k,n+j,l","k,n - (j-1),l")}$
                    elseif (bc_type(2,1)%sf(k,0,l) == -1) then
                        ${PRIM_PERIODIC_BC("k,n+j,l","k,j-1,l")}$
                    elseif (bc_type(2,1)%sf(k,0,l) == -15) then
                        ${PRIM_SLIP_WALL_BC("y","R")}$
                    elseif (bc_type(2,1)%sf(k,0,l) == -16) then
                        ${PRIM_NO_SLIP_WALL_BC("y","R")}$
                    elseif (bc_type(2,1)%sf(k,0,l) == -17) then
                        ${PRIM_DIRICHLET_BC(2,1,"k,n+j,l","k,i,l")}$
                    end if
                end do
            end do
        end if

        if (qbmm .and. (.not. polytropic)) then
            if (bcyb < 0) then
                !$acc parallel loop collapse(2) gang vector default(present)
                do l = 0, p
                    do k = -buff_size, m + buff_size
                        if (bc_type(2,-1)%sf(k,0,l) >= -13 .and. bc_type(2,-1)%sf(k,0,l) <= -3) then
                            ${QBMM_BC("k,-j,l,q,i","k,0,l,q,i")}$
                        elseif (bc_type(2,-1)%sf(k,0,l) == -2) then
                            ${QBMM_BC("k,-j,l,q,i","k,j-1,l,q,i")}$
                        elseif (bc_type(2,-1)%sf(k,0,l) == -1) then
                            ${QBMM_BC("k,-j,l,q,i","k,n - (j-1),l,q,i")}$
                        end if
                    end do
                end do
            end if

            if (bcye < 0) then
                !$acc parallel loop collapse(2) gang vector default(present)
                do l = 0, p
                    do k = -buff_size, m + buff_size
                        if (bc_type(2,1)%sf(k,0,l) >= -13 .and. bc_type(2,1)%sf(k,0,l) <= -3) then
                            ${QBMM_BC("k,n+j,l,q,i","k,n,l,q,i")}$
                        elseif (bc_type(2,1)%sf(k,0,l) == -2) then
                            ${QBMM_BC("k,n+j,l,q,i","k,n - (j-1),l,q,i")}$
                        elseif (bc_type(2,1)%sf(k,0,l) == -1) then
                            ${QBMM_BC("k,n+j,l,q,i","k,j-1,k,q,i")}$
                        end if
                    end do
                end do
            end if
        end if

        if (p == 0) return

        !< z-direction
        if (bczb >= 0) then
            call s_mpi_sendrecv_variables_buffers(q_prim_vf, pb, mv, 3, -1)
        else
            !$acc parallel loop collapse(2) gang vector default(present)
            do l = -buff_size, n + buff_size
                do k = -buff_size, m + buff_size
                    if (bc_type(3,-1)%sf(k,l,0) >= -13 .and. bc_type(3,-1)%sf(k,l,0) <= -3) then
                        ${PRIM_GHOST_CELL_EXTRAPOLATION_BC("k,l,-j","k,l,0")}$
                    elseif (bc_type(3,-1)%sf(k,l,0) == -2) then
                        ${PRIM_SYMMETRY_BC(3,"k,l,-j","k,l,j-1")}$
                    elseif (bc_type(3,-1)%sf(k,l,0) == -1) then
                        ${PRIM_PERIODIC_BC("k,l,-j","k,l,p-(j-1)")}$
                    elseif (bc_type(3,-1)%sf(k,l,0) == -15) then
                        ${PRIM_SLIP_WALL_BC("z","L")}$
                    elseif (bc_type(3,-1)%sf(k,l,0) == -16) then
                        ${PRIM_NO_SLIP_WALL_BC("z","L")}$
                    elseif (bc_type(3,-1)%sf(k,l,0) == -17) then
                        ${PRIM_DIRICHLET_BC(3,-1,"k,l,-j","k,l,i")}$
                    end if
                end do
            end do
        end if

        if (bcze >= 0) then
            call s_mpi_sendrecv_variables_buffers(q_prim_vf, pb, mv, 3, 1)
        else
            !$acc parallel loop collapse(2) gang vector default(present)
            do l = -buff_size, n + buff_size
                do k = -buff_size, m + buff_size
                    if (bc_type(3,1)%sf(k,l,0) >= -13 .and. bc_type(3,1)%sf(k,l,0) <= -3) then
                        ${PRIM_GHOST_CELL_EXTRAPOLATION_BC("k,l,m+j","k,l,m")}$
                    elseif (bc_type(3,1)%sf(k,l,0) == -2) then
                        ${PRIM_SYMMETRY_BC(3,"k,l,p+j","k,l,p - (j-1)")}$
                    elseif (bc_type(3,1)%sf(k,l,0) == -1) then
                        ${PRIM_PERIODIC_BC("k,l,p+j","k,l,j-1")}$
                    elseif (bc_type(3,1)%sf(k,l,0) == -15) then
                        ${PRIM_SLIP_WALL_BC("z","R")}$
                    elseif (bc_type(3,1)%sf(k,l,0) == -16) then
                        ${PRIM_NO_SLIP_WALL_BC("z","R")}$
                    elseif (bc_type(3,1)%sf(k,l,0) == -17) then
                        ${PRIM_DIRICHLET_BC(3,1,"k,l,p+j","k,l,i")}$
                    end if
                end do
            end do
        end if

        if (qbmm .and. (.not. polytropic)) then
            if (bczb < 0) then
                !$acc parallel loop collapse(2) gang vector default(present)
                do l = -buff_size, n + buff_size
                    do k = -buff_size, m + buff_size
                        if (bc_type(3,-1)%sf(k,l,0) >= -13 .and. bc_type(3,-1)%sf(k,l,0) <= -3) then
                            ${QBMM_BC("k,l,-j,q,i","k,l,0,q,i")}$
                        elseif (bc_type(3,-1)%sf(k,l,0) == -2) then
                            ${QBMM_BC("k,l,-j,q,i","k,l,j-1,q,i")}$
                        elseif (bc_type(3,-1)%sf(k,l,0) == -1) then
                            ${QBMM_BC("k,l,-j,q,i","k,l,p - (j-1),q,i")}$
                        end if
                    end do
                end do
            end if

            if (bcze < 0) then
                !$acc parallel loop collapse(2) gang vector default(present)
                do l = -buff_size, n + buff_size
                    do k = -buff_size, m + buff_size
                        if (bc_type(3,1)%sf(k,l,0) >= -13 .and. bc_type(3,1)%sf(k,l,0) <= -3) then
                            ${QBMM_BC("k,l,p+j,q,i","k,l,p,q,i")}$
                        elseif (bc_type(3,1)%sf(k,l,0) == -2) then
                            ${QBMM_BC("k,l,p+j,q,i","k,l,p - (j-1),q,i")}$
                        elseif (bc_type(3,1)%sf(k,l,0) == -1) then
                            ${QBMM_BC("k,l,p+j,q,i","k,l,j-1,q,i")}$
                        end if
                    end do
                end do
            end if
        end if

    end subroutine s_populate_variables_buffers

    subroutine s_populate_capillary_buffers(c_divs)

        type(scalar_field), dimension(num_dims + 1), intent(inout) :: c_divs
        integer :: i, j, k, l

        ! x - direction
        if (bc_x%beg <= -3) then !< ghost cell extrapolation
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do l = 0, p
                    do k = 0, n
                        do j = 1, buff_size
                            c_divs(i)%sf(-j, k, l) = &
                                c_divs(i)%sf(0, k, l)
                        end do
                    end do
                end do
            end do
        elseif (bc_x%beg == -2) then !< slip wall or reflective
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do l = 0, p
                    do k = 0, n
                        do j = 1, buff_size
                            if (i == 1) then
                                c_divs(i)%sf(-j, k, l) = &
                                    -c_divs(i)%sf(j - 1, k, l)
                            else
                                c_divs(i)%sf(-j, k, l) = &
                                    c_divs(i)%sf(j - 1, k, l)
                            end if
                        end do
                    end do
                end do
            end do
        elseif (bc_x%beg == -1) then
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do l = 0, p
                    do k = 0, n
                        do j = 1, buff_size
                            c_divs(i)%sf(-j, k, l) = &
                                c_divs(i)%sf(m - (j - 1), k, l)
                        end do
                    end do
                end do
            end do
        else
            call s_mpi_sendrecv_capilary_variables_buffers(c_divs, 1, -1)
        end if

        if (bc_x%end <= -3) then !< ghost-cell extrapolation
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do l = 0, p
                    do k = 0, n
                        do j = 1, buff_size
                            c_divs(i)%sf(m + j, k, l) = &
                                c_divs(i)%sf(m, k, l)
                        end do
                    end do
                end do
            end do
        elseif (bc_x%end == -2) then
            !$acc parallel loop collapse(4) default(present)
            do i = 1, num_dims + 1
                do l = 0, p
                    do k = 0, n
                        do j = 1, buff_size
                            if (i == 1) then
                                c_divs(i)%sf(m + j, k, l) = &
                                    -c_divs(i)%sf(m - (j - 1), k, l)
                            else
                                c_divs(i)%sf(m + j, k, l) = &
                                    c_divs(i)%sf(m - (j - 1), k, l)
                            end if
                        end do
                    end do
                end do
            end do
        else if (bc_x%end == -1) then
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do l = 0, p
                    do k = 0, n
                        do j = 1, buff_size
                            c_divs(i)%sf(m + j, k, l) = &
                                c_divs(i)%sf(j - 1, k, l)
                        end do
                    end do
                end do
            end do
        else
            call s_mpi_sendrecv_capilary_variables_buffers(c_divs, 1, 1)
        end if

        if (n == 0) then
            return
        elseif (bc_y%beg <= -3) then !< ghost-cell extrapolation
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do k = 0, p
                    do j = 1, buff_size
                        do l = -buff_size, m + buff_size
                            c_divs(i)%sf(l, -j, k) = &
                                c_divs(i)%sf(l, 0, k)
                        end do
                    end do
                end do
            end do
        elseif (bc_y%beg == -2) then !< slip wall or reflective
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do k = 0, p
                    do j = 1, buff_size
                        do l = -buff_size, m + buff_size
                            if (i == 2) then
                                c_divs(i)%sf(l, -j, k) = &
                                    -c_divs(i)%sf(l, j - 1, k)
                            else
                                c_divs(i)%sf(l, -j, k) = &
                                    c_divs(i)%sf(l, j - 1, k)
                            end if
                        end do
                    end do
                end do
            end do
        elseif (bc_y%beg == -1) then
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do k = 0, p
                    do j = 1, buff_size
                        do l = -buff_size, m + buff_size
                            c_divs(i)%sf(l, -j, k) = &
                                c_divs(i)%sf(l, n - (j - 1), k)
                        end do
                    end do
                end do
            end do
        else
            call s_mpi_sendrecv_capilary_variables_buffers(c_divs, 2, -1)
        end if

        if (bc_y%end <= -3) then !< ghost-cell extrapolation
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do k = 0, p
                    do j = 1, buff_size
                        do l = -buff_size, m + buff_size
                            c_divs(i)%sf(l, n + j, k) = &
                                c_divs(i)%sf(l, n, k)
                        end do
                    end do
                end do
            end do
        elseif (bc_y%end == -2) then !< slip wall or reflective
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do k = 0, p
                    do j = 1, buff_size
                        do l = -buff_size, m + buff_size
                            if (i == 2) then
                                c_divs(i)%sf(l, n + j, k) = &
                                    -c_divs(i)%sf(l, n - (j - 1), k)
                            else
                                c_divs(i)%sf(l, n + j, k) = &
                                    c_divs(i)%sf(l, n - (j - 1), k)
                            end if
                        end do
                    end do
                end do
            end do
        elseif (bc_y%end == -1) then
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do k = 0, p
                    do j = 1, buff_size
                        do l = -buff_size, m + buff_size
                            c_divs(i)%sf(l, n + j, k) = &
                                c_divs(i)%sf(l, j - 1, k)
                        end do
                    end do
                end do
            end do
        else
            call s_mpi_sendrecv_capilary_variables_buffers(c_divs, 2, 1)
        end if

        if (p == 0) then
            return
        elseif (bc_z%beg <= -3) then !< ghost-cell extrapolation
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do j = 1, buff_size
                    do l = -buff_size, n + buff_size
                        do k = -buff_size, m + buff_size
                            c_divs(i)%sf(k, l, -j) = &
                                c_divs(i)%sf(k, l, 0)
                        end do
                    end do
                end do
            end do
        elseif (bc_z%beg == -2) then !< symmetry
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do j = 1, buff_size
                    do l = -buff_size, n + buff_size
                        do k = -buff_size, m + buff_size
                            if (i == 3) then
                                c_divs(i)%sf(k, l, -j) = &
                                    -c_divs(i)%sf(k, l, j - 1)
                            else
                                c_divs(i)%sf(k, l, -j) = &
                                    c_divs(i)%sf(k, l, j - 1)
                            end if
                        end do
                    end do
                end do
            end do
        elseif (bc_z%beg == -1) then
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do j = 1, buff_size
                    do l = -buff_size, n + buff_size
                        do k = -buff_size, m + buff_size
                            c_divs(i)%sf(k, l, -j) = &
                                c_divs(i)%sf(k, l, p - (j - 1))
                        end do
                    end do
                end do
            end do
        else
            call s_mpi_sendrecv_capilary_variables_buffers(c_divs, 3, -1)
        end if

        if (bc_z%end <= -3) then !< ghost-cell extrapolation
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do j = 1, buff_size
                    do l = -buff_size, n + buff_size
                        do k = -buff_size, m + buff_size
                            c_divs(i)%sf(k, l, p + j) = &
                                c_divs(i)%sf(k, l, p)
                        end do
                    end do
                end do
            end do
        elseif (bc_z%end == -2) then !< symmetry
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do j = 1, buff_size
                    do l = -buff_size, n + buff_size
                        do k = -buff_size, m + buff_size
                            if (i == 3) then
                                c_divs(i)%sf(k, l, p + j) = &
                                    -c_divs(i)%sf(k, l, p - (j - 1))
                            else
                                c_divs(i)%sf(k, l, p + j) = &
                                    c_divs(i)%sf(k, l, p - (j - 1))
                            end if
                        end do
                    end do
                end do
            end do
        elseif (bc_z%end == -1) then
            !$acc parallel loop collapse(4) gang vector default(present)
            do i = 1, num_dims + 1
                do j = 1, buff_size
                    do l = -buff_size, n + buff_size
                        do k = -buff_size, m + buff_size
                            c_divs(i)%sf(k, l, p + j) = &
                                c_divs(i)%sf(k, l, j - 1)
                        end do
                    end do
                end do
            end do
        else
            call s_mpi_sendrecv_capilary_variables_buffers(c_divs, 3, 1)
        end if


    end subroutine s_populate_capillary_buffers

    subroutine s_read_boundary_condition_files(step_dirpath, bc_type)

        character(LEN=*), intent(in) :: step_dirpath

        type(integer_field), dimension(1:num_dims,-1:1) :: bc_type

        call s_read_boundary_condition_types(step_dirpath, bc_type)

        call s_read_boundary_condition_buffers(step_dirpath)

    end subroutine s_read_boundary_condition_files

    subroutine s_read_boundary_condition_types(step_dirpath, bc_type)

        character(LEN=*), intent(in) :: step_dirpath

        type(integer_field), dimension(1:num_dims,-1:1) :: bc_type

        integer :: dir, loc
        logical :: file_exist
        character(len=path_len) :: file_path

        character(len=10) :: status

#ifdef MFC_MPI
        integer :: ierr
        integer :: file_id
        integer :: offset
        character(len=7) :: proc_rank_str
#endif

        if (parallel_io .eqv. .false.) then
            file_path = trim(step_dirpath)//'/bc_type.dat'
        else
#ifdef MFC_MPI

#endif
        end if

        inquire (FILE=trim(file_path), EXIST=file_exist)
        if (.not. file_exist) then
            call s_mpi_abort(trim(file_path)//' is missing. Exiting ...')
        end if

        if (parallel_io .eqv. .false.) then
            open (1, FILE=trim(file_path), FORM='unformatted', STATUS='unknown')
            do dir = 1, num_dims
                do loc = -1, 1, 2
                    read (1) bc_type(dir, loc)%sf
                end do
            end do
            close (1)
        else
#ifdef MFC_MPI
            if (file_per_process) then

            else

            end if
#endif
        end if

    end subroutine s_read_boundary_condition_types

    subroutine s_read_boundary_condition_buffers(step_dirpath)

        character(LEN=*), intent(in) :: step_dirpath

        type(integer_field), dimension(1:num_dims,-1:1) :: bc_type

        integer :: dir, loc
        logical :: file_exist
        character(len=path_len) :: file_path

        character(len=10) :: status

#ifdef MFC_MPI
        integer :: ierr
        integer :: file_id
        integer :: offset
        character(len=7) :: proc_rank_str
#endif

        if (parallel_io .eqv. .false.) then
            file_path = trim(step_dirpath)//'/bc_buffers.dat'
        else
#ifdef MFC_MPI

#endif
        end if

        inquire (FILE=trim(file_path), EXIST=file_exist)
        if (.not. file_exist) then
            call s_mpi_abort(trim(file_path)//' is missing. Exiting ...')
        end if

        if (parallel_io .eqv. .false.) then
            open (1, FILE=trim(file_path), FORM='unformatted', STATUS='unknown')
            do dir = 1, num_dims
                do loc = -1, 1, 2
                    read (1) bc_buffers(dir, loc)%sf
                end do
            end do
            close (1)
        else
#ifdef MFC_MPI
            if (file_per_process) then

            else

            end if
#endif
        end if

    end subroutine s_read_boundary_condition_buffers

    subroutine s_finalize_boundary_conditions_module()

        @:DEALLOCATE(bc_buffers(1, -1)%sf)
        @:DEALLOCATE(bc_buffers(1, 1)%sf)
        if (n > 0) then
            @:DEALLOCATE(bc_buffers(2,-1)%sf)
            @:DEALLOCATE(bc_buffers(2,1)%sf)
            if (p > 0) then
                @:DEALLOCATE(bc_buffers(3,-1)%sf)
                @:DEALLOCATE(bc_buffers(3,1)%sf)
            end if
        end if

        @:DEALLOCATE(bc_buffers)

    end subroutine s_finalize_boundary_conditions_module


end module m_boundary_conditions
