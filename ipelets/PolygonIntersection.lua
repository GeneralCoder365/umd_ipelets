
-- Define the Ipelet
label = "2 Convex Polygon Intersection"
about = "Given two convex polygons, a filled intersection is returned"

function incorrect(title, model) model:warning(title) end

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
	for i=1, #vertices-1 do
		table.insert( segments, ipe.Segment(vertices[i], vertices[i+1]) )
	end

	table.insert( segments, ipe.Segment(vertices[#vertices], vertices[1]) )
	return segments
end

function not_in_table(vectors, vector_comp)
    local flag = true
    for _, vertex in ipairs(vectors) do
        if vertex == vector_comp then
            flag = false
        end
    end
    return flag
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
	local segments = create_segments_from_vertices(vertices)
	return vertices, segments
end

function is_convex(vertices)
	local _, convex_hull_vectors = convex_hull(vertices)
	return #convex_hull_vectors == #vertices
end

function copy_table(orig_table)
	local new_table = {}
	for i=1, #orig_table do new_table[i] = orig_table[i] end
	return new_table
end

function get_two_polygons_selection(model)

	local p = model:page()

	if not p:hasSelection() then incorrect("Please select 2 convex polygons", model) return end

	local pathObject1
 	local pathObject2
	local count = 0
	local flag = true

	for _, obj, sel, _ in p:objects() do
        if sel then
            count = count + 1
            if obj:type() == "path" and flag then
                pathObject1 = obj
                flag = not flag
            else
                if obj:type() == "path" then pathObject2 = obj end
            end
        end
    end

	if not pathObject1 or not pathObject2 then incorrect("Please select 2 convex polygons", model) return end

	local vertices1, segments1 = get_polygon_vertices_and_segments(pathObject1, model)
	local vertices2, segments2 = get_polygon_vertices_and_segments(pathObject2, model)
	
	local poly1_convex = is_convex(copy_table(vertices1))
	local poly2_convex = is_convex(copy_table(vertices2))
	if poly1_convex == false or poly2_convex == false then incorrect("Polygons must be convex", model) return end

	return vertices1, segments1, vertices2, segments2
end

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

function get_overlapping_points(v1, v2, model)
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

function polygon_intersection(v1, s1, v2, s2, model)
	local intersections = get_intersection_points(s1, s2)
	if #intersections == 0 then
		return nil
	end
	local overlap1 = get_overlapping_points(v1, v2, model)
	local overlap2 = get_overlapping_points(v2, v1, model)

	local region = {}
	for i=1, #intersections do table.insert(region, intersections[i]) end
	for i=1, #overlap1 do table.insert(region, overlap1[i]) end
	for i=1, #overlap2 do table.insert(region, overlap2[i]) end

	local shape, _ = convex_hull(region)
	local region_obj = ipe.Path(model.attributes, { shape })
	return region_obj
end

--! Run the Ipelet
function run(model)
	if not get_two_polygons_selection(model) then return end
	local v1,s1,v2,s2 = get_two_polygons_selection(model)
	local obj =	polygon_intersection(v1,s1,v2,s2, model)
	if obj == nil then
		return
	end
	model:creation("polygon intersection", obj)
end
