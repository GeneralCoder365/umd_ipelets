-- Define the Ipelet
label = "Polar Body"
about = "Displays the polar body of a convex polygon"

function incorrect(title, model) model:warning(title) end

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

	return S

end

function is_convex(vertices)
	local convex_hull_vectors = convex_hull(vertices)
	return #convex_hull_vectors == #vertices
end

function copy_table(orig_table)
	local new_table = {}
	for i=1, #orig_table do new_table[i] = orig_table[i] end
	return new_table
end

function get_original_vertices(model)
	local p = model:page()

	if not p:hasSelection() then incorrect("Please select a convex polygon", model) return end

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

	if not pathObject then incorrect("Please select a convex polygon", model) return end

	local shape = pathObject:shape()
	local polygon = pathObject:matrix()

	local orig_vertices = {}

	local vertex = polygon * shape[1][1][1]
	table.insert(orig_vertices, vertex)

	for i=1, #shape[1] do
		vertex = polygon * shape[1][i][2]
		table.insert(orig_vertices, vertex)
	end

	orig_vertices = unique_points(orig_vertices)

    if not is_convex(copy_table(orig_vertices)) then incorrect("Selected polygon is not convex", model) return end

	return orig_vertices, referenceObject
end

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

function dual_transform(v,model)
	lines = {}
	for i=1, #v do table.insert(lines, vertex_dual(v[i])) end
	return lines
end

function intersect(l1,l2, model)
	return l1:intersects(l2)
end


function get_intersection_points(l,model)
	polar_vertices = {}
	for i=1, #l-1 do table.insert(polar_vertices, intersect(l[i], l[i+1])) end
	table.insert(polar_vertices, intersect(l[#l], l[1], model))
	return polar_vertices
end

function create_polar_body(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do table.insert(shape, {type="segment", v[i], v[i+1]}) end
    table.insert(shape, {type="segment", v[#v], v[1]})
	local obj = ipe.Path(model.attributes, { shape })
    model:creation("Polar Dual", obj)
end

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
        table.insert(shifted_vertices, ipe.Vector((2048*vertex.x)+x, (2048*vertex.y)+y))
    end
    
    return shifted_vertices
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

--! Run the Ipelet
function run(model)
    
    local orig_vertices, origin_obj = get_original_vertices(model)
	if not orig_vertices then return end

	local origin
	if origin_obj then
		origin = origin_obj:matrix() * origin_obj:position()
	end

    local orig_vertices, offset_x, offset_y = shift_to_origin(orig_vertices)
    local lines = dual_transform(orig_vertices, model)
    local polar_vertices = get_intersection_points(lines)

	if origin then
		polar_vertices = shift_back(polar_vertices, origin.x, origin.y)
		create_polar_body(polar_vertices, model)
		local obj =  ipe.Reference(model.attributes,model.attributes.markshape, origin)
    	model:creation("Polar Dual Origin", obj)
	else
		polar_vertices = shift_back(polar_vertices, offset_x, offset_y)
		create_polar_body(polar_vertices, model)
		local obj = ipe.Reference(model.attributes,model.attributes.markshape, ipe.Vector(offset_x, offset_y))
    	model:creation("Polar Dual Origin", obj)
	end
end
