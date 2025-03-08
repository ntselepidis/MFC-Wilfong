# state file generated using paraview version 5.11.0
import paraview
paraview.compatibility.major = 5
paraview.compatibility.minor = 11

#### import the simple module from the paraview
from paraview.simple import *
import glob
import re
#### disable automatic camera reset on 'Show'
paraview.simple._DisableFirstRenderCameraReset()

case_dir="/fastscratch/bwilfong3/software/MFC-Wilfong/examples/3D_multijet"

# ----------------------------------------------------------------
# setup views used in the visualization
# ----------------------------------------------------------------

# get the material library
materialLibrary1 = GetMaterialLibrary()

# Create a new 'Render View'
renderView1 = CreateView('RenderView')
renderView1.ViewSize = [872, 531]
renderView1.AxesGrid = 'GridAxes3DActor'
renderView1.OrientationAxesVisibility = 0
renderView1.CenterOfRotation = [0.0, -1.734723475976807e-18, -1.734723475976807e-18]
renderView1.StereoType = 'Crystal Eyes'
renderView1.CameraPosition = [0.014624138465596076, -0.02812389108235468, 0.0401804984017618]
renderView1.CameraFocalPoint = [-0.00917631426914208, 0.008406729407614109, -0.01514558623077001]
renderView1.CameraViewUp = [-0.16181772794869215, 0.7900679022246406, 0.5912763590706791]
renderView1.CameraViewAngle = 27.522935779816518
renderView1.CameraFocalDisk = 1.0
renderView1.CameraParallelScale = 0.026692668937382646
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
layout1.SetSize(872, 531)

# ----------------------------------------------------------------
# restore active view
SetActiveView(renderView1)
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# setup the data processing pipelines
# ----------------------------------------------------------------

# create a new 'Cylinder'
# cylinder1 = Cylinder(registrationName='Cylinder1')
# cylinder1.Resolution = 128
# cylinder1.Height = 0.001
# cylinder1.Radius = 0.0075
# cylinder1.Center = [0.0, -0.0205, 0.0]

# create a new 'VisItSiloReader'
file_dir=f"{case_dir}/3D_multijet/silo_hdf5/root/*"
print(file_dir)
files = glob.glob(f"{case_dir}/silo_hdf5/root/*")
sorted_files = sorted(files, key=lambda x: int(x.rsplit('_', 1)[-1][:-5]))
print(sorted_files)
collection_0silo = VisItSiloReader(registrationName='collection_0.silo*', FileName=sorted_files)
collection_0silo.MeshStatus = ['rectilinear_grid']
collection_0silo.CellArrayStatus = ['alpha1']

# create a new 'Resample To Image'
resampleToImage1 = ResampleToImage(registrationName='ResampleToImage1', Input=collection_0silo)
resampleToImage1.SamplingDimensions = [640, 400, 400]
resampleToImage1.SamplingBounds = [-0.02, 0.02, -0.0125, 0.0125, -0.0125, 0.0125]

# ----------------------------------------------------------------
# setup the visualization in view 'renderView1'
# ----------------------------------------------------------------

# show data from resampleToImage1
resampleToImage1Display = Show(resampleToImage1, renderView1, 'UniformGridRepresentation')

# get 2D transfer function for 'alpha1'
alpha1TF2D = GetTransferFunction2D('alpha1')
alpha1TF2D.ScalarRangeInitialized = 1
alpha1TF2D.Range = [0.1, 0.9, 0.0, 1.0]

# get color transfer function/color map for 'alpha1'
alpha1LUT = GetColorTransferFunction('alpha1')
alpha1LUT.AutomaticRescaleRangeMode = 'Never'
alpha1LUT.TransferFunction2D = alpha1TF2D
alpha1LUT.RGBPoints = [0.1, 1.0, 1.0, 1.0, 0.14705879999999993, 0.919118, 0.948529, 0.948529, 0.19725479999999998, 0.832843, 0.893627, 0.893627, 0.24745080000000003, 0.746569, 0.838725, 0.838725, 0.29764719999999995, 0.660294, 0.783824, 0.783824, 0.3478432000000001, 0.603922, 0.708987, 0.728922, 0.39803920000000004, 0.54902, 0.63317, 0.67402, 0.44823519999999994, 0.494118, 0.557353, 0.619118, 0.4984313720000001, 0.439216, 0.481536, 0.564216, 0.5486276, 0.384314, 0.405719, 0.509314, 0.5988236000000001, 0.329412, 0.329902, 0.454412, 0.6490196, 0.27451, 0.27451, 0.379085, 0.6992155999999999, 0.219608, 0.219608, 0.303268, 0.7494116000000001, 0.164706, 0.164706, 0.227451, 0.799608, 0.109804, 0.109804, 0.151634, 0.8498040000000001, 0.054902, 0.054902, 0.075817, 0.9, 0.0, 0.0, 0.0]
alpha1LUT.ColorSpace = 'Lab'
alpha1LUT.NanColor = [1.0, 0.0, 0.0]
alpha1LUT.ScalarRangeInitialized = 1.0

# get opacity transfer function/opacity map for 'alpha1'
alpha1PWF = GetOpacityTransferFunction('alpha1')
alpha1PWF.Points = [0.1, 0.0, 0.5, 0.0, 0.9, 1.0, 0.5, 0.0]
alpha1PWF.ScalarRangeInitialized = 1

# trace defaults for the display properties.
resampleToImage1Display.Representation = 'Volume'
resampleToImage1Display.ColorArrayName = ['POINTS', 'alpha1']
resampleToImage1Display.LookupTable = alpha1LUT
resampleToImage1Display.SelectTCoordArray = 'None'
resampleToImage1Display.SelectNormalArray = 'None'
resampleToImage1Display.SelectTangentArray = 'None'
resampleToImage1Display.OSPRayScaleArray = 'alpha1'
resampleToImage1Display.OSPRayScaleFunction = 'PiecewiseFunction'
resampleToImage1Display.SelectOrientationVectors = 'None'
resampleToImage1Display.ScaleFactor = 0.0039999960000000005
resampleToImage1Display.SelectScaleArray = 'None'
resampleToImage1Display.GlyphType = 'Arrow'
resampleToImage1Display.GlyphTableIndexArray = 'None'
resampleToImage1Display.GaussianRadius = 0.00019999980000000002
resampleToImage1Display.SetScaleArray = ['POINTS', 'alpha1']
resampleToImage1Display.ScaleTransferFunction = 'PiecewiseFunction'
resampleToImage1Display.OpacityArray = ['POINTS', 'alpha1']
resampleToImage1Display.OpacityTransferFunction = 'PiecewiseFunction'
resampleToImage1Display.DataAxesGrid = 'GridAxesRepresentation'
resampleToImage1Display.PolarAxes = 'PolarAxesRepresentation'
resampleToImage1Display.ScalarOpacityUnitDistance = 5.717986384160912e-05
resampleToImage1Display.ScalarOpacityFunction = alpha1PWF
resampleToImage1Display.TransferFunction2D = alpha1TF2D
resampleToImage1Display.OpacityArrayName = ['POINTS', 'alpha1']
resampleToImage1Display.ColorArray2Name = ['POINTS', 'alpha1']
resampleToImage1Display.SliceFunction = 'Plane'
resampleToImage1Display.Slice = 199
resampleToImage1Display.SelectInputVectors = [None, '']
resampleToImage1Display.WriteLog = ''

# init the 'PiecewiseFunction' selected for 'ScaleTransferFunction'
resampleToImage1Display.ScaleTransferFunction.Points = [-0.04653765474433749, 0.0, 0.5, 0.0, 1.0764508157018176, 1.0, 0.5, 0.0]

# init the 'PiecewiseFunction' selected for 'OpacityTransferFunction'
resampleToImage1Display.OpacityTransferFunction.Points = [-0.04653765474433749, 0.0, 0.5, 0.0, 1.0764508157018176, 1.0, 0.5, 0.0]

# init the 'Plane' selected for 'SliceFunction'
resampleToImage1Display.SliceFunction.Origin = [0.0, -1.734723475976807e-18, -1.734723475976807e-18]

# show data from cylinder1
# cylinder1Display = Show(cylinder1, renderView1, 'GeometryRepresentation')

# trace defaults for the display properties.
# cylinder1Display.Representation = 'Surface'
# cylinder1Display.ColorArrayName = [None, '']
# cylinder1Display.Interpolation = 'PBR'
# cylinder1Display.Roughness = 0.51
# cylinder1Display.Metallic = 1.0
# cylinder1Display.SelectTCoordArray = 'TCoords'
# cylinder1Display.SelectNormalArray = 'Normals'
# cylinder1Display.SelectTangentArray = 'None'
# cylinder1Display.Orientation = [0.0, 0.0, -90.0]
# cylinder1Display.OSPRayScaleArray = 'Normals'
# cylinder1Display.OSPRayScaleFunction = 'PiecewiseFunction'
# cylinder1Display.SelectOrientationVectors = 'None'
# cylinder1Display.ScaleFactor = 0.0014999999664723875
# cylinder1Display.SelectScaleArray = 'None'
# cylinder1Display.GlyphType = 'Arrow'
# cylinder1Display.GlyphTableIndexArray = 'None'
# cylinder1Display.GaussianRadius = 7.499999832361936e-05
# cylinder1Display.SetScaleArray = ['POINTS', 'Normals']
# cylinder1Display.ScaleTransferFunction = 'PiecewiseFunction'
# cylinder1Display.OpacityArray = ['POINTS', 'Normals']
# cylinder1Display.OpacityTransferFunction = 'PiecewiseFunction'
# cylinder1Display.DataAxesGrid = 'GridAxesRepresentation'
# cylinder1Display.PolarAxes = 'PolarAxesRepresentation'
# cylinder1Display.SelectInputVectors = ['POINTS', 'Normals']
# cylinder1Display.WriteLog = ''

# # init the 'PiecewiseFunction' selected for 'ScaleTransferFunction'
# cylinder1Display.ScaleTransferFunction.Points = [-1.0, 0.0, 0.5, 0.0, 1.0, 1.0, 0.5, 0.0]

# # init the 'PiecewiseFunction' selected for 'OpacityTransferFunction'
# cylinder1Display.OpacityTransferFunction.Points = [-1.0, 0.0, 0.5, 0.0, 1.0, 1.0, 0.5, 0.0]

# # init the 'PolarAxesRepresentation' selected for 'PolarAxes'
# cylinder1Display.PolarAxes.Orientation = [0.0, 0.0, -90.0]

# ----------------------------------------------------------------
# setup color maps and opacity mapes used in the visualization
# note: the Get..() functions create a new object, if needed
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# restore active source
SetActiveSource(resampleToImage1)
# ----------------------------------------------------------------

# Ensure all time steps are considered
timeKeeper = GetTimeKeeper()
timeSteps = timeKeeper.TimestepValues

animationScene = GetAnimationScene()

i = 0
# Save all timesteps
for t in timeSteps:
    animationScene.AnimationTime = t
    SaveScreenshot(f"{case_dir}/render/pic_{i:04d}.png", renderView1, ImageResolution=[4096, 2500])
    print(i)
    i = i + 1

