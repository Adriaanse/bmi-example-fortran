/**
 * bmi_from_spec.h
 *
 * C-callable equivalent of the abstract Fortran BMI interface defined in
 * bmi_heat/bmi.f90 (module bmif_2_0, CSDMS BMI v2.0).
 *
 * Generation rules
 * ----------------
 * Each Fortran abstract interface is mapped to a C function signature
 * as mechanically as possible, with the following systematic choices:
 *
 *   class(bmi), intent(*)       -> void* handle
 *   integer / integer, intent(out)  -> int / int*
 *   integer, intent(in)         -> int   (by value; see NOTE 1)
 *   double precision, intent(out)   -> double*
 *   double precision, intent(in)    -> double  (by value; see NOTE 1)
 *   double precision, dimension(:)  -> double*
 *   integer, dimension(:), intent(out/inout) -> int*
 *   integer, dimension(:), intent(in)        -> const int*
 *   real, dimension(:), intent(inout)        -> float*
 *   real, dimension(:), intent(in)           -> const float*
 *   character(len=*), intent(in)    -> const char*  (null-terminated)
 *   character(len=*), intent(out)   -> char*  (caller-allocated; see NOTE 2)
 *   character(len=*), pointer, intent(out)   -> char** (see NOTE 3)
 *   character(len=*), pointer, intent(out) :: names(:) -> char** (see NOTE 4)
 *   TYPE, pointer, intent(inout) :: p(:)  -> TYPE** (see NOTE 5)
 *   function result integer       -> int (C return value)
 *
 * NOTES — deviations from strict Fortran ABI or from bmi.h
 * ---------------------------------------------------------
 *
 * NOTE 1 — Scalar intent(in) arguments passed by value
 *   The Fortran spec (no bind(C), no VALUE attribute) would pass scalars
 *   by reference in the raw Fortran ABI.  However, the spec *intent* is
 *   clearly to pass a value (grid id, time), so C signatures use pass-by-
 *   value, matching what bind(C)+VALUE implementations (like bmi_heat_shared.f90)
 *   actually do.
 *
 * NOTE 2 — Out-string buffer ownership
 *   Fortran `character(len=*), intent(out)` is an assumed-length output
 *   string.  In C we require the caller to pass a pre-allocated buffer.
 *   Minimum sizes: BMI_MAX_COMPONENT_NAME for component names,
 *   BMI_MAX_VAR_NAME for everything else.
 *
 * NOTE 3 — get_component_name: pointer-to-string
 *   The spec has `character(len=*), pointer, intent(out) :: name`, meaning
 *   the implementation sets the pointer to point at its own internal string
 *   (not a copy).  In C: `char** name`; the function sets `*name` to point
 *   into library-owned memory.  The string may NOT be null-terminated and
 *   may have trailing blanks (Fortran convention).  Contrast with bmi.h,
 *   which uses a caller-allocated buffer to avoid these issues.
 *
 * NOTE 4 — get_input/output_var_names: pointer to array of strings
 *   The spec has `character(len=*), pointer, intent(out) :: names(:)`, a
 *   pointer to a rank-1 array of Fortran strings.  In C there is no safe
 *   direct equivalent: `char** names` is used (set to library-owned array
 *   of pointers), but Fortran's array descriptor carries length and extent
 *   information that is lost.  Contrast with bmi.h which uses a flat
 *   caller-allocated byte buffer (count * BMI_MAX_VAR_NAME bytes) with a
 *   fixed stride — safer and JNA-friendly.
 *
 * NOTE 5 — get_value_ptr typed variants (THREE functions in spec)
 *   The spec defines THREE typed pointer functions:
 *     get_value_ptr_int, get_value_ptr_float, get_value_ptr_double
 *   each returning a typed Fortran pointer array.  In C: int**, float**,
 *   double** respectively.  Contrast with bmi.h which collapses all three
 *   into a single `bmi_get_value_ptr(... void** dest_ptr)`.  The spec is
 *   more type-safe; bmi.h trades that for simplicity and JNA compatibility.
 *
 * NOTE 6 — No element count on value / at_indices functions
 *   Fortran assumed-shape arrays (`dest(:)`, `inds(:)`, `src(:)`) carry
 *   their size in the array descriptor — there is NO explicit `n` parameter
 *   in the spec.  In C, the pointer alone carries no size information; the
 *   caller must know the element count from bmi_get_grid_size or
 *   bmi_get_var_nbytes / bmi_get_var_itemsize before calling these functions.
 *   Contrast with bmi.h which adds an explicit `int n` to every
 *   get/set_value* function for safety.
 *
 * NOTE 7 — bmi_create / bmi_destroy not in spec
 *   The Fortran BMI spec has no factory methods.  The abstract type is
 *   instantiated by the concrete implementation (Fortran ALLOCATE or
 *   object construction).  For C/Java interop a heap-allocation pair is
 *   needed; see bmi.h for the Deltares convention.  These functions are
 *   intentionally absent here.
 *
 * NOTE 8 — bmif_initialize this intent(out)
 *   In the spec, `initialize` has `class(bmi), intent(out) :: this`,
 *   meaning the object is constructed *inside* initialize.  In C, the
 *   handle must already exist (from bmi_create or equivalent static
 *   allocation) before initialize is called.  We treat `handle` as
 *   intent(inout) in the C mapping.
 */

#ifndef BMI_FROM_SPEC_H
#define BMI_FROM_SPEC_H

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Constants (from bmif_2_0 module parameters)                         */
/* ------------------------------------------------------------------ */
#define BMI_SUCCESS            0
#define BMI_FAILURE            1
#define BMI_MAX_COMPONENT_NAME 2048
#define BMI_MAX_VAR_NAME       2048
#define BMI_MAX_TYPE_NAME      2048
#define BMI_MAX_UNITS_NAME     2048

/*
 * NOTE 7: bmi_create() and bmi_destroy() are NOT part of the BMI spec.
 * They are required for C/Java interop with Fortran heap-allocated models.
 * See bmi.h for the Deltares convention.
 */

/* ------------------------------------------------------------------ */
/* Initialize, run, finalize (IRF)                                     */
/* ------------------------------------------------------------------ */

/**
 * Perform startup tasks for the model.
 *
 * NOTE 8: In the Fortran spec this has `class(bmi), intent(out) :: this`,
 * meaning the object is initialised inside this function.  In C, `handle`
 * must point to pre-allocated storage (from bmi_create or similar).
 *
 * @param config_file  null-terminated path to the configuration file
 */
int bmi_initialize(void* handle, const char* config_file);

/**
 * Advance the model one time step.
 */
int bmi_update(void* handle);

/**
 * Advance the model until the given time.
 *
 * NOTE 1: Fortran spec has `double precision, intent(in) :: time` (no VALUE
 * attribute), which is technically pass-by-reference in the raw Fortran ABI.
 * Translated to pass-by-value here following the spec intent.
 */
int bmi_update_until(void* handle, double time);

/**
 * Perform teardown tasks for the model.
 */
int bmi_finalize(void* handle);

/* ------------------------------------------------------------------ */
/* Exchange items                                                       */
/* ------------------------------------------------------------------ */

/**
 * Get the name of the model.
 *
 * NOTE 3: Fortran spec has `character(len=*), pointer, intent(out) :: name`.
 * The implementation sets `*name` to point to library-owned memory.
 * The string may NOT be null-terminated; it may have trailing blanks.
 * Use BMI_MAX_COMPONENT_NAME as the maximum expected length.
 */
int bmi_get_component_name(void* handle, char** name);

/**
 * Count a model's input variables.
 */
int bmi_get_input_item_count(void* handle, int* count);

/**
 * Count a model's output variables.
 */
int bmi_get_output_item_count(void* handle, int* count);

/**
 * List a model's input variables.
 *
 * NOTE 4: Fortran spec has `character(len=*), pointer, intent(out) :: names(:)`.
 * The implementation sets `*names` to point to a library-owned array of
 * string pointers.  Each string has up to BMI_MAX_VAR_NAME characters
 * (Fortran blank-padded, not necessarily null-terminated).
 * Call bmi_get_input_item_count first to know how many entries to read.
 */
int bmi_get_input_var_names(void* handle, char** names);

/**
 * List a model's output variables.
 *
 * NOTE 4: same as bmi_get_input_var_names; call bmi_get_output_item_count
 * first.
 */
int bmi_get_output_var_names(void* handle, char** names);

/* ------------------------------------------------------------------ */
/* Variable information                                                 */
/* ------------------------------------------------------------------ */

/**
 * Get the grid identifier for the given variable.
 */
int bmi_get_var_grid(void* handle, const char* name, int* grid);

/**
 * Get the data type of the given variable as a string.
 * @param type  caller-allocated buffer, BMI_MAX_TYPE_NAME bytes  (NOTE 2)
 */
int bmi_get_var_type(void* handle, const char* name, char* type);

/**
 * Get the units of the given variable.
 * @param units  caller-allocated buffer, BMI_MAX_UNITS_NAME bytes  (NOTE 2)
 */
int bmi_get_var_units(void* handle, const char* name, char* units);

/**
 * Get memory use per array element, in bytes.
 */
int bmi_get_var_itemsize(void* handle, const char* name, int* size);

/**
 * Get size of the given variable in bytes (all elements combined).
 */
int bmi_get_var_nbytes(void* handle, const char* name, int* nbytes);

/**
 * Describe where a variable is located: "node", "edge", or "face".
 * @param location  caller-allocated buffer, BMI_MAX_VAR_NAME bytes  (NOTE 2)
 */
int bmi_get_var_location(void* handle, const char* name, char* location);

/* ------------------------------------------------------------------ */
/* Time information                                                     */
/* ------------------------------------------------------------------ */

int bmi_get_current_time(void* handle, double* time);
int bmi_get_start_time  (void* handle, double* time);
int bmi_get_end_time    (void* handle, double* time);

/**
 * @param units  caller-allocated buffer, BMI_MAX_UNITS_NAME bytes  (NOTE 2)
 */
int bmi_get_time_units(void* handle, char* units);

int bmi_get_time_step(void* handle, double* time_step);

/* ------------------------------------------------------------------ */
/* Getters, by type                                                     */
/* ------------------------------------------------------------------ */

/**
 * Get a copy of values (flattened) of the given integer variable.
 *
 * NOTE 6: No element count in spec.  Caller must determine the number of
 * elements via bmi_get_grid_size or bmi_get_var_nbytes/bmi_get_var_itemsize
 * before allocating dest.
 *
 * @param dest  caller-allocated int array, size = get_grid_size(get_var_grid(name))
 */
int bmi_get_value_int   (void* handle, const char* name, int*    dest);

/**
 * Get a copy of values (flattened) of the given real (float) variable.
 * NOTE 6 applies.
 * @param dest  caller-allocated float array
 */
int bmi_get_value_float (void* handle, const char* name, float*  dest);

/**
 * Get a copy of values (flattened) of the given double variable.
 * NOTE 6 applies.
 * @param dest  caller-allocated double array
 */
int bmi_get_value_double(void* handle, const char* name, double* dest);

/**
 * Get a reference (zero-copy) to the given integer variable.
 *
 * NOTE 5: The spec defines THREE typed pointer functions (int, float, double).
 * This is bmi_get_value_ptr_int from the spec — NOT the single void**
 * variant in bmi.h.  The pointer is set to point directly into the model's
 * internal storage.
 *
 * @param dest_ptr  out: *dest_ptr is set to the model's internal int array
 */
int bmi_get_value_ptr_int   (void* handle, const char* name, int**    dest_ptr);

/**
 * Get a reference (zero-copy) to the given real (float) variable.
 * NOTE 5 applies.
 * @param dest_ptr  out: *dest_ptr is set to the model's internal float array
 */
int bmi_get_value_ptr_float (void* handle, const char* name, float**  dest_ptr);

/**
 * Get a reference (zero-copy) to the given double variable.
 * NOTE 5 applies.
 * @param dest_ptr  out: *dest_ptr is set to the model's internal double array
 */
int bmi_get_value_ptr_double(void* handle, const char* name, double** dest_ptr);

/**
 * Get integer values at particular (0-based, flat) indices.
 *
 * NOTE 6: Neither dest nor inds carries an element count.  The caller must
 * know n = length of inds (and pre-allocate dest accordingly).
 *
 * @param dest  caller-allocated int array (n elements)
 * @param inds  array of 0-based flat indices (n elements)
 */
int bmi_get_value_at_indices_int   (void* handle, const char* name,
                                    int*    dest, const int* inds);

/**
 * Get real (float) values at particular (0-based, flat) indices.
 * NOTE 6 applies.
 */
int bmi_get_value_at_indices_float (void* handle, const char* name,
                                    float*  dest, const int* inds);

/**
 * Get double values at particular (0-based, flat) indices.
 * NOTE 6 applies.
 */
int bmi_get_value_at_indices_double(void* handle, const char* name,
                                    double* dest, const int* inds);

/* ------------------------------------------------------------------ */
/* Setters, by type                                                     */
/* ------------------------------------------------------------------ */

/**
 * Set new values for an integer model variable.
 * NOTE 6: No element count in spec; caller must match the variable's size.
 * @param src  int array of values to write
 */
int bmi_set_value_int   (void* handle, const char* name, const int*    src);

/**
 * Set new values for a real (float) model variable.
 * NOTE 6 applies.
 */
int bmi_set_value_float (void* handle, const char* name, const float*  src);

/**
 * Set new values for a double model variable.
 * NOTE 6 applies.
 */
int bmi_set_value_double(void* handle, const char* name, const double* src);

/**
 * Set integer values at particular (0-based, flat) indices.
 * NOTE 6: No element count.  Caller must know the length of inds and src.
 * @param inds  0-based flat index array
 * @param src   values to write at those indices
 */
int bmi_set_value_at_indices_int   (void* handle, const char* name,
                                    const int* inds, const int*    src);

/**
 * Set real (float) values at particular (0-based, flat) indices.
 * NOTE 6 applies.
 */
int bmi_set_value_at_indices_float (void* handle, const char* name,
                                    const int* inds, const float*  src);

/**
 * Set double values at particular (0-based, flat) indices.
 * NOTE 6 applies.
 */
int bmi_set_value_at_indices_double(void* handle, const char* name,
                                    const int* inds, const double* src);

/* ------------------------------------------------------------------ */
/* Grid information                                                     */
/* ------------------------------------------------------------------ */

/**
 * Get the number of dimensions of the computational grid.
 * NOTE 1: grid passed by value (spec intent is a scalar identifier).
 */
int bmi_get_grid_rank(void* handle, int grid, int* rank);

/**
 * Get the total number of elements in the computational grid.
 * NOTE 1 applies.
 */
int bmi_get_grid_size(void* handle, int grid, int* size);

/**
 * Get the grid type as a string (e.g. "uniform_rectilinear", "scalar").
 * @param type  caller-allocated buffer, BMI_MAX_TYPE_NAME bytes  (NOTE 2)
 * NOTE 1 applies.
 */
int bmi_get_grid_type(void* handle, int grid, char* type);

/* Uniform rectilinear -------------------------------------------- */

/**
 * Get the dimensions of the computational grid.
 * shape[0] = number of rows (y / n_y), shape[1] = number of columns (x / n_x).
 * @param shape  caller-allocated int array, rank elements
 */
int bmi_get_grid_shape  (void* handle, int grid, int*    shape);

/**
 * Get distance between nodes of the computational grid.
 * Spec uses double precision; spacing[0] = dy, spacing[1] = dx.
 * @param spacing  caller-allocated double array, rank elements
 */
int bmi_get_grid_spacing(void* handle, int grid, double* spacing);

/**
 * Get coordinates of the origin of the computational grid.
 * Spec uses double precision.
 * @param origin  caller-allocated double array, rank elements
 */
int bmi_get_grid_origin (void* handle, int grid, double* origin);

/* Non-uniform rectilinear / curvilinear -------------------------- */

/**
 * Get the x-coordinates of the nodes.
 * Spec uses double precision, dimension(:).
 * @param x  caller-allocated double array, get_grid_node_count elements
 */
int bmi_get_grid_x(void* handle, int grid, double* x);

/**
 * Get the y-coordinates of the nodes.
 * @param y  caller-allocated double array, get_grid_node_count elements
 */
int bmi_get_grid_y(void* handle, int grid, double* y);

/**
 * Get the z-coordinates of the nodes.
 * @param z  caller-allocated double array, get_grid_node_count elements
 */
int bmi_get_grid_z(void* handle, int grid, double* z);

/* Unstructured --------------------------------------------------- */

int bmi_get_grid_node_count(void* handle, int grid, int* count);
int bmi_get_grid_edge_count(void* handle, int grid, int* count);
int bmi_get_grid_face_count(void* handle, int grid, int* count);

/**
 * Get the edge-node connectivity.
 * @param edge_nodes  caller-allocated int array, 2 * get_grid_edge_count elements
 */
int bmi_get_grid_edge_nodes    (void* handle, int grid, int* edge_nodes);

/**
 * Get the face-edge connectivity.
 * @param face_edges  caller-allocated int array, sum of nodes_per_face elements
 */
int bmi_get_grid_face_edges    (void* handle, int grid, int* face_edges);

/**
 * Get the face-node connectivity.
 * @param face_nodes  caller-allocated int array, sum of nodes_per_face elements
 */
int bmi_get_grid_face_nodes    (void* handle, int grid, int* face_nodes);

/**
 * Get the number of nodes for each face.
 * @param nodes_per_face  caller-allocated int array, get_grid_face_count elements
 */
int bmi_get_grid_nodes_per_face(void* handle, int grid, int* nodes_per_face);

#ifdef __cplusplus
}
#endif

#endif /* BMI_FROM_SPEC_H */
