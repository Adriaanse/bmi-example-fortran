/**
 * bmi.h
 *
 * C header for the exported symbols of libbmi_heat (.so / .dll).
 *
 * These are the actual bind(C) function names exported by:
 *   bmi_heat/iso_c_bmif_2_0.f90  — generic C-interop layer (all BMI methods)
 *   bmi_heat/register_bmi.f90    — model-specific factory function
 *
 * Relationship to bmi_from_spec.h
 * --------------------------------
 * bmi_from_spec.h was derived mechanically from the abstract Fortran spec and
 * adds a `bmi_` prefix to every function. THIS file matches the ACTUAL exported
 * symbols, which have NO prefix.  The two files also differ in ABI for several
 * parameters — see the DIFFERENCES section below.
 *
 * DIFFERENCES from bmi_from_spec.h
 * ---------------------------------
 *
 * DIFF 1 — No bmi_ prefix
 *   Every symbol is exported without the bmi_ prefix (e.g., initialize, not
 *   bmi_initialize).  Constraint from the NOAA-OWP iso_c_fortran_bmi pattern.
 *
 * DIFF 2 — register_bmi factory / finalize cleanup
 *   register_bmi(void** handle) allocates the model and returns an opaque
 *   handle. finalize(void* handle) BOTH runs the BMI finalize AND deallocates
 *   the model (it replaces bmi_destroy). There is no separate bmi_destroy.
 *
 * DIFF 3 — Scalar intent(in) parameters passed by reference (NOT by value)
 *   The Fortran iso_c_bmif_2_0.f90 functions do NOT use the Fortran VALUE
 *   attribute for scalar intent(in) parameters such as `grid` (int) and `time`
 *   (double). Without VALUE the Fortran bind(C) ABI passes these by reference.
 *   Affected functions:
 *     update_until           — time is  const double*  (not double)
 *     get_grid_rank          — grid is  const int*     (not int)
 *     get_grid_size          — grid is  const int*
 *     get_grid_type          — grid is  const int*
 *     get_grid_shape         — grid is  const int*
 *     get_grid_spacing       — grid is  const int*
 *     get_grid_origin        — grid is  const int*
 *     get_grid_x/y/z         — grid is  const int*
 *     get_grid_node/edge/face_count   — grid is const int*
 *     get_grid_edge_nodes    — grid is  const int*
 *     get_grid_face_edges    — grid is  const int*
 *     get_grid_face_nodes    — grid is  const int*
 *     get_grid_nodes_per_face — grid is const int*
 *   This differs from bmi_from_spec.h NOTE 1, which mapped these to by-value.
 *
 * DIFF 4 — get_component_name uses a caller-allocated buffer (char*)
 *   iso_c_bmif_2_0.f90 copies the component name into a caller-provided char
 *   buffer (dimension(*), intent(out)).  Minimum size: BMI_MAX_COMPONENT_NAME.
 *   This differs from bmi_from_spec.h NOTE 3 which used char** (pointer-set).
 *
 * DIFF 5 — get_input/output_var_names takes void** (array of pre-allocated buffers)
 *   The Fortran parameter is `type(c_ptr), intent(inout) :: names(*)`, i.e. an
 *   assumed-size array of c_ptr. Each names[i] must already point to a caller-
 *   allocated buffer of BMI_MAX_VAR_NAME bytes before the call; the function
 *   writes the null-terminated variable name into each buffer.  Call
 *   get_input_item_count / get_output_item_count first to know how many
 *   elements to prepare.
 *
 * DIFF 6 — get_value_ptr_* takes void** (type(c_ptr) passed by reference)
 *   The Fortran parameter is `type(c_ptr) :: dest_ptr` (no VALUE, no intent)
 *   which maps to void** in C — a pointer to a void* that the function sets.
 *   NOTE: these three functions are currently STUB IMPLEMENTATIONS that set
 *   *dest_ptr = NULL and return BMI_FAILURE.
 *
 * KNOWN BUGS in iso_c_bmif_2_0.f90 (do NOT modify that file per constraints)
 * ---------------------------------------------------------------------------
 * BUG 1 — get_grid_edge_nodes: line 893 reads
 *     bmi_status = 2 * bmi_box%ptr%get_grid_edge_count(grid, num_nodes)
 *   which multiplies the returned BMI status by 2 instead of doubling num_nodes.
 *   Correct intent was:
 *     bmi_status = bmi_box%ptr%get_grid_edge_count(grid, num_nodes)
 *     num_nodes  = 2 * num_nodes
 *   Result: get_grid_edge_nodes will silently pass only 1 element to the
 *   underlying Fortran array slice instead of 2*edge_count elements.
 *   Workaround: call get_grid_node_count to derive the expected buffer size
 *   independently; the returned edge_nodes data may still be correct if the
 *   underlying model fills the full array, but this is not guaranteed.
 *
 * BUG 2 — get_value_at_indices_*, set_value_at_indices_*: STUB IMPLEMENTATIONS
 *   All six functions simply return BMI_FAILURE (lines 517–680). Do not rely on
 *   indexed get/set operations.
 */

#ifndef BMI_H
#define BMI_H

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Constants                                                            */
/* ------------------------------------------------------------------ */
#define BMI_SUCCESS             0
#define BMI_FAILURE             1
#define BMI_MAX_COMPONENT_NAME  2048
#define BMI_MAX_VAR_NAME        2048
#define BMI_MAX_TYPE_NAME       2048
#define BMI_MAX_UNITS_NAME      2048

/* ------------------------------------------------------------------ */
/* Lifecycle                                                            */
/* ------------------------------------------------------------------ */

/**
 * Allocate a new model instance and return an opaque handle.
 *
 * DIFF 2: This is the factory function — replaces bmi_create().
 * @param handle  out: set to an opaque pointer identifying the model instance
 * @return BMI_SUCCESS or BMI_FAILURE
 */
int register_bmi(void** handle);

/**
 * Perform startup tasks for the model.
 *
 * @param handle       opaque model handle from register_bmi()
 * @param config_file  null-terminated path to the configuration file
 */
int initialize(void* handle, const char* config_file);

/**
 * Advance the model by one internal time step.
 */
int update(void* handle);

/**
 * Advance the model until the given model time.
 *
 * DIFF 3: time is passed by reference (const double*), not by value.
 * @param time  pointer to the target time value
 */
int update_until(void* handle, const double* time);

/**
 * Perform teardown tasks for the model AND deallocate the model instance.
 *
 * DIFF 2: finalize() also frees the memory allocated by register_bmi().
 * Do NOT use handle after calling finalize().  There is no separate
 * bmi_destroy() — this function replaces it.
 */
int finalize(void* handle);

/* ------------------------------------------------------------------ */
/* Model information                                                    */
/* ------------------------------------------------------------------ */

/**
 * Get the name of the model component.
 *
 * DIFF 4: Uses a caller-allocated buffer (char*), not char**.
 * @param name  caller-allocated buffer, at least BMI_MAX_COMPONENT_NAME bytes
 */
int get_component_name(void* handle, char* name);

/** Count a model's input variables. */
int get_input_item_count(void* handle, int* count);

/** Count a model's output variables. */
int get_output_item_count(void* handle, int* count);

/**
 * List a model's input variables.
 *
 * DIFF 5: names is an array of pre-allocated char buffers (void**).
 * Before calling, allocate count buffers of BMI_MAX_VAR_NAME bytes each and
 * store their addresses in names[0..count-1].  The function writes each
 * null-terminated variable name into the corresponding buffer.
 *
 * @param names  array of count pre-allocated char* buffers
 */
int get_input_var_names(void* handle, void** names);

/**
 * List a model's output variables.
 * DIFF 5 applies; see get_input_var_names.
 */
int get_output_var_names(void* handle, void** names);

/* ------------------------------------------------------------------ */
/* Variable information                                                 */
/* ------------------------------------------------------------------ */

/** Get the grid identifier for the given variable. */
int get_var_grid(void* handle, const char* name, int* grid);

/**
 * Get the data type of the given variable as a string.
 * @param type  caller-allocated buffer, BMI_MAX_TYPE_NAME bytes
 */
int get_var_type(void* handle, const char* name, char* type);

/**
 * Get the units of the given variable.
 * @param units  caller-allocated buffer, BMI_MAX_UNITS_NAME bytes
 */
int get_var_units(void* handle, const char* name, char* units);

/** Get memory use per array element, in bytes. */
int get_var_itemsize(void* handle, const char* name, int* size);

/** Get total size of the variable in bytes (all elements combined). */
int get_var_nbytes(void* handle, const char* name, int* nbytes);

/**
 * Get the location of the variable on the grid: "node", "edge", or "face".
 * @param location  caller-allocated buffer, BMI_MAX_VAR_NAME bytes
 */
int get_var_location(void* handle, const char* name, char* location);

/* ------------------------------------------------------------------ */
/* Time information                                                     */
/* ------------------------------------------------------------------ */

int get_current_time(void* handle, double* time);
int get_start_time  (void* handle, double* time);
int get_end_time    (void* handle, double* time);

/**
 * @param units  caller-allocated buffer, BMI_MAX_UNITS_NAME bytes
 */
int get_time_units(void* handle, char* units);
int get_time_step (void* handle, double* time_step);

/* ------------------------------------------------------------------ */
/* Getters — full array copy                                            */
/* ------------------------------------------------------------------ */

/**
 * Get a flattened copy of the given integer variable.
 * Caller must pre-allocate dest: use get_var_nbytes / get_var_itemsize to
 * determine the element count before calling.
 */
int get_value_int   (void* handle, const char* name, int*    dest);
int get_value_float (void* handle, const char* name, float*  dest);
int get_value_double(void* handle, const char* name, double* dest);

/* ------------------------------------------------------------------ */
/* Getters — zero-copy reference                                        */
/* ------------------------------------------------------------------ */

/**
 * Get a pointer directly into the model's internal storage.
 *
 * DIFF 6: dest_ptr is type(c_ptr) without VALUE → C void**; the function
 * sets *dest_ptr to the model's internal array.
 *
 * NOTE: CURRENTLY STUB IMPLEMENTATIONS — always return BMI_FAILURE and set
 * *dest_ptr = NULL (iso_c_bmif_2_0.f90, lines 477–507).
 *
 * @param dest_ptr  out: *dest_ptr is set to model-internal storage (or NULL)
 */
int get_value_ptr_int   (void* handle, const char* name, void** dest_ptr);
int get_value_ptr_float (void* handle, const char* name, void** dest_ptr);
int get_value_ptr_double(void* handle, const char* name, void** dest_ptr);

/* ------------------------------------------------------------------ */
/* Getters — indexed                                                    */
/* ------------------------------------------------------------------ */

/**
 * Get values at particular (0-based flat) indices.
 *
 * NOTE: CURRENTLY STUB IMPLEMENTATIONS — always return BMI_FAILURE
 * (iso_c_bmif_2_0.f90, lines 509–540).
 *
 * @param dest  caller-allocated array, n elements
 * @param inds  array of 0-based flat indices, n elements
 */
int get_value_at_indices_int   (void* handle, const char* name,
                                int*    dest, const int* inds);
int get_value_at_indices_float (void* handle, const char* name,
                                float*  dest, const int* inds);
int get_value_at_indices_double(void* handle, const char* name,
                                double* dest, const int* inds);

/* ------------------------------------------------------------------ */
/* Setters — full array                                                 */
/* ------------------------------------------------------------------ */

/**
 * Set new values for the given variable.
 * Caller must ensure src has the correct element count (see get_var_nbytes).
 */
int set_value_int   (void* handle, const char* name, const int*    src);
int set_value_float (void* handle, const char* name, const float*  src);
int set_value_double(void* handle, const char* name, const double* src);

/* ------------------------------------------------------------------ */
/* Setters — indexed                                                    */
/* ------------------------------------------------------------------ */

/**
 * Set values at particular (0-based flat) indices.
 *
 * NOTE: CURRENTLY STUB IMPLEMENTATIONS — always return BMI_FAILURE
 * (iso_c_bmif_2_0.f90, lines 649–680).
 *
 * @param inds  0-based flat index array
 * @param src   values to write at those indices
 */
int set_value_at_indices_int   (void* handle, const char* name,
                                const int* inds, const int*    src);
int set_value_at_indices_float (void* handle, const char* name,
                                const int* inds, const float*  src);
int set_value_at_indices_double(void* handle, const char* name,
                                const int* inds, const double* src);

/* ------------------------------------------------------------------ */
/* Grid information                                                     */
/* ------------------------------------------------------------------ */

/*
 * DIFF 3 applies to all grid functions: grid is `integer(c_int), intent(in)`
 * WITHOUT the Fortran VALUE attribute, so it is passed by reference (const int*).
 */

/** Get the number of dimensions of the computational grid. */
int get_grid_rank(void* handle, const int* grid, int* rank);

/** Get the total number of elements in the computational grid. */
int get_grid_size(void* handle, const int* grid, int* size);

/**
 * Get the grid type as a null-terminated string (e.g. "uniform_rectilinear").
 * @param type  caller-allocated buffer, BMI_MAX_TYPE_NAME bytes
 */
int get_grid_type(void* handle, const int* grid, char* type);

/* Uniform rectilinear ------------------------------------------------ */

/**
 * Get the dimensions of the grid.
 * shape[0] = rows (n_y), shape[1] = columns (n_x).
 * @param shape  caller-allocated int array, rank elements
 */
int get_grid_shape  (void* handle, const int* grid, int*    shape);

/**
 * Get spacing between grid nodes.
 * spacing[0] = dy, spacing[1] = dx.
 * @param spacing  caller-allocated double array, rank elements
 */
int get_grid_spacing(void* handle, const int* grid, double* spacing);

/**
 * Get coordinates of the grid origin.
 * @param origin  caller-allocated double array, rank elements
 */
int get_grid_origin (void* handle, const int* grid, double* origin);

/* Non-uniform / unstructured ---------------------------------------- */

/**
 * Get x-coordinates of the grid nodes.
 * @param x  caller-allocated double array, get_grid_node_count elements
 */
int get_grid_x(void* handle, const int* grid, double* x);
int get_grid_y(void* handle, const int* grid, double* y);
int get_grid_z(void* handle, const int* grid, double* z);

int get_grid_node_count(void* handle, const int* grid, int* count);
int get_grid_edge_count(void* handle, const int* grid, int* count);
int get_grid_face_count(void* handle, const int* grid, int* count);

/**
 * Get edge-node connectivity.
 * @param edge_nodes  caller-allocated int array, 2*get_grid_edge_count elements
 *
 * BUG 1 WARNING: iso_c_bmif_2_0.f90 line 893 has a logic error that may cause
 * the wrong number of elements to be filled. See file header BUG 1 for details.
 */
int get_grid_edge_nodes    (void* handle, const int* grid, int* edge_nodes);

/**
 * Get face-edge connectivity.
 * @param face_edges  caller-allocated int array, sum(nodes_per_face) elements
 */
int get_grid_face_edges    (void* handle, const int* grid, int* face_edges);

/**
 * Get face-node connectivity.
 * @param face_nodes  caller-allocated int array, sum(nodes_per_face) elements
 */
int get_grid_face_nodes    (void* handle, const int* grid, int* face_nodes);

/**
 * Get the number of nodes per face.
 * @param nodes_per_face  caller-allocated int array, get_grid_face_count elements
 */
int get_grid_nodes_per_face(void* handle, const int* grid, int* nodes_per_face);

#ifdef __cplusplus
}
#endif

#endif /* BMI_H */
