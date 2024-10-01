-- Ipelet: Minkowski Sum

-- Define the Ipelet
label = "Minkowski Sum"
about = "Computes the Minkowski Sum of two convex polygons in R^2"


--! PRINT FUNCTIONS
function incorrect(title, model) model:warning(title) end

function print_vertices(vertices, title, model)
    local msg = title ..  ": "
    for _, vertex in ipairs(vertices) do
        msg = msg .. ": " .. string.format("Vertex: (%f, %f), ", vertex.x, vertex.y)
    end
    model:warning(msg)
end

function print_table(t, title, model)
    -- Print lua table
    local msg = title ..  ": "
    for k, v in pairs(t) do
        msg = msg .. k .. " = " .. v .. ", "
    end
    model:warning(msg)
end

function print_vertex(v, title, model)
    local msg = title
    msg = msg .. ": " .. string.format("(%f, %f), ", v.x, v.y)
    model:warning(msg)
end

function print(x, title, model)
    local msg = title .. ": " .. x
    model:warning(msg)
end

function get_polygon_vertices(obj, model)

    local shape = obj:shape()
    local polygon = obj:matrix()

    local vertices = {}

        -- Apply transformation to the first vertex to handle translation
    local vertex = polygon * shape[1][1][1]
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

    local vertices1 = unique_points(get_polygon_vertices(pathObject1, model))
    local vertices2 = unique_points(get_polygon_vertices(pathObject2, model))

    local poly1_convex = is_convex(copy_table(vertices1))
    local poly2_convex = is_convex(copy_table(vertices2))

    if poly1_convex == false or poly2_convex == false then incorrect("Polygons must be convex", model) return end
    return vertices1, vertices2
end

--! MINKOWSKI SUM
-- Compute the Minkowski Sum
-- Uses the oriented cross product to ensure convexity and consistent vertex ordering
function minkowski(P, Q, model)
    local result = {}
    for i=1, #P do for j=1, #Q do table.insert(result, P[i] + Q[j]) end end
    return result
end

function orient(p, q, r) return ((q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y-q.y)) < 0 end

-- CONVEX HULL
--[=[
Given:
 - vertices: () -> {Vector}
Return:
 - shape of the convex hull of points: () -> Shape
--]=]
function convex_hull(points)
    table.sort(points, function(a,b)
        if a.x < b.x then
            return true
        elseif a.x == b.x then
            return a.y < b.y
        else
            return false
        end
    end)
    if #points < 3 then return end
    local hull, left_most, p, q = {}, 1, 1, 0
    while true do
        table.insert(hull, points[p])
        q = (p % #points) + 1
        for i=1, #points do
            if orient(points[p], points[i], points[q]) then q = i end
        end
        p = q
        if p == left_most then break end
    end
    return create_shape_from_vertices(hull), hull
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

--! Run the Ipelet
function run(model)
    if not get_two_polygons_selection(model) then return end
    local primary, secondary = get_two_polygons_selection(model)
    
    --! Compute the Minkowski sum of the two polygons and store resulting vertices
    local result_vertices = minkowski(primary, secondary, model)
    local centered_result_vertices = center_minkowski_sum(primary, secondary, result_vertices, model)

    --! Center the Minkowski sum around the two input shapes
    local result_shape_obj, _ = convex_hull(result_vertices)
    local centered_shape_obj, _ = convex_hull(centered_result_vertices)

    model:creation("Create Minkowski Sum", ipe.Path(model.attributes, { result_shape_obj }))
    model:creation("Create Centered Minkowski Sum", ipe.Path(model.attributes, { centered_shape_obj }))
end
