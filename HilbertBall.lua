-- Define the Ipelet
label = "Hilbert Ball"
about = "Given a polygon, and its center point, returns the Hilbert ball of the polygon"

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
	local segments_start_finish = {}
	for _, segment in ipairs(segment_matrix) do
		table.insert(segments, ipe.Segment(segment[1], segment[2]))
		table.insert( segments_start_finish, {segment[1], segment[2]} )
	end
	 
	table.insert(
		segments,
		ipe.Segment(segment_matrix[#segment_matrix][2], segment_matrix[1][1])
	)
	table.insert( segments_start_finish, {segment_matrix[#segment_matrix][2], segment_matrix[1][1]} )

	return segments, segments_start_finish
end
--[=[
Given:
 - path obj: () -> Path
Return:
 - table of vertices: () -> {Vector}
--]=]
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
	local segments, segments_start_finish = get_polygon_segments(obj)
	return get_polygon_vertices(obj), segments, segments_start_finish
end
--[=[
Given:
 - model
Return:
 - point: () -> Vector
 - vertices: () -> {Vector}
 - segments: () -> {Segment}
--]=]
function get_pt_and_polygon_selection(model)

	local p = model:page()
	if not p:hasSelection() then
	model.ui:explain("noselection") -- explain and quit if no selection
	return
	end

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
		model.ui:explain("Please select a point and polygon")
		return
	end

	local point = referenceObject:position()  -- retrieve the point position (Vector)
	local vertices, segments, segments_start_finish = get_polygon_vertices_and_segments(pathObject, model)

	return point, vertices, segments, segments_start_finish
end


--[=[
Given:
 - a vertex v = Vector(a,b)
 - a center point c = Vector(c,d)
Return:
 - a line going through c and v
 - () -> Line
--]=]
function create_ray(v,c, model)
	return ipe.LineThrough(v, c)
end

--[=[
Given:
 - ordered table of vertices {v1, v2, ... vn}: () -> {Vector}
 - center c: () -> Vector
Return:
 - table of tables of (vertex, ray): () -> {{Vector, Line}}
--]=]
function create_rays(v, c, model)
	local rays = {}
	for i=1, #v do table.insert( rays, { v[i],  create_ray(v[i], c, model) } ) end
	return rays
end

--[=[
Given:
 - ray r
 - segment s
Return:
 - r:intersects(s)
 - type() -> Vector
--]=]
function intersect(s,r)
	return r:intersects(s)
end
--[=[
Given:
 - table of rays with associated vertex: () -> {{Vector, Line}}
 - segments of polygon: () -> {Segment}
Return:
 - table of segments: () -> {Segment}
 - Segment: (start: vertex, finish: intersection point on edge) 
--]=]
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
		-- local line = ipe.LineThrough(segments[j][1],segments[j][2])
		if not equal(segments[j][1], rays[i][1]) and not equal(segments[j][2], rays[i][1]) then
			local intersection = ipe.Segment(segments[j][1],segments[j][2]):intersects(rays[i][2])
			if intersection ~= nil then
				table.insert( vertex_intersect, {rays[i][1].x, rays[i][1].y, intersection.x, intersection.y} )
				table.insert( spokes, {type="segment", rays[i][1], intersection} )
			end
		end
    end
  end
  model:warning(#vertex_intersect)
  return spokes, vertex_intersect
end

--[=[
spokes: () -> {Segment for shape}
--]=]
function get_spokes_path_objs(spokes, model)
    local spoke_obj_list = {}
    for _, spoke in ipairs(spokes) do
        local shape = {type="curve", closed=true; spoke}
        local obj = ipe.Path(model.attributes, { shape })
        table.insert(spoke_obj_list, obj)
    end
    return spoke_obj_list
end

-- point between the center and intersection point

function compute_K_constants(a,b,d,R, model)
    local top_fraction = (b.x-d.x)*(b.x-d.x) + (b.y-d.y)*(b.y-d.y)
    local bottom_fraction = (b.x-a.x)*(b.x-a.x) + (b.y-a.y)*(b.y-a.y)
    local square_root_part = math.sqrt(top_fraction/bottom_fraction)
    local exponent_part = 2*(2*R - math.log(square_root_part))
    local K1 = math.exp(exponent_part)
    local K2 = (a.y-d.y) / (a.x-d.x)
    return K1, K2
end

function get_point_vertical(a,b,d,R, model) 
	local K1,_ = compute_K_constants(a,b,d,R, model)
	local A = 1-K1
	local B = -2*a.y+2*d.y*K1
	local C_1 = (a.x*a.x) - 2*(a.x*a.x) - K1*(a.x*a.x) + 2*K1*d.x*a.x
	local C_2 = K1*((d.x*d.x)+(d.y*d.y))-(a.x*a.x)-(a.y*a.y)
	local C = C_1 - C_2
	local x
	local y
	local discriminant = (B*B)-4*A*C
	
	if d.y > a.y then
		x = a.x
		y = (-B + math.sqrt(discriminant)) / (2*A)
	else
		x = a.x
		y = (-B - math.sqrt(discriminant)) / (2*A)
	end
	
	return ipe.Vector(x,y)
end

function get_point(a,b,d,R, model)
	local K1,K2 = compute_K_constants(a,b,d,R, model)
	local A = 1 + (K2*K2) - K1 - K1*(K2*K2)
	local B = -2*a.x-2*a.x*(K2*K2)+2*a.y*K2-2*a.y*K2+2*K1*d.x+2*K1*a.x*(K2*K2)-2*K1*a.y*K2+2*d.y*K1*K2
	local C_1 = (a.x*a.x)*(K2*K2)-2*a.x*a.y*K2+(a.y*a.y)-2*a.y*(-K2*a.x+a.y)-K1*((a.x*a.x)*(K2*K2)-2*a.x*a.y*K2+(a.y*a.y))+2*d.y*K1*(-K2*a.x+a.y)
	local C_2 = K1*((d.x*d.x)+(d.y*d.y))-(a.x*a.x)-(a.y*a.y)
	local C = C_1 - C_2

	local discriminant = (B*B)-4*A*C
	local x_1 = (-B + math.sqrt(discriminant)) / (2*A)
	local y_1 = K2*(x_1-a.x)+a.y

	local x_2 = (-B - math.sqrt(discriminant)) / (2*A)
	local y_2 = K2*(x_2-a.x)+a.y

	return ipe.Vector(x_1,y_1), ipe.Vector(x_2, y_2)
end

 -- If D is further to the right, we want to use -B +, -B- 
function get_points_on_spokes(vertex_intersect, center, radius, polygon, model)
	
    local points_on_spokes = {}

    for i=1, #vertex_intersect do

		local vertex = ipe.Vector(vertex_intersect[i][1], vertex_intersect[i][2])
		local intersect = ipe.Vector(vertex_intersect[i][3], vertex_intersect[i][4])

		if intersect.x == vertex.x then
			local point1 = get_point_vertical(vertex, center, intersect, radius, model)
			local point2 = get_point_vertical(intersect, center, vertex, radius, model)
			table.insert(points_on_spokes, point1)
			table.insert(points_on_spokes, point2)
		else
			local point1, point2 = get_point(vertex, center, intersect, radius, model)
			local point3, point4 = get_point(intersect, center, vertex, radius, model)
			
			if vertex.x < intersect.x  then
				table.insert(points_on_spokes, point1)
			else
				table.insert(points_on_spokes, point2)
			end
			if intersect.x < vertex.x then
				table.insert(points_on_spokes, point3)
			else
				table.insert(points_on_spokes, point4)
			end
		end
		

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
-- val > 0 => CCW
-- val < 0 => CW
-- val == 0 => collinear
function orient(p, q, r)
    val = p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y)
    return val
end
--[=[
Given:
 - vertices: () -> {Vector}
Return:
 - shape of the convex hull of points: () -> Shape
--]=]
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

	return create_shape_from_vertices(S)

end
--! Run the Ipelet
function run(model)
    local center, vertices, _, segments_start_finish = get_pt_and_polygon_selection(model)
    local v_rays = create_rays(vertices, center, model)
    local spokes, vertex_intersect = get_spokes(v_rays, segments_start_finish, model)
	
    local spoke_obj_list = get_spokes_path_objs(spokes, model)
    local points_on_spokes = get_points_on_spokes(vertex_intersect, center, 1, vertices, model)
    table.insert(spoke_obj_list, ipe.Path(model.attributes, { convex_hull(points_on_spokes) }))


    model:creation("points on spokes", ipe.Group(spoke_obj_list) )
end