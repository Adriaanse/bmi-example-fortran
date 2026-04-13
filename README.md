[![Basic Model Interface](https://img.shields.io/badge/CSDMS-Basic%20Model%20Interface-green.svg)](https://bmi.readthedocs.io/)
[![Build/Test](https://github.com/csdms/bmi-example-fortran/workflows/Build/Test/badge.svg)](https://github.com/csdms/bmi-example-fortran/actions?query=workflow%3ABuild%2FTest)

# bmi-example-fortran

An example of implementing the
[Fortran bindings](https://github.com/csdms/bmi-fortran)
for the CSDMS [Basic Model Interface](https://bmi.csdms.io) (BMI).

## Overview

This is an example of implementing a BMI
for a simple model that  solves the diffusion equation
on a uniform rectangular plate
with Dirichlet boundary conditions.
Tests and examples of using the BMI are provided.
The model is written in Fortran 90.
The BMI is written in Fortran 2003.

This repository is organized with the following directories:

<dl>
    <dt>heat</dt>
	<dd>Holds the model and a sample main program</dd>
    <dt>bmi_heat</dt>
	<dd>Holds the BMI for the model and a main program to run the
    model through its BMI</dd>
	<dt>test</dt>
	<dd>Unit tests for the BMI-ed model</dd>
    <dt>example</dt>
	<dd>Examples of controlling the model through its BMI</dd>
</dl>

## Build/Install

This example can be built on Linux, macOS, and Windows.

**Prerequisites:**
* A Fortran compiler
* CMake or [Fortran Package Manager](https://fpm.fortran-lang.org/)
* If using CMake, the Fortran BMI bindings. Follow the build and
  install directions given in the
  [README](https://github.com/csdms/bmi-fortran/blob/master/README.md)
  in that repository.  You can choose to build them from source or
  install them through a conda binary. If using fpm, the binding
  will be automatically downloaded and built for you.
* pkg-config

### CMake - Linux and macOS

To configure and build this example from source with CMake,
using the current Fortran BMI version, run

    cmake -B _build -DCMAKE_INSTALL_PREFIX=<path-to-installation>
    cmake --build _build

where `<path-to-installation>` is the base directory
in which the Fortran BMI bindings have been installed
(`/usr/local` is the default).
When installing into a conda environment,
use the `$CONDA_PREFIX` environment variable.

Then, to install:

    cmake --install _build

The installation will look like
(on macOS, using v2.0 of the Fortran BMI specification):

```bash
.
|-- bin
|   |-- run_bmiheatf
|   `-- run_heatf
|-- include
|   |-- bmif_2_0.mod
|   |-- bmiheatf.mod
|   `-- heatf.mod
`-- lib
    |-- libbmif.a
    |-- libbmif.2.1.4.dylib
    |-- libbmif.dylib -> libbmif.2.1.4.dylib
    |-- libbmiheatf.dylib
    |-- libheatf.dylib
    `-- pkgconfig
        |-- bmif.pc
        |-- bmiheatf.pc
        `-- heatf.pc
```

Run unit tests and examples of using the sample implementation with

    ctest --test-dir _build

### CMake - Windows

An additional prerequisite is needed for Windows:

* Microsoft Visual Studio 2017 or Microsoft Build Tools for Visual Studio 2017

To configure and build this example from source with CMake
using the current Fortran BMI version,
run the following in a [Developer Command Prompt](https://docs.microsoft.com/en-us/dotnet/framework/tools/developer-command-prompt-for-vs)

    cmake -B _build -L -G Ninja -DCMAKE_INSTALL_PREFIX=<path-to-installation>
	cmake --build _build

where `<path-to-installation>` is the base directory
in which the Fortran BMI bindings have been installed.
The default is `"C:\Program Files (x86)"`.
Note that quotes and an absolute path are needed.
When using a conda environment, use `"%CONDA_PREFIX%\Library"`.

Then, to install:

	cmake --install _build

Run unit tests and examples of using the sample implementation with

    ctest --test-dir _build


### Fortran Package Manager (fpm)

If you don't already have fpm installed, you can do so via Conda:

    conda install fpm -c conda-forge

Then, to build and install:

    fpm build --profile release
    fpm install --prefix <path-to-installation>

where `<path-to-installation>` is the base directory in which to
install the model. Installation is optional.

To run the tests:

    fpm test -- test/sample.cfg

Here, `test/sample.cfg` is passed as a command line parameter to the
run executables, and tells the tests where to find the test config
file.

To run all of the examples:

    fpm run --example --all -- example

Similarly, `example` tells the example executables to look in the
`example` directory for config files. To run individual tests:

    fpm run --example <example-name> -- example

Where `<example-name>` is the name of the example to run. To see
a list of available examples, run `fpm run --example`. Note that the
non-BMI heat model executable is not built by default when using fpm.
If you want to build and install this too, you can do so from the
heat directory:

    cd heat
    fpm build --profile release
    fpm install --prefix <path-to-installation>


## Use

Run the heat model through its BMI with the `run_bmiheatf` program,
which takes a model configuration file
(see the [example](./example) directory for a sample)
as a required parameter.
If `run_bmiheatf` is in your path, run it with

    run_bmiheatf test1.cfg

Output from the model is written to the file **bmiheatf.out**
in the current directory.

If you built the model using fpm, you can alternatively run the
program using

    fpm run -- test.cfg

---

## Deltares FEWS / Java interop

This fork adds a C/Java interoperability layer on top of the standard BMI
implementation, following the [NOAA-OWP NextGen `iso_c_fortran_bmi`](https://github.com/NOAA-OWP/ngen/tree/development/extern/iso_c_fortran_bmi)
pattern. This allows the model to be called from Java via
[JNA (Java Native Access)](https://github.com/java-native-access/jna)
inside [Deltares FEWS](https://www.deltares.nl/en/software-and-data/products/delft-fews).

### Architecture

```
Java (FEWS)
    │  JNA – interop/FortranModelJnaLibrary.java
    ▼
libbmi_heat.so / .dll
    ├── register_bmi.f90          model-specific factory function
    ├── iso_c_bmif_2_0.f90        generic C-interop layer (all 50+ BMI functions)
    │       uses ↓
    ├── bmif_2_0_iso.f90          BMI abstract type with ISO C integer kinds
    │       extends ↓
    ├── bmi.f90                   CSDMS BMI v2.0 abstract spec
    │
    └── bmi_heat.f90              concrete heat-model BMI implementation
            uses ↓
        heat.f90                  2D heat equation physics
```

### Opaque handle pattern

`register_bmi(void** handle)` allocates a `bmi_heat` instance, wraps it in a
thin Fortran `box` type, and returns `c_loc(box)` as an opaque `void*`. Every
other BMI function takes this handle, recovers the Fortran object with
`c_f_pointer`, and dispatches polymorphically.

`finalize(void* handle)` **both** runs the BMI finalize method **and**
deallocates the model. There is no separate `bmi_destroy()` — do not use
the handle after calling `finalize`.

### FEWS build (GitHub Actions)

| Platform | Container / runner | Compiler | Output |
|----------|--------------------|----------|--------|
| Linux | AlmaLinux 8 Docker (`docker/Dockerfile`) | Intel ifx 2025.2 | `libbmi_heat.so` (statically linked Intel runtime) |
| Windows | `windows-latest` | Intel ifx 2025.2 | `libbmi_heat.dll` + 4 Intel runtime DLLs |

### Java usage (JNA)

```java
import bmi.model.FortranModelJnaLibrary;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Memory;
import com.sun.jna.ptr.*;

// Load the shared library
FortranModelJnaLibrary lib =
    Native.load("bmi_heat", FortranModelJnaLibrary.class);

// Allocate the model
PointerByReference handleRef = new PointerByReference();
lib.register_bmi(handleRef);
Pointer handle = handleRef.getValue();

// Initialize
lib.initialize(handle, "/path/to/config.cfg");

// Find grid size for a variable
IntByReference gridRef = new IntByReference();
lib.get_var_grid(handle, "plate_surface__temperature", gridRef);
IntByReference sizeRef = new IntByReference();
lib.get_grid_size(handle, gridRef, sizeRef);

// Run one step and retrieve results
lib.update(handle);
float[] dest = new float[sizeRef.getValue()];
lib.get_value_float(handle, "plate_surface__temperature", dest);

// Finalize (also frees memory)
lib.finalize(handle);
```

### Interop files

| File | Purpose |
|------|---------|
| `interop/bmi.h` | C header with exact exported symbol signatures and ABI notes |
| `interop/FortranModelJnaLibrary.java` | JNA interface (`bmi.model` package) |
| `interop/bmi_from_spec.h` | Reference header derived from the abstract Fortran spec (not the actual ABI) |

See `interop/bmi.h` for important ABI differences from the abstract spec,
including known stub implementations and a bug in `get_grid_edge_nodes`.

### Known limitations

- `get_value_ptr_*` — not implemented; always returns `BMI_FAILURE`.
- `get/set_value_at_indices_*` — not implemented; always returns `BMI_FAILURE`.
- `get_grid_edge_nodes` — contains a logic bug in `iso_c_bmif_2_0.f90`
  (line 893) that may cause incorrect array sizing. See `interop/bmi.h` (BUG 1).

### Credits

- NOAA-OWP `iso_c_fortran_bmi` interop layer: Nels Frazier, NOAA OWP (Apache 2.0)