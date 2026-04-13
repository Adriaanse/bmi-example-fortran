markdown# CLAUDE.md



\## Overview

A Fortran BMI (Basic Model Interface) implementation of the 2D heat equation model,

adapted to use the NOAA-OWP NextGen iso\_c\_fortran\_bmi pattern for C/Java interoperability.

This allows the model to be called from Java via JNA (Java Native Access) in Deltares FEWS.



\## Repository Structure



\### bmi\_heat/

\- `bmi.f90`              — CSDMS abstract BMI spec (bmif\_2\_0 module)

\- `bmif\_2\_0\_iso.f90`     — NOAA-OWP ISO C integer types version (bmif\_2\_0\_iso module)

\- `iso\_c\_bmif\_2\_0.f90`   — NOAA-OWP generic C interop layer (iso\_c\_bmif\_2\_0 module)

&#x20;                          Source: https://github.com/NOAA-OWP/ngen/extern/iso\_c\_fortran\_bmi

&#x20;                          Author: Nels Frazier, NOAA OWP, Apache 2.0

\- `bmi\_heat.f90`         — Heat model OO BMI implementation (bmiheatf module, bmi\_heat type)

\- `register\_bmi.f90`     — Model-specific factory function (ONLY model-specific file needed)



\### heat/

\- `heat.f90`             — Heat model physics (heatf module)



\### interop/

\- `bmi\_from\_spec.h`      — C header derived from bmi.f90 spec (reference only)

\- `bmi.h`                — TO BE GENERATED: C header matching actual exported symbols

\- `StandardBmi.java`     — TO BE GENERATED: JNA interface matching exported symbols



\### docker/

\- `Dockerfile`           — AlmaLinux 8 + Intel ifx 2025.2 build environment



\## Build

GitHub Actions builds via .github/workflows/build.yml:

\- Linux: AlmaLinux 8 Docker container, -static-intel, produces libbmi\_heat.so

\- Windows: windows-latest runner, //MD, produces libbmi\_heat.dll + 4 Intel runtime DLLs



\## Exported C Symbols

The shared library exports these C-callable functions (NO bmi\_ prefix):

\- register\_bmi          ← factory function (allocates model, returns opaque handle)

\- initialize            ← BMI initialize

\- update                ← BMI update

\- update\_until          ← BMI update\_until

\- finalize              ← BMI finalize AND memory cleanup (replaces bmi\_destroy)

\- get\_component\_name

\- get\_input\_item\_count / get\_output\_item\_count

\- get\_input\_var\_names / get\_output\_var\_names

\- get\_var\_grid / get\_var\_type / get\_var\_units

\- get\_var\_itemsize / get\_var\_nbytes / get\_var\_location

\- get\_current\_time / get\_start\_time / get\_end\_time

\- get\_time\_step / get\_time\_units

\- get\_value\_int / get\_value\_float / get\_value\_double

\- get\_value\_ptr\_int / get\_value\_ptr\_float / get\_value\_ptr\_double

\- get\_value\_at\_indices\_int / get\_value\_at\_indices\_float / get\_value\_at\_indices\_double

\- set\_value\_int / set\_value\_float / set\_value\_double

\- set\_value\_at\_indices\_int / set\_value\_at\_indices\_float / set\_value\_at\_indices\_double

\- get\_grid\_rank / get\_grid\_size / get\_grid\_type

\- get\_grid\_shape / get\_grid\_spacing / get\_grid\_origin

\- get\_grid\_x / get\_grid\_y / get\_grid\_z

\- get\_grid\_node\_count / get\_grid\_edge\_count / get\_grid\_face\_count

\- get\_grid\_edge\_nodes / get\_grid\_face\_edges / get\_grid\_face\_nodes

\- get\_grid\_nodes\_per\_face



\## Java Lifecycle (via JNA)

```java

Pointer handle = lib.register\_bmi();        // allocate model

lib.initialize(handle, "config.cfg");       // initialize

lib.update(handle);                         // run timestep

lib.get\_value\_float(handle, "plate\_surface\_\_temperature", dest);

lib.finalize(handle);                       // finalize AND deallocate

```



## TODO for Claude Code

1. Generate interop/bmi.h — C header matching exported symbols above

2. Generate interop/FortranModelJnaLibrary.java — JNA interface derived from bmi.h
   - Package: bmi.model

3. Write README.md — human readable explanation of the architecture

\## Constraints

\- Do NOT modify bmi\_heat.f90, bmi.f90, bmif\_2\_0\_iso.f90, iso\_c\_bmif\_2\_0.f90

\- Do NOT add bmi\_ prefix to function names in bmi.h or StandardBmi.java

\- bmi\_destroy does NOT exist — finalize() handles cleanup

\- register\_bmi() replaces bmi\_create()

