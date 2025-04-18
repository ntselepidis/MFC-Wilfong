## Getting the code

1. `git clone git@github.com:wilfonba/MFC-Wilfong.git`
2. `cd MFC-Wilfong/`
3. `git checkout MFC_IDEAS_WS`

## Building and running on GPUs

0. Begin by moving to the `MFC-Wilfong` directory:
1. Load modules for compiling with GPUs:
- (PACE Phoenix) `. ./mfc.sh load -c p -m g`
- (ACCESS Bridges2) `. ./mfc.sh load -c b -m g`
- (ACCESS Delta) `. ./mfc.sh laod -c d -m g`
- (ACCESS DeltaAI) `. ./mfc.sh load -c dai -m g`)
2. Build the code with GPU support with case optimization 
```
./mfc.sh run examples/2D_shockbubble/case.py --case-optimization --gpu -N 1 -n 1 --dry-run -j 32
```
3a. Run the code with GPU support (if already in an interactive session)
```
./mfc.sh run examples/2D_shockbubble/case.py --case-optimization --gpu -N 1 -n 1 -c <computer> -j 32
```
where
- `<computer>` = phoenix for PACE Phoenix
- `<computer>` = bridges2 for ACCESS Bridges2
- `<computer>` = delta for ACCESS Delta
- `<computer>` = deltaai for ACCESS DeltaAI
3b. Run the code with GPU support (in a batch job)
```
./mfc.sh run examples/2D_shockbubble/case.py --case-optimization --gpu -N 1 -n 1 -c <computer> -j 32 -e batch -a <account> -# <job_name> -w 1:00:00
```
where
- `<computer>` = phoenix for PACE Phoenix
- `<computer>` = bridges2 for ACCESS Bridges2
- `<computer>` = delta for ACCESS Delta
- `<computer>` = deltaai for ACCESS DeltaAI

## Post Processing

Post processing is not yet as automated as building and running the code.
The following sections are outlines on how to post process on Phoenix, though they
don't currently work due to an issue with the Paraview version on that system.
In general, an EGL version of Paraview 5.11.2 coupled with a CUDA module should work.
For assistance with post processing on Bridges2, Delta, or DeltaAI, please reach
out to me via email at `bwilfong3@gatech.edu` and I can assist with picking the 
correct modules if needed.

### Post Processing on Phoenix (interactive mode)
0. Begin in the `MFC-Wilfong/examples/2D_shockbubble/` directory
1. Load modules for visualization on Phoenix
```
module load paraview/5.12.0-egl cuda
```
2. Visualize the results using `pvbatch`
```
pvbatch visualize.py
```
4. Download the images (stored in `examples/2D_shockbubble/render`) to your local machine with `rsync`, `scp`, or your tool of choice
5. Render the video with `ffmpeg` on your local machine
```
ffmpeg -r 30 -f image2 -i pic.%04d.png -vcodec libx264 -crf 25  -pix_fmt yuv420p test.mp4
```

### Post Processing on Phoenix (batch mode)
0. Begin in the `MFC-Wilfong/examples/2D_shockbubble/` directory
1. Paste the following into a SLURM submission script `visualize.sh`:
```
#!/bin/bash
#SBATCH -A <account>
#SBATCH -J visualize
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
#SBATCH --gre=gpu:RTX_6000:1
#SBATCH --output="visualize.out"
#SBATCH --error="visualize.err"
#SBATCH -t 00:10:00

module load paraview/5.12.0-egl cuda
pvbatch visualize.py $SLURM_SUBMIT_DIR

```
2. Submit the back job to the quueue with `sbatch visualize.sh`
3. Download the images (stored in `examples/2D_shockbubble/render`) to your local machine with `rsync`, `scp`, or your tool of choice
4. Render the video with `ffmpeg` on your local machine
```
ffmpeg -r 30 -f image2 -i pic.%04d.png -vcodec libx264 -crf 25  -pix_fmt yuv420p test.mp4
```

