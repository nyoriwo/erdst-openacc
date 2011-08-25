#ifdef MKL
#  include "mkl_dfti.f90"
#endif

module fft_iface
#ifdef MKL
  use MKL_DFTI
#endif
  implicit none
  
  integer :: fftsize(3)

  type fft_handle
#ifdef MKL
  type(Dfti_Descriptor), pointer :: desc
#endif
#ifdef FFTW
     integer(8) :: plan
#endif
  end type fft_handle

#ifdef FFTW
#include "fftw3.f"
#endif
  
contains 

  subroutine fft_set_size(fftsize_in)
    integer, intent(in) :: fftsize_in(3)  
    fftsize(:) = fftsize_in(:)
  end subroutine fft_set_size

#ifdef MKL
  ! 3D-FFT, MKL version
  
  ! initialize FFT, real to complex, out-of-place
  subroutine fft_init_rtc(handle, in, out)
    use MKL_DFTI
    type(fft_handle), intent(out) :: handle
    real, intent(inout) :: in(fftsize(1), fftsize(2), fftsize(3))
    complex, intent(inout) :: out(fftsize(1)/2+1, fftsize(2), fftsize(3))
    integer :: stat
    real :: dummy
    if(kind(dummy) == 8) then
       stat = DftiCreateDescriptor(handle%desc, DFTI_DOUBLE, DFTI_REAL, 3, fftsize)
    else
       stat = DftiCreateDescriptor(handle%desc, DFTI_FLOAT, DFTI_REAL, 3, fftsize)
    endif
    if(stat /= 0) stop "MKL-FFT: failed to execute DftiCreateDescriptor"
    stat = DftiSetValue(handle%desc, DFTI_PLACEMENT, DFTI_NOT_INPLACE)
    if(stat /= 0) stop "MKL-FFT: failed to set DFTI_NOT_INPLACE"
    stat = DftiSetValue(handle%desc, DFTI_PACKED_FORMAT, DFTI_CCE_FORMAT)
    if(stat /= 0) stop "MKL-FFT: failed to set DFTI_PACKED_FORMAT"
    stat = DftiCommitDescriptor(handle%desc)
    if(stat /= 0) stop "MKL-FFT: failed to execute DftiCommitDescriptor"
  end subroutine fft_init_rtc

  ! real to complex. Note that MKL's DFT interface is exactly the same for r2c and c2r, thus just pass the argument.
  subroutine fft_init_ctr(handle, in, out)
    type(fft_handle), intent(out) :: handle
    complex, intent(inout) :: in(fftsize(1)/2+1, fftsize(2), fftsize(3))
    real, intent(inout) :: out(fftsize(1), fftsize(2), fftsize(3))
    call fft_init_rtc(handle, out, in)
  end subroutine fft_init_ctr

  ! real-to-complex, out-of-place FFT
  subroutine fft_rtc(handle, in, out)
    use MKL_DFTI
    type(fft_handle), intent(in) :: handle
    ! use fortran77-style size to bypass type-check. Note that this invalidates type-check!
    real, intent(in) :: in(*)
    complex, intent(out) :: out(*)

    integer :: stat

    stat = DftiComputeForward(handle%desc, in, out)
    if(stat /= 0) stop "MKL-FFT: failed to execute DftiComputeForward @ rtc (oops!)"
  end subroutine fft_rtc

  ! complex-to-real, out-of-place FFT
  subroutine fft_ctr(handle, in, out)
    use MKL_DFTI
    type(fft_handle), intent(in) :: handle
    ! use fortran77-style size to bypass type-check. Note that this invalidates type-check!
    complex, intent(in) :: in(*)
    real, intent(out) :: out(*)

    integer :: stat

    stat = DftiComputeBackward(handle%desc, in, out)
    if(stat /= 0) stop "MKL-FFT: failed to execute DftiComputeForward @ ctr (oops!)"
  end subroutine fft_ctr

  ! clean-up fft handle
  subroutine fft_cleanup_rtc(handle)
    type(fft_handle), intent(in) :: handle

    integer :: stat
    stat = DftiFreeDescriptor(handle%desc)
    if(stat /= 0) stop "MKL-FFT: failed to execute DftiFreeDescriptor (oops!)"
  end subroutine fft_cleanup_rtc

   ! clean-up fft handle
  subroutine fft_cleanup_ctr(handle)
    type(fft_handle), intent(in) :: handle

    integer :: stat
    stat = DftiFreeDescriptor(handle%desc)
    if(stat /= 0) stop "MKL-FFT: failed to execute DftiFreeDescriptor (oops!)"
  end subroutine fft_cleanup_ctr

#endif
#ifdef FFTW
  ! 3D-FFT, FFTW version
  ! This one is unsupported; use at your own risk.

  ! Initialize real-to-complex
  subroutine fft_init_rtc(handle, in, out)
    type(fft_handle), intent(out) :: handle
    real, intent(in) :: in(fftsize(1), fftsize(2), fftsize(3))
    complex, intent(out) :: out(fftsize(1)/2+1, fftsize(2), fftsize(3))
    integer :: stat
    real :: dummy

    if(kind(dummy) == 8) then
       call dfftw_import_system_wisdom(stat)
       call dfftw_plan_dft_r2c_3d(handle%plan, fftsize(1), fftsize(2), fftsize(3), &
            in, out, &
            FFTW_MEASURE)
    else
       ! FFTW need separate compilation for single precision,
       ! and many people incorrecly report this as a bug.
       stop "fftw for single precision not supported"
    endif
  end subroutine fft_init_rtc

  ! Initialize complex-to-real
  subroutine fft_init_ctr(handle, in, out)
    type(fft_handle), intent(out) :: handle
    complex, intent(in) :: in(fftsize(1)/2+1, fftsize(2), fftsize(3))
    real, intent(out) :: out(fftsize(1), fftsize(2), fftsize(3))
    integer :: stat
    real :: dummy

    if(kind(dummy) == 8) then
       call dfftw_import_system_wisdom(stat)
       call dfftw_plan_dft_c2r_3d(handle%plan, fftsize(1), fftsize(2), fftsize(3), &
            in, out, &
            FFTW_MEASURE)
    else
       stop "fftw for single precision not supported"
    endif
  end subroutine fft_init_ctr

  subroutine fft_ctr(handle, in, out)
    type(fft_handle), intent(in) :: handle
    complex, intent(in) :: in(fftsize(1)/2+1, fftsize(2), fftsize(3))
    real, intent(out) :: out(fftsize(1), fftsize(2), fftsize(3))
    real :: dummy
    if(kind(dummy) == 8) then
       call dfftw_execute(handle%plan)
    else
       stop
    endif
  end subroutine fft_ctr

  subroutine fft_rtc(handle, in, out)
    type(fft_handle), intent(in) :: handle
    real, intent(in) :: in(fftsize(1), fftsize(2), fftsize(3))
    complex, intent(out) :: out(fftsize(1)/2+1, fftsize(2), fftsize(3))
    real :: dummy
    if(kind(dummy) == 8) then
       call dfftw_execute(handle%plan)
    else
       stop
    endif
  end subroutine fft_rtc

  ! clean-up fft handle
  subroutine fft_cleanup_ctr(handle)
    type(fft_handle), intent(in) :: handle
    real :: dummy
    if(kind(dummy) == 8) then
       call dfftw_destroy_plan(handle%plan)
    else
       stop
    endif
  end subroutine fft_cleanup_ctr
  
  ! clean-up fft handle
  subroutine fft_cleanup_rtc(handle)
    type(fft_handle), intent(in) :: handle
    real :: dummy
    if(kind(dummy) == 8) then
       call dfftw_destroy_plan(handle%plan)
    else
       stop
    endif
  end subroutine fft_cleanup_rtc
  
#endif

end module fft_iface
