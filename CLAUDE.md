# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Fortran implementation of the [CSDMS Basic Model Interface (BMI)](https://bmi.csdms.io) for a 2D heat equation model. Forked by Deltares and modified to use `iso_c_binding` for cross-platform shared library support (Linux `.so` and Windows `.dll`).

## Build Systems

> **Note for this project:** The CI build path (direct `ifx` compilation via 
> GitHub Actions) is the only build path currently in use. Updating CMake and fpm would be the last optional step for now.
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

The CI workflow (`build.yml`) compiles directly with the Intel Fortran compiler (`ifx`) into a single shared library. `bmi_heat_shared.f90` is the only BMI source file needed — it replaces both the old OO wrapper and the old C wrapper:

```bash
# Linux  (-fpp enables C preprocessor for #ifdef guards)
$FC -shared -fPIC -fpp -Iheat -o libbmi_heat.so heat/heat.f90 bmi.f90 bmi_heat/bmi_heat_shared.f90

# Windows  (//fpp enables C preprocessor; // is bash syntax for ifx's /fpp flag)
$FC //LD //fpp -Iheat -o libbmi_heat.dll heat/heat.f90 bmi.f90 bmi_heat/bmi_heat_shared.f90
```

`bmi.f90` is downloaded directly from `csdms/bmi-fortran` master during CI.

## Architecture

### Layer separation

```
bmi_heat/bmi_heat_shared.f90  ← Flat C-interoperable BMI (bind(C) on every function)
bmi_heat/bmi_heat.f90         ← Legacy OO BMI wrapper (kept untouched, not compiled)
bmi_heat/bmi.f90              ← Abstract BMI interface (type bmi, from csdms/bmi-fortran)
heat/heat.f90                 ← Physical model (type heat_model)
```

`bmi_heat_shared.f90` holds a heap-allocated `heat_model` directly via an opaque `c_ptr`
handle — no abstract type, no OO inheritance. `bmi_heat.f90` is kept for reference but
is no longer compiled.

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

`bmi_get_value_ptr` and `bmi_get/set_value_at_indices` use `iso_c_binding` (`c_loc` / `c_f_pointer`) to expose the internal 2D temperature array as a flat 1D pointer. When flattening `temperature(n_y, n_x)`, the array is laid out in column-major order.

### Config file format

Plain text, one line:
```
<alpha>  <t_end>  <n_x>  <n_y>
```
Example (`example/test1.cfg`): `1.0  100.0  5  10`

### Tests

Each BMI function has its own test file in `test/`. All tests share a `fixtures.f90` helper and receive `test/sample.cfg` as a command-line argument. To add a new test with CMake, add a `make_test(<test_name>)` call in `test/CMakeLists.txt`.

## Java Interop — `bmi_heat_shared.f90`

The shared library is called from Java via JNA (Java Native Access). All exported symbols live in `bmi_heat/bmi_heat_shared.f90`, which is a flat Fortran module with `bind(C)` on every function. There is no intermediate OO layer.

### Opaque handle pattern

Java holds a `long` (mapped from `type(c_ptr)`) pointing to a heap-allocated `heat_model` instance. Lifecycle:

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

### String helpers (internal, not exported)

| Helper | Purpose |
|---|---|
| `strlen(c_str)` | Find null terminator; loops up to `BMI_MAX_VAR_NAME` |
| `char_array_to_string(c_str, f_str)` | Null-terminated C → blank-padded Fortran |
| `string_to_char_array(f_str, c_str)` | Fortran → null-terminated C buffer |
| `pack_name(name, buf, slot)` | Write one name into a `BMI_MAX_VAR_NAME`-stride flat buffer at 0-based slot index |

### Array conventions

All `get/set_value*` functions carry an explicit `integer(c_int) n` element count. Grid shape/spacing/origin arrays have no explicit `n` — the caller knows the size from `bmi_get_grid_rank`. Java passes primitive arrays (`float[]`, `int[]`, `double[]`); JNA maps these directly to `float*` etc.

### Zero-copy pointer (`bmi_get_value_ptr`)

Returns a raw `Pointer` to the model's internal `temperature` buffer (`plate_surface__temperature` only, stored as `real(c_float)`). Java can read/write this directly without copying. Returns `null` on failure or for unsupported variables.

### Cross-platform symbol visibility

Every exported function uses a preprocessor guard:

```fortran
#ifdef _WIN32
  !DEC$ ATTRIBUTES DLLEXPORT :: bmi_initialize
#else
  !GCC$ ATTRIBUTES VISIBILITY="default" :: bmi_initialize
#endif
```

- `_WIN32` is defined automatically by `ifx` on Windows.
- Both platforms require an explicit preprocessor flag: `-fpp` on Linux, `//fpp` on Windows (bash syntax for ifx's `/fpp` flag).
- `//LD` alone does **not** activate the preprocessor on Windows — `//fpp` is required separately.

### Exported C symbols (all prefixed `bmi_`)

`bmi_create`, `bmi_destroy`, `bmi_initialize`, `bmi_finalize`, `bmi_get_component_name`, `bmi_get_input_item_count`, `bmi_get_output_item_count`, `bmi_get_input_var_names`, `bmi_get_output_var_names`, `bmi_get_start_time`, `bmi_get_end_time`, `bmi_get_current_time`, `bmi_get_time_step`, `bmi_get_time_units`, `bmi_update`, `bmi_update_until`, `bmi_get_var_grid`, `bmi_get_var_type`, `bmi_get_var_units`, `bmi_get_var_itemsize`, `bmi_get_var_nbytes`, `bmi_get_var_location`, `bmi_get_grid_rank`, `bmi_get_grid_size`, `bmi_get_grid_type`, `bmi_get_grid_shape`, `bmi_get_grid_spacing`, `bmi_get_grid_origin`, `bmi_get_grid_x/y/z`, `bmi_get_grid_node/edge/face_count`, `bmi_get_grid_edge_nodes`, `bmi_get_grid_face_edges/nodes`, `bmi_get_grid_nodes_per_face`, `bmi_get_value_int/float/double`, `bmi_get_value_ptr`, `bmi_get_value_at_indices_int/float/double`, `bmi_set_value_int/float/double`, `bmi_set_value_at_indices_int/float/double`

### Known limitations

- `bmi_get_value_ptr` only supports `plate_surface__temperature` (the only variable stored as a contiguous `real(c_float)` array)
- Unstructured grid functions (`bmi_get_grid_edge_nodes`, `bmi_get_grid_face_edges`, `bmi_get_grid_face_nodes`, `bmi_get_grid_nodes_per_face`) always return `BMI_FAILURE` — not applicable to a uniform rectilinear grid
- `bmi_create` uses `c_loc` on `heat_model` (a non-`bind(C)` derived type); this works with `ifx` but is not strictly standard Fortran
- `!DEC$ ATTRIBUTES DLLEXPORT` is Intel `ifx` specific; `!GCC$ ATTRIBUTES VISIBILITY="default"` targets GCC/gfortran on Linux

## Constraints
- Do NOT modify `bmi.f90` — this is the upstream CSDMS file fetched during CI
- Do NOT modify `heat.f90` — this is the upstream CSDMS file fetched during CI
- Do NOT modify `bmi_heat.f90` — kept untouched as legacy reference, not compiled
- No local Fortran compiler available — all builds are validated via GitHub Actions CI
- `bmi_heat/bmi.f90` in the repo is a corrupted HTML download (kept as reference); the CI always fetches the real file fresh from `raw.githubusercontent.com`
