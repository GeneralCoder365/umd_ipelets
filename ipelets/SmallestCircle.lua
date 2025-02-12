----------------------------------------------------------------------
-- Smallest circle auto-generation for points
----------------------------------------------------------------------
label = "Euclidean Minimum Enclosing Ball"
revertOriginal = _G.revertOriginal
about = [[
Generates the Euclidean Minimum Enclosing Ball for a set of points.
This Lua ipelet script is written by Hongyang Du hongyangdu182@gmail.com.
]]

function get_dist(center,point)
	return math.sqrt((center.x - point.x)^2 + (center.y - point.y)^2)
end

function get_center(p1,p2,p3)
	local bi1 = ipe.Bisector(p1, p2)
	local bi2 = ipe.Bisector(p2, p3)
	local center = bi1:intersects(bi2)
	return center
end

function create_circle(model, center, radius)
	local shape =  { type="ellipse";
		ipe.Matrix(radius, 0, 0, radius, center.x, center.y) }
	model:creation("Smallest Circle",ipe.Path(model.attributes, { shape } ))
  end

function is_in_circle(point, center, radius)
	if (point.x - center.x)^2 + (point.y - center.y)^2 <= radius^2 + 0.000001 then -- deal with floating points overflow
		return true
	else
		return false
	end
end

function convex_hull_points(points)

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

function extreme_point(points)
    local max = -1
    local p1 = nil 
    local p2 = nil  
    for i, point1 in ipairs(points) do 
        for j, point2 in ipairs(points) do
            if i ~= j then  -- Ensure we're not comparing the same points
                local dist = math.sqrt((point1.x - point2.x)^2 + (point1.y - point2.y)^2)
                if dist > max then
                    max = dist
                    p1 = point1
                    p2 = point2
                end
            end
        end
    end
    return p1, p2  -- Return the two points with the maximum distance between them
end

function generate_smallest_circle(model, p1, p2, points)
	local temp_radius = math.maxinteger
	local temp_center = nil


	for i=1, #points do
		if not ((points[i].x == p1.x and points[i].y == p1.y) or (points[i].x == p2.x and points[i].y == p2.y)) then
			local center = get_center(p1,p2,points[i])
			local radius = get_dist(center,p1)
			local flag = true

			for j=1, #points do
				if not is_in_circle(points[j], center,radius) then
					flag = false
					break
				end
			end

			if flag and (radius <= temp_radius) then
				temp_radius = radius
				temp_center = center
			end


		end
	end

	
	local radius = get_dist(p1,p2)/2
	local center2 = ipe.Vector((p1.x + p2.x)/2, (p1.y + p2.y)/2)


	if temp_center == nil then
		create_circle(model, center2, radius)
		return
	elseif radius <= temp_radius then
		for j=1, #points do
			if not is_in_circle(points[j], center2,radius) then
				create_circle(model, temp_center, temp_radius)
				return
			end
		end
	end

	-- failed to generate the circle of 3 points
	create_circle(model, center2, radius)

end

function incorrect(title, model) model:warning(title) end

function run(model)

	local p = model:page()

    if not p:hasSelection() then incorrect("Please select at least 2 points", model) return end

	local referenceObjects = {}
	local count = 0
	for _, obj, sel, _ in p:objects() do
		if sel then
		count = count + 1
			if obj:type() ~= "reference" then
				incorrect("One or more selections are not points", model)
				return
			else
				table.insert(referenceObjects, obj:matrix() * obj:position())
			end
		end
	end
	
    if count < 2 then incorrect("Please select at least 2 points", model) return end

	if count == 2 then
		local p1 = referenceObjects[1]
		local p2 = referenceObjects[2]
		local center = ipe.Vector((p1.x + p2.x)/2, (p1.y + p2.y)/2)
		local radius = get_dist(p1,p2)/2
		create_circle(model, center, radius)
		return
	end

	local edge_points = convex_hull_points(referenceObjects)
	local extreme1, extreme2 = extreme_point(edge_points)


	generate_smallest_circle(model, extreme1, extreme2, edge_points)

end

