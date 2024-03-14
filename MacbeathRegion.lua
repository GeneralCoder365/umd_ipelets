----------------------------------------------------------------------
-- Macbeath region auto-generation for arbitray polygon
----------------------------------------------------------------------
label = "MacbeathRegion"
revertOriginal = _G.revertOriginal
about = [[
Generate macbeth region for a polygon, best used with shortcuts.
This Lua ipelet script is written by Hongyang Du hongyangdu182@gmail.com.
]]
shortcuts.ipelet_macbeth_region = "Ctrl+M" -- Assigning a shortcut (Ctrl+M) for the ipelet_macbeth_region


--[=[
Given:
 - path obj
 - () -> Path
Return:
 - table of segments
 - () -> {Segment}
--]=]
function get_polygon_segments(obj, model)

	local shape = obj:shape()

	local segment_matrix = shape[1]

	local segments = {}
	for _, segment in ipairs(segment_matrix) do
		table.insert(segments, ipe.Segment(segment[1], segment[2]))
	end
	 
	table.insert(
		segments,
		ipe.Segment(segment_matrix[#segment_matrix][2], segment_matrix[1][1])
	)

	return segments
end

--[=[
Given:
 - path obj
 - () -> Path
Return:
 - table of vertices
 - table of segments
 - () -> {Vector}
 - () -> {Segment}
--]=]
function get_polygon_vertices_and_segments(obj, model)

	local shape = obj:shape()
	local polygon = obj:matrix()

	local vertices = {}
	local vertex = polygon * shape[1][1][1]
	table.insert(vertices, vertex)

	for i=1, #shape[1] do
		vertex = polygon * shape[1][i][2]
		table.insert(vertices, vertex)
	end

	local segment_matrix = shape[1]
	local segments = {}
	for i, segment in ipairs(segment_matrix) do 
		table.insert(segments, ipe.Segment(segment[1], segment[2]))
	end
	 
	table.insert(
		segments, 
		ipe.Segment(segment_matrix[#segment_matrix][2], segment_matrix[1][1])
	)

	return vertices, segments
end

function apply_transform(v, point)
	return 2*point-v
end

function macbeath_vertices(orig_vertices, point)
	new_vertices = {}
	for i=1, #orig_vertices do 
		table.insert(new_vertices, apply_transform(orig_vertices[i], point))
	end
	return new_vertices
end

--[=[
Given:
 - vertices, segments of polygon A: () -> {Vector}, () -> {Segment} 
 - vertices, segments of polygon B: () -> {Vector}, () -> {Segment} 
Return:
 - table of interection points: () -> {Vector}
--]=]
function get_intersection_points(s1,s2)
	local intersections = {}
	for i=1,#s2 do
		for j=1,#s1 do
			local intersection = s2[i]:intersects(s1[j])
			if intersection then
				table.insert(intersections, intersection)
			end
		end
	end

	return intersections
end

--[=[
Given:
 - point: () -> Vector
 - vertices of a polygon: () -> {Vector}
Return:
 - returns true if point is inside the polygon, false otherwise
 - if the point is on the edge of a polygon, then false is returned
 - () -> Bool
--]=]
function is_in_polygon(point, polygon)
    local x, y = point.x, point.y
    local j = #polygon
    local inside = false

    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y

        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

--[=[
Given:
 - vertices of polygon A: () -> {Vector}
 - vertices of polygon B: () -> {Vector}
 - points of A in B
Return:
 - table of overlapping points: () -> {Vector}
--]=]
function get_overlapping_points(v1, v2)
	local overlap = {}
	for i=1, #v1 do
		if is_in_polygon(v1[i], v2) then
			table.insert(overlap, v1[i])
		end
	end
	return overlap
end

function create_shape_from_vertices(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do 
		table.insert(shape, {type="segment", v[i], v[i+1]})
	end
  	table.insert(shape, {type="segment", v[#v], v[1]})
	return shape
end

function orient(p, q, r)
    val = p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y)
    return val
end

function sortByX(a,b) return a.x < b.x end

function convex_hull(points, model)
	table.sort(points, sortByX)
    
	local upper = {}
	table.insert(upper, points[1])
	table.insert(upper, points[2])
	for i=3, #points do
		while #upper >= 2 and orient(points[i], upper[#upper], upper[#upper-1]) <= 0 do
			table.remove(upper, #upper)
		end
		table.insert(upper, points[i])
	end

    local lower = {}
	table.insert(lower, points[#points])
	table.insert(lower, points[#points-1])
	for i = #points-2, 1, -1 do
		while #lower >= 2 and orient(points[i], lower[#lower], lower[#lower-1]) <= 0 do
			table.remove(lower, #lower)
		end
		table.insert(lower, points[i])
	end

	table.remove(upper, 1)
	table.remove(upper, #upper)
	
	local S = {}
	for i=1, #lower do table.insert(S, lower[i]) end
	for i=1, #upper do table.insert(S, upper[i]) end

	return create_shape_from_vertices(S)

end

function polygon_intersection(v1, s1, v2, s2, model)
	local intersections = get_intersection_points(s1, s2)
	local overlap1 = get_overlapping_points(v1, v2)
	local overlap2 = get_overlapping_points(v2, v1)

	local region = {}
	for i=1, #intersections do table.insert(region, intersections[i]) end
	for i=1, #overlap1 do table.insert(region, overlap1[i]) end
	for i=1, #overlap2 do table.insert(region, overlap2[i]) end

	local region_obj = ipe.Path(model.attributes, { convex_hull(region) })
	region_obj:set("pathmode", "strokedfilled")
	region_obj:set("fill", "red")
	return region_obj
end

function run(model,num)
	-- First, we select two objects from the canvas. 
	-- One is the polygon (Path object) and another one is a point (Reference boject).

	local p = model:page()
	if not p:hasSelection() then
	model.ui:explain("noselection") -- explain and quit if no selection
	return
	end

	-- Now check if a polygon and a point are selected

	local referenceObject
	local pathObject
	local count = 0

	for _, obj, sel, _ in p:objects() do
	if sel then
		count = count + 1
		if obj:type() == "path" then pathObject = obj end  -- assign pathObject
		if obj:type() == "reference" then referenceObject = obj end -- assign referenceObject
		end
	end

	if count ~= 2 then
		model.ui:explain("Please select 2 items") -- explain incorrect selection and quit
		return
	end

	local point = referenceObject:position()  -- retrieve the point position (Vector)
	local original_vertices, segments = get_polygon_vertices_and_segments(pathObject, model)
	
	local macbeath_vertices = macbeath_vertices(original_vertices, point)
	local macbeath_shape = create_shape_from_vertices(macbeath_vertices)
	local macbeath_obj = ipe.Path(model.attributes, { macbeath_shape })
	local macbeath_segments = get_polygon_segments(macbeath_obj)

	local macbeath_region_obj = polygon_intersection(original_vertices, segments, macbeath_vertices, macbeath_segments, model)
  	model:creation("Macbeath Region", ipe.Group({macbeath_obj,macbeath_region_obj}))

end
