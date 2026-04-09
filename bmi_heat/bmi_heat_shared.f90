! bmi_heat_shared.f90
!
! Flat, C-interoperable BMI implementation for the 2D heat equation.
! Replaces both bmi_heat.f90 (Fortran OO layer) and bmi_c_wrapper.f90.
!
! Design:
!   - Caller holds an opaque c_ptr (long in Java) to a heap-allocated heat_model.
!   - All functions use bind(C) directly — no abstract type, no OO layer.
!   - Preprocessor guards select DEC$ (Windows) vs GCC$ (Linux) visibility.
!   - Build with //fpp (Windows ifx) or -fpp (Linux ifx).
!
! String conventions (Java/JNA):
!   In  : null-terminated char* -> character(kind=c_char)(*)
!   Out : caller-allocated buffer of BMI_MAX_* bytes, null-terminated
!   Var-name lists: flat buffer, BMI_MAX_VAR_NAME bytes per slot, null-terminated
!
! Array conventions:
!   All get/set_value* carry explicit integer(c_int) n (element count).
!   Grid shape/spacing/origin arrays: caller knows size from get_grid_rank.
!
! Type mapping (ifx, all platforms):
!   default integer  -> integer(c_int)   4 bytes
!   default real     -> real(c_float)    4 bytes
!   double precision -> real(c_double)   8 bytes

module bmi_heat_shared

  use iso_c_binding
  use heatf
  use bmif_2_0, only: BMI_SUCCESS, BMI_FAILURE, &
                      BMI_MAX_COMPONENT_NAME, BMI_MAX_VAR_NAME

  implicit none
  private

  integer, parameter :: INPUT_ITEM_COUNT  = 3
  integer, parameter :: OUTPUT_ITEM_COUNT = 1

contains

  ! ============================================================
  ! String helpers (not exported)
  ! ============================================================

  integer function strlen(c_str)
    character(kind=c_char), intent(in) :: c_str(*)
    integer :: i
    strlen = 0
    do i = 1, BMI_MAX_COMPONENT_NAME
      if (c_str(i) == c_null_char) then
        strlen = i - 1
        return
      end if
    end do
  end function strlen

  ! Convert null-terminated C string to blank-padded Fortran string.
  subroutine char_array_to_string(c_str, f_str)
    character(kind=c_char), intent(in)  :: c_str(*)
    character(len=*),        intent(out) :: f_str
    integer :: i
    f_str = ' '
    do i = 1, len(f_str)
      if (c_str(i) == c_null_char) exit
      f_str(i:i) = c_str(i)
    end do
  end subroutine char_array_to_string

  ! Write null-terminated Fortran string into a C char buffer.
  subroutine string_to_char_array(f_str, c_str)
    character(len=*),        intent(in)  :: f_str
    character(kind=c_char),  intent(out) :: c_str(*)
    integer :: i, n
    n = len_trim(f_str)
    do i = 1, n
      c_str(i) = f_str(i:i)
    end do
    c_str(n + 1) = c_null_char
  end subroutine string_to_char_array

  ! Pack one name into a flat BMI_MAX_VAR_NAME-stride buffer at slot index
  ! (0-based slot).
  subroutine pack_name(name, buf, slot)
    character(len=*),        intent(in)  :: name
    character(kind=c_char),  intent(out) :: buf(*)
    integer,                 intent(in)  :: slot
    integer :: i, n, base
    base = slot * BMI_MAX_VAR_NAME
    n = len_trim(name)
    do i = 1, n
      buf(base + i) = name(i:i)
    end do
    buf(base + n + 1) = c_null_char
  end subroutine pack_name

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
    type(heat_model), pointer :: m
    allocate(m)
    handle = c_loc(m)
  end function bmi_create

  subroutine bmi_destroy(handle) bind(C, name="bmi_destroy")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_destroy
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_destroy
#endif
    type(c_ptr), value, intent(in) :: handle
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    deallocate(m)
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_COMPONENT_NAME) :: path
    call c_f_pointer(handle, m)
    call char_array_to_string(config_file, path)
    if (len_trim(path) > 0) then
      call initialize_from_file(m, trim(path))
    else
      call initialize_from_defaults(m)
    end if
    status = BMI_SUCCESS
  end function bmi_initialize

  function bmi_finalize(handle) result(status) bind(C, name="bmi_finalize")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_finalize
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_finalize
#endif
    type(c_ptr), value, intent(in) :: handle
    integer(c_int)                 :: status
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    call cleanup(m)
    status = BMI_SUCCESS
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
    call string_to_char_array("The 2D Heat Equation", name)
    status = BMI_SUCCESS
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
    count = INPUT_ITEM_COUNT
    status = BMI_SUCCESS
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
    count = OUTPUT_ITEM_COUNT
    status = BMI_SUCCESS
  end function bmi_get_output_item_count

  ! names: flat buffer, INPUT_ITEM_COUNT * BMI_MAX_VAR_NAME bytes.
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
    call pack_name("plate_surface__temperature",        names, 0)
    call pack_name("plate_surface__thermal_diffusivity", names, 1)
    call pack_name("model__identification_number",       names, 2)
    status = BMI_SUCCESS
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
    call pack_name("plate_surface__temperature", names, 0)
    status = BMI_SUCCESS
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
    time = 0.0_c_double
    status = BMI_SUCCESS
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
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    time = real(m%t_end, c_double)
    status = BMI_SUCCESS
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
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    time = real(m%t, c_double)
    status = BMI_SUCCESS
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
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    time_step = real(m%dt, c_double)
    status = BMI_SUCCESS
  end function bmi_get_time_step

  function bmi_get_time_units(handle, units) result(status) &
      bind(C, name="bmi_get_time_units")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_time_units
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_time_units
#endif
    type(c_ptr),            value, intent(in)  :: handle
    character(kind=c_char),        intent(out) :: units(BMI_MAX_VAR_NAME)
    integer(c_int)                             :: status
    call string_to_char_array("s", units)
    status = BMI_SUCCESS
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
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    call advance_in_time(m)
    status = BMI_SUCCESS
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
    type(heat_model), pointer :: m
    integer :: n_steps, i
    real :: dt_save
    call c_f_pointer(handle, m)
    if (time < real(m%t, c_double)) then
      status = BMI_FAILURE
      return
    end if
    n_steps = int((time - real(m%t, c_double)) / real(m%dt, c_double))
    do i = 1, n_steps
      call advance_in_time(m)
    end do
    if (real(m%t, c_double) < time) then
      dt_save = m%dt
      m%dt = real(time - real(m%t, c_double))
      call advance_in_time(m)
      m%dt = dt_save
    end if
    status = BMI_SUCCESS
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
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      grid = 0; status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity", "model__identification_number")
      grid = 1; status = BMI_SUCCESS
    case default
      grid = -1; status = BMI_FAILURE
    end select
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
    character(kind=c_char),        intent(out) :: var_type(BMI_MAX_VAR_NAME)
    integer(c_int)                             :: status
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature", "plate_surface__thermal_diffusivity")
      call string_to_char_array("real", var_type)
      status = BMI_SUCCESS
    case("model__identification_number")
      call string_to_char_array("integer", var_type)
      status = BMI_SUCCESS
    case default
      call string_to_char_array("-", var_type)
      status = BMI_FAILURE
    end select
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
    character(kind=c_char),        intent(out) :: units(BMI_MAX_VAR_NAME)
    integer(c_int)                             :: status
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      call string_to_char_array("K", units);      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      call string_to_char_array("m2 s-1", units); status = BMI_SUCCESS
    case("model__identification_number")
      call string_to_char_array("1", units);      status = BMI_SUCCESS
    case default
      call string_to_char_array("-", units);      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      itemsize = int(sizeof(m%temperature(1,1)), c_int); status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      itemsize = int(sizeof(m%alpha), c_int);            status = BMI_SUCCESS
    case("model__identification_number")
      itemsize = int(sizeof(m%id), c_int);               status = BMI_SUCCESS
    case default
      itemsize = -1; status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      nbytes = int(sizeof(m%temperature(1,1)), c_int) * m%n_x * m%n_y
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      nbytes = int(sizeof(m%alpha), c_int); status = BMI_SUCCESS
    case("model__identification_number")
      nbytes = int(sizeof(m%id), c_int);   status = BMI_SUCCESS
    case default
      nbytes = -1; status = BMI_FAILURE
    end select
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
    character(kind=c_char),        intent(out) :: location(BMI_MAX_VAR_NAME)
    integer(c_int)                             :: status
    call string_to_char_array("node", location)
    status = BMI_SUCCESS
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
    select case(grid)
    case(0); rank = 2; status = BMI_SUCCESS
    case(1); rank = 0; status = BMI_SUCCESS
    case default; rank = -1; status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    select case(grid)
    case(0); size = int(m%n_x * m%n_y, c_int); status = BMI_SUCCESS
    case(1); size = 1_c_int;                    status = BMI_SUCCESS
    case default; size = -1_c_int;              status = BMI_FAILURE
    end select
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
    character(kind=c_char),        intent(out) :: grid_type(BMI_MAX_VAR_NAME)
    integer(c_int)                             :: status
    select case(grid)
    case(0)
      call string_to_char_array("uniform_rectilinear", grid_type)
      status = BMI_SUCCESS
    case(1)
      call string_to_char_array("scalar", grid_type)
      status = BMI_SUCCESS
    case default
      call string_to_char_array("-", grid_type)
      status = BMI_FAILURE
    end select
  end function bmi_get_grid_type

  ! shape(1)=n_rows (n_y), shape(2)=n_cols (n_x) — BMI row-major convention.
  function bmi_get_grid_shape(handle, grid, shape) result(status) &
      bind(C, name="bmi_get_grid_shape")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_shape
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_shape
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: shape(*)
    integer(c_int)                     :: status
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    if (grid == 0) then
      shape(1) = int(m%n_y, c_int)
      shape(2) = int(m%n_x, c_int)
      status = BMI_SUCCESS
    else
      status = BMI_FAILURE
    end if
  end function bmi_get_grid_shape

  ! spacing(1)=dy, spacing(2)=dx — same order as shape.
  function bmi_get_grid_spacing(handle, grid, spacing) result(status) &
      bind(C, name="bmi_get_grid_spacing")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_spacing
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_spacing
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    real(c_double),        intent(out) :: spacing(*)
    integer(c_int)                     :: status
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    if (grid == 0) then
      spacing(1) = real(m%dy, c_double)
      spacing(2) = real(m%dx, c_double)
      status = BMI_SUCCESS
    else
      status = BMI_FAILURE
    end if
  end function bmi_get_grid_spacing

  function bmi_get_grid_origin(handle, grid, origin) result(status) &
      bind(C, name="bmi_get_grid_origin")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_origin
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_origin
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    real(c_double),        intent(out) :: origin(*)
    integer(c_int)                     :: status
    if (grid == 0) then
      origin(1) = 0.0_c_double
      origin(2) = 0.0_c_double
      status = BMI_SUCCESS
    else
      status = BMI_FAILURE
    end if
  end function bmi_get_grid_origin

  function bmi_get_grid_x(handle, grid, x) result(status) &
      bind(C, name="bmi_get_grid_x")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_x
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_x
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    real(c_double),        intent(out) :: x(*)
    integer(c_int)                     :: status
    if (grid == 1) then; x(1) = 0.0_c_double; status = BMI_SUCCESS
    else;                                       status = BMI_FAILURE
    end if
  end function bmi_get_grid_x

  function bmi_get_grid_y(handle, grid, y) result(status) &
      bind(C, name="bmi_get_grid_y")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_y
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_y
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    real(c_double),        intent(out) :: y(*)
    integer(c_int)                     :: status
    if (grid == 1) then; y(1) = 0.0_c_double; status = BMI_SUCCESS
    else;                                       status = BMI_FAILURE
    end if
  end function bmi_get_grid_y

  function bmi_get_grid_z(handle, grid, z) result(status) &
      bind(C, name="bmi_get_grid_z")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_z
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_z
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    real(c_double),        intent(out) :: z(*)
    integer(c_int)                     :: status
    if (grid == 1) then; z(1) = 0.0_c_double; status = BMI_SUCCESS
    else;                                       status = BMI_FAILURE
    end if
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
    type(heat_model), pointer :: m
    call c_f_pointer(handle, m)
    select case(grid)
    case(0); count = int(m%n_x * m%n_y, c_int); status = BMI_SUCCESS
    case(1); count = 1_c_int;                    status = BMI_SUCCESS
    case default; count = -1_c_int;              status = BMI_FAILURE
    end select
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
    count = -1_c_int; status = BMI_FAILURE
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
    count = -1_c_int; status = BMI_FAILURE
  end function bmi_get_grid_face_count

  function bmi_get_grid_edge_nodes(handle, grid, edge_nodes) result(status) &
      bind(C, name="bmi_get_grid_edge_nodes")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_edge_nodes
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_edge_nodes
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: edge_nodes(*)
    integer(c_int)                     :: status
    status = BMI_FAILURE
  end function bmi_get_grid_edge_nodes

  function bmi_get_grid_face_edges(handle, grid, face_edges) result(status) &
      bind(C, name="bmi_get_grid_face_edges")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_face_edges
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_face_edges
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: face_edges(*)
    integer(c_int)                     :: status
    status = BMI_FAILURE
  end function bmi_get_grid_face_edges

  function bmi_get_grid_face_nodes(handle, grid, face_nodes) result(status) &
      bind(C, name="bmi_get_grid_face_nodes")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_face_nodes
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_face_nodes
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: face_nodes(*)
    integer(c_int)                     :: status
    status = BMI_FAILURE
  end function bmi_get_grid_face_nodes

  function bmi_get_grid_nodes_per_face(handle, grid, nodes_per_face) result(status) &
      bind(C, name="bmi_get_grid_nodes_per_face")
#ifdef _WIN32
    !DEC$ ATTRIBUTES DLLEXPORT :: bmi_get_grid_nodes_per_face
#else
    !GCC$ ATTRIBUTES VISIBILITY :: bmi_get_grid_nodes_per_face
#endif
    type(c_ptr),    value, intent(in)  :: handle
    integer(c_int), value, intent(in)  :: grid
    integer(c_int),        intent(out) :: nodes_per_face(*)
    integer(c_int)                     :: status
    status = BMI_FAILURE
  end function bmi_get_grid_nodes_per_face

  ! ============================================================
  ! Get values
  ! temperature is stored as real(c_float); upcasting to double where needed.
  ! Zero-copy pointer is only available for real(c_float) (plate_surface__temperature).
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("model__identification_number")
      dest(1) = int(m%id, c_int); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: src
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      src = c_loc(m%temperature(1,1))
      call c_f_pointer(src, flat, [m%n_y * m%n_x])
      dest(1:n) = flat(1:n)
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      dest(1) = real(m%alpha, c_float); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: src
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      src = c_loc(m%temperature(1,1))
      call c_f_pointer(src, flat, [m%n_y * m%n_x])
      do i = 1, n
        dest(i) = real(flat(i), c_double)
      end do
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      dest(1) = real(m%alpha, c_double); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
  end function bmi_get_value_double

  ! Returns raw pointer into the model's internal buffer (zero-copy).
  ! Only plate_surface__temperature is supported (stored as real/c_float).
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      dest_ptr = c_loc(m%temperature(1,1)); status = BMI_SUCCESS
    case default
      dest_ptr = c_null_ptr; status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("model__identification_number")
      do i = 1, n
        dest(i) = int(m%id, c_int)
      end do
      status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: src
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      src = c_loc(m%temperature(1,1))
      call c_f_pointer(src, flat, [m%n_y * m%n_x])
      do i = 1, n
        dest(i) = flat(inds(i))
      end do
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      do i = 1, n; dest(i) = real(m%alpha, c_float); end do
      status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: src
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      src = c_loc(m%temperature(1,1))
      call c_f_pointer(src, flat, [m%n_y * m%n_x])
      do i = 1, n
        dest(i) = real(flat(inds(i)), c_double)
      end do
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      do i = 1, n; dest(i) = real(m%alpha, c_double); end do
      status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
  end function bmi_get_value_at_indices_double

  ! ============================================================
  ! Set values
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("model__identification_number")
      m%id = int(src(1)); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: dest
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      dest = c_loc(m%temperature(1,1))
      call c_f_pointer(dest, flat, [m%n_y * m%n_x])
      flat(1:n) = src(1:n)
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      m%alpha = real(src(1)); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: dest
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      dest = c_loc(m%temperature(1,1))
      call c_f_pointer(dest, flat, [m%n_y * m%n_x])
      do i = 1, n
        flat(i) = real(src(i))
      end do
      status = BMI_SUCCESS
    case("plate_surface__thermal_diffusivity")
      m%alpha = real(src(1)); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    character(len=BMI_MAX_VAR_NAME) :: name_f
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("model__identification_number")
      m%id = int(src(1)); status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: dest
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      dest = c_loc(m%temperature(1,1))
      call c_f_pointer(dest, flat, [m%n_y * m%n_x])
      do i = 1, n
        flat(inds(i)) = src(i)
      end do
      status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
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
    type(heat_model), pointer :: m
    real(c_float), pointer :: flat(:)
    type(c_ptr) :: dest
    character(len=BMI_MAX_VAR_NAME) :: name_f
    integer :: i
    call c_f_pointer(handle, m)
    call char_array_to_string(name, name_f)
    select case(trim(name_f))
    case("plate_surface__temperature")
      dest = c_loc(m%temperature(1,1))
      call c_f_pointer(dest, flat, [m%n_y * m%n_x])
      do i = 1, n
        flat(inds(i)) = real(src(i))
      end do
      status = BMI_SUCCESS
    case default
      status = BMI_FAILURE
    end select
  end function bmi_set_value_at_indices_double

end module bmi_heat_shared
