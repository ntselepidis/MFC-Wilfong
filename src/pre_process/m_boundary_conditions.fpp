!>
!! @file m_perturbation.fpp
!! @brief Contains module m_perturbation

!> @brief This module contains
module m_boundary_conditions

    use m_derived_types
    use m_global_parameters

    implicit none

    real(wp) :: x_centroid, y_centroid, z_centroid
    real(wp) :: length_x, length_y, length_z
    type(bounds_info) :: x_boundary, y_boundary, z_boundary  !<

    integer :: i, j, k, l

    private; public :: s_apply_boundary_patches

contains

    subroutine s_line_segment_bc(patch_id, q_prim_vf, bc_type)

        type(scalar_field), dimension(sys_size) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type
        integer, intent(in) :: patch_id

        ! Patch is a vertical line at x_beg or x_end
        if (patch_bc(patch_id)%dir == 1) then
            y_centroid = patch_bc(patch_id)%centroid(2)
            length_y = patch_bc(patch_id)%length(2)

            y_boundary%beg = y_centroid - 0.5_wp*length_y
            y_boundary%end = y_centroid + 0.5_wp*length_y

            ! Patch is a vertical line at x_beg and x_beg is a domain boundary
            if (patch_bc(patch_id)%loc == -1 .and. bc_x%beg < 0) then
                do i = 0, n
                    if (y_cc(i) > y_boundary%beg .and. y_cc(i) < y_boundary%end) then
                        bc_type(1,-1)%sf(0,i,0) = patch_bc(patch_id)%type
                        if (patch_bc(patch_id)%type == -17) then ! Dirichlet BC
                            do j = 1, buff_size
                                ! Velocities
                                do k = 1, num_dims
                                    q_prim_vf(momxb+k-1)%sf(-j,i,0 ) = patch_bc(patch_id)%vel(k)
                                end do

                                ! Density and volume fraction
                                do k = 1, num_fluids
                                    q_prim_vf(k)%sf(-j,i,0 ) = patch_bc(patch_id)%alpha_rho(k)
                                    q_prim_vf(advxb+k-1)%sf(-j,i,0 ) = patch_bc(patch_id)%alpha(k)
                                end do

                                ! Pressure
                                q_prim_vf(E_idx)%sf(-j,i,0 ) = patch_bc(patch_id)%pres
                            end do
                        end if
                    end if
                end do
            end if
        end if

    end subroutine s_line_segment_bc

    subroutine s_circle_bc(patch_id, q_prim_vf, bc_type)

        type(scalar_field), dimension(sys_size) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type

        integer, intent(in) :: patch_id

    end subroutine s_circle_bc

    subroutine s_rectangle_bc(patch_id, q_prim_vf, bc_type)

        type(scalar_field), dimension(sys_size) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type

        integer, intent(in) :: patch_id

    end subroutine s_rectangle_bc

    subroutine s_apply_boundary_patches(q_prim_vf, bc_type)

        type(scalar_field), dimension(sys_size) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type

        !< Apply 2D patches to 3D domain
        if (p > 0) then
            do i = 1, num_bc_patches
                if (proc_rank == 0) then
                    print *, 'Processing boundary condition patch', i
                end if

                if (patch_bc(i)%geometry == 2) then
                    call s_circle_bc(i, q_prim_vf, bc_type)
                elseif (patch_bc(i)%geometry == 3) then
                    call s_rectangle_bc(i, q_prim_vf, bc_type)
                end if
            end do
        !< Apply 1D patches to 2D domain
        elseif (n > 0) then
            do i = 1, num_bc_patches
                if (proc_rank == 0) then
                    print *, 'Processing boundary condition patch', i
                end if

                if (patch_bc(i)%geometry == 1) then
                    call s_line_segment_bc(i, q_prim_vf, bc_type)
                end if
            end do
        end if

    end subroutine s_apply_boundary_patches

end module m_boundary_conditions
