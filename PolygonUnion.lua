-- Define the Ipelet
label = "Polygon Union"
about = "Computes the union of two convex polygons"
-- Get the selection data
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
            if obj:type() ~= "path" then
                incorrect(model)
                return
            end
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

--! Print Vertices
function print_vertices(vertices, title, model)
    local msg = title .. ": "
    for _, vertex in ipairs(vertices) do
        msg = msg .. string.format("Vertex: (%d, %d), ", vertex.x, vertex.y)
    end
    model:warning(msg)
end

function print(x, title, model)
    local msg = title .. ": " .. x
    model:warning(msg)
end

function print_vertex(v, title, model)
    local msg = title
    msg = msg .. string.format("(%d, %d), ", v.x, v.y)
    model:warning(msg)
end

-- Check whether a vertex is in a polyon
-- Adapted from the C Code on this website: https://alienryderflex.com/polygon/
-- For now just sticking to the simplest code(though ineffecient)
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

-- Closed set calculator
-- Translated code to lua from https://www.geeksforgeeks.org/find-simple-closed-path-for-a-given-set-of-points/
function distance_squared(point_a, point_b)
    return (point_a.x - point_b.x) * (point_a.x - point_b.x) + (point_a.y - point_b.y) * (point_a.y - point_b.y)
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

function reorder_polygon(P)
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
    for i = 1, pos - 1 do
        table.insert(reordered, P[i])
    end
    return reordered
end

function get_polygon_segments(obj, model)
    local shape = obj:shape()

    local segment_matrix = shape[1]

    local segments = {}
    for _, segment in ipairs(segment_matrix) do
        table.insert(segments, ipe.Segment(segment[1], segment[2]))
    end

    table.insert(
        segments,
        ipe.Segment(segment_matrix[#segment_matrix][2], segment_matrix[1][1])
    )

    return segments
end

function get_lower_polygon(poly1, poly2, model)
    if poly1[1].y < poly2[1].y then
        return poly1, poly2
    elseif poly1[1].y == poly2[1].y and poly1[1].x < poly2[1].x then
        return poly1, poly2
    else
        return poly2, poly1
    end
end

function get_intersections(poly1, poly2, model)
    local union_points = {}

    local visited_points = {}
    poly1 = make_clockwise(poly1, model)
    poly2 = make_clockwise(poly2, model)
    poly1 = reorder_polygon(poly1)
    poly2 = reorder_polygon(poly2)

    poly1, poly2 = get_lower_polygon(poly1, poly2, model)
    for i = 1, #poly1 do
        table.insert(union_points, poly1[i])
        local s1 = ipe.Segment(poly1[i], poly1[(i % #poly1) + 1])
        for j = 1, #poly2 do
            local s2 = ipe.Segment(poly2[j], poly2[(j % #poly2) + 1])
            local intersection = s1:intersects(s2)
            if intersection then
                if not (is_in_polygon(poly2[(j % #poly2) + 1], poly1, model)) then
                    table.insert(union_points, intersection)
                    table.insert(visited_points, poly2[(j % #poly2) + 1])
                    union_points = traverse_rest_points(poly1, poly2, i + 1, (j % #poly2) + 1, union_points,
                        visited_points, model)

                    return union_points
                end
            end
        end
    end
    return union_points
end

function traverse_rest_points(poly1, poly2, is, jn, union_points, visited_points, model)
    local ci = is
    local cj = jn
    local traversing_2 = true
    local has_intersected = false
    while ci ~= 1 do
        if traversing_2 then
            has_intersected = false
            local s1 = ipe.Segment(poly2[cj], poly2[(cj % #poly2) + 1])
            table.insert(union_points, poly2[cj])
            for i = 1, #poly1 do
                -- print_vertex(poly1[i], "start", model)
                -- print_vertex(poly1[(i % #poly1) + 1], "stop", model)
                local s2 = ipe.Segment(poly1[i], poly1[(i % #poly1) + 1])
                local intersection = s1:intersects(s2)
                if intersection then
                    local x = math.floor(intersection.x)
                    local y = math.floor(intersection.y)
                    intersection = ipe.Vector(x, y)
                    if not_in_table(visited_points, poly1[(i % #poly1) + 1]) then
                        if not (is_in_polygon(poly1[(i % #poly1) + 1], poly2, model)) then
                            table.insert(union_points, intersection)
                            table.insert(visited_points, poly1[(i % #poly1) + 1])

                            traversing_2 = false
                            has_intersected = true
                            ci = (i % #poly1) + 1
                            break
                        end
                    else
                    end
                end
            end
            if not has_intersected then
                cj = cj % # poly2 + 1
            end
        else
            has_intersected = false
            table.insert(union_points, poly1[ci])
            local s1 = ipe.Segment(poly1[ci], poly1[(ci % #poly1) + 1])
            for j = 1, #poly2 do
                local s2 = ipe.Segment(poly2[j], poly2[(j % #poly2) + 1])
                local intersection = s1:intersects(s2)
                if intersection then
                    local x = math.floor(intersection.x)
                    local y = math.floor(intersection.y)
                    intersection = ipe.Vector(x, y)
                    if not_in_table(visited_points, poly2[(j % #poly2) + 1]) then
                        if not (is_in_polygon(poly2[(j % #poly2) + 1], poly1, model)) then
                            table.insert(union_points, intersection)
                            table.insert(visited_points, poly2[(j % #poly2) + 1])
                            traversing_2 = true
                            cj = (j % #poly2) + 1
                            has_intersected = true
                            break
                        end
                    end
                end
            end
            if not has_intersected then
                ci = ci % #poly1 + 1
            end
        end
    end
    return union_points
end

function get_polygon_vertices(obj, model)
    local shape = obj:shape()
    local polygon = obj:matrix()

    vertices = {}

    vertex = polygon * shape[1][1][1]
    table.insert(vertices, vertex)

    for i = 1, #shape[1] do
        vertex = polygon * shape[1][i][2]
        table.insert(vertices, vertex)
    end

    return vertices
end

function create_shape_from_vertices(v, model)
    local shape = { type = "curve", closed = true, }
    for i = 1, #v - 1 do
        table.insert(shape, { type = "segment", v[i], v[i + 1] })
    end
    table.insert(shape, { type = "segment", v[#v], v[1] })
    return shape
end

function run(model)
    -- Obtain the first page of the Ipe document.
    -- Typically, work with thes objects (like polygons) on this page.
    --local page = model.doc[1]
    local page = model:page()
    local obj1, obj2 = get_selection_data(model)
    local obj1_vertices = get_polygon_vertices(obj1, model)
    local obj2_vertices = get_polygon_vertices(obj2, model)
    local shape = create_shape_from_vertices(get_intersections(obj1_vertices, obj2_vertices, model))
    local result_obj = ipe.Path(model.attributes, { shape }) -- Generate the original result shape
    model:creation("Create Polygon Union", result_obj)
end
