! module atomic_mod
!     use, intrinsic :: iso_c_binding
!     use cudafor
!     implicit none

!     ! Define a valid kind parameter for half-precision (if supported)
!     integer, parameter :: half_kind = selected_real_kind(2, 2)

!     interface
!         function atomicAdd_half(addr, val) bind(C, name="atomicAdd_half")
!             use, intrinsic :: iso_c_binding
!             real(half_kind), value :: addr
!             real(half_kind), value :: val
!             real(half_kind) :: atomicAdd_half
!         end function atomicAdd_half
!     end interface

!     ! Apply attributes outside of interface block
!     attributes(device) :: atomicAdd_half

! end module atomic_mod


!module atomic_mod
!    use, intrinsic :: iso_c_binding
!    use cudafor
!    implicit none

!    interface
!        function atomicAdd_half(addr, val) bind(C, name="atomicAdd_half")
!            use, intrinsic :: iso_c_binding
!            real(c_float16) :: addr
!            real(c_float16) :: val
!            real(c_float16) :: atomicAdd_half
!            attributes(device) :: atomicAdd_half  ! Correct placement of attributes
!        end function atomicAdd_half
!        !$acc routine(atomicAdd_half) seq
!    end interface
!end module atomic_mod

module atomic_mod
    use, intrinsic :: iso_c_binding
    use cudafor
    implicit none

    interface
        attributes(device) function atomicAdd_half(addr, val) bind(C, name="atomicAdd_half")
            use, intrinsic :: iso_c_binding
            real(2) :: addr(*)
            real(2) :: val(*)
            real(2) :: atomicAdd_half
            !$acc routine(atomicAdd_half) seq
        end function atomicAdd_half

    end interface
end module
