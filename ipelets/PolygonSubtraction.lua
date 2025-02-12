-- Define the Ipelet
label = "Polygon Subtraction"
about = "Implement Polygon subtraction using two polygons"

function incorrect(model)
    model:warning("One or more selections are not polygons")
end

function get_selection_data(model)
    local page = model:page()
    local primary_obj, secondary_obj
    local j = 0

    for i = 1, #page do
        if primary_obj ~= nil and secondary_obj ~= nil then
            break
        end

        local obj = page[i]
        if page:select(i) then
            if obj:type() ~= "path" then
                incorrect(model)
                return
            end

            if page:primarySelection() == i then
                primary_obj = obj
            else
                secondary_obj = obj
            end
            j = j + 1
        end
    end

    if j ~= 2 then
        model:warning("Please select 2 polygons")
        return nil, nil 
    end

    return primary_obj, secondary_obj
end

--[=[
    Given:
        - {vertices}
        - Vertex
    Return:
        True if vertex doesnt exist in vertices
        False otherweise 
]=]
function not_in_table(vertices, vertex_comp)
    local flag = true
    for _, vertex in ipairs(vertices) do
        if vertex == vertex_comp then
            flag = false
        end
    end
    return flag
end
--[=[
    Given:
        - Ipelet Object
    Return:
        - List of vertices of Ipelet Object
]=]
function collect_vertices(obj)
    local vertices = {}

    local shape = obj:shape()
    local m = obj:matrix()

    for _, subpath in ipairs(shape) do
        for _, segment in ipairs(subpath) do
            if not_in_table(vertices, m*segment[1]) then
                table.insert(vertices, m*segment[1])
            end
            if not_in_table(vertices, m*segment[2]) then
                table.insert(vertices, m*segment[2])
            end
        end
    end

    return vertices
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

function create_segments_from_vertices(vertices)
	local segments = {}
	for i=1, #vertices-1 do
		table.insert( segments, ipe.Segment(vertices[i], vertices[i+1]) )
	end

	table.insert( segments, ipe.Segment(vertices[#vertices], vertices[1]) )
	return segments
end

function get_polygon_vertices_and_segments(obj, model)
	local vertices = collect_vertices(obj)
	vertices = unique_points(vertices)
	local segments = create_segments_from_vertices(vertices)
	return vertices, segments
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

-- Closed set calculator
-- Translated code to lua from https://www.geeksforgeeks.org/find-simple-closed-path-for-a-given-set-of-points/
function distance_squared(point_a, point_b)
    return (point_a.x - point_b.x) * (point_a.x - point_b.x) + (point_a.y - point_b.y) * (point_a.y - point_b.y)
end

--[=[
    Taken from https://stackoverflow.com/questions/328107/how-can-you-determine-a-point-is-between-two-other-points-on-a-line-segment
    Given:
        - Vertex a, b, c
    Return:
        - true if vertex c exists between the line created between vertex a and b
        - false otherwise
]=]

function is_between(a, b, c)
    
    local crossproduct = (c.y - a.y) * (b.x - a.x) - (c.x - a.x) * (b.y - a.y)
    local epsilon = 1e-10

    if math.abs(crossproduct) > epsilon then
        return false
    end

    local dotproduct = (c.x - a.x) * (b.x - a.x) + (c.y - a.y)*(b.y - a.y)
    if dotproduct < 0 then
        return false
    end

    local squaredlengthba = distance_squared(a,b)
    if dotproduct > squaredlengthba then
        return false
    end
    
    return true

end

--[=[
    Given:
        - Vertex c
    Return:
        - Comparator function comparing the distances of both vertices from c
]=]
function cmp_pt_by_dist(c)
    return function (a, b)
        return distance_squared(a,c) < distance_squared(b, c)
    end
end

function get_midpoint(a, b)
    local x0 = 0 
    local y0 = 0
    x0 = (a.x + b.x)/2
    y0 = (a.y + b.y)/2
    return ipe.Vector(x0, y0)
end

--[=[
    Given:
        - Intersection points between two vertices 
        - {vertices from single polygon}
        - isPrimary check if it is primary polygon in order to insert extra points
            between intsection points on the same side
        - other_poly - for adding extra points, only add extra points if outside of other poly
    Return:
        {vertices in eithr CW ordering with intersection points in correct ordering}

]=]
function insert_intersection(vertices, intersections, is_primary, other_poly)
    local new_v = {}
    for i=1, #vertices do
        local p_a = vertices[i]
        local p_b = vertices[(i % #vertices) + 1]
        table.insert(new_v, p_a)
        local seg_intersections = {}
        for _, i_point in ipairs(intersections) do 
            if is_between(p_a, p_b, i_point) then
                table.insert(seg_intersections, i_point)
            end
        end

        -- In case we get multiple intersections on a segment, we need to figure out the ordering of inserting intersections by distance
        if #seg_intersections ~= 0 then
            table.sort(seg_intersections, cmp_pt_by_dist(p_a))
        end

        for i = 1, #seg_intersections do 
            table.insert(new_v, seg_intersections[i])
            if is_primary then
                if i < #seg_intersections then
                    local new_pt = get_midpoint(seg_intersections[i], seg_intersections[i+1])
                    if not is_in_polygon(new_pt, other_poly) then
                        table.insert(new_v, new_pt)
                    end
                end
            end
        end
    end

    return new_v
end 

-- val > 0 => CCW
-- val < 0 => CW
-- val == 0 => collinear
function orient(p, q, r)
    local val = p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y)
    return val
end

function reverse_list(lst)
    local i = 1
    local j = #lst
    while i < j do
        local temp = lst[i]
        lst[i] = lst[j]
        lst[j] = temp
        i = i + 1
        j = j -1
    end

    return lst
end

--[=[
    Given: 
        - {vertices}
    Return:
        - {vertices ordered in clockwise fashion}
]=]
function reorient_cw(vertices)
    if orient(vertices[1], vertices[2], vertices[3]) > 0 then
        return reverse_list(vertices)
    else
        return vertices
    end


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
        - Point p
        - List of vetices of given polygon 
    Return:
        - Index of vertex in polygon_v matching point p 
        - Otherwise -1 
--]=]
function find_cross_index(p, polygon_v)
    for i, v in ipairs(polygon_v) do 
        if v.x == p.x and v.y == p.y then 
            return i
        end
    end

    return -1
end

--[=[
    Reprocess the list of vertices with the following flags for each vertex:
    If the vertex has been processed
    The vertex reference
    If the vertex is outside of the alternate polygon
    The location of the point index in the other polygon, -1 otherwise
    Given:
        - {vertices to processed}
        - {vertices of alternate polygon}
    Return:
        - table{table{["vertex"], ["processed"], ["outside"], ["cross"]}}
]=]
function add_flags(vertices, other_vertices)
    new_v = {}
    for _, v in ipairs(vertices) do
        table.insert(new_v, {["processed"] = false, ["vertex"] = v,
         ["outside"] = not is_in_polygon(v, other_vertices), ["cross"] = find_cross_index(v, other_vertices)})
    end

    return new_v
end

--[=[
    Processes the vertices by reorienting the vertices in counter clockwise, and adding in the intersection points
    Adds in the following flags to the vertices:
        - If it has been processed,
        - The index of the intersection point, in the other polygon vertex list 
        - If point is outside of the other polygon
        - 
    Return:
        - table{table{["vertex"], ["processed"], ["outside"], ["cross"]}}
--]=]
function process_vertices(primary_v, secondary_v, intersection)
    -- Reorient vertices to clockwise directions, then insert intersections in order 
    local primary_v = reorient_cw(primary_v)
    local secondary_v = reorient_cw(secondary_v)
    primary_v = insert_intersection(primary_v, intersection, true, secondary_v)
    secondary_v = insert_intersection(secondary_v, intersection, false, primary_v)
    -- Add flags have to be done after both vertices are processed with intersections
    local temp = add_flags(primary_v, secondary_v)
    secondary_v = add_flags(secondary_v, primary_v)
    primary_v = temp

    -- print_processed(primary_v)
    -- print("--------------------------")
    -- print("secondary")
    -- print_processed(secondary_v)

    return primary_v, secondary_v
end

function  get_outside_unused_point(vertices) 
    for i, v in ipairs(vertices) do 
        if v["outside"] and not v["processed"] and v["cross"] == -1 then
            return i 
        end
    end

    return -1
end

--[=[ 
    Perform polygon subtraction
    Algorithm pulled from: https://www.pnnl.gov/main/publications/external/technical_reports/PNNL-SA-97135.pdf
    Given: 
        - Primary - primary vertices fully processed with following flags: vertex, processed, outside, crossed
        - Secondary - secondary vertices fully processed with following flags: vertex, processed, outside, crossed
        - table{table{["vertex"], ["processed"], ["outside"], ["cross"]}}
    Return:
        - list of resulting shape vertices from subtraction
        - table{list of table {list of vertices}}
--]=] 
function perform_subtraction(primary, secondary, model)
    local offset = 1
    local index = get_outside_unused_point(primary)
    local poly_operands = {[1] = primary, [2] = secondary}
    local curr_poly = 0
    local res_polys = {}
    local poly = {}

    while index ~= -1 do
        local v = poly_operands[(curr_poly % #poly_operands) + 1][index]
        if not v["processed"] then
            table.insert(poly, v["vertex"])
            v["processed"] = true
        
            if v["cross"] ~= -1 then
                index = v["cross"]
                offset = offset * -1
                curr_poly = curr_poly + 1
                poly_operands[(curr_poly % #poly_operands) + 1][index]["processed"] = true
            end
            index = index + offset
            if index == 0 then
                index = #poly_operands[(curr_poly % #poly_operands) + 1]
            elseif index == (#poly_operands[(curr_poly % #poly_operands) + 1] + 1) then
                index = 1
            end

        else
            table.insert(res_polys, poly)
            index = get_outside_unused_point(primary)
            poly = {}
            curr_poly = 0
            offset = 1
        end
    end 

    return res_polys

end

function incorrect_with_title(title, model) model:warning(title) end

function convex_hull(points)

	function sortByX(a,b) return a.x < b.x end
    function orient_ch(p, q, r) return p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y) end
	
    local pts = {}
    for i=1, #points do pts[i] = points[i] end
    table.sort(pts, sortByX)
    
	local upper = {}
	table.insert(upper, pts[1])
	table.insert(upper, pts[2])
	for i=3, #pts do
		while #upper >= 2 and orient_ch(pts[i], upper[#upper], upper[#upper-1]) <= 0 do
			table.remove(upper, #upper)
		end
		table.insert(upper, pts[i])
	end

  local lower = {}
	table.insert(lower, pts[#pts])
	table.insert(lower, pts[#pts-1])
	for i = #pts-2, 1, -1 do
		while #lower >= 2 and orient_ch(pts[i], lower[#lower], lower[#lower-1]) <= 0 do
			table.remove(lower, #lower)
		end
		table.insert(lower, pts[i])
	end

	table.remove(upper, 1)
	table.remove(upper, #upper)
	
	local S = {}
	for i=1, #lower do table.insert(S, lower[i]) end
	for i=1, #upper do table.insert(S, upper[i]) end

	return S

end

--[=[
    Function for drawing a new instance of the same shape wihtout overriding 
    orignal shape's properties
    Given: table{vertices}
    Return: Shape object using given vertices
--]=]
function draw_shape(vertices, model) 
    local result_shape = { type = "curve", closed = true, }
    
    for i = 1, #vertices - 1 do
        table.insert(result_shape, { type = "segment", vertices[i], vertices[i + 1]})
    end

    local result_obj = ipe.Path(model.attributes, { result_shape })
    result_obj:set("pathmode", "stroked")
    result_obj:set("stroke", "red")
    return result_obj
end

function is_convex(v)
	local convex_hull_vectors = convex_hull(v)
	return #convex_hull_vectors == #v
end

function run(model)
    local page = model:page()
    local primary_obj, secondary_obj = get_selection_data(model)
    if primary_obj == nil or secondary_obj == nil then
        return
    end
    
    local p_v, p_s = get_polygon_vertices_and_segments(primary_obj, model)
    local s_v, s_s = get_polygon_vertices_and_segments(secondary_obj, model)

    if not is_convex(p_v) or not is_convex(s_v) then
        incorrect_with_title("Polygons are not convex. Polygon subtraction might not work as expected.", model)
    end

    local intersections = get_intersection_points(p_s, s_s)

    if #intersections == 0 then
        -- If completely enclosed, draw shape with hole
        if is_in_polygon(s_v[1], p_v ) then
            res_obj_lst = {draw_shape(p_v, model),draw_shape(s_v, model)}
            model:creation("Create polygon subtraction", ipe.Group(res_obj_lst))
        end

        return 
    end

    p_v, s_v = process_vertices(p_v, s_v, intersections)
    local res_polys = perform_subtraction(p_v, s_v, model)
    local objs = {}
    for _, s in ipairs(res_polys) do 
        local result_shape = { type = "curve", closed = true, }
        if #s >= 3 then 
            for i = 1, #s - 1 do
                table.insert(result_shape, { type = "segment", s[i], s[i + 1]})
            end

            local result_obj = ipe.Path(model.attributes, { result_shape })
            table.insert(objs, result_obj)
        end
    end

    model:creation("Create polygon subtraction", ipe.Group(objs))

end
