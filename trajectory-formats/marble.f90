! MARBLE trajectory I/O
module trajectory
  type handle
     integer :: iohandle
  end type handle
  
contains

  ! Open trajectory and returns handle as htraj. 
  ! Should open fails, the program abends.
  subroutine open_trajectory(htraj, fname)
    use utility, only: newunit
    implicit none
    type(handle), intent(inout) :: htraj
    character(len=*), intent(in) :: fname

    open(unit=newunit(htraj%iohandle), file=fname, action="READ", form="FORMATTED")
    read(htraj%iohandle)

  end subroutine open_trajectory

  ! Close trajectory specified by handle
  subroutine close_trajectory(htraj)
    implicit none
    type(handle), intent(inout) :: htraj

    close(htraj%iohandle)
  end subroutine close_trajectory

  ! Read trajectory and returns [crd] as a coordinates, and [cell] as a periodic cell, represented in Angstrom.
  ! [status] is non-zero if any error occurs. In such a case, [crd] and [cell] can be an arbitrary value.
  ! [cell] may be an arbitrary value if the trajectory does not contain cell information.
  ! The coordinate is not guaranteed to be within a unit cell.
  subroutine read_trajectory(htraj, natom, is_periodic, crd, cell, status)
    implicit none
    type(handle), intent(in) :: htraj
    integer, intent(in) :: natom
    logical, intent(in) :: is_periodic
    real(8), intent(out) :: crd(3,natom)
    real(8), intent(out) :: cell(3,3)
    integer, intent(out) :: status
    integer :: i, j

    do i = 1, natom
       read(htraj%iohandle, *, err=999) crd(:, i)
    end do
    do i = 1, 3
       read(htraj%iohandle, *, err=999) cell(:, i)
    end do
    status = 0
    return

999 status = 1
    return
  end subroutine read_trajectory

end module trajectory
