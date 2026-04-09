! bmi_c_wrapper.f90
!
! C-callable wrapper around bmiheatf for Java/JNA interop.
!
! Design:
!   - Java holds an opaque c_ptr (long) to a heap-allocated bmi_heat instance.
!   - Call bmi_create() to allocate the instance; bmi_destroy() to free it.
!   - All string inputs are null-terminated c_char arrays.
!   - String outputs are fixed-width BMI_MAX_*-byte buffers, null-terminated.
!   - Array arguments carry an explicit element count n.
!   - bmi_get_value_ptr returns a raw c_ptr to the model's internal memory
!     (zero-copy); currently supported only for plate_surface__temperature.
!
! Compiler note:
!   !DEC$ ATTRIBUTES DLLEXPORT is Intel Fortran (ifx/ifort).
!   Replace with !GCC$ ATTRIBUTES DLLEXPORT for gfortran on Windows.
!
! Type mapping assumptions (hold on all supported platforms with ifx):
!   Fortran default integer == integer(c_int)  (4 bytes)
!   Fortran default real    == real(c_float)   (4 bytes)
!   Fortran double precision == real(c_double) (8 bytes)

module bmi_c_wrapper

  use iso_c_binding
  use bmiheatf
  use bmif_2_0, only: BMI_SUCCESS, BMI_FAILURE, &
                      BMI_MAX_COMPONENT_NAME, BMI_MAX_VAR_NAME

  implicit none
  private

  integer, parameter :: MAX_STR_LEN = BMI_MAX_VAR_NAME  ! reused for units/type/location

contains

  ! ============================================================
  ! Internal helpers — not exported to C
  ! ============================================================

  subroutine c_to_f_string(c_str, f_str)
    character(kind=c_char), intent(in)  :: c_str(*)
    character(len=*),        intent(out) :: f_str
    integer :: i
    f_str = ' '
    do i = 1, len(f_str)
      if (c_str(i) == c_null_char) exit
      f_str(i:i) = c_str(i)
    end do
  end subroutine c_to_f_string

  subroutine f_to_c_string(f_str, c_str)
    character(len=*),       intent(in)  :: f_str
    character(kind=c_char), intent(out) :: c_str(*)
    integer :: i, slen
    slen = len_trim(f_str)
    do i = 1, slen
      c_str(i) = f_str(i:i)
    end do
    c_str(slen + 1) = c_null_char
  end subroutine f_to_c_string

  ! ============================================================
  ! Lifecycle
  ! ============================================================

  function bmi_create() result(handle) bind(C, name="bmi_create")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_create
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_create
#endif
    type(c_ptr) :: handle
    type(bmi_heat), pointer :: self
    allocate(self)
    handle = c_loc(self)
  end function bmi_create

  subroutine bmi_destroy(handle) bind(C, name="bmi_destroy")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_destroy
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_destroy
#endif
    type(c_ptr), value, intent(in) :: handle
    type(bmi_heat), pointer :: self
    call c_f_pointer(handle, self)
    deallocate(self)
  end subroutine bmi_destroy

  function bmi_initialize(handle, config_file) result(status) &
      bind(C, name="bmi_initialize")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_initialize
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_initialize
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: config_file(*)
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_COMPONENT_NAME) :: config_f
    call c_f_pointer(handle, self)
    call c_to_f_string(config_file, config_f)
    status = int(self%initialize(trim(config_f)), c_int)
  end function bmi_initialize

  function bmi_finalize(handle) result(status) bind(C, name="bmi_finalize")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_finalize
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_finalize
#endif
    type(c_ptr), value, intent(in) :: handle
    integer(c_int)                 :: status
    type(bmi_heat), pointer :: self
    call c_f_pointer(handle, self)
    status = int(self%finalize(), c_int)
  end function bmi_finalize

  ! ============================================================
  ! Model info
  ! ============================================================

  function bmi_get_component_name(handle, name) result(status) &
      bind(C, name="bmi_get_component_name")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_component_name
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_component_name
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(out) :: name(BMI_MAX_COMPONENT_NAME)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_COMPONENT_NAME), pointer :: f_name
    call c_f_pointer(handle, self)
    status = int(self%get_component_name(f_name), c_int)
    if (status == BMI_SUCCESS) call f_to_c_string(f_name, name)
  end function bmi_get_component_name

  function bmi_get_input_item_count(handle, count) result(status) &
      bind(C, name="bmi_get_input_item_count")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_input_item_count
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_input_item_count
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int),        intent(out) :: count
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: count_f
    call c_f_pointer(handle, self)
    status = int(self%get_input_item_count(count_f), c_int)
    count = int(count_f, c_int)
  end function bmi_get_input_item_count

  function bmi_get_output_item_count(handle, count) result(status) &
      bind(C, name="bmi_get_output_item_count")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_output_item_count
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_output_item_count
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int),        intent(out) :: count
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: count_f
    call c_f_pointer(handle, self)
    status = int(self%get_output_item_count(count_f), c_int)
    count = int(count_f, c_int)
  end function bmi_get_output_item_count

  ! names: flat buffer of count * BMI_MAX_VAR_NAME bytes.
  ! Each name occupies a BMI_MAX_VAR_NAME-wide slot, null-terminated.
  ! Caller allocates after bmi_get_input_item_count.
  function bmi_get_input_var_names(handle, names) result(status) &
      bind(C, name="bmi_get_input_var_names")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_input_var_names
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_input_var_names
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(out) :: names(*)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME), pointer :: f_names(:)
    integer :: i, count_f
    call c_f_pointer(handle, self)
    status = int(self%get_input_item_count(count_f), c_int)
    if (status /= BMI_SUCCESS) return
    status = int(self%get_input_var_names(f_names), c_int)
    if (status /= BMI_SUCCESS) return
    do i = 1, count_f
      call f_to_c_string(f_names(i), names((i - 1) * BMI_MAX_VAR_NAME + 1))
    end do
  end function bmi_get_input_var_names

  function bmi_get_output_var_names(handle, names) result(status) &
      bind(C, name="bmi_get_output_var_names")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_output_var_names
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_output_var_names
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(out) :: names(*)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME), pointer :: f_names(:)
    integer :: i, count_f
    call c_f_pointer(handle, self)
    status = int(self%get_output_item_count(count_f), c_int)
    if (status /= BMI_SUCCESS) return
    status = int(self%get_output_var_names(f_names), c_int)
    if (status /= BMI_SUCCESS) return
    do i = 1, count_f
      call f_to_c_string(f_names(i), names((i - 1) * BMI_MAX_VAR_NAME + 1))
    end do
  end function bmi_get_output_var_names

  ! ============================================================
  ! Time
  ! ============================================================

  function bmi_get_start_time(handle, time) result(status) &
      bind(C, name="bmi_get_start_time")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_start_time
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_start_time
#endif
    type(c_ptr),    value, intent(in)  :: handle
    real(c_double),        intent(out) :: time
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision :: time_f
    call c_f_pointer(handle, self)
    status = int(self%get_start_time(time_f), c_int)
    time = real(time_f, c_double)
  end function bmi_get_start_time

  function bmi_get_end_time(handle, time) result(status) &
      bind(C, name="bmi_get_end_time")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_end_time
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_end_time
#endif
    type(c_ptr),    value, intent(in)  :: handle
    real(c_double),        intent(out) :: time
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision :: time_f
    call c_f_pointer(handle, self)
    status = int(self%get_end_time(time_f), c_int)
    time = real(time_f, c_double)
  end function bmi_get_end_time

  function bmi_get_current_time(handle, time) result(status) &
      bind(C, name="bmi_get_current_time")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_current_time
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_current_time
#endif
    type(c_ptr),    value, intent(in)  :: handle
    real(c_double),        intent(out) :: time
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision :: time_f
    call c_f_pointer(handle, self)
    status = int(self%get_current_time(time_f), c_int)
    time = real(time_f, c_double)
  end function bmi_get_current_time

  function bmi_get_time_step(handle, time_step) result(status) &
      bind(C, name="bmi_get_time_step")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_time_step
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_time_step
#endif
    type(c_ptr),    value, intent(in)  :: handle
    real(c_double),        intent(out) :: time_step
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision :: step_f
    call c_f_pointer(handle, self)
    status = int(self%get_time_step(step_f), c_int)
    time_step = real(step_f, c_double)
  end function bmi_get_time_step

  function bmi_get_time_units(handle, units) result(status) &
      bind(C, name="bmi_get_time_units")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_time_units
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_time_units
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(out) :: units(MAX_STR_LEN)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=MAX_STR_LEN) :: units_f
    call c_f_pointer(handle, self)
    status = int(self%get_time_units(units_f), c_int)
    if (status == BMI_SUCCESS) call f_to_c_string(units_f, units)
  end function bmi_get_time_units

  ! ============================================================
  ! Control
  ! ============================================================

  function bmi_update(handle) result(status) bind(C, name="bmi_update")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_update
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_update
#endif
    type(c_ptr), value, intent(in) :: handle
    integer(c_int)                 :: status
    type(bmi_heat), pointer :: self
    call c_f_pointer(handle, self)
    status = int(self%update(), c_int)
  end function bmi_update

  function bmi_update_until(handle, time) result(status) &
      bind(C, name="bmi_update_until")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_update_until
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_update_until
#endif
    type(c_ptr),    value, intent(in) :: handle
    real(c_double), value, intent(in) :: time
    integer(c_int)                    :: status
    type(bmi_heat), pointer :: self
    call c_f_pointer(handle, self)
    status = int(self%update_until(dble(time)), c_int)
  end function bmi_update_until

  ! ============================================================
  ! Variable info
  ! ============================================================

  function bmi_get_var_grid(handle, name, grid) result(status) &
      bind(C, name="bmi_get_var_grid")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_var_grid
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_var_grid
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    integer(c_int),                intent(out) :: grid
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: grid_f
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_var_grid(trim(name_f), grid_f), c_int)
    grid = int(grid_f, c_int)
  end function bmi_get_var_grid

  function bmi_get_var_type(handle, name, var_type) result(status) &
      bind(C, name="bmi_get_var_type")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_var_type
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_var_type
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    character(kind=c_char),        intent(out) :: var_type(MAX_STR_LEN)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    character(len=MAX_STR_LEN) :: type_f
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_var_type(trim(name_f), type_f), c_int)
    if (status == BMI_SUCCESS) call f_to_c_string(type_f, var_type)
  end function bmi_get_var_type

  function bmi_get_var_units(handle, name, units) result(status) &
      bind(C, name="bmi_get_var_units")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_var_units
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_var_units
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    character(kind=c_char),        intent(out) :: units(MAX_STR_LEN)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    character(len=MAX_STR_LEN) :: units_f
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_var_units(trim(name_f), units_f), c_int)
    if (status == BMI_SUCCESS) call f_to_c_string(units_f, units)
  end function bmi_get_var_units

  function bmi_get_var_itemsize(handle, name, itemsize) result(status) &
      bind(C, name="bmi_get_var_itemsize")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_var_itemsize
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_var_itemsize
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    integer(c_int),                intent(out) :: itemsize
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: size_f
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_var_itemsize(trim(name_f), size_f), c_int)
    itemsize = int(size_f, c_int)
  end function bmi_get_var_itemsize

  function bmi_get_var_nbytes(handle, name, nbytes) result(status) &
      bind(C, name="bmi_get_var_nbytes")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_var_nbytes
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_var_nbytes
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    integer(c_int),                intent(out) :: nbytes
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: nbytes_f
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_var_nbytes(trim(name_f), nbytes_f), c_int)
    nbytes = int(nbytes_f, c_int)
  end function bmi_get_var_nbytes

  function bmi_get_var_location(handle, name, location) result(status) &
      bind(C, name="bmi_get_var_location")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_var_location
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_var_location
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    character(kind=c_char),        intent(out) :: location(MAX_STR_LEN)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    character(len=MAX_STR_LEN) :: location_f
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_var_location(trim(name_f), location_f), c_int)
    if (status == BMI_SUCCESS) call f_to_c_string(location_f, location)
  end function bmi_get_var_location

  ! ============================================================
  ! Grid info
  ! ============================================================

  function bmi_get_grid_rank(handle, grid, rank) result(status) &
      bind(C, name="bmi_get_grid_rank")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_rank
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_rank
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: rank
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: rank_f
    call c_f_pointer(handle, self)
    status = int(self%get_grid_rank(int(grid), rank_f), c_int)
    rank = int(rank_f, c_int)
  end function bmi_get_grid_rank

  function bmi_get_grid_size(handle, grid, size) result(status) &
      bind(C, name="bmi_get_grid_size")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_size
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_size
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: size
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: size_f
    call c_f_pointer(handle, self)
    status = int(self%get_grid_size(int(grid), size_f), c_int)
    size = int(size_f, c_int)
  end function bmi_get_grid_size

  function bmi_get_grid_type(handle, grid, grid_type) result(status) &
      bind(C, name="bmi_get_grid_type")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_type
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_type
#endif
    type(c_ptr),            value, intent(in)  :: handle
    integer(c_int),         value, intent(in)  :: grid
    character(kind=c_char),        intent(out) :: grid_type(MAX_STR_LEN)
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=MAX_STR_LEN) :: type_f
    call c_f_pointer(handle, self)
    status = int(self%get_grid_type(int(grid), type_f), c_int)
    if (status == BMI_SUCCESS) call f_to_c_string(type_f, grid_type)
  end function bmi_get_grid_type

  ! n = rank (caller obtains from bmi_get_grid_rank first)
  function bmi_get_grid_shape(handle, grid, shape, n) result(status) &
      bind(C, name="bmi_get_grid_shape")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_shape
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_shape
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    integer(c_int),        intent(out) :: shape(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer, allocatable :: shape_f(:)
    call c_f_pointer(handle, self)
    allocate(shape_f(n))
    status = int(self%get_grid_shape(int(grid), shape_f), c_int)
    shape = int(shape_f, c_int)
    deallocate(shape_f)
  end function bmi_get_grid_shape

  ! n = rank
  function bmi_get_grid_spacing(handle, grid, spacing, n) result(status) &
      bind(C, name="bmi_get_grid_spacing")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_spacing
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_spacing
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    real(c_double),        intent(out) :: spacing(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision, allocatable :: spacing_f(:)
    call c_f_pointer(handle, self)
    allocate(spacing_f(n))
    status = int(self%get_grid_spacing(int(grid), spacing_f), c_int)
    spacing = real(spacing_f, c_double)
    deallocate(spacing_f)
  end function bmi_get_grid_spacing

  ! n = rank
  function bmi_get_grid_origin(handle, grid, origin, n) result(status) &
      bind(C, name="bmi_get_grid_origin")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_origin
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_origin
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    real(c_double),        intent(out) :: origin(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision, allocatable :: origin_f(:)
    call c_f_pointer(handle, self)
    allocate(origin_f(n))
    status = int(self%get_grid_origin(int(grid), origin_f), c_int)
    origin = real(origin_f, c_double)
    deallocate(origin_f)
  end function bmi_get_grid_origin

  function bmi_get_grid_x(handle, grid, x, n) result(status) &
      bind(C, name="bmi_get_grid_x")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_x
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_x
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    real(c_double),        intent(out) :: x(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision, allocatable :: x_f(:)
    call c_f_pointer(handle, self)
    allocate(x_f(n))
    status = int(self%get_grid_x(int(grid), x_f), c_int)
    x = real(x_f, c_double)
    deallocate(x_f)
  end function bmi_get_grid_x

  function bmi_get_grid_y(handle, grid, y, n) result(status) &
      bind(C, name="bmi_get_grid_y")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_y
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_y
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    real(c_double),        intent(out) :: y(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision, allocatable :: y_f(:)
    call c_f_pointer(handle, self)
    allocate(y_f(n))
    status = int(self%get_grid_y(int(grid), y_f), c_int)
    y = real(y_f, c_double)
    deallocate(y_f)
  end function bmi_get_grid_y

  function bmi_get_grid_z(handle, grid, z, n) result(status) &
      bind(C, name="bmi_get_grid_z")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_z
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_z
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    real(c_double),        intent(out) :: z(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    double precision, allocatable :: z_f(:)
    call c_f_pointer(handle, self)
    allocate(z_f(n))
    status = int(self%get_grid_z(int(grid), z_f), c_int)
    z = real(z_f, c_double)
    deallocate(z_f)
  end function bmi_get_grid_z

  function bmi_get_grid_node_count(handle, grid, count) result(status) &
      bind(C, name="bmi_get_grid_node_count")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_node_count
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_node_count
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: count
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: count_f
    call c_f_pointer(handle, self)
    status = int(self%get_grid_node_count(int(grid), count_f), c_int)
    count = int(count_f, c_int)
  end function bmi_get_grid_node_count

  function bmi_get_grid_edge_count(handle, grid, count) result(status) &
      bind(C, name="bmi_get_grid_edge_count")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_edge_count
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_edge_count
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: count
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: count_f
    call c_f_pointer(handle, self)
    status = int(self%get_grid_edge_count(int(grid), count_f), c_int)
    count = int(count_f, c_int)
  end function bmi_get_grid_edge_count

  function bmi_get_grid_face_count(handle, grid, count) result(status) &
      bind(C, name="bmi_get_grid_face_count")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_face_count
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_face_count
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: count
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer :: count_f
    call c_f_pointer(handle, self)
    status = int(self%get_grid_face_count(int(grid), count_f), c_int)
    count = int(count_f, c_int)
  end function bmi_get_grid_face_count

  function bmi_get_grid_edge_nodes(handle, grid, edge_nodes, n) result(status) &
      bind(C, name="bmi_get_grid_edge_nodes")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_edge_nodes
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_edge_nodes
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    integer(c_int),        intent(out) :: edge_nodes(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer, allocatable :: en_f(:)
    call c_f_pointer(handle, self)
    allocate(en_f(n))
    status = int(self%get_grid_edge_nodes(int(grid), en_f), c_int)
    edge_nodes = int(en_f, c_int)
    deallocate(en_f)
  end function bmi_get_grid_edge_nodes

  function bmi_get_grid_face_edges(handle, grid, face_edges, n) result(status) &
      bind(C, name="bmi_get_grid_face_edges")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_face_edges
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_face_edges
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    integer(c_int),        intent(out) :: face_edges(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer, allocatable :: fe_f(:)
    call c_f_pointer(handle, self)
    allocate(fe_f(n))
    status = int(self%get_grid_face_edges(int(grid), fe_f), c_int)
    face_edges = int(fe_f, c_int)
    deallocate(fe_f)
  end function bmi_get_grid_face_edges

  function bmi_get_grid_face_nodes(handle, grid, face_nodes, n) result(status) &
      bind(C, name="bmi_get_grid_face_nodes")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_face_nodes
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_face_nodes
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    integer(c_int),        intent(out) :: face_nodes(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer, allocatable :: fn_f(:)
    call c_f_pointer(handle, self)
    allocate(fn_f(n))
    status = int(self%get_grid_face_nodes(int(grid), fn_f), c_int)
    face_nodes = int(fn_f, c_int)
    deallocate(fn_f)
  end function bmi_get_grid_face_nodes

  function bmi_get_grid_nodes_per_face(handle, grid, nodes_per_face, n) result(status) &
      bind(C, name="bmi_get_grid_nodes_per_face")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_nodes_per_face
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_nodes_per_face
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid, n
    integer(c_int),        intent(out) :: nodes_per_face(n)
    integer(c_int)                     :: status
    type(bmi_heat), pointer :: self
    integer, allocatable :: npf_f(:)
    call c_f_pointer(handle, self)
    allocate(npf_f(n))
    status = int(self%get_grid_nodes_per_face(int(grid), npf_f), c_int)
    nodes_per_face = int(npf_f, c_int)
    deallocate(npf_f)
  end function bmi_get_grid_nodes_per_face

  ! ============================================================
  ! Get values  (n = number of elements in dest)
  ! ============================================================

  function bmi_get_value_int(handle, name, dest, n) result(status) &
      bind(C, name="bmi_get_value_int")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_int
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_int
#endif
    type(c_ptr),            value, intent(in)    :: handle
    character(kind=c_char),        intent(in)    :: name(*)
    integer(c_int),                intent(inout) :: dest(n)
    integer(c_int),         value, intent(in)    :: n
    integer(c_int)                               :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer, allocatable :: dest_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(dest_f(n))
    dest_f = int(dest)
    status = int(self%get_value(trim(name_f), dest_f), c_int)
    dest = int(dest_f, c_int)
    deallocate(dest_f)
  end function bmi_get_value_int

  function bmi_get_value_float(handle, name, dest, n) result(status) &
      bind(C, name="bmi_get_value_float")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_float
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_float
#endif
    type(c_ptr),            value, intent(in)    :: handle
    character(kind=c_char),        intent(in)    :: name(*)
    real(c_float),                 intent(inout) :: dest(n)
    integer(c_int),         value, intent(in)    :: n
    integer(c_int)                               :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    real, allocatable :: dest_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(dest_f(n))
    dest_f = real(dest)
    status = int(self%get_value(trim(name_f), dest_f), c_int)
    dest = real(dest_f, c_float)
    deallocate(dest_f)
  end function bmi_get_value_float

  function bmi_get_value_double(handle, name, dest, n) result(status) &
      bind(C, name="bmi_get_value_double")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_double
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_double
#endif
    type(c_ptr),            value, intent(in)    :: handle
    character(kind=c_char),        intent(in)    :: name(*)
    real(c_double),                intent(inout) :: dest(n)
    integer(c_int),         value, intent(in)    :: n
    integer(c_int)                               :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    double precision, allocatable :: dest_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(dest_f(n))
    dest_f = dble(dest)
    status = int(self%get_value(trim(name_f), dest_f), c_int)
    dest = real(dest_f, c_double)
    deallocate(dest_f)
  end function bmi_get_value_double

  ! Returns a raw C pointer to the model's internal array (zero-copy).
  ! Supported only for plate_surface__temperature (real/float).
  ! Java receives this as a Pointer and can read/write the live model buffer.
  ! dest_ptr is set to c_null_ptr on failure.
  function bmi_get_value_ptr(handle, name, dest_ptr) result(status) &
      bind(C, name="bmi_get_value_ptr")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_ptr
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_ptr
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(in)  :: name(*)
    type(c_ptr),                   intent(out) :: dest_ptr
    integer(c_int)                             :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    real(c_float), pointer :: f_ptr(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    status = int(self%get_value_ptr(trim(name_f), f_ptr), c_int)
    if (status == BMI_SUCCESS .and. associated(f_ptr)) then
      dest_ptr = c_loc(f_ptr(1))
    else
      dest_ptr = c_null_ptr
    end if
  end function bmi_get_value_ptr

  function bmi_get_value_at_indices_int(handle, name, dest, inds, n) result(status) &
      bind(C, name="bmi_get_value_at_indices_int")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_at_indices_int
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_at_indices_int
#endif
    type(c_ptr),            value, intent(in)    :: handle
    character(kind=c_char),        intent(in)    :: name(*)
    integer(c_int),                intent(inout) :: dest(n)
    integer(c_int),                intent(in)    :: inds(n)
    integer(c_int),         value, intent(in)    :: n
    integer(c_int)                               :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer, allocatable :: dest_f(:), inds_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(dest_f(n), inds_f(n))
    dest_f = int(dest)
    inds_f = int(inds)
    status = int(self%get_value_at_indices(trim(name_f), dest_f, inds_f), c_int)
    dest = int(dest_f, c_int)
    deallocate(dest_f, inds_f)
  end function bmi_get_value_at_indices_int

  function bmi_get_value_at_indices_float(handle, name, dest, inds, n) result(status) &
      bind(C, name="bmi_get_value_at_indices_float")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_at_indices_float
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_at_indices_float
#endif
    type(c_ptr),            value, intent(in)    :: handle
    character(kind=c_char),        intent(in)    :: name(*)
    real(c_float),                 intent(inout) :: dest(n)
    integer(c_int),                intent(in)    :: inds(n)
    integer(c_int),         value, intent(in)    :: n
    integer(c_int)                               :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    real, allocatable :: dest_f(:)
    integer, allocatable :: inds_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(dest_f(n), inds_f(n))
    dest_f = real(dest)
    inds_f = int(inds)
    status = int(self%get_value_at_indices(trim(name_f), dest_f, inds_f), c_int)
    dest = real(dest_f, c_float)
    deallocate(dest_f, inds_f)
  end function bmi_get_value_at_indices_float

  function bmi_get_value_at_indices_double(handle, name, dest, inds, n) result(status) &
      bind(C, name="bmi_get_value_at_indices_double")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_value_at_indices_double
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_value_at_indices_double
#endif
    type(c_ptr),            value, intent(in)    :: handle
    character(kind=c_char),        intent(in)    :: name(*)
    real(c_double),                intent(inout) :: dest(n)
    integer(c_int),                intent(in)    :: inds(n)
    integer(c_int),         value, intent(in)    :: n
    integer(c_int)                               :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    double precision, allocatable :: dest_f(:)
    integer, allocatable :: inds_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(dest_f(n), inds_f(n))
    dest_f = dble(dest)
    inds_f = int(inds)
    status = int(self%get_value_at_indices(trim(name_f), dest_f, inds_f), c_int)
    dest = real(dest_f, c_double)
    deallocate(dest_f, inds_f)
  end function bmi_get_value_at_indices_double

  ! ============================================================
  ! Set values  (n = number of elements in src)
  ! ============================================================

  function bmi_set_value_int(handle, name, src, n) result(status) &
      bind(C, name="bmi_set_value_int")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_set_value_int
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_set_value_int
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: name(*)
    integer(c_int),                intent(in) :: src(n)
    integer(c_int),         value, intent(in) :: n
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer, allocatable :: src_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(src_f(n))
    src_f = int(src)
    status = int(self%set_value(trim(name_f), src_f), c_int)
    deallocate(src_f)
  end function bmi_set_value_int

  function bmi_set_value_float(handle, name, src, n) result(status) &
      bind(C, name="bmi_set_value_float")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_set_value_float
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_set_value_float
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: name(*)
    real(c_float),                 intent(in) :: src(n)
    integer(c_int),         value, intent(in) :: n
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    real, allocatable :: src_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(src_f(n))
    src_f = real(src)
    status = int(self%set_value(trim(name_f), src_f), c_int)
    deallocate(src_f)
  end function bmi_set_value_float

  function bmi_set_value_double(handle, name, src, n) result(status) &
      bind(C, name="bmi_set_value_double")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_set_value_double
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_set_value_double
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: name(*)
    real(c_double),                intent(in) :: src(n)
    integer(c_int),         value, intent(in) :: n
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    double precision, allocatable :: src_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(src_f(n))
    src_f = dble(src)
    status = int(self%set_value(trim(name_f), src_f), c_int)
    deallocate(src_f)
  end function bmi_set_value_double

  function bmi_set_value_at_indices_int(handle, name, inds, src, n) result(status) &
      bind(C, name="bmi_set_value_at_indices_int")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_set_value_at_indices_int
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_set_value_at_indices_int
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: name(*)
    integer(c_int),                intent(in) :: inds(n)
    integer(c_int),                intent(in) :: src(n)
    integer(c_int),         value, intent(in) :: n
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer, allocatable :: inds_f(:), src_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(inds_f(n), src_f(n))
    inds_f = int(inds)
    src_f = int(src)
    status = int(self%set_value_at_indices(trim(name_f), inds_f, src_f), c_int)
    deallocate(inds_f, src_f)
  end function bmi_set_value_at_indices_int

  function bmi_set_value_at_indices_float(handle, name, inds, src, n) result(status) &
      bind(C, name="bmi_set_value_at_indices_float")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_set_value_at_indices_float
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_set_value_at_indices_float
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: name(*)
    integer(c_int),                intent(in) :: inds(n)
    real(c_float),                 intent(in) :: src(n)
    integer(c_int),         value, intent(in) :: n
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer, allocatable :: inds_f(:)
    real, allocatable :: src_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(inds_f(n), src_f(n))
    inds_f = int(inds)
    src_f = real(src)
    status = int(self%set_value_at_indices(trim(name_f), inds_f, src_f), c_int)
    deallocate(inds_f, src_f)
  end function bmi_set_value_at_indices_float

  function bmi_set_value_at_indices_double(handle, name, inds, src, n) result(status) &
      bind(C, name="bmi_set_value_at_indices_double")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_set_value_at_indices_double
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_set_value_at_indices_double
#endif
    type(c_ptr),            value, intent(in) :: handle
    character(kind=c_char),        intent(in) :: name(*)
    integer(c_int),                intent(in) :: inds(n)
    real(c_double),                intent(in) :: src(n)
    integer(c_int),         value, intent(in) :: n
    integer(c_int)                            :: status
    type(bmi_heat), pointer :: self
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer, allocatable :: inds_f(:)
    double precision, allocatable :: src_f(:)
    call c_f_pointer(handle, self)
    call c_to_f_string(name, name_f)
    allocate(inds_f(n), src_f(n))
    inds_f = int(inds)
    src_f = dble(src)
    status = int(self%set_value_at_indices(trim(name_f), inds_f, src_f), c_int)
    deallocate(inds_f, src_f)
  end function bmi_set_value_at_indices_double

end module bmi_c_wrapper
