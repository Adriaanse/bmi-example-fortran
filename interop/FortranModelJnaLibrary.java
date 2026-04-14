/**
 * FortranModelJnaLibrary.java
 *
 * JNA (Java Native Access) interface for libbmi_heat (.so / .dll).
 *
 * Derived from interop/bmi.h, which documents the actual exported symbols and
 * their ABI differences from the abstract BMI spec.  Read bmi.h first — it
 * contains all caveats, known bugs, and stub-implementation warnings that also
 * apply here.
 *
 * Type mapping summary (C → JNA)
 * --------------------------------
 *  void** handle     → PointerByReference  (DIFF 8: every handle is void** — see NOTE G)
 *  void**            → PointerByReference  (non-handle uses, e.g. get_value_ptr_*)
 *  int*   (scalar out)  → IntByReference
 *  double* (scalar out) → DoubleByReference
 *  const double* (scalar in, by-ref) → DoubleByReference  (see NOTE A)
 *  const int*    (scalar in, by-ref) → IntByReference      (see NOTE A)
 *  const char*   (string in)         → byte[]  (EXACTLY BMI_MAX_* bytes — see NOTE F)
 *  char*  (string out buffer)        → byte[]  (pre-allocate BMI_MAX_* bytes)
 *  int*   (array in/out)             → int[]
 *  float* (array in/out)             → float[]
 *  double* (array in/out)            → double[]
 *  void** (array of char buffers)    → Pointer[]  (see NOTE B)
 *
 * NOTE A — Scalar by-reference input parameters
 *   Fortran intent(in) scalars without the VALUE attribute are passed by
 *   reference in the bind(C) ABI.  update_until(time) and all get_grid_*
 *   functions take their scalar inputs (time, grid) as pointers, not values.
 *   Pass a single-element ByReference wrapper rather than a Java primitive.
 *
 * NOTE B — get_input/output_var_names
 *   The native function expects void** names where names[i] points to a
 *   pre-allocated char buffer.  In JNA, pass Pointer[] where each element
 *   is a com.sun.jna.Memory of BMI_MAX_VAR_NAME bytes.  Example:
 *
 *     int count = ...;  // from get_input_item_count
 *     Memory[] bufs = new Memory[count];
 *     Pointer[] ptrs = new Pointer[count];
 *     for (int i = 0; i < count; i++) {
 *         bufs[i] = new Memory(BMI_MAX_VAR_NAME);
 *         ptrs[i] = bufs[i];
 *     }
 *     lib.get_input_var_names(handleRef, ptrs);
 *     for (int i = 0; i < count; i++) {
 *         String varName = bufs[i].getString(0);
 *     }
 *
 * NOTE C — get_value_ptr_* stub implementations
 *   These three functions currently always return BMI_FAILURE and set
 *   *dest_ptr = NULL.  They are present in the interface for completeness.
 *
 * NOTE D — at_indices_* stub implementations
 *   get_value_at_indices_* and set_value_at_indices_* always return
 *   BMI_FAILURE.  Do not rely on indexed get/set operations.
 *
 * NOTE E — get_grid_edge_nodes bug
 *   See BUG 1 in bmi.h.  Buffer allocation for edge_nodes may need a manual
 *   workaround using get_grid_node_count.
 *
 * NOTE F — String input parameters MUST be byte[], not String
 *   The Fortran iso_c_bmif_2_0.f90 functions receive string inputs as
 *   fixed-length Fortran character arrays (character(kind=c_char, len=*)),
 *   NOT as null-terminated char* pointers.  The ABI requires the caller to
 *   supply a buffer of EXACTLY BMI_MAX_FILE_NAME or BMI_MAX_VAR_NAME bytes.
 *   Passing a Java String causes JNA to marshal a null-terminated char* and
 *   the Fortran side reads past the end of the buffer → SIGSEGV.
 *   Use new FortranString(s).toBytes() to produce a correctly
 *   sized, space-padded byte[] before calling any method that takes byte[] name
 *   or byte[] configFile.
 *
 * NOTE G — handle is PointerByReference (DIFF 8 in bmi.h)
 *   iso_c_bmif_2_0.f90 declares the handle as `type(c_ptr), intent(in)` without
 *   the VALUE attribute, so Fortran bind(C) passes it by reference → void** in C.
 *   Every method except register_bmi therefore takes PointerByReference as the
 *   first argument.  Do NOT unwrap with .getValue() before passing to methods.
 *
 * Typical usage lifecycle:
 *
 *   FortranModelJnaLibrary lib = Native.load("bmi_heat", FortranModelJnaLibrary.class);
 *   PointerByReference handleRef = new PointerByReference();
 *   lib.register_bmi(handleRef);
 *   // NOTE G: do NOT unwrap handleRef — all methods take PointerByReference directly
 *   lib.initialize(handleRef, new FortranString("/path/to/config.cfg").toBytes());
 *   lib.update(handleRef);
 *   float[] dest = new float[gridSize];
 *   lib.get_value_float(handleRef, new FortranString("plate_surface__temperature").toBytes(), dest);
 *   lib.finalize(handleRef);   // also deallocates; do not use handleRef after this
 */
package bmi.model;

import com.sun.jna.Library;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.DoubleByReference;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.PointerByReference;

public interface FortranModelJnaLibrary extends Library {

    /** BMI return codes */
    int BMI_SUCCESS = 0;
    int BMI_FAILURE = 1;

    /**
     * REQUIRED buffer sizes — Fortran expects EXACTLY this many bytes.
     * Use FortranString.toBytes() to create correctly sized buffers.
     *
     * <p>String INPUT parameters (byte[] name, byte[] configFile) must be
     * padded to exactly the declared size below; the Fortran side reads a
     * fixed-length character array, not a null-terminated string.
     * String OUTPUT parameters (byte[] dest) are also sized to these limits.
     */
    int BMI_MAX_FILE_NAME      = 2048;
    int BMI_MAX_COMPONENT_NAME = 2048;
    int BMI_MAX_VAR_NAME       = 2048;
    int BMI_MAX_TYPE_NAME      = 2048;
    int BMI_MAX_UNITS_NAME     = 2048;

    // ----------------------------------------------------------------
    // Lifecycle
    // ----------------------------------------------------------------

    /**
     * Allocate a new model instance and return an opaque handle.
     * Replaces bmi_create(). Pair with finalize() to release memory.
     *
     * @param handle  out: set to the opaque model pointer
     */
    int register_bmi(PointerByReference handle);

    /**
     * Perform startup tasks.
     *
     * @param handle      opaque model handle from register_bmi()
     * @param configFile  path to the configuration file, padded to exactly
     *                    BMI_MAX_FILE_NAME bytes (use FortranString.toBytes())
     */
    int initialize(PointerByReference handle, byte[] configFile);

    /** Advance the model by one internal time step. */
    int update(PointerByReference handle);

    /**
     * Advance the model until the given model time.
     *
     * NOTE A: time is passed by reference (Fortran intent(in) without VALUE).
     *
     * @param time  reference to the target time value
     */
    int update_until(PointerByReference handle, DoubleByReference time);

    /**
     * Finalize the model AND deallocate the model instance.
     * Do NOT use handle after calling finalize().
     */
    int finalize(PointerByReference handle);

    // ----------------------------------------------------------------
    // Model information
    // ----------------------------------------------------------------

    /**
     * Get the model component name into a caller-allocated buffer.
     *
     * @param name  pre-allocated byte array, exactly BMI_MAX_COMPONENT_NAME bytes
     */
    int get_component_name(PointerByReference handle, byte[] name);

    /** Count a model's input variables. */
    int get_input_item_count(PointerByReference handle, IntByReference count);

    /** Count a model's output variables. */
    int get_output_item_count(PointerByReference handle, IntByReference count);

    /**
     * List a model's input variable names.
     *
     * NOTE B: names must be a Pointer[] of count pre-allocated buffers,
     * each BMI_MAX_VAR_NAME bytes.  See class-level NOTE B for an example.
     *
     * @param names  array of count pre-allocated char buffers (Pointer[])
     */
    int get_input_var_names(PointerByReference handle, Pointer[] names);

    /**
     * List a model's output variable names.
     * NOTE B applies; see get_input_var_names.
     */
    int get_output_var_names(PointerByReference handle, Pointer[] names);

    // ----------------------------------------------------------------
    // Variable information
    // ----------------------------------------------------------------

    /**
     * Get the grid identifier for the given variable.
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int get_var_grid(PointerByReference handle, byte[] name, IntByReference grid);

    /**
     * Get the data type of the variable as a null-terminated string.
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     * @param type  pre-allocated byte array, at least BMI_MAX_TYPE_NAME bytes
     */
    int get_var_type(PointerByReference handle, byte[] name, byte[] type);

    /**
     * Get the units of the variable.
     * @param name   variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     * @param units  pre-allocated byte array, at least BMI_MAX_UNITS_NAME bytes
     */
    int get_var_units(PointerByReference handle, byte[] name, byte[] units);

    /**
     * Get memory use per array element, in bytes.
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int get_var_itemsize(PointerByReference handle, byte[] name, IntByReference size);

    /**
     * Get total size of the variable in bytes (all elements).
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int get_var_nbytes(PointerByReference handle, byte[] name, IntByReference nbytes);

    /**
     * Get the location of the variable: "node", "edge", or "face".
     * @param name      variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     * @param location  pre-allocated byte array, at least BMI_MAX_VAR_NAME bytes
     */
    int get_var_location(PointerByReference handle, byte[] name, byte[] location);

    // ----------------------------------------------------------------
    // Time information
    // ----------------------------------------------------------------

    int get_current_time(PointerByReference handle, DoubleByReference time);
    int get_start_time  (PointerByReference handle, DoubleByReference time);
    int get_end_time    (PointerByReference handle, DoubleByReference time);

    /**
     * @param units  pre-allocated byte array, at least BMI_MAX_UNITS_NAME bytes
     */
    int get_time_units(PointerByReference handle, byte[] units);
    int get_time_step (PointerByReference handle, DoubleByReference timeStep);

    // ----------------------------------------------------------------
    // Getters — full array copy
    // ----------------------------------------------------------------

    /**
     * Get a flattened copy of the given integer variable.
     * Pre-allocate dest: use get_var_nbytes / get_var_itemsize to determine
     * the element count.
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int get_value_int   (PointerByReference handle, byte[] name, int[]    dest);
    int get_value_float (PointerByReference handle, byte[] name, float[]  dest);
    int get_value_double(PointerByReference handle, byte[] name, double[] dest);

    // ----------------------------------------------------------------
    // Getters — zero-copy reference (NOTE C: STUB — always BMI_FAILURE)
    // ----------------------------------------------------------------

    /**
     * Get a direct pointer into the model's internal storage.
     * NOTE C: Currently stub implementations — always return BMI_FAILURE.
     * @param name     variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     * @param destPtr  out: *destPtr is set to model-internal memory (or NULL)
     */
    int get_value_ptr_int   (PointerByReference handle, byte[] name, PointerByReference destPtr);
    int get_value_ptr_float (PointerByReference handle, byte[] name, PointerByReference destPtr);
    int get_value_ptr_double(PointerByReference handle, byte[] name, PointerByReference destPtr);

    // ----------------------------------------------------------------
    // Getters — indexed (NOTE D: STUB — always BMI_FAILURE)
    // ----------------------------------------------------------------

    /**
     * Get values at the given 0-based flat indices.
     * NOTE D: STUB implementation — always returns BMI_FAILURE.
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int get_value_at_indices_int   (PointerByReference handle, byte[] name, int[]    dest, int[] inds);
    int get_value_at_indices_float (PointerByReference handle, byte[] name, float[]  dest, int[] inds);
    int get_value_at_indices_double(PointerByReference handle, byte[] name, double[] dest, int[] inds);

    // ----------------------------------------------------------------
    // Setters — full array
    // ----------------------------------------------------------------

    /**
     * Set new values for the given variable.
     * Ensure src has the correct element count (see get_var_nbytes).
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int set_value_int   (PointerByReference handle, byte[] name, int[]    src);
    int set_value_float (PointerByReference handle, byte[] name, float[]  src);
    int set_value_double(PointerByReference handle, byte[] name, double[] src);

    // ----------------------------------------------------------------
    // Setters — indexed (NOTE D: STUB — always BMI_FAILURE)
    // ----------------------------------------------------------------

    /**
     * Set values at the given 0-based flat indices.
     * NOTE D: STUB implementation — always returns BMI_FAILURE.
     * @param name  variable name, padded to exactly BMI_MAX_VAR_NAME bytes
     */
    int set_value_at_indices_int   (PointerByReference handle, byte[] name, int[] inds, int[]    src);
    int set_value_at_indices_float (PointerByReference handle, byte[] name, int[] inds, float[]  src);
    int set_value_at_indices_double(PointerByReference handle, byte[] name, int[] inds, double[] src);

    // ----------------------------------------------------------------
    // Grid information
    // ----------------------------------------------------------------

    /*
     * NOTE A applies to all grid functions: the grid parameter is
     * `integer(c_int), intent(in)` without VALUE in Fortran, so it is passed
     * by reference.  Use IntByReference to wrap the grid identifier integer.
     */

    /** Get the number of dimensions of the computational grid. */
    int get_grid_rank(PointerByReference handle, IntByReference grid, IntByReference rank);

    /** Get the total number of elements in the computational grid. */
    int get_grid_size(PointerByReference handle, IntByReference grid, IntByReference size);

    /**
     * Get the grid type as a null-terminated string.
     * @param type  pre-allocated byte array, at least BMI_MAX_TYPE_NAME bytes
     */
    int get_grid_type(PointerByReference handle, IntByReference grid, byte[] type);

    // Uniform rectilinear

    /**
     * Get grid dimensions.  shape[0] = rows (n_y), shape[1] = columns (n_x).
     * @param shape  pre-allocated int array, rank elements
     */
    int get_grid_shape  (PointerByReference handle, IntByReference grid, int[]    shape);

    /**
     * Get spacing between grid nodes.  spacing[0] = dy, spacing[1] = dx.
     * @param spacing  pre-allocated double array, rank elements
     */
    int get_grid_spacing(PointerByReference handle, IntByReference grid, double[] spacing);

    /**
     * Get coordinates of the grid origin.
     * @param origin  pre-allocated double array, rank elements
     */
    int get_grid_origin (PointerByReference handle, IntByReference grid, double[] origin);

    // Non-uniform / unstructured

    /**
     * Get x-coordinates of grid nodes.
     * @param x  pre-allocated double array, get_grid_node_count elements
     */
    int get_grid_x(PointerByReference handle, IntByReference grid, double[] x);
    int get_grid_y(PointerByReference handle, IntByReference grid, double[] y);
    int get_grid_z(PointerByReference handle, IntByReference grid, double[] z);

    int get_grid_node_count(PointerByReference handle, IntByReference grid, IntByReference count);
    int get_grid_edge_count(PointerByReference handle, IntByReference grid, IntByReference count);
    int get_grid_face_count(PointerByReference handle, IntByReference grid, IntByReference count);

    /**
     * Get edge-node connectivity.
     * @param edgeNodes  pre-allocated int array, 2*get_grid_edge_count elements
     *
     * NOTE E (BUG 1): see bmi.h — the Fortran implementation has a logic error
     * in the array-size calculation for this function.
     */
    int get_grid_edge_nodes    (PointerByReference handle, IntByReference grid, int[] edgeNodes);

    /**
     * Get face-edge connectivity.
     * @param faceEdges  pre-allocated int array, sum(nodes_per_face) elements
     */
    int get_grid_face_edges    (PointerByReference handle, IntByReference grid, int[] faceEdges);

    /**
     * Get face-node connectivity.
     * @param faceNodes  pre-allocated int array, sum(nodes_per_face) elements
     */
    int get_grid_face_nodes    (PointerByReference handle, IntByReference grid, int[] faceNodes);

    /**
     * Get the number of nodes for each face.
     * @param nodesPerFace  pre-allocated int array, get_grid_face_count elements
     */
    int get_grid_nodes_per_face(PointerByReference handle, IntByReference grid, int[] nodesPerFace);
}
