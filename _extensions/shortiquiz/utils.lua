local M = {}

function M.writeEnvironments()
    if quarto.doc.is_format("html:js") then
        quarto.doc.add_html_dependency({
            name = "sq-components",
            version = "1.0.0",
            scripts = {
                { path = "sq-components.js" } },
        })
        quarto.doc.add_html_dependency({
            name = "plain-draggable",
            version = "2.5.15",
            scripts = {
                { path = "plain-draggable.min.js", afterBody = "true" } },
        })
        quarto.doc.add_html_dependency({
            name = "alpine",
            version = "3.12",
            scripts = {
                { path = "sort-alpine.min.js", afterBody = "true" },
                { path = "alpine.min.js",      afterBody = "true" }
            },
        })
        quarto.doc.add_html_dependency({
            name = "qstyles",
            version = "1",
            stylesheets = { "qstyles.css" }
        })
    end
end

function M.ShuffleInPlace(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- считаем количество пробелов в начале строки
function M.count_leading_spaces(str)
    local match = str:match("^%s+")
    if match then
        return #match
    else
        return 0
    end
end

function M.RandomStringID(length)
    local res = ""
    for i = 1, length do
        res = res .. string.char(math.random(97, 122))
    end
    return res
end

-- в мультистрочном блоке инструкций
-- удаляем начальные пробелы в каждой строке
function M.trim_initial_spaces(input)
    -- Разбиваем строку на строки по символу новой строки
    local lines = {}
    for line in input:gmatch("[^\r\n]+") do
        -- Удаляем начальные пробелы
        line = line:gsub("^%s+", "")
        table.insert(lines, line)
    end

    -- Объединяем строки обратно в одну строку с символом новой строки
    return table.concat(lines, "\n")
end

function M.escapeHtmlDataAttribute(str)
    local entities = {
        ['"'] = "&quot;",
        ["'"] = "&#39;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ["&"] = "&amp;",
        [" "] = "&#32;",
    }

    return str:gsub('[&<>"\'\t\n\r ]', function(c)
        return entities[c] or c
    end)
end

function M.css_style(str)
    local top, left, width, height = str:match("(%-?%d+%.?%d*) (%-?%d+%.?%d*) (%-?%d+%.?%d*) (%-?%d+%.?%d*)")
    return string.format("style=\"top: %s%%; left: %s%%; width: %s%%; height: %s%%\"", top, left, width, height)
end

return M