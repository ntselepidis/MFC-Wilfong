#!/usr/bin/env python3
import math
import json

pA = 101325
rhoA = 1.29
gam = 1.4
c_l = math.sqrt(1.4 * pA / rhoA)

M = 1.5
pS = 2.458*pA
velS = 0.701*c_l
rhoS = 1.862*rhoA

# M = 3.0
# pS = 10.333*pA
# velS = 0.475*c_l
# rhoS = 3.857*rhoA

leng = 1e-2
rJet = leng/8
rC = 2*leng/5
Ny = 250
Nx = Ny * 2
Nz = Ny
dx = leng / Nx

time_end = 10 * leng / (M * c_l)
cfl = 0.6

dt = cfl * dx / c_l
Nt = int(time_end / dt)

eps = 1e-5

# Configuring case dictionary
print(
    json.dumps(
        {
            # Logistics
            "run_time_info": "T",
            # Computational Domain Parameters
            "x_domain%beg": -2 * leng,
            "x_domain%end": 3 * leng,
            "y_domain%beg": -1.25 * leng,
            "y_domain%end": 1.25 * leng,
            "z_domain%beg": -1.25 * leng,
            "z_domain%end": 1.25 * leng,
            "m": int(Nx),
            "n": int(Ny),
            "p": int(Nz),
            "dt": dt,
            "t_step_start": 0,
            "t_step_stop": Nt,
            "t_step_save": int(Nt / 100.0),
            # "t_step_stop": 1,
            # "t_step_save": 1,#int(Nt / 20.0),
            # Simulation Algorithm Parameters
            "num_patches": 1,
            "model_eqns": 2,
            "alt_soundspeed": "F",
            "num_fluids": 2,
            "mpp_lim": "F",
            "mixture_err": "F",
            "time_stepper": 3,
            "weno_order": 5,
            "weno_eps": 1.0e-16,
            "weno_Re_flux": "F",
            "weno_avg": "F",
            "mapped_weno": "T",
            "null_weights": "F",
            "mp_weno": "T",
            "riemann_solver": 2,
            "wave_speeds": 1,
            "avg_state": 2,
            # "igr": "T",
            # "alf_igr": 10,
            "elliptic_smoothing": "T",
            "elliptic_smoothing_iters": 100,

            "bc_x%beg": -2,
            "bc_x%end": -3,
            "bc_y%beg": -3,
            "bc_y%end": -3,
            "bc_z%beg": -3,
            "bc_z%end": -3,

            "num_bc_patches": 3,
            # Top jet inlet at left side of domain
            "patch_bc(1)%dir": 1,
            "patch_bc(1)%loc": -1,
            "patch_bc(1)%geometry": 2,
            "patch_bc(1)%type": -17,
            "patch_bc(1)%centroid(2)": rC,
            "patch_bc(1)%centroid(3)": 0,
            "patch_bc(1)%radius": rJet,
            "patch_bc(1)%vel(1)": velS,
            "patch_bc(1)%vel(2)": 0,
            "patch_bc(1)%vel(3)": 0,
            "patch_bc(1)%pres": pS,
            "patch_bc(1)%alpha_rho(1)": rhoS,
            "patch_bc(1)%alpha(1)": 1.0 - eps,
            "patch_bc(1)%alpha_rho(2)": eps,
            "patch_bc(1)%alpha(2)": eps,

            "patch_bc(2)%dir": 1,
            "patch_bc(2)%loc": -1,
            "patch_bc(2)%geometry": 2,
            "patch_bc(2)%type": -17,
            "patch_bc(2)%centroid(2)": -rC*math.sin(math.pi/6),
            "patch_bc(2)%centroid(3)": rC*math.cos(math.pi/6),
            "patch_bc(2)%radius": rJet,
            "patch_bc(2)%vel(1)": velS,
            "patch_bc(2)%vel(2)": 0,
            "patch_bc(2)%vel(3)": 0,
            "patch_bc(2)%pres": pS,
            "patch_bc(2)%alpha_rho(1)": rhoS,
            "patch_bc(2)%alpha(1)": 1.0 - eps,
            "patch_bc(2)%alpha_rho(2)": eps,
            "patch_bc(2)%alpha(2)": eps,

            "patch_bc(3)%dir": 1,
            "patch_bc(3)%loc": -1,
            "patch_bc(3)%geometry": 2,
            "patch_bc(3)%type": -17,
            "patch_bc(3)%centroid(2)": -rC*math.sin(math.pi/6),
            "patch_bc(3)%centroid(3)": -rC*math.cos(math.pi/6),
            "patch_bc(3)%radius": rJet,
            "patch_bc(3)%vel(1)": velS,
            "patch_bc(3)%vel(2)": 0,
            "patch_bc(3)%vel(3)": 0,
            "patch_bc(3)%pres": pS,
            "patch_bc(3)%alpha_rho(1)": rhoS,
            "patch_bc(3)%alpha(1)": 1.0 - eps,
            "patch_bc(3)%alpha_rho(2)": eps,
            "patch_bc(3)%alpha(2)": eps,

            # Formatted Database Files Structure Parameters
            "format": 1,
            "precision": 2,
            "prim_vars_wrt": "T",
            "parallel_io": "T",
            # "file_per_process": "T",

            # Patch 1: Background
            "patch_icpp(1)%geometry": 9,
            "patch_icpp(1)%x_centroid": 0.0,
            "patch_icpp(1)%y_centroid": 0.0,
            "patch_icpp(1)%z_centroid": 0.0,
            "patch_icpp(1)%length_x": 8 * leng,
            "patch_icpp(1)%length_y": 4 * leng,
            "patch_icpp(1)%length_z": 4 * leng,
            "patch_icpp(1)%vel(1)": 0.0e00,
            "patch_icpp(1)%vel(2)": 0.0e00,
            "patch_icpp(1)%vel(3)": 0.0e00,
            "patch_icpp(1)%pres": pA,
            "patch_icpp(1)%alpha_rho(1)": eps*rhoA,
            "patch_icpp(1)%alpha(1)": eps,
            "patch_icpp(1)%alpha_rho(2)": (1-eps)*rhoA,
            "patch_icpp(1)%alpha(2)": 1.0-eps,

            # Fluids Physical Parameters
            "fluid_pp(1)%gamma": 1.0e00 / (1.4e00 - 1.0e00),
            "fluid_pp(1)%pi_inf": 0.0,
            "fluid_pp(2)%gamma": 1.0e00 / (1.4e00 - 1.0e00),
            "fluid_pp(2)%pi_inf": 0.0,

        }
    )
)
