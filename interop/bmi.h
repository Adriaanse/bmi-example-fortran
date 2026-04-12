/**
 * bmi.h - Deltares BMI C interop convention
 *
 * This header defines a C-callable interface for Fortran BMI models,
 * designed for Java/JNA interop. It deliberately differs from the
 * CSDMS bmi-c specification in the following ways:
 *
 * 1. Flat functions with explicit void* handle instead of struct Bmi
 * 2. Typed get/set_value_int/float/double instead of void*
 * 3. Flat char* buffer for var name lists instead of char**
 * 4. Explicit int n element count on all get/set_value* functions
 * 5. Added bmi_create()/bmi_destroy() for Fortran heap management
 *
 * These changes make the interface directly usable from Java via JNA
 * without unsafe casting or complex marshalling.
 *
 * Calling conventions
 * -------------------
 * All functions use the default C calling convention, requires compilation of the fortran code using ISO_C_BINDING
 * Every function returns int:
 *   BMI_SUCCESS (0) on success, BMI_FAILURE (1) on failure.
 *
 * Handle
 * ------
 * bmi_create() or similar factory method allocates a heat_model on the Fortran heap and returns an
 * opaque void* to it.  Pass this handle as the first argument to every other
 * function.  Release it with bmi_destroy() or similar when done.
 *
 * String conventions
 * ------------------
 *   In  (const char*): null-terminated, caller-owned.
 *   Out (char*):       caller-allocated buffer; library writes null-terminated
 *                      content.  Minimum buffer sizes:
 *                        component name  -> BMI_MAX_COMPONENT_NAME bytes
 *                        all other names -> BMI_MAX_VAR_NAME bytes
 *   Var-name lists: flat buffer of count * BMI_MAX_VAR_NAME bytes; names are
 *                   packed at fixed BMI_MAX_VAR_NAME-byte strides, each
 *                   null-terminated.  Call bmi_get_{input,output}_item_count
 *                   first to know 'count'.
 *
 * Array conventions
 * -----------------
 *   get/set_value* carry an explicit int n (element count).
 *   Grid shape / spacing / origin arrays have no explicit n — the caller
 *   knows the size from bmi_get_grid_rank.
 *
 * Type sizes (ifx, all platforms)
 * --------------------------------
 *   int    4 bytes   (Fortran integer(c_int))
 *   float  4 bytes   (Fortran real(c_float))
 *   double 8 bytes   (Fortran real(c_double))
 */

#ifndef BMI_H
#define BMI_H

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Return codes                                                         */
/* ------------------------------------------------------------------ */
#define BMI_SUCCESS 0
#define BMI_FAILURE 1

/* ------------------------------------------------------------------ */
/* Buffer sizes                                                         */
/* ------------------------------------------------------------------ */
#define BMI_MAX_COMPONENT_NAME 2048
#define BMI_MAX_VAR_NAME       2048

/* ------------------------------------------------------------------ */
/* Lifecycle                                                            */
/* ------------------------------------------------------------------ */

/**
 * Initialize the model.
 * @param config_file  Path to a plain-text config file
 *                     Pass an empty string "" to use built-in defaults.
 */
int   bmi_initialize(void* handle, const char* config_file);

/** Release all internal resources (arrays, etc.). */
int   bmi_finalize(void* handle);

/* ------------------------------------------------------------------ */
/* Model information                                                    */
/* ------------------------------------------------------------------ */

/** Write the component name into 'name' (BMI_MAX_COMPONENT_NAME bytes). */
int bmi_get_component_name(void* handle, char* name);

/** Return the number of input variables. */
int bmi_get_input_item_count(void* handle, int* count);

/** Return the number of output variables. */
int bmi_get_output_item_count(void* handle, int* count);

/**
 * Fill 'names' with input variable names.
 * 'names' must be count * BMI_MAX_VAR_NAME bytes; call
 * bmi_get_input_item_count first.
 */
int bmi_get_input_var_names(void* handle, char* names);

/**
 * Fill 'names' with output variable names.
 * 'names' must be count * BMI_MAX_VAR_NAME bytes; call
 * bmi_get_output_item_count first.
 */
int bmi_get_output_var_names(void* handle, char* names);

/* ------------------------------------------------------------------ */
/* Time                                                                 */
/* ------------------------------------------------------------------ */

int bmi_get_start_time  (void* handle, double* time);
int bmi_get_end_time    (void* handle, double* time);
int bmi_get_current_time(void* handle, double* time);
int bmi_get_time_step   (void* handle, double* time_step);

/** Write the time-unit string into 'units' (BMI_MAX_VAR_NAME bytes). */
int bmi_get_time_units  (void* handle, char* units);

/* ------------------------------------------------------------------ */
/* Control                                                              */
/* ------------------------------------------------------------------ */

/** Advance the model by one time step. */
int bmi_update(void* handle);

/**
 * Advance the model until the given model time.
 * 'time' is passed by value.
 */
int bmi_update_until(void* handle, double time);

/* ------------------------------------------------------------------ */
/* Variable metadata                                                    */
/* ------------------------------------------------------------------ */

/**
 * Return the grid id for variable 'name'.
 * @param grid  out: 0 = uniform_rectilinear,
 *                   1 = scalar (diffusivity, id)
 */
int bmi_get_var_grid    (void* handle, const char* name, int* grid);

/** Write the type string ("real", "integer") into var_type (BMI_MAX_VAR_NAME). */
int bmi_get_var_type    (void* handle, const char* name, char* var_type);

/** Write the unit string ("K", "m2 s-1", "1") into units (BMI_MAX_VAR_NAME). */
int bmi_get_var_units   (void* handle, const char* name, char* units);

/** Return the size in bytes of one element of variable 'name'. */
int bmi_get_var_itemsize(void* handle, const char* name, int* itemsize);

/** Return the total size in bytes of variable 'name'. */
int bmi_get_var_nbytes  (void* handle, const char* name, int* nbytes);

/** Write the location string ("node") into location (BMI_MAX_VAR_NAME). */
int bmi_get_var_location(void* handle, const char* name, char* location);

/* ------------------------------------------------------------------ */
/* Grid information                                                     */
/* ------------------------------------------------------------------ */

/**
 * Return the rank (number of dimensions) of grid 'grid'.
 */
int bmi_get_grid_rank(void* handle, int grid, int* rank);

/**
 * Return the total number of nodes in grid 'grid'.
 */
int bmi_get_grid_size(void* handle, int grid, int* size);

/** Write the grid type string ("uniform_rectilinear", "scalar") (BMI_MAX_VAR_NAME). */
int bmi_get_grid_type(void* handle, int grid, char* grid_type);

/**
 * Fill 'shape' with the grid shape.
 * Grid 0: shape[0] = n_rows (n_y), shape[1] = n_cols (n_x).
 * 'shape' must have at least rank elements.
 */
int bmi_get_grid_shape  (void* handle, int grid, int* shape);

/**
 * Fill 'spacing' with the cell spacing (same order as shape).
 * Grid 0: spacing[0] = dy, spacing[1] = dx.
 * 'spacing' must have at least rank elements.
 */
int bmi_get_grid_spacing(void* handle, int grid, double* spacing);

/**
 * Fill 'origin' with the grid origin coordinates (same order as shape).
 * Grid 0: origin[0] = 0.0, origin[1] = 0.0.
 * 'origin' must have at least rank elements.
 */
int bmi_get_grid_origin (void* handle, int grid, double* origin);

/* Coordinate arrays — only meaningful for grid 1 (scalar). */
int bmi_get_grid_x(void* handle, int grid, double* x);
int bmi_get_grid_y(void* handle, int grid, double* y);
int bmi_get_grid_z(void* handle, int grid, double* z);

int bmi_get_grid_node_count(void* handle, int grid, int* count);

/** Not applicable to uniform_rectilinear grids — always returns BMI_FAILURE. */
int bmi_get_grid_edge_count(void* handle, int grid, int* count);

/** Not applicable to uniform_rectilinear grids — always returns BMI_FAILURE. */
int bmi_get_grid_face_count(void* handle, int grid, int* count);

/** Not applicable to uniform_rectilinear grids — always returns BMI_FAILURE. */
int bmi_get_grid_edge_nodes    (void* handle, int grid, int* edge_nodes);

/** Not applicable to uniform_rectilinear grids — always returns BMI_FAILURE. */
int bmi_get_grid_face_edges    (void* handle, int grid, int* face_edges);

/** Not applicable to uniform_rectilinear grids — always returns BMI_FAILURE. */
int bmi_get_grid_face_nodes    (void* handle, int grid, int* face_nodes);

/** Not applicable to uniform_rectilinear grids — always returns BMI_FAILURE. */
int bmi_get_grid_nodes_per_face(void* handle, int grid, int* nodes_per_face);

/* ------------------------------------------------------------------ */
/* Get values (copy)                                                    */
/* ------------------------------------------------------------------ */

/**
 * Copy integer values of variable 'name' into 'dest'.
 * @param dest  caller-allocated array of n ints
 * @param n     number of elements to copy
 */
int bmi_get_value_int   (void* handle, const char* name, int*    dest, int n);

/**
 * Copy single-precision float values of variable 'name' into 'dest'.
 * @param dest  caller-allocated array of n floats
 * @param n     number of elements to copy
 */
int bmi_get_value_float (void* handle, const char* name, float*  dest, int n);

/**
 * Copy double-precision float values of variable 'name' into 'dest'.
 * @param dest  caller-allocated array of n doubles
 * @param n     number of elements to copy
 */
int bmi_get_value_double(void* handle, const char* name, double* dest, int n);

/**
 * Return a raw pointer directly into the model's internal buffer (zero-copy).
 * The pointer remains valid until bmi_finalize() or bmi_destroy().
 * @param dest_ptr  out: pointer to the internal buffer, or NULL on failure
 */
int bmi_get_value_ptr(void* handle, const char* name, void** dest_ptr);

/**
 * Copy integer values at the given flat (0-based) indices.
 * @param inds  array of n 0-based flat indices
 * @param n     number of elements
 */
int bmi_get_value_at_indices_int   (void* handle, const char* name,
                                    int*    dest, const int* inds, int n);

/** Copy float values at the given flat (0-based) indices. */
int bmi_get_value_at_indices_float (void* handle, const char* name,
                                    float*  dest, const int* inds, int n);

/** Copy double values at the given flat (0-based) indices. */
int bmi_get_value_at_indices_double(void* handle, const char* name,
                                    double* dest, const int* inds, int n);

/* ------------------------------------------------------------------ */
/* Set values                                                           */
/* ------------------------------------------------------------------ */

/**
 * Write n integers from 'src' into variable 'name'.
 * @param n  number of elements
 */
int bmi_set_value_int   (void* handle, const char* name, const int*    src, int n);

/** Write n floats from 'src' into variable 'name'. */
int bmi_set_value_float (void* handle, const char* name, const float*  src, int n);

/** Write n doubles from 'src' into variable 'name'. */
int bmi_set_value_double(void* handle, const char* name, const double* src, int n);

/**
 * Write integer values at the given flat (0-based) indices.
 * @param inds  array of n 0-based flat indices
 */
int bmi_set_value_at_indices_int   (void* handle, const char* name,
                                    const int* inds, const int*    src, int n);

/** Write float values at the given flat (0-based) indices. */
int bmi_set_value_at_indices_float (void* handle, const char* name,
                                    const int* inds, const float*  src, int n);

/** Write double values at the given flat (0-based) indices. */
int bmi_set_value_at_indices_double(void* handle, const char* name,
                                    const int* inds, const double* src, int n);

#ifdef __cplusplus
}
#endif

#endif /* BMI_H */
