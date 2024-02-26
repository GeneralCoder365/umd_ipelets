-- Define the Ipelet
label = "Polar Body"
about = "Computes the Minkowski Sum of two convex polygons in R^2"

function incorrect(model)
    model:warning("Selection is not a polygon")
end

function get_original_vertices(model)
	local p = model:page()
	local prim = p:primarySelection()
	local obj = p[prim]

	if obj:type() ~= "path" then incorrect(model) return end

	local shape = obj:shape()
	local polygon = obj:matrix()

	orig_vertices = {}

	vertex = polygon * shape[1][1][1]
	table.insert(orig_vertices, vertex)

	for i=1, #shape[1] do
		vertex = polygon * shape[1][i][2]
		table.insert(orig_vertices, vertex)
	end

	return orig_vertices
end
--[=[
Given:
 - a vertex v = Vector(a,b)
Return:
 - a line with equation ax + by = 1
 - () -> Line
--]=]
function vertex_dual(v)
	local a = v.x
	local b = v.y
    local p1
    local p2
    if a == 0 then
        p1 = ipe.Vector(0, 1/b)
        p2 = ipe.Vector(1, 1/b)
    elseif b == 0 then
        p1 = ipe.Vector(0, 1/a)
        p2 = ipe.Vector(1, 1/a)
    else
        p1 = ipe.Vector(1/a, 0)
	    p2 = ipe.Vector(0, 1/b)
    end

	return ipe.LineThrough(p1, p2)
end
--[=[
Given:
 - a vertices of original polygon v
Return:
 - table of lines with equation ax + by = 1
 - () -> table -> () -> Line
--]=]
function dual_transform(v,model)
	lines = {}
	for i=1, #v do table.insert(lines, vertex_dual(v[i])) end
	return lines
end
--[=[
Given:
 - line l1
 - line l2
Return:
 - l1:intersects(l2) 
 - type() -> Vector
--]=]
function intersect(l1,l2, model)
	return l1:intersects(l2)
end

--[=[
Given:
 - ordered table of lines {l1, l2, ... ln}
Return:
 - table of polar vertices
 - () -> table -> () -> Vector 
--]=]
function get_intersection_points(l,model)
	polar_vertices = {}
	for i=1, #l-1 do table.insert(polar_vertices, intersect(l[i], l[i+1])) end
	table.insert(polar_vertices, intersect(l[#l], l[1], model))
	return polar_vertices
end

--[=[
Given:
 - ordered table of polar vertices v
Return:
 - model:creation("Polar Dual", obj)
--]=]
function create_polar_body(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do table.insert(shape, {type="segment", v[i], v[i+1]}) end
    table.insert(shape, {type="segment", v[#v], v[1]})
	local obj = ipe.Path(model.attributes, { shape })
    obj:set("pen", 0.1)
    model:creation("Polar Dual", obj)
end

--[=[
Given:
 - table of vertices v
Return:
 - table of shifted vertices
--]=]
function shift_to_origin(v)

    -- centroid calculation
    local x = 0
    local y = 0
    for _, vertex in ipairs(v) do
        x = x + vertex.x
        y = y + vertex.y
    end

    x = x / #v
    y = y / #v
    
    local shifted_vertices = {}
    for _, vertex in ipairs(v) do
        table.insert(shifted_vertices, ipe.Vector(vertex.x-x, vertex.y-y))
    end
    
    return shifted_vertices, x, y
end

-- Centers the polar body within the original polygon
-- also applies a scaling factor to make the body more visible
function shift_back(v, x, y)
    
    local shifted_vertices = {}
    for _, vertex in ipairs(v) do
        table.insert(shifted_vertices, ipe.Vector((32*vertex.x)+x, (32*vertex.y)+y))
    end
    
    return shifted_vertices
end

--! Run the Ipelet
function run(model)
    orig_vertices = get_original_vertices(model)
    orig_vertices, offset_x, offset_y = shift_to_origin(orig_vertices)
    lines = dual_transform(orig_vertices, model)
    polar_vertices = get_intersection_points(lines,model)
    polar_vertices = shift_back(polar_vertices, offset_x, offset_y)
    create_polar_body(polar_vertices, model)
end
