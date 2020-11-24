local Overlap = {}

--[[
	GetEdges( { {Int, Int ...}, {Int, Int ...}, ... } Polygons ) : { {Int, Int}, {Int, Int}, ... }
		Gets the set of all unique edges
		for a given set of polygons.
--]]

function GetEdges(polygons)
	local edges = {}
	local hash = {}
	for polygonIndex, polygon in pairs(polygons) do
		for pointIndex, point in pairs(polygon) do
			local nextPoint = polygon[(pointIndex % #polygon) + 1]
			if (nextPoint < point) then nextPoint, point = point, nextPoint end
			local hashCode = tostring(point) .. "," .. tostring(nextPoint)
			if not hash[hashCode] then
				hash[hashCode] = true
				table.insert(edges, {point, nextPoint})
			end
		end
	end
	return edges
end

--[[
	IsClose(Float ValueA, Float ValueB, Flaot Epsilon) : Boolean
		returns true if valueA and valueB are equal
		to each other within error epsilon.
--]]

function IsClose(valueA, valueB, epsilon)
	local diffrence = valueA - valueB
	if diffrence > epsilon or diffrence < -epsilon then
		return false
	end
	return true
end

--[[
	IsCollinear(Vector3 VectorA, Vector3 VectorB) : Boolean
		Returns true if VectorA and VectorB are collinear.
--]]

function IsCollinear(vectorA, vectorB)
	local dot = math.abs(vectorA:Dot(vectorB))
	local magnatudes = vectorA.Magnitude * vectorB.Magnitude
	return IsClose(dot, magnatudes, 0.0001)
end

--[[
	SetContainsCollinear( { Vector3, Vector3, ... } Set, Vector3 Vector ) : Boolean
		Returns true the set contains a vector
		that is collieanr to the given vector.
--]]

function SetContainsCollinear(set, vector)
	for textVectorIndex, testVector in pairs(set) do
		if IsCollinear(vector, testVector) then
			return true
		end
	end
	return false
end

--[[
	GetEdgeAxes( {Vector3, Vector3, ...} Points, { {int, int}, {int, int}, ... } Edges) : {Vector3, Vector3, ...}
		Returns a list of common axes for all
		given edges
--]]

function GetEdgeAxes(points, edges)
	local axes = {}
	for edgeIndex, edge in pairs(edges) do
		local axis = points[edge[1]] - points[edge[2]]
		if not SetContainsCollinear(axes, axis) then
			table.insert(axes, axis.unit)
		end
	end
	return axes
end

--[[
	UnitRay.new(Vector3 Point, Vector3 Direction)
		Used to represent face positions and normals.
		The direction vector is automatically normalized.
--]]

UnitRay = {}
UnitRay.__index = UnitRay
function UnitRay.new(position, direction)
	direction = direction.Unit
	return setmetatable({
		Position  = position,
		Direction = direction
	}, UnitRay)
end

--[[
	UnitRay:GetProjection(Vector3 Point) : Float
		Returns the projected distance from the point
		on to the ray.
--]]

function UnitRay:GetProjection(point)
	return (point - self.Position):Dot(self.Direction)
end

--[[
	Mesh.new( { Vector3, Vector3, ... } Points, { {Int, Int ...}, {Int, Int ...}, ... } Polygons, [optional] { Vector3, Vector3, ... } Edge Axes)
		Represents a 3D object made out of poligonal faces.
		All polygons are assumed to be flat and have 3+ points.
		Note: Points are used for overlap detection so dangling
			  points could cause inaccurate overlaps
--]]

Mesh = {}
Mesh.__index = Mesh
function Mesh.new(points, polygons, edgeAxes)
	local edges = GetEdges(polygons)
	if edgeAxes == nil then edgeAxes = GetEdgeAxes(points, edges) end
	return setmetatable({
		Points   = points,
		Polygons = polygons,
		Edges    = edges,
		EdgeAxes = edgeAxes
	}, Mesh)
end

--[[
	Mesh:GetPoints() : {Vector3, Vector3, ...}
		Returns the meshe's points.
--]]

function Mesh:GetPoints()
	return self.Points
end

--[[
	Mesh:GetEdgeAxes() : {Vector3, Vector3, ...}
		Returns the meshe's common edge axes.
--]]

function Mesh:GetEdgeAxes()
	return self.EdgeAxes
end

--[[
	Mesh:GetRays() : {UnitRay, UnitRay, ...}
		Returns a unit ray for each face where the 
		position of the ray is the center of the face 
		and the direction is the faces normal.
--]]

function Mesh:GetRays()
	local rays = {}
	for polygonIndex, polygon in pairs(self.Polygons) do
		local center = Vector3.new(0,0,0)
		for pointIndex, point in pairs(polygon) do center = center + self.Points[point] end
		center = center / #polygon
		local sideA = self.Points[polygon[1]] - self.Points[polygon[2]]
		local sideB = self.Points[polygon[3]] - self.Points[polygon[2]]
		local normal = sideA:Cross(sideB)
		table.insert(rays, UnitRay.new(center, normal))
	end
	return rays
end

--[[
	TestConvexMeshOverlap(Mesh MeshA, Mesh MeshB) : Boolean
		Tests if two convex meshes are over lapping using
		the separating axis theorem. Returns true if they
		overlap.
--]]

function Overlap.TestConvexMeshOverlap(meshA, meshB)
	if TestMeshFaces(meshA, meshB) and
	   TestMeshFaces(meshB, meshA) and
	   TestMeshEdges(meshA, meshB) then
		return true
	end
	return false
end

--[[
	TestMeshFaces(Mesh MeshA, Mesh MeshB) : Boolean
		Returns true if it can't find
		a seperated axis
--]]

function TestMeshFaces(meshA, meshB)
	local points = meshA:GetPoints()
	local rays = meshB:GetRays()
	for rayIndex, ray in pairs(rays) do
		local clear = true
		for pointIndex, point in pairs(points) do
			local projection = ray:GetProjection(point)
			if projection < 0 then
				clear = false
				break
			end
		end
		if clear then return false end
	end
	return true
end


--[[
	TestMeshEdges(Mesh MeshA, Mesh MeshB) : Boolean
		Returns true if it can't find
		a seperated axis
--]]

function TestMeshEdges(meshA, meshB)
	local axesA = meshA:GetEdgeAxes()
	local pointsA = meshA:GetPoints()
	local axesB = meshB:GetEdgeAxes()
	local pointsB = meshB:GetPoints()
	for axisAIndex, axisA in pairs(axesA) do
		for axisBIndex, axisB in pairs(axesB) do
			if not IsCollinear(axisA, axisB) then
				local testAxis = axisA:Cross(axisB)
				local minA, maxA
				for pointIndex, point in pairs(pointsA) do
					local projection = testAxis:Dot(point)
					if minA == nil or projection < minA then minA = projection end
					if maxA == nil or projection > maxA then maxA = projection end
				end
				local minB, maxB
				for pointIndex, point in pairs(pointsB) do
					local projection = testAxis:Dot(point)
					if minB == nil or projection < minB then minB = projection end
					if maxB == nil or projection > maxB then maxB = projection end
				end
				if not (minA >= minB and minA <= maxB) and
				   not (maxA >= minB and maxA <= maxB) and
				   not (minB >= minA and minB <= maxA) and
				   not (maxB >= minA and maxB <= maxA) then
					return false
				end
			end
		end
	end
	return true
end

--[[
	GetMeshFromBlock() : Mesh
		Returns a mesh object the size and cframe
		of the part in the shape of a block.
--]]

function Overlap.GetMeshFromBlock(Part)
	local points, polygons, axes = {}, {}, {}
	local extents = Part.Size / 2
	local position = Part.CFrame.p
	local up = Part.CFrame.UpVector * extents.Y
	local right = Part.CFrame.RightVector * extents.X
	local look = Part.CFrame.LookVector * extents.Z
	
	points[1] = position + up + right + look -- Top right Front
	points[2] = position + up - right + look -- Top Left Front
	points[3] = position - up - right + look -- Bottom Left Front
	points[4] = position - up + right + look -- Bottom right Front
	points[5] = position + up + right - look -- Top right Back
	points[6] = position + up - right - look -- Top Left Back
	points[7] = position - up - right - look -- Bottom Left Back
	points[8] = position - up + right - look -- Bottom right Back
	
	polygons[1] = {1, 2, 3, 4} -- Front face
	polygons[2] = {5, 8, 7, 6} -- Back face
	polygons[3] = {1, 4, 8, 5} -- Right face
	polygons[4] = {2, 6, 7, 3} -- Left face
	polygons[5] = {1, 5, 6, 2} -- Top Face
	polygons[6] = {3, 7, 8, 4} -- Bottom Face
	
	axes[1] = Part.CFrame.UpVector
	axes[2] = Part.CFrame.RightVector
	axes[3] = Part.CFrame.LookVector
	
	return Mesh.new(points, polygons, axes)
end

--[[
	GetMeshFromBlock() : Mesh
		Returns a mesh object the size and cframe
		of the part in the shape of a wedge.
--]]
function Overlap.GetMeshFromWedge(Part)
	local points, polygons, axes = {}, {}, {}
	local extents = Part.Size / 2
	local position = Part.CFrame.p
	local up = Part.CFrame.UpVector * extents.Y
	local right = Part.CFrame.RightVector * extents.X
	local look = Part.CFrame.LookVector * extents.Z
	
	points[1] = position - up - right + look -- Bottom Left Front
	points[2] = position - up + right + look -- Bottom right Front
	points[3] = position + up + right - look -- Top right Back
	points[4] = position + up - right - look -- Top Left Back
	points[5] = position - up - right - look -- Bottom Left Back
	points[6] = position - up + right - look -- Bottom right Back
	
	polygons[1] = {1, 2, 3, 4} -- Slant face
	polygons[2] = {3, 6, 5, 4} -- Back face
	polygons[3] = {2, 6, 3}    -- Right face
	polygons[4] = {4, 5, 1}    -- Left face
	polygons[6] = {1, 5, 6, 2} -- Bottom Face
	
	axes[1] = Part.CFrame.UpVector
	axes[2] = Part.CFrame.RightVector
	axes[3] = Part.CFrame.LookVector
	axes[4] = (Part.CFrame.UpVector - Part.CFrame.LookVector).Unit
	
	return Mesh.new(points, polygons, axes)
end

--[[
	GetMeshFromBlock() : Mesh
		Returns a mesh object the size and cframe
		of the part in the shape of a corner wedge.
--]]
function Overlap.GetMeshFromCornerWedge(Part)
	local points, polygons, axes = {}, {}, {}
	local extents = Part.Size / 2
	local position = Part.CFrame.p
	local up = Part.CFrame.UpVector * extents.Y
	local right = Part.CFrame.RightVector * extents.X
	local look = Part.CFrame.LookVector * extents.Z
	
	points[1] = position + up + right + look -- Top right Front
	points[2] = position - up - right + look -- Bottom Left Front
	points[3] = position - up + right + look -- Bottom right Front
	points[4] = position - up - right - look -- Bottom Left Back
	points[5] = position - up + right - look -- Bottom right Back
	
	polygons[1] = {1, 2, 3} -- Front face
	polygons[2] = {5, 4, 1} -- Back face
	polygons[3] = {1, 3, 5} -- Right face
	polygons[4] = {1, 4, 2} -- Left face
	polygons[6] = {2, 4, 5, 3} -- Bottom Face
	
	axes[1] = Part.CFrame.UpVector
	axes[2] = Part.CFrame.RightVector
	axes[3] = Part.CFrame.LookVector
	axes[4] = (Part.CFrame.UpVector - Part.CFrame.LookVector - Part.CFrame.RightVector).Unit
	
	return Mesh.new(points, polygons, axes)
end

return Overlap
