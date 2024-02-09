local M = {}

local data_path = string.format("%s/2048.json", vim.fn.stdpath("data"))
local defaults = {
    board_height = 4,
    board_width = 4,
    cs = {
        values = nil,
        score = 0,
        high_score = 0,
    },
    ps = {
        values = nil,
        score = 0,
        high_score = 0,
    },
}

defaults.cs.values = {}
for _ = 1, defaults.board_height do
    local tmp = {}
    for _ = 1, defaults.board_width do
        table.insert(tmp, 0)
    end
    table.insert(defaults.cs.values, tmp)
end
defaults.cs.values[math.random(1, defaults.board_height)][math.random(1, defaults.board_width)] = 2
defaults.ps.values = vim.deepcopy(defaults.cs.values)

function M.load()
    local file = io.open(data_path, "r")
    if file then
        local json = file:read("*a")
        file:close()
        return vim.json.decode(json)
    else
        return defaults
    end
end

function M.save(cs, ps, board_height, board_width)
    local json = vim.json.encode({
        board_height = board_height,
        board_width = board_width,
        cs = cs,
        ps = ps,
    })

    local file = io.open(data_path, "w")
    if file then
        file:write(json)
        file:close()
    else
        error("2048: failed to save data")
    end
end

return M
