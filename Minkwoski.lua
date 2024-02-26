-- Ipelet: Minkowski Sum
-- Template: https://cp-algorithms.com/geometry/minkowski.html#algorithm

-- Define the Ipelet
label = "Minkowski Sum"
about = "Computes the Minkowski Sum of two convex polygons in R^2"

--! PRINT FUNCTIONS
function print_vertices(vertices, title, model)
    local msg = title ..  ": "
    for _, vertex in ipairs(vertices) do
        msg = msg .. ": " .. string.format("Vertex: (%f, %f), ", vertex.x, vertex.y)
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


--! BASIC OPERATIONS
-- Add points: P + Q = (P.x + Q.x, P.y + Q.y)
function add(p1, p2)
    return ipe.Vector(p1.x + p2.x, p1.y + p2.y)
end

-- Subtract points: P - Q = (P.x - Q.x, P.y - Q.y)
function subtract(p1, p2)
    return ipe.Vector(p1.x - p2.x, p1.y - p2.y)
end

-- 2D cross product: P x Q = P.x*Q.y - P.y*Q.x
-- Used to determine the orientation of three points (counterclockwise, collinear, clockwise)
function cross(p1, p2)
    return p1.x * p2.y - p1.y * p2.x
end


--! MINKOWSKI SUM
-- Reorder polygon vertices
-- Ensures the first vertex has the smallest y-coordinate (and x in case of tie)
-- Aids in consistently starting the Minkowski sum from a specific vertex
function reorder_polygon(P, model)
    local pos = 1
    for i = 2, #P do
        if P[i].y < P[pos].y or (P[i].y == P[pos].y and P[i].x < P[pos].x) then
            pos = i
        end
    end
    local reordered = {}
    for i = pos, #P do
        table.insert(reordered, P[i])
    end
    for i = 1, pos-1 do
        table.insert(reordered, P[i])
    end
    return reordered
end

-- Compute the Minkowski Sum
-- Uses the oriented cross product to ensure convexity and consistent vertex ordering
function minkowski(P, Q, model)
    -- Reorder vertices to have a consistent starting point
    local P = reorder_polygon(P, model)
    local Q = reorder_polygon(Q, model)

    -- Ensure cyclic indexing by adding the first two points at the end
    table.insert(P, P[1])
    table.insert(P, P[2])
    table.insert(Q, Q[1])
    table.insert(Q, Q[2])
    

    local result = {}
    local i, j = 1, 1

    -- Iterate over P and Q vertices, adding corresponding points and determining which polygon’s vertex to move to next
    while i < #P-1 or j < #Q-1 do
        table.insert(result, add(P[i],Q[j])) -- Add vertices P[i], Q[j] and insert into result
        local cross = cross(subtract(P[i + 1], P[i]), subtract(Q[j + 1], Q[j])) -- Compute cross product of vectors P[i+1]P[i], Q[j+1]Q[j]

        -- Determine which vertex to move to next based on the cross product sign
        if cross >= 0 and i < #P-1 then -- Ensures we always have 2 elems to work with, if at length - 2, then stay at same index
            i = i + 1
        end
        if cross <= 0 and j < #Q-1 then -- Ensures we always have 2 elems to work with, if at length - 2, then stay at same index
            j = j + 1
        end

        --? NOTE: When cross == 0,
        --? it indicates that the two vectors, which are edges from the polygons P and Q, are parallel.
        --? If both i and j are incremented, it means that the algorithm is considering the next vertex from both polygons 
            --? P and Q for the resultant Minkowski sum.
        --? This might be appropriate in some cases, especially when the parallel edges from P and Q
                                                    --? are part of the boundary of the Minkowski sum.
    end
    return result
end


--! IPELET FUNCTIONS
-- GET SELECTION DATA
function incorrect(model)
    model:warning("One or more selections are not polygons")
end
function get_selection_data(model)
    local page = model:page()
    local polygons = {}

    for i = 1, #page do
        local obj = page[i]
        if page:select(i) then
            if obj:type() ~= "path" then incorrect(model) return end
            table.insert(polygons, obj)
        end
    end

    if #polygons ~= 2 then
        model:warning("Please select 2 polygons")
    end

    return polygons[1], polygons[2]
end

-- COLLECT VERTICES
function not_in_table(vertices, vertex_comp)
    local flag = true
    for _, vertex in ipairs(vertices) do
        if vertex == vertex_comp then
            flag = false
        end
    end
    return flag
end
function collect_vertices(obj)
    local vertices = {}

    local shape = obj:shape()
    local m = obj:matrix()

    for _, subpath in ipairs(shape) do
        for _, segment in ipairs(subpath) do
            if not_in_table(vertices, segment[1]) then
                table.insert(vertices, segment[1])
            end
            if not_in_table(vertices, segment[2]) then
                table.insert(vertices, segment[2])
            end
        end
    end

    return vertices
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
function shift_polygon(vertices, shift_vector)
    local shifted_vertices = {}
    for _, v in ipairs(vertices) do
        table.insert(shifted_vertices, ipe.Vector(v.x + shift_vector.x, v.y + shift_vector.y))
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
    local shift_vector = ipe.Vector(midpoint.x - centroid_minkowski.x, 
                                    midpoint.y - centroid_minkowski.y)

    -- Shift the Minkowski sum to be centered around the midpoint
    return shift_polygon(minkowski_result, shift_vector)
end

--! Run the Ipelet
function run(model)
    -- Obtain the first page of the Ipe document.
    local page = model:page()
    
    -- Get info for the two objects
    local obj1, obj2 = get_selection_data(model)
    local primary = collect_vertices(obj1)
    local secondary = collect_vertices(obj2)
    
    -- Testing
    -- print_vertices(primary, 1, model)
    -- print_vertices(secondary, 2, model)
    
    --! Compute the Minkowski sum of the two polygons and store resulting vertices
    local result_vertices = minkowski(primary, secondary, model)
    -- print_vertices(result_vertices, "Original Result Vertices", model)
    --! Center the Minkowski sum around the two input shapes
    local centered_result_vertices = center_minkowski_sum(primary, secondary, result_vertices, model)
    -- print_vertices(centered_result_vertices, "Centered Result Vertices", model)

    --! Convert to a shape
    -- Original
    local result_shape = {type="curve", closed=true;}
    for i=1, #result_vertices-1 do -- Add each vertex pair --> segment to the shape
        table.insert(result_shape, segmentation(result_vertices[i], result_vertices[i + 1]))
    end
    -- Centered
    local centered_result_shape = {type="curve", closed=true;}
    for i=1, #centered_result_vertices-1 do -- Add each vertex pair --> segment to the shape
        table.insert(centered_result_shape, segmentation(centered_result_vertices[i], centered_result_vertices[i + 1]))
    end

    local result_obj = ipe.Path(model.attributes, {result_shape}) -- Generate the original result shape
    local centered_result_obj = ipe.Path(model.attributes, {centered_result_shape}) -- Generate the centered result shape

    model:creation("Create Minkowski Sum", result_obj)
    model:creation("Create Centered Minkowski Sum", centered_result_obj)
end