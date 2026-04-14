# CLAUDE.md

## Overview

A Fortran BMI (Basic Model Interface) implementation of the 2D heat equation model,
adapted to use the NOAA-OWP NextGen `iso_c_fortran_bmi` pattern for C/Java interoperability.
This allows the model to be called from Java via JNA (Java Native Access) in Deltares FEWS.

## Repository Structure

### bmi_heat/
- `bmi.f90`              — CSDMS abstract BMI spec (bmif_2_0 module)
- `bmif_2_0_iso.f90`     — NOAA-OWP ISO C integer types version (bmif_2_0_iso module)
- `iso_c_bmif_2_0.f90`   — NOAA-OWP generic C interop layer (iso_c_bmif_2_0 module)
                           Source: https://github.com/NOAA-OWP/ngen/extern/iso_c_fortran_bmi
                           Author: Nels Frazier, NOAA OWP, Apache 2.0
- `bmi_heat.f90`         — Heat model OO BMI implementation (bmiheatf module, bmi_heat type)
- `register_bmi.f90`     — Model-specific factory function (ONLY model-specific file needed)

### heat/
- `heat.f90`             — Heat model physics (heatf module)

### interop/
- `bmi_from_spec.h`           — C header derived from bmi.f90 spec (reference only)
- `bmi.h`                     — C header matching actual exported symbols and ABI
- `FortranModelJnaLibrary.java` — JNA interface (package bmi.model)
- `FortranString.java`        — Helper: converts Java String ↔ Fortran fixed-size byte[]

### docker/
- `Dockerfile`           — AlmaLinux 8 + Intel ifx 2025.2 build environment

## Build

GitHub Actions builds via .github/workflows/build.yml:
- Linux: AlmaLinux 8 Docker container, -static-intel, produces libbmi_heat.so
- Windows: windows-latest runner, /MD, produces libbmi_heat.dll + 4 Intel runtime DLLs

## Exported C Symbols

The shared library exports these C-callable functions (NO bmi_ prefix):
- register_bmi          ← factory function (allocates model, returns opaque handle via void**)
- initialize            ← BMI initialize
- update                ← BMI update
- update_until          ← BMI update_until
- finalize              ← BMI finalize AND memory cleanup (replaces bmi_destroy)
- get_component_name
- get_input_item_count / get_output_item_count
- get_input_var_names / get_output_var_names
- get_var_grid / get_var_type / get_var_units
- get_var_itemsize / get_var_nbytes / get_var_location
- get_current_time / get_start_time / get_end_time
- get_time_step / get_time_units
- get_value_int / get_value_float / get_value_double
- get_value_ptr_int / get_value_ptr_float / get_value_ptr_double
- get_value_at_indices_int / get_value_at_indices_float / get_value_at_indices_double
- set_value_int / set_value_float / set_value_double
- set_value_at_indices_int / set_value_at_indices_float / set_value_at_indices_double
- get_grid_rank / get_grid_size / get_grid_type
- get_grid_shape / get_grid_spacing / get_grid_origin
- get_grid_x / get_grid_y / get_grid_z
- get_grid_node_count / get_grid_edge_count / get_grid_face_count
- get_grid_edge_nodes / get_grid_face_edges / get_grid_face_nodes
- get_grid_nodes_per_face

## Critical ABI details

**handle is void\*\* (not void\*)**
Every function except `register_bmi` receives the opaque handle as
`type(c_ptr), intent(in)` WITHOUT the Fortran VALUE attribute.
Without VALUE, Fortran bind(C) passes by reference → the C ABI is `void**`.
In Java/JNA this means `PointerByReference`, not `Pointer`. Do NOT unwrap
with `.getValue()` before calling BMI methods.

**Strings must be fixed-size byte[] buffers**
String input parameters are Fortran `character(kind=c_char), dimension(*)` —
fixed-length arrays of exactly BMI_MAX_FILE_NAME (2048) or BMI_MAX_VAR_NAME (2048)
bytes. Use `new FortranString("...").toBytes()` for every string argument.
Passing a Java String directly causes JNA to send a short char* → SIGSEGV.

See `interop/bmi.h` for the full list of ABI differences (DIFF 1–8).

## Java Lifecycle (via JNA)

```java
FortranModelJnaLibrary lib = Native.load("bmi_heat", FortranModelJnaLibrary.class);

PointerByReference handleRef = new PointerByReference();
lib.register_bmi(handleRef);
// All methods take handleRef directly — do NOT call handleRef.getValue()

lib.initialize(handleRef, new FortranString("config.cfg").toBytes());
lib.update(handleRef);

float[] dest = new float[gridSize];
lib.get_value_float(handleRef, new FortranString("plate_surface__temperature").toBytes(), dest);

lib.finalize(handleRef);   // finalize AND deallocate — do not use handleRef after this
```

## Constraints

- Do NOT modify bmi_heat.f90, bmi.f90, bmif_2_0_iso.f90, iso_c_bmif_2_0.f90
- Do NOT add bmi_ prefix to function names in bmi.h or FortranModelJnaLibrary.java
- bmi_destroy does NOT exist — finalize() handles cleanup
- register_bmi() replaces bmi_create()
