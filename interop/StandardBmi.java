import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.DoubleByReference;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.PointerByReference;

/**
 * JNA interface for BMI fortran (.so / .dll using C_ISO_BINDING).
 *
 * Derived from interop/bmi.h.  Load with:
 *
 *   StandardBmi lib = Native.load("bmi_lib", StandardBmi.class);
 *
 * Typical lifecycle:
 *
 *   Pointer handle = lib.bmi_create(); // model specific !
 *   lib.bmi_initialize(handle, "test1.cfg");
 *   // ... use the model ...
 *   lib.bmi_finalize(handle);
 *   lib.bmi_destroy(handle);
 *
 * String conventions
 * ------------------
 *   In  : plain Java String — JNA converts it to a null-terminated char*.
 *   Out : pre-allocated byte[] of the required size; convert the result
 *         with Native.toString(bytes).
 *   Var-name lists: byte[count * BMI_MAX_VAR_NAME]; split into
 *         BMI_MAX_VAR_NAME-byte chunks and trim each with Native.toString.
 *
 * Return codes
 * ------------
 *   BMI_SUCCESS = 0
 *   BMI_FAILURE = 1
 */
public interface StandardBmi extends Library {

    /* ---------------------------------------------------------------- */
    /* Buffer sizes (mirror bmi.h constants)                             */
    /* ---------------------------------------------------------------- */
    int BMI_MAX_COMPONENT_NAME = 2048;
    int BMI_MAX_VAR_NAME       = 2048;

    /* ---------------------------------------------------------------- */
    /* Return codes                                                      */
    /* ---------------------------------------------------------------- */
    int BMI_SUCCESS = 0;
    int BMI_FAILURE = 1;

    /* ---------------------------------------------------------------- */
    /* Lifecycle                                                         */
    /* ---------------------------------------------------------------- */

    /**
     * Allocate a new model instance.
     * @return opaque Pointer (hold as a long handle in Fortran)
     */
    Pointer bmi_create();

    /**
     * Free a model instance.  Do not use 'handle' after this call.
     */
    void bmi_destroy(Pointer handle);

    /**
     * Initialize the model from a config file.
     * Pass an empty string "" to use built-in defaults.
     * @param configFile null-terminated path string, e.g. "test1.cfg\0"
     */
    int bmi_initialize(Pointer handle, String configFile);

    /** Release internal resources (arrays, etc.). */
    int bmi_finalize(Pointer handle);

    /* ---------------------------------------------------------------- */
    /* Model information                                                 */
    /* ---------------------------------------------------------------- */

    /**
     * @param name pre-allocated byte[BMI_MAX_COMPONENT_NAME]
     */
    int bmi_get_component_name(Pointer handle, byte[] name);

    int bmi_get_input_item_count (Pointer handle, IntByReference count);
    int bmi_get_output_item_count(Pointer handle, IntByReference count);

    /**
     * Fill a flat name buffer with input variable names.
     * @param names pre-allocated byte[count * BMI_MAX_VAR_NAME]
     */
    int bmi_get_input_var_names (Pointer handle, byte[] names);

    /**
     * Fill a flat name buffer with output variable names.
     * @param names pre-allocated byte[count * BMI_MAX_VAR_NAME]
     */
    int bmi_get_output_var_names(Pointer handle, byte[] names);

    /* ---------------------------------------------------------------- */
    /* Time                                                              */
    /* ---------------------------------------------------------------- */

    int bmi_get_start_time  (Pointer handle, DoubleByReference time);
    int bmi_get_end_time    (Pointer handle, DoubleByReference time);
    int bmi_get_current_time(Pointer handle, DoubleByReference time);
    int bmi_get_time_step   (Pointer handle, DoubleByReference timeStep);

    /**
     * @param units pre-allocated byte[BMI_MAX_VAR_NAME]
     */
    int bmi_get_time_units(Pointer handle, byte[] units);

    /* ---------------------------------------------------------------- */
    /* Control                                                           */
    /* ---------------------------------------------------------------- */

    /** Advance by one time step. */
    int bmi_update(Pointer handle);

    /**
     * Advance until model time 'time'.
     * 'time' is passed by value (double, not a pointer).
     */
    int bmi_update_until(Pointer handle, double time);

    /* ---------------------------------------------------------------- */
    /* Variable metadata                                                 */
    /* ---------------------------------------------------------------- */

    /**
     * @param grid out: 0 = uniform_rectilinear (temperature),
     *                  1 = scalar (diffusivity, id)
     */
    int bmi_get_var_grid    (Pointer handle, String name, IntByReference grid);

    /**
     * @param varType pre-allocated byte[BMI_MAX_VAR_NAME]
     *                contains "real" or "integer"
     */
    int bmi_get_var_type    (Pointer handle, String name, byte[] varType);

    /**
     * @param units pre-allocated byte[BMI_MAX_VAR_NAME]
     *              contains "K", "m2 s-1", or "1"
     */
    int bmi_get_var_units   (Pointer handle, String name, byte[] units);

    /** @param itemsize out: size in bytes of one element */
    int bmi_get_var_itemsize(Pointer handle, String name, IntByReference itemsize);

    /** @param nbytes out: total size in bytes of the variable */
    int bmi_get_var_nbytes  (Pointer handle, String name, IntByReference nbytes);

    /**
     * @param location pre-allocated byte[BMI_MAX_VAR_NAME]
     *                 contains "node"
     */
    int bmi_get_var_location(Pointer handle, String name, byte[] location);

    /* ---------------------------------------------------------------- */
    /* Grid information                                                  */
    /* ---------------------------------------------------------------- */

    /**
     * @param rank out: 2 for temperature grid (0), 0 for scalar grid (1)
     */
    int bmi_get_grid_rank(Pointer handle, int grid, IntByReference rank);

    /**
     * @param size out: n_x*n_y for grid 0, 1 for grid 1
     */
    int bmi_get_grid_size(Pointer handle, int grid, IntByReference size);

    /**
     * @param gridType pre-allocated byte[BMI_MAX_VAR_NAME]
     *                 contains "uniform_rectilinear" or "scalar"
     */
    int bmi_get_grid_type(Pointer handle, int grid, byte[] gridType);

    /**
     * Fill 'shape' with the grid shape (row-major: [n_rows, n_cols]).
     * @param shape pre-allocated int[rank]
     */
    int bmi_get_grid_shape  (Pointer handle, int grid, int[]    shape);

    /**
     * Fill 'spacing' with cell spacing in the same order as shape ([dy, dx]).
     * @param spacing pre-allocated double[rank]
     */
    int bmi_get_grid_spacing(Pointer handle, int grid, double[] spacing);

    /**
     * Fill 'origin' with the lower-left origin coordinates ([y0, x0]).
     * @param origin pre-allocated double[rank]
     */
    int bmi_get_grid_origin (Pointer handle, int grid, double[] origin);

    /** @param x pre-allocated double[] (size from get_grid_node_count) */
    int bmi_get_grid_x(Pointer handle, int grid, double[] x);

    /** @param y pre-allocated double[] (size from get_grid_node_count) */
    int bmi_get_grid_y(Pointer handle, int grid, double[] y);

    /** @param z pre-allocated double[] (size from get_grid_node_count) */
    int bmi_get_grid_z(Pointer handle, int grid, double[] z);

    int bmi_get_grid_node_count(Pointer handle, int grid, IntByReference count);

    /** Not applicable to uniform_rectilinear — always returns BMI_FAILURE. */
    int bmi_get_grid_edge_count(Pointer handle, int grid, IntByReference count);

    /** Not applicable to uniform_rectilinear — always returns BMI_FAILURE. */
    int bmi_get_grid_face_count(Pointer handle, int grid, IntByReference count);

    /** Not applicable to uniform_rectilinear — always returns BMI_FAILURE. */
    int bmi_get_grid_edge_nodes    (Pointer handle, int grid, int[] edgeNodes);

    /** Not applicable to uniform_rectilinear — always returns BMI_FAILURE. */
    int bmi_get_grid_face_edges    (Pointer handle, int grid, int[] faceEdges);

    /** Not applicable to uniform_rectilinear — always returns BMI_FAILURE. */
    int bmi_get_grid_face_nodes    (Pointer handle, int grid, int[] faceNodes);

    /** Not applicable to uniform_rectilinear — always returns BMI_FAILURE. */
    int bmi_get_grid_nodes_per_face(Pointer handle, int grid, int[] nodesPerFace);

    /* ---------------------------------------------------------------- */
    /* Get values (copy)                                                 */
    /* ---------------------------------------------------------------- */

    /**
     * Copy n integer values into 'dest'.
     * @param dest pre-allocated int[n]
     */
    int bmi_get_value_int   (Pointer handle, String name, int[]    dest, int n);

    /**
     * Copy n float values into 'dest'.
     * @param dest pre-allocated float[n]
     */
    int bmi_get_value_float (Pointer handle, String name, float[]  dest, int n);

    /**
     * Copy n double values into 'dest'.
     * @param dest pre-allocated double[n]
     */
    int bmi_get_value_double(Pointer handle, String name, double[] dest, int n);

    /**
     * Return a direct (zero-copy) pointer into the model's temperature buffer.
     * Only "plate_surface__temperature" is supported; the buffer contains floats.
     * Valid until bmi_finalize() or bmi_destroy().
     *
     * Usage:
     *   PointerByReference ref = new PointerByReference();
     *   lib.bmi_get_value_ptr(handle, "plate_surface__temperature", ref);
     *   Pointer buf = ref.getValue();  // buf.getFloatArray(0, n) to read
     */
    int bmi_get_value_ptr(Pointer handle, String name, PointerByReference destPtr);

    /**
     * Copy integer values at the given flat 0-based indices.
     * @param dest pre-allocated int[n]
     * @param inds int[n] of 0-based flat indices
     */
    int bmi_get_value_at_indices_int   (Pointer handle, String name,
                                        int[]    dest, int[] inds, int n);

    /** Copy float values at the given flat 0-based indices. */
    int bmi_get_value_at_indices_float (Pointer handle, String name,
                                        float[]  dest, int[] inds, int n);

    /** Copy double values at the given flat 0-based indices. */
    int bmi_get_value_at_indices_double(Pointer handle, String name,
                                        double[] dest, int[] inds, int n);

    /* ---------------------------------------------------------------- */
    /* Set values                                                        */
    /* ---------------------------------------------------------------- */

    /**
     * Write n integers from 'src' into variable 'name'.
     * @param src int[n]
     */
    int bmi_set_value_int   (Pointer handle, String name, int[]    src, int n);

    /** Write n floats from 'src' into variable 'name'. */
    int bmi_set_value_float (Pointer handle, String name, float[]  src, int n);

    /** Write n doubles from 'src' into variable 'name'. */
    int bmi_set_value_double(Pointer handle, String name, double[] src, int n);

    /**
     * Write integer values at the given flat 0-based indices.
     * @param inds int[n] of 0-based flat indices
     * @param src  int[n]
     */
    int bmi_set_value_at_indices_int   (Pointer handle, String name,
                                        int[] inds, int[]    src, int n);

    /** Write float values at the given flat 0-based indices. */
    int bmi_set_value_at_indices_float (Pointer handle, String name,
                                        int[] inds, float[]  src, int n);

    /** Write double values at the given flat 0-based indices. */
    int bmi_set_value_at_indices_double(Pointer handle, String name,
                                        int[] inds, double[] src, int n);
}
