#!/usr/bin/env python3
import math
import json

Nx = 39
Ny = 312
Nz = 39

# Configuration case dictionary
data = {
    # Logistics
    "run_time_info": "T",
    # Computational Domain
    "x_domain%beg": 0,
    "x_domain%end": 0.5,
    "y_domain%beg": 0,
    "y_domain%end": 4,
    "z_domain%beg": 0,
    "z_domain%end": 0.5,
    "m": Nx,
    "n": Ny,
    "p": Nz,
    "cyl_coord": "F",
    "cfl_adap_dt": "T",
    "cfl_target": 0.8,
    "n_start": 0,
    "t_stop": 2,
    "t_save": 2/50,
    # Simulation Algorithm
    "model_eqns": 2,
    "alt_soundspeed": "F",
    "time_stepper": 3,
    "avg_state": 2,
    "weno_order": 7,
    "weno_eps": 1e-16,
    "mapped_weno": "T",
    "null_weights": "F",
    "mp_weno": "F",
    "weno_Re_flux": "F",
    "riemann_solver": 2,
    "wave_speeds": 1,
    "bc_x%beg": -2,
    "bc_x%end": -2,
    "bc_y%beg": -3,
    "bc_y%end": -3,
    "bc_z%beg": -2,
    "bc_z%end": -2,
    "num_patches": 1,
    "num_fluids": 1,
    # Database Structure Parameters
    "format": 1,
    "precision": 2,
    "prim_vars_wrt": "T",
    "parallel_io": "T",
    # Fluid Parameters (Heavy Gas)
    "fluid_pp(1)%gamma": 1.0e00 / (1.4e00 - 1.0e00),
    "fluid_pp(1)%pi_inf": 0.0e00,
    # Water Patch
    "patch_icpp(1)%geometry": 13,
    "patch_icpp(1)%hcid": 302,
    "patch_icpp(1)%x_centroid": 0,
    "patch_icpp(1)%y_centroid": 2,
    "patch_icpp(1)%z_centroid": 0,
    "patch_icpp(1)%length_x": 1,
    "patch_icpp(1)%length_y": 4,
    "patch_icpp(1)%length_z": 1,
    "patch_icpp(1)%vel(1)": 0.0,
    "patch_icpp(1)%vel(2)": 0.0,
    "patch_icpp(1)%vel(3)": 0.0,
    "patch_icpp(1)%pres": 1e5,
    "patch_icpp(1)%alpha_rho(1)": 1,
    "patch_icpp(1)%alpha(1)": 1,
}

print(json.dumps(data))
