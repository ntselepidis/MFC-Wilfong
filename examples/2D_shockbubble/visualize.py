# state file generated using paraview version 5.11.0
import paraview
paraview.compatibility.major = 5
paraview.compatibility.minor = 11

#### import the simple module from the paraview
from paraview.simple import *
import os, re, glob
#### disable automatic camera reset on 'Show'
paraview.simple._DisableFirstRenderCameraReset()

# ----------------------------------------------------------------
# setup views used in the visualization
# ----------------------------------------------------------------

# get the material library
materialLibrary1 = GetMaterialLibrary()

# Create a new 'Render View'
renderView1 = CreateView('RenderView')
renderView1.ViewSize = [2210, 772]
renderView1.InteractionMode = '2D'
renderView1.AxesGrid = 'GridAxes3DActor'
renderView1.OrientationAxesVisibility = 0
renderView1.CenterOfRotation = [1.0, 0.0, 0.0]
renderView1.UseLight = 0
renderView1.StereoType = 'Crystal Eyes'
renderView1.CameraPosition = [1.0, 0.0, 6.109051323707208]
renderView1.CameraFocalPoint = [1.0, 0.0, 0.0]
renderView1.CameraFocalDisk = 1.0
renderView1.CameraParallelScale = 0.6711215151728613
renderView1.UseColorPaletteForBackground = 0
renderView1.Background = [1.0, 1.0, 1.0]
renderView1.BackEnd = 'OSPRay raycaster'
renderView1.OSPRayMaterialLibrary = materialLibrary1

SetActiveView(None)

# ----------------------------------------------------------------
# setup view layouts
# ----------------------------------------------------------------

# create new layout object 'Layout #1'
layout1 = CreateLayout(name='Layout #1')
layout1.AssignView(0, renderView1)
layout1.SetSize(2210, 772)

# ----------------------------------------------------------------
# restore active view
SetActiveView(renderView1)
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# setup the data processing pipelines
# ----------------------------------------------------------------

# create a new 'VisItSiloReader'
case_dir=os.getcwd()
print(case_dir)
# create a new 'VisItSiloReader'
files = glob.glob(f"{case_dir}/silo_hdf5/root/*")
print(files)
sorted_files = sorted(files, key=lambda x: int(x.rsplit('_', 1)[-1][:-5]))
print(sorted_files)
collection_0silo = VisItSiloReader(registrationName='collection_0.silo*', FileName=sorted_files)
collection_0silo.MeshStatus = ['rectilinear_grid']
collection_0silo.CellArrayStatus = ['alpha1', 'alpha2', 'alpha_rho1', 'alpha_rho2', 'pres', 'vel1', 'vel2']

# ----------------------------------------------------------------
# setup the visualization in view 'renderView1'
# ----------------------------------------------------------------

# show data from collection_0silo
collection_0siloDisplay = Show(collection_0silo, renderView1, 'UniformGridRepresentation')

# get 2D transfer function for 'alpha1'
alpha1TF2D = GetTransferFunction2D('alpha1')
alpha1TF2D.ScalarRangeInitialized = 1
alpha1TF2D.Range = [1e-08, 0.99999999, 0.0, 1.0]

# get color transfer function/color map for 'alpha1'
alpha1LUT = GetColorTransferFunction('alpha1')
alpha1LUT.TransferFunction2D = alpha1TF2D
alpha1LUT.RGBPoints = [-0.001545367168915121, 0.231373, 0.298039, 0.752941, 0.49922731535958514, 0.865003, 0.865003, 0.865003, 0.9999999978880855, 0.705882, 0.0156863, 0.14902]
alpha1LUT.ScalarRangeInitialized = 1.0

# get opacity transfer function/opacity map for 'alpha1'
alpha1PWF = GetOpacityTransferFunction('alpha1')
alpha1PWF.Points = [-0.001545367168915121, 0.0, 0.5, 0.0, 0.9999999978880855, 1.0, 0.5, 0.0]
alpha1PWF.ScalarRangeInitialized = 1

# trace defaults for the display properties.
collection_0siloDisplay.Representation = 'Surface'
collection_0siloDisplay.ColorArrayName = ['CELLS', 'alpha1']
collection_0siloDisplay.LookupTable = alpha1LUT
collection_0siloDisplay.SelectTCoordArray = 'None'
collection_0siloDisplay.SelectNormalArray = 'None'
collection_0siloDisplay.SelectTangentArray = 'None'
collection_0siloDisplay.OSPRayScaleFunction = 'PiecewiseFunction'
collection_0siloDisplay.SelectOrientationVectors = 'None'
collection_0siloDisplay.ScaleFactor = 0.30000000000000004
collection_0siloDisplay.SelectScaleArray = 'None'
collection_0siloDisplay.GlyphType = 'Arrow'
collection_0siloDisplay.GlyphTableIndexArray = 'None'
collection_0siloDisplay.GaussianRadius = 0.015
collection_0siloDisplay.SetScaleArray = [None, '']
collection_0siloDisplay.ScaleTransferFunction = 'PiecewiseFunction'
collection_0siloDisplay.OpacityArray = [None, '']
collection_0siloDisplay.OpacityTransferFunction = 'PiecewiseFunction'
collection_0siloDisplay.DataAxesGrid = 'GridAxesRepresentation'
collection_0siloDisplay.PolarAxes = 'PolarAxesRepresentation'
collection_0siloDisplay.ScalarOpacityUnitDistance = 0.09872385855544324
collection_0siloDisplay.ScalarOpacityFunction = alpha1PWF
collection_0siloDisplay.TransferFunction2D = alpha1TF2D
collection_0siloDisplay.OpacityArrayName = ['CELLS', 'alpha1']
collection_0siloDisplay.ColorArray2Name = ['CELLS', 'alpha1']
collection_0siloDisplay.SliceFunction = 'Plane'
collection_0siloDisplay.SelectInputVectors = [None, '']
collection_0siloDisplay.WriteLog = ''

# init the 'Plane' selected for 'SliceFunction'
collection_0siloDisplay.SliceFunction.Origin = [1.0, 0.0, 0.0]

# ----------------------------------------------------------------
# setup color maps and opacity mapes used in the visualization
# note: the Get..() functions create a new object, if needed
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# restore active source
SetActiveSource(collection_0silo)
# ----------------------------------------------------------------

# Ensure all time steps are considered
timeKeeper = GetTimeKeeper()
timeSteps = timeKeeper.TimestepValues

animationScene = GetAnimationScene()

directory_path = f"{case_dir}/render"
os.makedirs(directory_path, exist_ok=True)

i = 0
# Save all timesteps
for t in timeSteps:
    animationScene.AnimationTime = t
    SaveScreenshot(f"{case_dir}/render/pic.{i:04d}.png", renderView1, ImageResolution=[2110,722])
    print(i)
    i = i + 1
