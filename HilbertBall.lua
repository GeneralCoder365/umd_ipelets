-- Define the Ipelet
label = "Hilbert Ball (EXPERIMENTAL) (MANGO)"
revertOriginal = _G.revertOriginal
about = "Given a polygon, and its center point, returns the Hilbert ball of the polygon"

function incorrect(title, model) model:warning(title) end

function is_convex(vertices)
	local _, convex_hull_vectors = convex_hull(vertices)
	return #convex_hull_vectors == #vertices
end

function not_in_table(vectors, vector_comp)
    local flag = true
    for _, vertex in ipairs(vectors) do if vertex == vector_comp then flag = false end end
    return flag
end

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

function get_polygon_vertices(obj, model)

	local shape = obj:shape()
	local polygon = obj:matrix()

	vertices = {}

	vertex = polygon * shape[1][1][1]
	table.insert(vertices, vertex)

	for i=1, #shape[1] do
		vertex = polygon * shape[1][i][2]
		table.insert(vertices, vertex)
	end

	return vertices
end

function create_segments_from_vertices(vertices)
	local segments = {}
	local segments_start_finish = {}
	for i=1, #vertices-1 do
		table.insert( segments, ipe.Segment(vertices[i], vertices[i+1]) )
		table.insert( segments_start_finish, {vertices[i],vertices[i+1]} )
	end

	table.insert( segments, ipe.Segment(vertices[#vertices], vertices[1]) )
	table.insert( segments_start_finish, {vertices[#vertices], vertices[1]} )
	return segments, segments_start_finish
end

function unique_points(points, model)
	-- Check for duplicate points and remove them
    local uniquePoints = {}
    for i = 1, #points do
        if (not_in_table(uniquePoints, points[i])) then
			table.insert(uniquePoints, points[i])
		end
    end
    return uniquePoints
end

function get_polygon_vertices_and_segments(obj, model)
	local vertices = get_polygon_vertices(obj)
	vertices = unique_points(vertices)
	local segments, segments_start_finish = create_segments_from_vertices(vertices)
	return vertices, segments, segments_start_finish
end

function copy_table(orig_table)
	local new_table = {}
	for i=1, #orig_table do new_table[i] = orig_table[i] end
	return new_table
end

function get_pt_and_polygon_selection(model)

	local p = model:page()

	if not p:hasSelection() then incorrect("Please select a convex polygon and a point", model) return end

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

	if not referenceObject or not pathObject then incorrect("Please select a convex polygon and a point", model) return end

	local point = referenceObject:matrix() * referenceObject:position()
	local vertices, segments, segments_start_finish = get_polygon_vertices_and_segments(pathObject, model)

	local poly1_convex = is_convex(copy_table(vertices))
	if poly1_convex == false then incorrect("Polygon must be convex", model) return end
	if not is_in_polygon(point, copy_table(vertices)) then incorrect("Point must be inside the polygon", model) return end

	return point, vertices, segments, segments_start_finish
end

function create_ray(v,c, model)
	return ipe.LineThrough(v, c)
end

function create_rays(v, c, model)
	local rays = {}
	for i=1, #v do table.insert( rays, { v[i],  create_ray(v[i], c, model) } ) end
	return rays
end

function intersect(s,r)
	return r:intersects(s)
end

function equal(v1,v2)
	if v1.x == v2.x and v1.y == v2.y then
		return true
	else
		return false
	end
end

function get_spokes(rays, segments, model)

  local spokes = {}
  local vertex_intersect = {}
  for j=1, #segments do
  	for i=1, #rays do
		if not equal(segments[j][1], rays[i][1]) and not equal(segments[j][2], rays[i][1]) then
			local intersection = ipe.Segment(segments[j][1],segments[j][2]):intersects(rays[i][2])
			if intersection ~= nil then
				table.insert( vertex_intersect, {rays[i][1].x, rays[i][1].y, intersection.x, intersection.y} )
				table.insert( spokes, {type="segment", rays[i][1], intersection} )
			end
		end
    end
  end
  return spokes, vertex_intersect
end

function get_spokes_path_objs(spokes, model)
    local spoke_obj_list = {}
    for _, spoke in ipairs(spokes) do
        local shape = {type="curve", closed=true; spoke}
        local obj = ipe.Path(model.attributes, { shape })
        table.insert(spoke_obj_list, obj)
    end
    return spoke_obj_list
end

function norm(p1, p2) return math.sqrt( (p1.x-p2.x)^2 + (p1.y-p2.y)^2 ) end
function get_point(A, C, D, r, model) return (1 / (1 + ( norm(C,D) / norm(A,C) ) * math.exp(2*r))) * (D-A) + A end

function get_points_on_spokes(vertex_intersect, center, radius, model)
    local points_on_spokes = {}
    for i=1, #vertex_intersect do
		local vertex = ipe.Vector(vertex_intersect[i][1], vertex_intersect[i][2])
		local intersect = ipe.Vector(vertex_intersect[i][3], vertex_intersect[i][4])
        table.insert(points_on_spokes, get_point(vertex, center, intersect, radius, model))
        table.insert(points_on_spokes, get_point(intersect, center, vertex, radius, model))
    end
    return points_on_spokes
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

function convex_hull(points, model)

	function sortByX(a,b) return a.x < b.x end
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

	return create_shape_from_vertices(S), S

end

function run_spokes(model)
	if not get_pt_and_polygon_selection(model) then return end
    local center, vertices, _, segments_start_finish = get_pt_and_polygon_selection(model)
    local v_rays = create_rays(vertices, center, model)
    local spokes, vertex_intersect = get_spokes(v_rays, segments_start_finish, model)
	
    local spoke_obj_list = get_spokes_path_objs(spokes, model)
    local points_on_spokes = get_points_on_spokes(vertex_intersect, center, 1, vertices, model)
	local shape, _ = convex_hull(points_on_spokes)
    table.insert(spoke_obj_list, ipe.Path(model.attributes, { shape }))

    model:creation("points on spokes", ipe.Group(spoke_obj_list) )
end

function run_without_spokes(model)
	if not get_pt_and_polygon_selection(model) then return end
    local center, vertices, _, segments_start_finish = get_pt_and_polygon_selection(model)
    local v_rays = create_rays(vertices, center, model)
    local _, vertex_intersect = get_spokes(v_rays, segments_start_finish, model)
	
    local points_on_spokes = get_points_on_spokes(vertex_intersect, center, 1, vertices, model)
	local shape, _ = convex_hull(points_on_spokes)

    model:creation("points on spokes", ipe.Path(model.attributes, { shape }) )
end

methods = {
	{ label="With Spokes", run = run_spokes },
	{ label="Without Spokes", run = run_without_spokes },
  }
