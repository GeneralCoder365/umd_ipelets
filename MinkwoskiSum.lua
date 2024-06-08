-- Ipelet: Minkowski Sum

-- Define the Ipelet
label = "Minkowski Sum"
about = "Computes the Minkowski Sum of two convex polygons in R^2"


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

-- function is_convex(vertices, model)
--     local _, convex_hull_vectors = convex_hull(vertices, model)
--     return #convex_hull_vectors == #vertices
-- end
--! Explanation: O(n)
-- Iterates over all triplets of vertices in the polygon.
-- For each triplet, it checks the orientation (clockwise, counterclockwise, or collinear).
-- If a non-collinear orientation is found, it is compared with the first non-collinear orientation encountered.
    -- If a mismatch is found (indicating both clockwise and counterclockwise orientations), the polygon is non-convex.
-- If all non-collinear triplets have the same orientation, the polygon is convex.
function is_convex(vertices, model)
    local n = #vertices
    if n < 3 then return false end -- Less than 3 points can't be a convex polygon

    local firstOrientation = nil

    for i = 1, n do
        local orientationResult = orientation(vertices[i], vertices[(i % n) + 1], vertices[((i + 1) % n) + 1], model)

        if orientationResult ~= 0 then -- if not collinear
            if firstOrientation == nil then
                firstOrientation = orientationResult
            elseif orientationResult ~= firstOrientation then
                return false -- Found both clockwise and counterclockwise orientations
            end
        end
    end

    return true -- All non-collinear triplets have the same orientation
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

    local poly1_convex = is_convex(copy_table(vertices1), model)
    local poly2_convex = is_convex(copy_table(vertices2), model)

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



--! CONVEX HULL (GRAHAM SCAN)
-- https://www.codingdrills.com/tutorial/introduction-to-divide-and-conquer-algorithms/convex-hull-graham-scan

-- Function to calculate the squared distance between two points
function squared_distance(p1, p2)
    return (p1.x - p2.x)^2 + (p1.y - p2.y)^2
end


-- Function to find the orientation of ordered triplet (p, q, r).
-- The function returns the following values:
-- 0 : Collinear points
-- 1 : Clockwise points
-- 2 : Counterclockwise  
function orientation(p, q, r, model)
    -- print the vectors and val
    -- print_vertices({p, q, r}, "Orientation", model)
    local val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
    -- print(val, "Orientation", model)
    if val == 0 then return 0  -- Collinear
    elseif val > 0 then return 2  -- Counterclockwise
    else return 1  -- Clockwise
    end
end


-- Function to compare two points with respect to a given 'lowest' point
-- Closure over the lowest point to create a compare function
function create_compare_function(lowest, model)
    return function(p1, p2) -- anonymous function

        -- Determine the orientation of the triplet (lowest, p1, p2)
        local o = orientation(lowest, p1, p2, model)

        -- If p1 and p2 are collinear with lowest, choose the farther one to lowest
        if o == 0 then
            return squared_distance(lowest, p1) < squared_distance(lowest, p2)
        end

        -- For non-collinear points, choose the one that forms a counterclockwise turn with lowest
        return o == 2
    end
end


-- O(nlog(n))
function convex_hull(points, model)
    local n = #points
    if n < 3 then return {} end  -- Less than 3 points cannot form a convex hull

    -- Find the point with the lowest y-coordinate (or leftmost in case of a tie)
    local lowest = 1
    for i = 2, n do
        if points[i].y < points[lowest].y or (points[i].y == points[lowest].y and points[i].x < points[lowest].x) then
            lowest = i
        end
    end

    -- Swap the lowest point to the start of the array
    points[1], points[lowest] = points[lowest], points[1]

    -- Sort the rest of the points based on their polar angle with the lowest point
    local compare = create_compare_function(points[1], model) -- closure over the lowest point
    table.sort(points, compare)

    -- Sorted points are necessary but not sufficient to form a convex hull.
    --! The stack is used to maintain the vertices of the convex hull in construction.

    -- Initializing stack with the first three sorted points
    -- These form the starting basis of the convex hull.
    local stack = {points[1], points[2], points[3]}

    -- Process the remaining points to build the convex hull
    for i = 4, n do
        -- Check if adding the new point maintains the convex shape.
        -- Remove points from the stack if they create a 'right turn'.
        -- This ensures only convex shapes are formed.
        while #stack > 1 and orientation(stack[#stack - 1], stack[#stack], points[i]) ~= 2 do
            table.remove(stack)  -- Remove point from stack if it creates a non-convex turn
        end
        table.insert(stack, points[i])  -- Add the new point to the stack
    end

    -- The stack now contains the vertices of the convex hull in counterclockwise order.
    return create_shape_from_vertices(stack, model), stack
end


--! SHAPE CREATION
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
    local primary, secondary = get_two_polygons_selection(model)
    if not primary or not secondary then return end
    
    --! Compute the Minkowski sum of the two polygons and store resulting vertices
    local result_vertices = minkowski(primary, secondary, model)
    local centered_result_vertices = center_minkowski_sum(primary, secondary, result_vertices, model)

    --! Center the Minkowski sum around the two input shapes
    local result_shape_obj, _ = convex_hull(result_vertices, model)
    local centered_shape_obj, _ = convex_hull(centered_result_vertices, model)

    -- model:creation("Create Minkowski Sum", ipe.Path(model.attributes, { result_shape_obj }))
    model:creation("Create Centered Minkowski Sum", ipe.Path(model.attributes, { centered_shape_obj }))
end
