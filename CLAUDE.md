# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Fortran implementation of the [CSDMS Basic Model Interface (BMI)](https://bmi.csdms.io) for a 2D heat equation model. Forked by Deltares and modified to use `iso_c_binding` for cross-platform shared library support (Linux `.so` and Windows `.dll`).

## Build Systems

> **Note for this project:** The CI build path (direct `ifx` compilation via 
> GitHub Actions) is the only build path currently in use. updating CMake and fpm would be the last optional step for now.
There are two supported build methods:

### fpm (Fortran Package Manager) — preferred for development

```bash
fpm build --profile release
fpm test -- test/sample.cfg        # run all tests
fpm run --example --all -- example # run all examples
fpm run --example <name> -- example # run a single example
```

### CMake

**Linux/macOS:**
```bash
cmake -B _build -DCMAKE_INSTALL_PREFIX=<path>
cmake --build _build
cmake --install _build
ctest --test-dir _build            # run all tests
```

**Windows (Developer Command Prompt with Ninja):**
```bash
cmake -B _build -G Ninja -DCMAKE_INSTALL_PREFIX=<path>
cmake --build _build
ctest --test-dir _build
```

CMake requires the `bmif` Fortran BMI bindings to be installed and discoverable via `pkg-config`. With fpm, `bmif` is fetched automatically from `csdms/bmi-fortran`.

### CI — direct ifx compilation

The CI workflow (`build.yml`) bypasses CMake/fpm and compiles directly with the Intel Fortran compiler (`ifx`) into a single shared library:

```bash
# Linux  (-fpp enables C preprocessor for #ifdef guards)
$FC -shared -fPIC -fpp -Iheat -o libbmi_heat.so heat/heat.f90 bmi.f90 bmi_heat/bmi_heat.f90 bmi_heat/bmi_c_wrapper.f90

# Windows  (ifx //LD enables preprocessor by default)
$FC //LD -Iheat -o libbmi_heat.dll heat/heat.f90 bmi.f90 bmi_heat/bmi_heat.f90 bmi_heat/bmi_c_wrapper.f90
```

`bmi.f90` is downloaded directly from `csdms/bmi-fortran` master during CI.

## Architecture

### Layer separation

```
bmi_heat/bmi_heat.f90   ← BMI wrapper (type bmi_heat extends bmi)
bmi_heat/bmi.f90        ← Abstract BMI interface (type bmi, from csdms/bmi-fortran)
heat/heat.f90           ← Physical model (type heat_model)
```

`bmi_heat` contains a `heat_model` as a private member and delegates all BMI calls to it. It does not inherit from `heat_model`.

### The heat model (`heat_model` in `heat/heat.f90`)

Solves the 2D diffusion equation on a uniform rectangular plate with Dirichlet (zero) boundary conditions. Key fields:
- `temperature(n_y, n_x)` — stored column-major (Fortran order)
- `alpha` — thermal diffusivity; also controls time step: `dt = 1 / (4 * alpha)`
- Initialized from a config file: one line `alpha  t_end  n_x  n_y`

### BMI variable mapping

| Variable name | Grid | Type | Notes |
|---|---|---|---|
| `plate_surface__temperature` | 0 (`uniform_rectilinear`, rank 2) | `real` | primary output |
| `plate_surface__thermal_diffusivity` | 1 (`scalar`) | `real` | |
| `model__identification_number` | 1 (`scalar`) | `integer` | |

### Cross-platform memory access

`get_value_ptr` and `get/set_value_at_indices` use `iso_c_binding` (`c_loc` / `c_f_pointer`) to expose the internal 2D temperature array as a flat 1D pointer. This is the key Deltares modification enabling Windows DLL compatibility. When flattening `temperature(n_y, n_x)`, the array is laid out in column-major order.

### Config file format

Plain text, one line:
```
<alpha>  <t_end>  <n_x>  <n_y>
```
Example (`example/test1.cfg`): `1.0  100.0  5  10`

### Tests

Each BMI function has its own test file in `test/`. All tests share a `fixtures.f90` helper and receive `test/sample.cfg` as a command-line argument. To add a new test with CMake, add a `make_test(<test_name>)` call in `test/CMakeLists.txt`.

## Java Interop — C Wrapper Layer

The shared library is called from Java via JNA (Java Native Access). The C wrapper is implemented in `bmi_heat/bmi_c_wrapper.f90` and compiled as part of the shared library.

### Opaque handle pattern

Java holds a `long` (mapped from `type(c_ptr)`) pointing to a heap-allocated `bmi_heat` instance. Lifecycle:

```java
long handle = lib.bmi_create();
lib.bmi_initialize(handle, "test1.cfg\0");
// ... use the model ...
lib.bmi_finalize(handle);
lib.bmi_destroy(handle);
```

### String conventions

- **In**: null-terminated `byte[]` (JNA maps `String` or `byte[]` to `char*`)
- **Out (scalar)**: caller provides a `byte[BMI_MAX_VAR_NAME]` buffer; wrapper writes null-terminated content
- **Out (var names)**: flat `byte[count * BMI_MAX_VAR_NAME]` buffer; names are packed at fixed `BMI_MAX_VAR_NAME`-byte strides, each null-terminated. Call `bmi_get_input_item_count` first to know `count`.

### Array conventions

All array functions carry an explicit `int n` element count. Java passes a primitive array (`float[]`, `int[]`, `double[]`); JNA maps these directly to `float*` etc.

### Zero-copy pointer (`bmi_get_value_ptr`)

Returns a raw `Pointer` to the model's internal temperature buffer (currently only `plate_surface__temperature`). Java can read/write this directly without copying. Returns `null` on failure or for unsupported variables.

### Exported C symbols (all prefixed `bmi_`)

`bmi_create`, `bmi_destroy`, `bmi_initialize`, `bmi_finalize`, `bmi_get_component_name`, `bmi_get_input_item_count`, `bmi_get_output_item_count`, `bmi_get_input_var_names`, `bmi_get_output_var_names`, `bmi_get_start_time`, `bmi_get_end_time`, `bmi_get_current_time`, `bmi_get_time_step`, `bmi_get_time_units`, `bmi_update`, `bmi_update_until`, `bmi_get_var_grid`, `bmi_get_var_type`, `bmi_get_var_units`, `bmi_get_var_itemsize`, `bmi_get_var_nbytes`, `bmi_get_var_location`, `bmi_get_grid_rank`, `bmi_get_grid_size`, `bmi_get_grid_type`, `bmi_get_grid_shape`, `bmi_get_grid_spacing`, `bmi_get_grid_origin`, `bmi_get_grid_x/y/z`, `bmi_get_grid_node/edge/face_count`, `bmi_get_grid_edge_nodes`, `bmi_get_grid_face_edges/nodes`, `bmi_get_grid_nodes_per_face`, `bmi_get_value_int/float/double`, `bmi_get_value_ptr`, `bmi_get_value_at_indices_int/float/double`, `bmi_set_value_int/float/double`, `bmi_set_value_at_indices_int/float/double`

### Cross-platform symbol visibility

Each exported function in `bmi_c_wrapper.f90` uses a preprocessor guard to select the correct compiler directive:

```fortran
#ifdef _WIN32
  !DEC$ ATTRIBUTES DLLEXPORT :: bmi_initialize
#else
  !GCC$ ATTRIBUTES VISIBILITY :: bmi_initialize
#endif
```

- `_WIN32` is defined automatically by `ifx` on Windows.
- On Linux, `-fpp` must be passed to `ifx` to activate C preprocessing (added to the Linux CI build command). Windows `ifx //LD` enables the preprocessor by default.

### Known limitations / future work

- `bmi_get_value_ptr` only supports `real(c_float)` (the only variable with a working `get_value_ptr` implementation in `bmi_heat.f90`)
- `get_value_at_indices` and `set_value_at_indices` for int and double types always return `BMI_FAILURE` (unimplemented stubs in `bmi_heat.f90`)
- `!DEC$ ATTRIBUTES DLLEXPORT` / `!GCC$ ATTRIBUTES VISIBILITY` are compiler-specific directives — see the `#ifdef _WIN32` guards in `bmi_c_wrapper.f90`
- `bmi_create` uses `c_loc` on a non-interoperable derived type (`bmi_heat` extends abstract `bmi`); this is an ifx extension, not strictly standard Fortran

## Constraints
- Do NOT modify `bmi.f90` — this is the upstream CSDMS file fetched during CI
- Do NOT modify `heat.f90` — this is the upstream CSDMS file fetched during CI
- No local Fortran compiler available — all builds are validated via GitHub Actions CI
- `bmi_heat/bmi.f90` in the repo is a corrupted HTML download (kept as reference); the CI always fetches the real file fresh from `raw.githubusercontent.com`
