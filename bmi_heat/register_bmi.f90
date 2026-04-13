! register_bmi.f90
!
! Model-specific factory function for the CSDMS heat equation BMI model.
! Follows the NOAA-OWP NextGen iso_c_fortran_bmi pattern:
! https://github.com/NOAA-OWP/ngen/extern/iso_c_fortran_bmi
!
! This is the ONLY model-specific file needed for C/Java interoperability.
! All BMI proxy functions are provided generically by iso_c_bmif_2_0.f90.

function register_bmi(this) result(bmi_status) bind(C, name="register_bmi")
#ifdef _WIN32
  !DEC$ ATTRIBUTES DLLEXPORT :: register_bmi
#else
  !GCC$ ATTRIBUTES VISIBILITY="default" :: register_bmi
#endif
  use, intrinsic :: iso_c_binding, only: c_ptr, c_loc, c_int
  use iso_c_bmif_2_0
  use bmiheatf
  implicit none

  type(c_ptr) :: this
  integer(kind=c_int) :: bmi_status
  type(bmi_heat), pointer :: bmi_model
  type(box), pointer :: bmi_box

  allocate(bmi_heat :: bmi_model)
  allocate(bmi_box)
  bmi_box%ptr => bmi_model

  if (.not. associated(bmi_box) .or. .not. associated(bmi_box%ptr)) then
    bmi_status = BMI_FAILURE
  else
    this = c_loc(bmi_box)
    bmi_status = BMI_SUCCESS
  end if

end function register_bmi
