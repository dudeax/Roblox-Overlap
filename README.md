# Roblox-Overlap
A module written for Roblox Luau that make detecting part overlap for simple primitives easy.

# API
Overlap.GetMeshFromBlock(Part)
  Returns a new mesh object from a part asssuming that part has a block form factor,
  I.e. the part is a rectangular prism.

Overlap.GetMeshFromWedge(Part)
  Returns a new mesh object from a part assuming it has a wedge shape

Overlap.GetMeshFromCornerWedge(Part)
  Returns a new mesh object from a part assuming it has a corner wedge shape

Overlap.TestConvexMeshOverlap(meshA, meshB)
  Returns true if the two meshes overlap, I.e. they share some of the same volume.

# Usage Example:

local overlap = require(path-to-overlap-module-here)

local block = game.workspace.part  -- A part with a block formfactor
local wedge = game.workspace.wedge -- A wedge part

-- Get the parts mesh data to use for overlap:
local blockMeshRepresentation = Overlap.GetMeshFromBlock(block)
local wedgeMeshRepresentation = Overlap.GetMeshFromWedge(wedge)

if (Overlap.TestConvexMeshOverlap(meshA, meshB)) then
  print("Parts overlap)
else
  print("Parts do not overlap")
end
