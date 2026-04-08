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
# Linux
$FC -shared -fPIC -Iheat -o libbmi_heat.so heat/heat.f90 bmi.f90 bmi_heat/bmi_heat.f90

# Windows
$FC //LD -Iheat -o libbmi_heat.dll heat/heat.f90 bmi.f90 bmi_heat/bmi_heat.f90
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

## ISO_C_BINDING Audit Required

The existing ISO_C_BINDING usage in `bmi_heat.f90` is incomplete:
- `c_loc` and `c_f_pointer` are used only as internal Fortran convenience
- No `bind(C, name=...)` on any functions
- No C-compatible types in function signatures
- Fortran pointer return types are not C-compatible

A full audit and C wrapper layer is needed before Java/JNA can call the library on either windows or linux.

## Java Interop Goal

The shared library will be called from Java via JNA (Java Native Access). 
This requires:
- All exported functions to be C-callable with `bind(C, name="...")` 
- DLLEXPORT directives (`!DIR$ ATTRIBUTES DLLEXPORT`) for Windows compatibility
- An opaque handle pattern: Java holds a `long` representing a `c_ptr` to 
  a heap-allocated `bmi_heat` instance
- No Fortran pointer types in the C API (Fortran pointers are not C-compatible)
- Proper C string handling (null-terminated `c_char` arrays)

## Constraints
- Do NOT modify `bmi.f90` — this is the upstream CSDMS file fetched during CI
- Do NOT modify `heat.f90` — this is the upstream CSDMS file fetched during CI
- No local Fortran compiler available — all builds are validated via GitHub Actions CI
- The C wrapper should be a new file, not modifications to existing source files
