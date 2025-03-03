!>
!! @file m_perturbation.fpp
!! @brief Contains module m_perturbation

!> @brief This module contains
module m_boundary_conditions

    use m_derived_types

    use m_global_parameters
#ifdef MFC_MPI
    use mpi
#endif
    use m_delay_file_access

    use m_compile_specific

    implicit none

    real(wp) :: x_centroid, y_centroid, z_centroid
    real(wp) :: length_x, length_y, length_z
    type(bounds_info) :: x_boundary, y_boundary, z_boundary  !<

    type(scalar_field), dimension(:,:), allocatable :: bc_buffers

    integer :: i, j, k, l

#ifdef MFC_MPI
    integer, dimension(1:3, -1:1) :: MPI_BC_TYPE_TYPE, MPI_BC_BUFFER_TYPE
#endif

    private; public :: s_initialize_boundary_conditions_module, &
        s_apply_boundary_patches, &
        s_write_serial_boundary_condition_files, &
        s_write_parallel_boundary_condition_files, &
        s_finalize_boundary_conditions_module

contains

    subroutine s_initialize_boundary_conditions_module()

        allocate(bc_buffers(1:num_dims, -1:1))

        allocate(bc_buffers(1, -1)%sf(1:sys_size, 0:n, 0:p))
        allocate(bc_buffers(1, 1)%sf(1:sys_size, 0:n, 0:p))
        if (n > 0) then
            allocate(bc_buffers(2,-1)%sf(-buff_size:m+buff_size,1:sys_size,0:p))
            allocate(bc_buffers(2,1)%sf(-buff_size:m+buff_size,1:sys_size,0:p))
            if (p > 0) then
                allocate(bc_buffers(3,-1)%sf(-buff_size:m+buff_size,-buff_size:n+buff_size,1:sys_size))
                allocate(bc_buffers(3,1)%sf(-buff_size:m+buff_size,-buff_size:n+buff_size,1:sys_size))
            end if
        end if

    end subroutine s_initialize_boundary_conditions_module

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
        integer :: i

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

    subroutine s_write_serial_boundary_condition_files(q_prim_vf, bc_type, step_dirpath)

        type(scalar_field), dimension(sys_size) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type

        character(LEN=*), intent(in) :: step_dirpath

        integer :: dir, loc
        character(len=path_len) :: file_path

        character(len=10) :: status

        if (old_grid) then
            status = 'old'
        else
            status = 'new'
        end if

        call s_pack_boundary_condition_buffers(q_prim_vf)

        file_path = trim(step_dirpath)//'/bc_type.dat'
        open (1, FILE=trim(file_path), FORM='unformatted', STATUS=status)
        do dir = 1, num_dims
            do loc = -1, 1, 2
                write (1) bc_type(dir, loc)%sf
            end do
        end do
        close (1)

        file_path = trim(step_dirpath)//'/bc_buffers.dat'
        open (1, FILE=trim(file_path), FORM='unformatted', STATUS=status)
        do dir = 1, num_dims
            do loc = -1, 1, 2
                write (1) bc_buffers(dir, loc)%sf
            end do
        end do
        close (1)

    end subroutine s_write_serial_boundary_condition_files

    subroutine s_write_parallel_boundary_condition_files(q_prim_vf, bc_type)

        type(scalar_field), dimension(sys_size) :: q_prim_vf
        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type

        integer :: dir, loc
        character(len=path_len) :: file_loc, file_path

        character(len=10) :: status

#ifdef MFC_MPI
        integer :: ierr
        integer :: file_id
        integer :: offset
        character(len=7) :: proc_rank_str
        logical :: dir_check

        call s_pack_boundary_condition_buffers(q_prim_vf)

        file_loc = trim(case_dir)//'/restart_data/boundary_conditions'
        if (proc_rank == 0) then
            call my_inquire(file_loc, dir_check)
            if (dir_check .neqv. .true.) then
                call s_create_directory(trim(file_loc))
            end if
        end if

        call s_create_mpi_types(bc_type)

        call s_mpi_barrier()

        call DelayFileAccess(proc_rank)

        write (proc_rank_str, '(I7.7)') proc_rank
        file_path = trim(file_loc)//'/bc_'//trim(proc_rank_str)//'.dat'
        call MPI_File_open(MPI_COMM_SELF, trim(file_path), MPI_MODE_CREATE + MPI_MODE_WRONLY, MPI_INFO_NULL, file_id, ierr)

        offset = 0

        ! Write bc_types
        do dir = 1, num_dims
            do loc = -1, 1, 2
                call MPI_File_set_view(file_id, int(offset, KIND=MPI_ADDRESS_KIND), MPI_INTEGER, MPI_BC_TYPE_TYPE(dir, loc), 'native', MPI_INFO_NULL, ierr)
                call MPI_File_write_all(file_id, bc_type(dir, loc)%sf, 1, MPI_BC_TYPE_TYPE(dir, loc), MPI_STATUS_IGNORE, ierr)
                offset = offset + sizeof(bc_type(dir, loc)%sf)
            end do
        end do
        print*, proc_rank, bc_type(1,-1)%sf(0,:,0)
        ! Write bc_buffers
        do dir = 1, num_dims
            do loc = -1, 1, 2
                call MPI_File_set_view(file_id, int(offset, KIND=MPI_ADDRESS_KIND), mpi_p, MPI_BC_BUFFER_TYPE(dir, loc), 'native', MPI_INFO_NULL, ierr)
                call MPI_File_write_all(file_id, bc_buffers(dir, loc)%sf, 1, MPI_BC_BUFFER_TYPE(dir, loc), MPI_STATUS_IGNORE, ierr)
                offset = offset + sizeof(bc_buffers(dir, loc)%sf)
            end do
        end do

        call MPI_File_close(file_id, ierr)
#endif

    end subroutine s_write_parallel_boundary_condition_files

    subroutine s_create_mpi_types(bc_type)

        type(integer_field), dimension(1:num_dims, -1:1) :: bc_type

#ifdef MFC_MPI
        integer :: dir, loc
        integer, dimension(3) :: sf_start_idx, sf_extents_loc
        integer :: ifile, ierr, data_size

        do dir = 1, num_dims
            do loc = -1, 1, 2
                sf_start_idx = (/0, 0, 0/)
                sf_extents_loc = shape(bc_type(dir, loc)%sf)

                call MPI_TYPE_CREATE_SUBARRAY(num_dims, sf_extents_loc, sf_extents_loc, sf_start_idx, &
                                              MPI_ORDER_FORTRAN, MPI_INTEGER, MPI_BC_TYPE_TYPE(dir, loc), ierr)
                call MPI_TYPE_COMMIT(MPI_BC_TYPE_TYPE(dir, loc), ierr)
            end do
        end do

        do dir = 1, num_dims
            do loc = -1, 1, 2
                sf_start_idx = (/0, 0, 0/)
                sf_extents_loc = shape(bc_buffers(dir, loc)%sf)

                call MPI_TYPE_CREATE_SUBARRAY(num_dims, sf_extents_loc, sf_extents_loc, sf_start_idx, &
                                              MPI_ORDER_FORTRAN, mpi_p, MPI_BC_BUFFER_TYPE(dir, loc), ierr)
                call MPI_TYPE_COMMIT(MPI_BC_BUFFER_TYPE(dir, loc), ierr)
            end do
        end do
#endif
    end subroutine s_create_mpi_types

    subroutine s_pack_boundary_condition_buffers(q_prim_vf)

        type(scalar_field), dimension(sys_size) :: q_prim_vf

        do k = 0, p
            do j = 0, n
                do i = 1, sys_size
                    bc_buffers(1,-1)%sf(i,j,k) = q_prim_vf(i)%sf(-1,j,k)
                    bc_buffers(1,1)%sf(i,j,k) = q_prim_vf(i)%sf(m+1,j,k)
                end do
            end do
        end do

        if (n > 0) then
            do k = 0, p
                do j = 1, sys_size
                    do i = 0, m
                        bc_buffers(2,-1)%sf(i,j,k) = q_prim_vf(j)%sf(i,-1,k)
                        bc_buffers(2,1)%sf(i,j,k) = q_prim_vf(j)%sf(i,n+1,k)
                    end do
                end do
            end do

            if (p > 0) then
                do k = 1, sys_size
                    do j = 0, n
                        do i = 0, m
                            bc_buffers(3,-1)%sf(i,j,k) = q_prim_vf(k)%sf(i,j,-1)
                            bc_buffers(3,1)%sf(i,j,k) = q_prim_vf(k)%sf(i,j,p+1)
                        end do
                    end do
                end do
            end if
        end if

    end subroutine s_pack_boundary_condition_buffers

    subroutine s_finalize_boundary_conditions_module()

        deallocate(bc_buffers(1, -1)%sf)
        deallocate(bc_buffers(1, 1)%sf)
        if (n > 0) then
            deallocate(bc_buffers(2,-1)%sf)
            deallocate(bc_buffers(2,1)%sf)
            if (p > 0) then
                deallocate(bc_buffers(3,-1)%sf)
                deallocate(bc_buffers(3,1)%sf)
            end if
        end if

        deallocate(bc_buffers)

    end subroutine s_finalize_boundary_conditions_module

end module m_boundary_conditions
