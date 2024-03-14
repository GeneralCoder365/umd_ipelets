-- Ipelet: Minkowski Sum

-- Define the Ipelet
label = "Minkowski Sum"
about = "Computes the Minkowski Sum of two convex polygons in R^2"

function incorrect(title, model) model:warning(title) end

--! MINKOWSKI SUM
-- Compute the Minkowski Sum
-- Uses the oriented cross product to ensure convexity and consistent vertex ordering
function minkowski(P, Q, model)

    local result = {}

    for i=1, #P do
        for j=1, #Q do
            table.insert(result, P[i] + Q[j])
        end
    end

    return result
end

function get_polygon_vertices(obj, model)

    local shape = obj:shape()
    local polygon = obj:matrix()

    vertices = {}

        -- Apply transformation to the first vertex to handle translation
    vertex = polygon * shape[1][1][1]
    table.insert(vertices, vertex)

        -- Apply transformation to the rest of the vertices to handle translation
    for i=1, #shape[1] do
        vertex = polygon * shape[1][i][2]
        table.insert(vertices, vertex)
    end

    return vertices
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

function startBottomLeft(vertices)
    local minimum = 1
    for k=1, #vertices do
        local current = vertices[k]
        local min = vertices[minimum]
        if current.y < min.y then
            minimum=k
        elseif current.y == min.y then
            if current.x < min.x then
                minimum=k
            end
        end
    end

    local new_vertices = {}
    for i=0, #vertices do
        new_vertices[i] = vertices[(i-1+minimum) % #vertices+1]
    end

    return new_vertices
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

    local vertices1 = get_polygon_vertices(pathObject1, model)
    local vertices2 = get_polygon_vertices(pathObject2, model)

    local vertices1 = startBottomLeft(make_clockwise(unique_points(vertices1)))
    local vertices2 = startBottomLeft(make_clockwise(unique_points(vertices2)))

    local poly1_convex = is_convex(copy_table(vertices1))
    local poly2_convex = is_convex(copy_table(vertices2))
    if poly1_convex == false or poly2_convex == false then incorrect("Polygons must be convex", model) return end
    return vertices1, vertices2
end


-- CONVEX HULL
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


-- SHAPE CREATION
function create_shape_from_vertices(v, model)
    local shape = {type="curve", closed=true;}
    for i=1, #v-1 do 
        table.insert(shape, {type="segment", v[i], v[i+1]})
    end
    table.insert(shape, {type="segment", v[#v], v[1]})
    return shape
end

-- Creates segments from vertex pairs
function segmentation(v1, v2)
    return {type="segment", v1, v2}
end


--! CENTERING FUNCTIONS
-- Function to calculate the centroid of a polygon
function calculate_centroid(vertices)
    local sum_x, sum_y = 0, 0
    for _, v in ipairs(vertices) do
        sum_x = sum_x + v.x
        sum_y = sum_y + v.y
    end
    return ipe.Vector(sum_x / #vertices, sum_y / #vertices)
end

-- Function to shift the vertices of a polygon by a given vector
function shift_polygon(vertices, shift_vector, model)
    local shifted_vertices = {}
    for _, v in ipairs(vertices) do
        table.insert(shifted_vertices, v + shift_vector)
    end
    return shifted_vertices
end

-- Function to center the Minkowski sum around the two input shapes
function center_minkowski_sum(primary, secondary, minkowski_result, model)
    local centroid_primary = calculate_centroid(primary)
    local centroid_secondary = calculate_centroid(secondary)
    local centroid_minkowski = calculate_centroid(minkowski_result)

    -- Calculate the midpoint between the two input centroids
    local midpoint = ipe.Vector((centroid_primary.x + centroid_secondary.x) / 2, 
                                (centroid_primary.y + centroid_secondary.y) / 2)

    -- Calculate the vector required to shift the Minkowski sum's centroid to the midpoint
    -- local shift_vector = ipe.Vector(midpoint.x - centroid_minkowski.x, 
    --                                 midpoint.y - centroid_minkowski.y)
    local shift_vector = midpoint - centroid_minkowski

    -- Shift the Minkowski sum to be centered around the midpoint
    return shift_polygon(minkowski_result, shift_vector, model)
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
        if not_in_table(uniquePoints, points[i]) then table.insert(uniquePoints, points[i]) end
    end
    return uniquePoints
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

--! Run the Ipelet
function run(model)

    if not get_two_polygons_selection(model) then return end
    local primary, secondary = get_two_polygons_selection(model)
    
    --! Compute the Minkowski sum of the two polygons and store resulting vertices
    local result_vertices = minkowski(primary, secondary, model)

    local result_shape_obj, s = convex_hull(result_vertices)

    --! Center the Minkowski sum around the two input shapes
    local centered_result_vertices = center_minkowski_sum(primary, secondary, s, model)

    local centered_shape_obj, _ = convex_hull(centered_result_vertices)

    -- model:creation("Create Minkowski Sum", ipe.Path(model.attributes, { result_shape_obj }))
    model:creation("Create Centered Minkowski Sum", ipe.Path(model.attributes, { centered_shape_obj }))
end
