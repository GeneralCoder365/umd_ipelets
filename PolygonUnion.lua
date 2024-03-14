label = "Polygon Union"
about = "Computes the union of two convex polygons"

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
              table.insert(intersections, {intersection, s1[j], s2[i]})
          end
      end
	end

	return intersections
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

function get_polygon_vertices_and_segments(obj, model)
	local vertices = get_polygon_vertices(obj)
	local segments, segments_start_finish = create_segments_from_vertices(vertices)
	return vertices, segments, segments_start_finish
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
--[=[
Given:
 - model
Return:
 - vertices1: () -> {Vector}
 - segments1: () -> {Segment}
 - vertices2: () -> {Vector}
 - segments2: () -> {Segment}
--]=]
function get_two_polygons_selection(model)

	local p = model:page()
	if not p:hasSelection() then
		model.ui:explain("noselection") -- explain and quit if no selection
		return
	end

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
			end
			if obj:type() == "path" then pathObject2 = obj end -- assign pathObject2
		end
	end

	if count ~= 2 then
		model.ui:explain("Please select 2 items")
		return
	end

	local vertices1, segments1 = get_polygon_vertices_and_segments(pathObject1, model)
	local vertices2, segments2 = get_polygon_vertices_and_segments(pathObject2, model)

	return unique_points(vertices1), segments1, unique_points(vertices2), segments2
end

function create_shape_from_vertices(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do 
		table.insert(shape, {type="segment", v[i], v[i+1]})
	end
  	table.insert(shape, {type="segment", v[#v], v[1]})
	return shape
end

--Gets the bottom left point from two sets of vertices v1 and v2
function getBottomLeft(v1,v2)
	local v3 = {}
	for i=1, #v1 do 
		v3[i]= v1[i]
	end
	for j=1, #v2 do 
		v3[#v1+j]= v2[j]
	end
	local minimum=1
	for k=1, #v3 do
		local current = v3[k]
		local mini = v3[minimum]
		if current.y < mini.y then
			minimum=k
		elseif current.y == mini.y then
			if current.x < mini.x then
				minimum=k
			end
		end
	end
	return v3[minimum]
end

--Is P on the segment between A and B
function pointOnSeg(A,B,P)
	local bool = false
	local AB = math.sqrt((A.x-B.x)^2+(A.y-B.y)^2)
	local AP = math.sqrt((A.x-P.x)^2+(A.y-P.y)^2)
	local PB = math.sqrt((P.x-B.x)^2+(P.y-B.y)^2)
	if (AP+PB<=AB+.0001) and (AP+PB>=AB-.0001) then
		bool = true
	end
	return bool
	
end

-- shifts the polygon by the given offset
-- returns shifted vertices
function shift_polygon(v, offset_x, offset_y)
    
    local shifted_vertices = {}
    for _, vertex in ipairs(v) do
        table.insert(shifted_vertices, ipe.Vector((vertex.x)-offset_x, (vertex.y)-offset_y))
    end
    
    return shifted_vertices
end

--is B closer to A than C?
function closer(A,B,C)
	local AB = math.sqrt((A.x-B.x)^2+(A.y-B.y)^2)
	local AC = math.sqrt((A.x-C.x)^2+(A.y-C.y)^2)
	if AB<AC then
		return true
	end
	return false
end

function create_shape_from_vertices(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do 
		table.insert(shape, {type="segment", v[i], v[i+1]})
	end
  	table.insert(shape, {type="segment", v[#v], v[1]})
	return shape
end

--Get the next intersection point on an array of intersections on v on the segment starting from nextval to nextnextval 
function getNextIntersection(intersects,v,nextnextval,nextval,model)
	local candidateIndex=-1
	for h=1, #intersects do
		if pointOnSeg(v[nextval],v[nextnextval],intersects[h]) then
			if candidateIndex~=-1 then
				if closer(v[nextval],intersects[h],intersects[candidateIndex]) then
					candidateIndex=h
				end
			else 
				candidateIndex=h
			end
		end
	end
	return candidateIndex
end

--find the position of a vertex in an array return -1 if it is not in there
function findPosition(arr,val)
	local position=-1
	for i=1, #arr do
		if arr[i]==val then
			position = i
		end
	end
	return position
end

--next index in an array wrapping around
function nextIndexWrap(v,pos)
	local pos = (pos % #v) + 1
	return pos
end

function getEndForIntersection(arr,inter)
	local index=-1
	for i=1, #arr do
		if pointOnSeg(arr[i],arr[nextIndexWrap(arr,i)],inter) then
			return nextIndexWrap(arr,i)
		end
	end
	return index
end

function make_clockwise(poly1, model)
    local reference = poly1[1]
    local should_reverse = false
    if orientation(poly1[1], poly1[2], poly1[3]) == 2 then
        should_reverse = true
    end
    if should_reverse then
        local i = 1
        local j = #poly1
        while i < j do
            local temp = poly1[i]
            poly1[i] = poly1[j]
            poly1[j] = temp
            i = i + 1
            j = j - 1
        end
    end
    return poly1
end

function orientation(point_a, point_b, point_c, model)
    local val = (point_b.y - point_a.y) * (point_c.x - point_b.x) - (point_b.x - point_a.x) * (point_c.y - point_b.y)
    if (val > 0) then
        return 1
    elseif (val < 0) then
        return 2
    else
        return 0
    end
end

--Is a point on the boundary of a polygon with vertices arr
function onPolygonBoundary(arr,point)
	for i=1, #arr do
		if pointOnSeg(arr[i], arr[nextIndexWrap(arr,i)], point) then
			return true
		end
	end
	return false
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

function incorrect(title, model) model:warning(title) end

function is_convex(vertices)
	local _, convex_hull_vectors = convex_hull(vertices)
	return #convex_hull_vectors == #vertices
end

function copy_table(orig_table)
	local new_table = {}
	for i=1, #orig_table do new_table[i] = orig_table[i] end
	return new_table
end

--[=[
Given:
 - vertices: () -> {Vector}
Return:
 - shape of the convex hull of points: () -> Shape
--]=]
function convex_hull(points, model)

	function orient(p, q, r) return p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y) end
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

function run(model)
    local page = model:page()

	--the vertices and segments
	local v1, s1, v2, s2 = get_two_polygons_selection(model)

	local poly1_convex = is_convex(copy_table(v1))
	local poly2_convex = is_convex(copy_table(v2))
	if poly1_convex == false then incorrect("One or more polygons are not convex", model) end
	if poly2_convex == false then incorrect("One or more polygons are not convex", model) end

	local intersections_table = get_intersection_points(s1,s2)
	v1=make_clockwise(v1)
	v2=make_clockwise(v2)
	--the intersection points
	local intersects =  {}
	for k=1, #intersections_table do
		intersects[k]=intersections_table[k][1]
	end

	
	--The final array
	local v4={}
	--This is all for the base case
	--Which array are we on
	local onv1=true
	--starting position
	local initial=0
	
	--Get the initial position position
	--start by getting the bottom left
	local bottomLeft = getBottomLeft(v1,v2)
	if findPosition(v1,bottomLeft)~=-1 then
		initial=findPosition(v1,bottomLeft)
	else
		initial=findPosition(v2,bottomLeft)
		onv1=false
	end
	
	--index for adding to v4
	local posv4=1
	
	--Now we have which polygon our start is on and what index it is
	local returned = false
	local posv1 = 1
	local posv2 = 1
	if onv1 then
		posv1=initial
		v4[posv4]=v1[posv1]
	else
		posv2=initial
		v4[posv4]=v2[posv2]
	end
	posv4=2
	
	
	--While we haven't returned to the original
	while returned ~= true do
		--on the polygon v1
		if onv1 then
			--let's check to see if we have an intersection point with v2 and need to switch to onv2
			--Is there an intersection, if there is, which one
			local intersectionCoord = getNextIntersection(intersects,v1,nextIndexWrap(v1,posv1),posv1,model)
			if (intersectionCoord ~= -1)  then
				--if it's a vertex check to see if it's in the polygon if it is
				if (findPosition(v2,intersects[intersectionCoord])~=-1) and is_in_polygon(v2[nextIndexWrap(v2,findPosition(v2,intersects[intersectionCoord]))],v1) then
					--next position on v1
					posv1 = nextIndexWrap(v1,posv1)
					--if it's not already there
					if findPosition(v4,v1[posv1])==-1 then v4[posv4]=v1[posv1] else returned = true end
				else
					--if it's on the boundary of our original polygon
					v4[posv4]=intersects[intersectionCoord]
					onv1=false
					--if it's the vertex get the next vertex point seg returns the same 
					if (findPosition(v2,intersects[intersectionCoord])~=-1) then
						posv2 = nextIndexWrap(v2,findPosition(v2,intersects[intersectionCoord]))
					else posv2 = getEndForIntersection(v2,v4[posv4]) end
					if findPosition(v4,v2[posv2])~=-1 then returned=true end
					posv4=posv4+1
					v4[posv4]=v2[posv2]
				--if we don't have an intersection
				end
			else
				--next position on v1
				posv1 = nextIndexWrap(v1,posv1)
			
			
				--if it's not already there
				if findPosition(v4,v1[posv1])==-1 then
					v4[posv4]=v1[posv1]
				else 
					returned = true
				end
			end

		else
			--let's check to see if we have an intersection point and need to switch
			local intersectionCoord = getNextIntersection(intersects,v2,nextIndexWrap(v2,posv2),posv2,model)
			if (intersectionCoord ~= -1) then
				if (findPosition(v1,intersects[intersectionCoord])~=-1) and is_in_polygon(v1[nextIndexWrap(v1,findPosition(v1,intersects[intersectionCoord]))],v2) then
					--next position on v2
					posv2 = nextIndexWrap(v2,posv2)
					--if it's not already there
					if findPosition(v4,v2[posv2])==-1 then v4[posv4]=v2[posv2] else returned = true end
				else
					v4[posv4]=intersects[intersectionCoord]
					onv1=true
					if (findPosition(v1,intersects[intersectionCoord])~=-1) then
						posv1 = nextIndexWrap(v1,findPosition(v1,intersects[intersectionCoord]))
					else
						posv1 = getEndForIntersection(v1,v4[posv4])
					end
					if findPosition(v4,v1[posv1])~=-1 then returned=true end
					posv4=posv4+1
					v4[posv4]=v1[posv1]
				end
			--if we don't have an intersection
			else
				posv2 = nextIndexWrap(v2,posv2)
				--if it's not already there
				if findPosition(v4,v2[posv2])==-1 then
					v4[posv4]=v2[posv2]
				else 
					--print("exit","exit",model)
					returned = true
				end
			end

		end
		posv4 =posv4+1
	end
    model:creation("Create Polygon Union", ipe.Path(model.attributes, {create_shape_from_vertices(unique_points(v4),model)} ))
end
