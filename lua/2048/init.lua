local Data = require("2048.data")

local M = {}
M.__index = M

function M.new()
    local data = Data.load()
    local self = {
        bufnr = nil,
        winnr = nil,
        score_bufnr = nil,
        score_winnr = nil,
        ns_id = vim.api.nvim_create_namespace("2048"),
        _square_height = 5,
        _square_width = 10,
        _vertical_padding = 1,
        _horizontal_padding = 2,
        _up_down_animation_interval = 30,
        _left_right_animation_interval = nil,
        board_height = data.board_height,
        board_width = data.board_width,
        cs = data.cs, -- current state
        ps = data.ps, -- previous state
        destinations = {
            { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 } },
            { { 2, 1 }, { 2, 2 }, { 2, 3 }, { 2, 4 } },
            { { 3, 1 }, { 3, 2 }, { 3, 3 }, { 3, 4 } },
            { { 4, 1 }, { 4, 2 }, { 4, 3 }, { 4, 4 } },
        },
        changed = false,
        did_undo = false,
    }
    -- vertical spaces are larger than the horizontal spaces, so we need to adjust some things
    self._left_right_animation_interval = self._up_down_animation_interval
        * (self._square_height + self._vertical_padding)
        / (self._square_width + self._horizontal_padding)
    return setmetatable(self, M)
end

function M.setup()
    math.randomseed(os.time())
    require("2048.highlights").setup()
    vim.api.nvim_create_user_command("Play2048", function(event)
        if #event.fargs > 0 then
            error("2048: command does not take arguments.")
        end
        local game = M.new()
        game:create_window()
    end, { nargs = 0, desc = "Start the game" })
end

function M:create_window()
    local height = self:get_window_height()
    local width = self:get_window_width()
    local nvim_uis = vim.api.nvim_list_uis()
    if #nvim_uis > 0 then
        if nvim_uis[1].height <= height or nvim_uis[1].width <= width then
            error("2048: increase the size of your Neovim instance.")
        end
    end
    local cols = vim.o.columns
    local lines = vim.o.lines - vim.o.cmdheight
    local bufnr = vim.api.nvim_create_buf(false, true)

    local winnr = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        anchor = "NW",
        title = " 2048 ",
        title_pos = "center",
        row = math.floor((lines - height) / 2),
        col = math.floor((cols - width) / 2),
        width = width,
        height = height,
        style = "minimal",
        border = "double",
        noautocmd = true,
    })

    if winnr == 0 then
        error("2048: failed to open window")
    end

    self.bufnr = bufnr
    self.winnr = winnr

    local replacement = {}
    for _ = 1, height do
        table.insert(replacement, string.rep(" ", width, ""))
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, replacement)

    self:create_scoreboard_window()
    self:set_keymaps()
    self:create_autocmds()
    self:draw()
end

function M:create_scoreboard_window()
    local width = self:get_window_width()
    local height = 1

    local bufnr = vim.api.nvim_create_buf(false, true)

    local winnr = vim.api.nvim_open_win(bufnr, false, {
        relative = "win",
        win = self.winnr,
        anchor = "SW",
        title = " Score ",
        title_pos = "center",
        row = -1,
        col = -1,
        width = width,
        height = height,
        style = "minimal",
        border = "single",
        noautocmd = true,
    })

    if winnr == 0 then
        error("2048: failed to open scoreboard window")
    end

    self.score_bufnr = bufnr
    self.score_winnr = winnr
end

function M:update_score()
    local score_text = string.format(" Score: %d", self.cs.score)
    local high_score_text = string.format("High Score: %d ", self.cs.high_score)
    local sep = string.rep(" ", self:get_window_width() - #score_text - #high_score_text, "")
    vim.api.nvim_buf_set_lines(
        self.score_bufnr,
        0,
        1,
        false,
        { string.format("%s%s%s", score_text, sep, high_score_text) }
    )
end

function M:set_keymaps()
    local function reset_destinations()
        self.destinations = {
            { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 } },
            { { 2, 1 }, { 2, 2 }, { 2, 3 }, { 2, 4 } },
            { { 3, 1 }, { 3, 2 }, { 3, 3 }, { 3, 4 } },
            { { 4, 1 }, { 4, 2 }, { 4, 3 }, { 4, 4 } },
        }
    end
    local opts = { buffer = true }
    vim.keymap.set("n", "j", function()
        reset_destinations()
        local tmp = vim.deepcopy(self.cs)
        self:add_down()
        if self.changed then
            self.ps = tmp
            self:animate_down()
        end
    end, opts)
    vim.keymap.set("n", "k", function()
        reset_destinations()
        local tmp = vim.deepcopy(self.cs)
        self:add_up()
        if self.changed then
            self.ps = tmp
            self:animate_up()
        end
    end, opts)
    vim.keymap.set("n", "l", function()
        reset_destinations()
        local tmp = vim.deepcopy(self.cs)
        self:add_right()
        if self.changed then
            self.ps = tmp
            self:animate_right()
        end
    end, opts)
    vim.keymap.set("n", "h", function()
        reset_destinations()
        local tmp = vim.deepcopy(self.cs)
        self:add_left()
        if self.changed then
            self.ps = tmp
            self:animate_left()
        end
    end, opts)
    vim.keymap.set("n", "u", function()
        self:undo()
    end, opts)
end

function M:create_autocmds()
    local autocmd = vim.api.nvim_create_autocmd
    local augroup = vim.api.nvim_create_augroup
    local grp = augroup("2048", {})

    autocmd("WinClosed", {
        group = grp,
        callback = function(ev)
            if tonumber(ev.match) == self.winnr then
                Data.save(self.cs, self.ps, self.board_height, self.board_width)
                vim.api.nvim_win_close(self.score_winnr, true)
                pcall(vim.api.nvim_del_augroup_by_id, grp)
            end
        end,
        desc = "Save the game state when closing the window",
    })
    autocmd("VimLeavePre", {
        group = grp,
        callback = function()
            Data.save(self.cs, self.ps, self.board_height, self.board_width)
        end,
        desc = "Save the game state when exiting Vim",
    })
end

function M:get_window_height()
    return self.board_height * (self._square_height + self._vertical_padding)
        + self._vertical_padding
end

function M:get_window_width()
    return self.board_width * (self._square_width + self._horizontal_padding)
        + self._horizontal_padding
end

function M:draw()
    self:update_score()
    if not self.did_undo and self.changed then
        self:spawn_2_or_4()
    end
    self.did_undo = false

    vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)
    local height = self:get_window_height()
    for i = 0, height - 1 do
        vim.api.nvim_buf_add_highlight(self.bufnr, self.ns_id, "2048_Background", i, 0, -1)
    end

    local current_row = self._vertical_padding
    local current_col = self._horizontal_padding

    for i = 1, self.board_height do
        local values = string.rep(" ", self._horizontal_padding, "")
        for j = 1, self.board_width do
            local val = tostring(self.cs.values[i][j])
            if val == "0" then
                val = ""
            end
            local inner_padding_left, inner_padding_right
            if (self._square_width - #val) % 2 == 1 then
                inner_padding_left = string.rep(" ", (self._square_width - #val - 1) / 2, "")
                inner_padding_right = string.rep(" ", (self._square_width - #val + 1) / 2, "")
            else
                inner_padding_left = string.rep(" ", (self._square_width - #val) / 2, "")
                inner_padding_right = inner_padding_left
            end
            values = values
                .. inner_padding_left
                .. val
                .. inner_padding_right
                .. string.rep(" ", self._horizontal_padding, "")
            vim.api.nvim_buf_set_lines(
                self.bufnr,
                current_row + math.floor(self._square_height / 2),
                current_row + math.floor(self._square_height / 2) + 1,
                false,
                { values }
            )
            -- nvim_buf_set_lines removes highlihting from that line
            vim.api.nvim_buf_add_highlight(
                self.bufnr,
                self.ns_id,
                "2048_Background",
                current_row + math.floor(self._square_height / 2),
                0,
                -1
            )
        end

        for j = 1, self.board_width do
            self:draw_square(current_col, current_row, i, j)
            current_col = current_col + self._square_width + self._horizontal_padding
        end
        current_col = self._horizontal_padding
        current_row = current_row + self._square_height + self._vertical_padding
    end

    if self:game_over() then
        return
    end
end

function M:spawn_2_or_4()
    local empty_squares = {}
    for i = 1, self.board_height do
        for j = 1, self.board_width do
            if self.cs.values[i][j] == 0 then
                table.insert(empty_squares, { i, j })
            end
        end
    end

    local selected_square = empty_squares[math.random(#empty_squares)]
    -- 10% chance for 4
    local two_or_four = 2
    if math.random() < 0.1 then
        two_or_four = 4
    end

    self.cs.values[selected_square[1]][selected_square[2]] = two_or_four
end

---draw square on the board
---@param x integer x coordinates of the top-left corner of the square
---@param y integer y coordinates of the top-left corner of the square
---@param i integer idx in the values table
---@param j integer idx in the values table
---@param _use_prev_state boolean? defaults to false
function M:draw_square(x, y, i, j, _use_prev_state)
    _use_prev_state = _use_prev_state or false
    local value
    if _use_prev_state then
        value = self.ps.values[i][j]
    else
        value = self.cs.values[i][j]
    end
    local hl_grp = "2048_Value" .. tostring(value)
    for k = 0, self._square_height - 1 do
        vim.api.nvim_buf_add_highlight(
            self.bufnr,
            self.ns_id,
            hl_grp,
            y + k,
            x,
            x + self._square_width
        )
    end
end

function M:add_down()
    self.changed = false
    for i = self.board_height, 2, -1 do
        for j = 1, self.board_width do
            local function first_empty_square()
                local empty_square = 0
                if self.cs.values[i][j] == 0 then
                    empty_square = i
                elseif self.cs.values[i - 1][j] == 0 then
                    empty_square = i - 1
                end
                return empty_square
            end
            local empty_square = first_empty_square()
            local non_empty_square = empty_square - 1
            while empty_square >= 1 and non_empty_square >= 1 do
                if self.cs.values[non_empty_square][j] ~= 0 then
                    self.cs.values[empty_square][j] = self.cs.values[non_empty_square][j]
                    self.cs.values[non_empty_square][j] = 0
                    self.destinations[non_empty_square][j] = { empty_square, j }
                    self.changed = true

                    empty_square = first_empty_square()
                end
                non_empty_square = non_empty_square - 1
            end

            if self.cs.values[i][j] ~= 0 and self.cs.values[i][j] == self.cs.values[i - 1][j] then
                self.cs.values[i][j] = self.cs.values[i][j] + self.cs.values[i - 1][j]
                self.cs.score = self.cs.score + self.cs.values[i][j]
                self.cs.high_score = math.max(self.cs.score, self.cs.high_score)
                self.cs.values[i - 1][j] = 0
                self.destinations[i - 1][j] = { i, j }
                self.changed = true
            end
        end
    end
end

function M:add_up()
    self.changed = false
    for i = 1, self.board_height - 1 do
        for j = 1, self.board_width do
            local function first_empty_square()
                local empty_square = self.board_height + 1
                if self.cs.values[i][j] == 0 then
                    empty_square = i
                elseif self.cs.values[i + 1][j] == 0 then
                    empty_square = i + 1
                end
                return empty_square
            end
            local empty_square = first_empty_square()
            local non_empty_square = empty_square + 1
            while empty_square <= self.board_height and non_empty_square <= self.board_height do
                if self.cs.values[non_empty_square][j] ~= 0 then
                    self.cs.values[empty_square][j] = self.cs.values[non_empty_square][j]
                    self.cs.values[non_empty_square][j] = 0
                    self.destinations[non_empty_square][j] = { empty_square, j }
                    self.changed = true

                    empty_square = first_empty_square()
                end
                non_empty_square = non_empty_square + 1
            end
            if self.cs.values[i][j] ~= 0 and self.cs.values[i][j] == self.cs.values[i + 1][j] then
                self.cs.values[i][j] = self.cs.values[i][j] + self.cs.values[i + 1][j]
                self.cs.score = self.cs.score + self.cs.values[i][j]
                self.cs.high_score = math.max(self.cs.score, self.cs.high_score)
                self.cs.values[i + 1][j] = 0
                self.destinations[i + 1][j] = { i, j }
                self.changed = true
            end
        end
    end
end

function M:add_right()
    self.changed = false
    for i = self.board_width, 2, -1 do
        for j = 1, self.board_height do
            local function first_empty_square()
                local empty_square = 0
                if self.cs.values[j][i] == 0 then
                    empty_square = i
                elseif self.cs.values[j][i - 1] == 0 then
                    empty_square = i - 1
                end
                return empty_square
            end
            local empty_square = first_empty_square()
            local non_empty_square = empty_square - 1
            while empty_square >= 1 and non_empty_square >= 1 do
                if self.cs.values[j][non_empty_square] ~= 0 then
                    self.cs.values[j][empty_square] = self.cs.values[j][non_empty_square]
                    self.cs.values[j][non_empty_square] = 0
                    self.destinations[j][non_empty_square] = { j, empty_square }
                    self.changed = true

                    empty_square = first_empty_square()
                end
                non_empty_square = non_empty_square - 1
            end

            if self.cs.values[j][i] ~= 0 and self.cs.values[j][i] == self.cs.values[j][i - 1] then
                self.cs.values[j][i] = self.cs.values[j][i] + self.cs.values[j][i - 1]
                self.cs.score = self.cs.score + self.cs.values[j][i]
                self.cs.high_score = math.max(self.cs.score, self.cs.high_score)
                self.cs.values[j][i - 1] = 0
                self.destinations[j][i - 1] = { j, i }
                self.changed = true
            end
        end
    end
end

function M:add_left()
    self.changed = false
    for i = 1, self.board_width - 1 do
        for j = 1, self.board_height do
            local function first_empty_square()
                local empty_square = self.board_width + 1
                if self.cs.values[j][i] == 0 then
                    empty_square = i
                elseif self.cs.values[j][i + 1] == 0 then
                    empty_square = i + 1
                end
                return empty_square
            end
            local empty_square = first_empty_square()
            local non_empty_square = empty_square + 1
            while empty_square <= self.board_width and non_empty_square <= self.board_width do
                if self.cs.values[j][non_empty_square] ~= 0 then
                    self.cs.values[j][empty_square] = self.cs.values[j][non_empty_square]
                    self.cs.values[j][non_empty_square] = 0
                    self.destinations[j][non_empty_square] = { j, empty_square }
                    self.changed = true

                    empty_square = first_empty_square()
                end
                non_empty_square = non_empty_square + 1
            end
            if self.cs.values[j][i] ~= 0 and self.cs.values[j][i] == self.cs.values[j][i + 1] then
                self.cs.values[j][i] = self.cs.values[j][i] + self.cs.values[j][i + 1]
                self.cs.score = self.cs.score + self.cs.values[j][i]
                self.cs.high_score = math.max(self.cs.score, self.cs.high_score)
                self.cs.values[j][i + 1] = 0
                self.destinations[j][i + 1] = { j, i }
                self.changed = true
            end
        end
    end
end

function M:undo()
    self.cs = vim.deepcopy(self.ps)
    self.did_undo = true
    self:draw()
end

---@return boolean
function M:game_over()
    local function is_full()
        for i = 1, self.board_height do
            for j = 1, self.board_width do
                if self.cs.values[i][j] == 0 then
                    return false
                end
            end
        end
        return true
    end

    if not is_full() then
        return false
    end

    -- test if any move is possible
    for i = 1, self.board_height do
        for j = 1, self.board_width do
            if i < self.board_height and self.cs.values[i][j] == self.cs.values[i + 1][j] then
                return false
            end
            if i > 1 and self.cs.values[i][j] == self.cs.values[i - 1][j] then
                return false
            end
            if j < self.board_width and self.cs.values[i][j] == self.cs.values[i][j + 1] then
                return false
            end
            if j > 1 and self.cs.values[i][j] == self.cs.values[i][j - 1] then
                return false
            end
        end
    end

    -- move is not possible, game over
    local msg = string.format("Game over! Your score is %d.", self.cs.score)
    local half_sep = string.rep(" ", math.floor((self:get_window_width() - #msg) / 2), "")
    vim.api.nvim_buf_set_lines(
        self.score_bufnr,
        0,
        1,
        false,
        { string.format("%s%s%s", half_sep, msg, half_sep) }
    )

    return true
end

---remove the square trail when moving squares from top to bottom
---@param x integer x coordinates of the top-left corner of the square
---@param y integer y coordinates of the top-left corner of the square
---@param len integer distance travelled
function M:remove_square_trail_down(x, y, len)
    local background_line = self._square_height + self._vertical_padding
    for k = y - len, y - 1 do
        vim.api.nvim_buf_set_text(
            self.bufnr,
            k,
            x,
            k,
            x + self._square_width,
            { string.rep(" ", self._square_width, "") }
        )
        local hl_grp
        if k % background_line < self._vertical_padding then
            hl_grp = "2048_Background"
        else
            hl_grp = "2048_Value0"
        end
        vim.api.nvim_buf_add_highlight(self.bufnr, self.ns_id, hl_grp, k, x, x + self._square_width)
    end
end

---remove the square trail when moving squares from bottom to top
---@param x integer x coordinates of the bottom-left corner of the square
---@param y integer y coordinates of the bottom-left corner of the square
---@param len integer distance travelled
function M:remove_square_trail_up(x, y, len)
    local background_line = self._square_height + self._vertical_padding
    for k = y + len, y + 1, -1 do
        vim.api.nvim_buf_set_text(
            self.bufnr,
            k,
            x,
            k,
            x + self._square_width,
            { string.rep(" ", self._square_width, "") }
        )
        local hl_grp
        if k % background_line < self._vertical_padding then
            hl_grp = "2048_Background"
        else
            hl_grp = "2048_Value0"
        end
        vim.api.nvim_buf_add_highlight(self.bufnr, self.ns_id, hl_grp, k, x, x + self._square_width)
    end
end

---remove the square trail when moving squares from left to right
---@param x integer x coordinates of the top-left corner of the square
---@param y integer y coordinates of the top-left corner of the square
---@param len integer distance travelled
function M:remove_square_trail_right(x, y, len)
    local background_line = self._square_width + self._horizontal_padding
    for i = y, y + self._square_height - 1 do
        for k = x - len, x - 1 do
            vim.api.nvim_buf_set_text(self.bufnr, i, k, i, k + 1, { " " })
            local hl_grp
            if k % background_line < self._horizontal_padding then
                hl_grp = "2048_Background"
            else
                hl_grp = "2048_Value0"
            end
            vim.api.nvim_buf_add_highlight(self.bufnr, self.ns_id, hl_grp, i, k, k + 1)
        end
    end
end

---remove the square trail when moving squares from right to left
---@param x integer x coordinates of the top-right corner of the square
---@param y integer y coordinates of the top-right corner of the square
---@param len integer distance travelled
function M:remove_square_trail_left(x, y, len)
    local background_line = self._square_width + self._horizontal_padding
    for i = y, y + self._square_height - 1 do
        for k = x + len, x + 1, -1 do
            vim.api.nvim_buf_set_text(self.bufnr, i, k, i, k + 1, { " " })
            local hl_grp
            if k % background_line < self._horizontal_padding then
                hl_grp = "2048_Background"
            else
                hl_grp = "2048_Value0"
            end
            vim.api.nvim_buf_add_highlight(self.bufnr, self.ns_id, hl_grp, i, k, k + 1)
        end
    end
end

function M:animate_down()
    -- distance each square has to travel
    local diffs = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local dest = self.destinations[i][j]
            -- left-right diff is irrelevant
            local diff = math.abs(i - dest[1])
            table.insert(tmp, diff)
        end
        table.insert(diffs, tmp)
    end

    -- coordinates of the top-left corner of each square
    local coords = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local x = self._horizontal_padding
                + (j - 1) * (self._square_width + self._horizontal_padding)
            local y = self._vertical_padding
                + (i - 1) * (self._square_height + self._vertical_padding)
            table.insert(tmp, { x, y })
        end
        table.insert(coords, tmp)
    end

    local timer = (vim.uv or vim.loop).new_timer()
    local steps = self._square_height + self._vertical_padding
    timer:start(
        0,
        self._up_down_animation_interval,
        vim.schedule_wrap(function()
            if steps == 0 then
                timer:stop()
                self:draw()
                return
            end
            -- some squares need to move less than others, so we need to speed them up so they all finish moving at the same time
            for i = 1, self.board_height do
                for j = 1, self.board_width do
                    if self.ps.values[i][j] ~= 0 and diffs[i][j] ~= 0 then
                        coords[i][j][2] = coords[i][j][2] + diffs[i][j]
                        local x, y = coords[i][j][1], coords[i][j][2]
                        self:draw_square(x, y, i, j, true)
                        self:remove_square_trail_down(x, y, diffs[i][j])
                    end
                end
            end
            steps = steps - 1
        end)
    )
end

function M:animate_up()
    -- distance each square has to travel
    local diffs = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local dest = self.destinations[i][j]
            -- left-right diff is irrelevant
            local diff = math.abs(i - dest[1])
            table.insert(tmp, diff)
        end
        table.insert(diffs, tmp)
    end

    -- coordinates of the bottom-left corner of each square
    local coords = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local x = self._horizontal_padding
                + (j - 1) * (self._square_width + self._horizontal_padding)
            local y = i * (self._square_height + self._vertical_padding)
            table.insert(tmp, { x, y })
        end
        table.insert(coords, tmp)
    end

    local timer = (vim.uv or vim.loop).new_timer()
    local steps = self._square_height + self._vertical_padding
    timer:start(
        0,
        self._up_down_animation_interval,
        vim.schedule_wrap(function()
            if steps == 0 then
                timer:stop()
                self:draw()
                return
            end
            -- some squares need to move less than others, so we need to speed them up so they all finish moving at the same time
            for i = 1, self.board_height do
                for j = 1, self.board_width do
                    if self.ps.values[i][j] ~= 0 and diffs[i][j] ~= 0 then
                        coords[i][j][2] = coords[i][j][2] - diffs[i][j]
                        local x, y = coords[i][j][1], coords[i][j][2]
                        self:draw_square(x, y - self._square_height + 1, i, j, true)
                        self:remove_square_trail_up(x, y, diffs[i][j])
                    end
                end
            end
            steps = steps - 1
        end)
    )
end

function M:animate_right()
    -- distance each square has to travel
    local diffs = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local dest = self.destinations[i][j]
            -- up-down diff is irrelevant
            local diff = math.abs(j - dest[2])
            table.insert(tmp, diff)
        end
        table.insert(diffs, tmp)
    end

    -- coordinates of the top-left corner of each square
    local coords = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local x = self._horizontal_padding
                + (j - 1) * (self._square_width + self._horizontal_padding)
            local y = self._vertical_padding
                + (i - 1) * (self._square_height + self._vertical_padding)
            table.insert(tmp, { x, y })
        end
        table.insert(coords, tmp)
    end

    local timer = (vim.uv or vim.loop).new_timer()
    local steps = self._square_width + self._horizontal_padding
    timer:start(
        0,
        self._left_right_animation_interval,
        vim.schedule_wrap(function()
            if steps == 0 then
                timer:stop()
                self:draw()
                return
            end
            -- some squares need to move less than others, so we need to speed them up so they all finish moving at the same time
            for i = 1, self.board_height do
                for j = 1, self.board_width do
                    if self.ps.values[i][j] ~= 0 and diffs[i][j] ~= 0 then
                        coords[i][j][1] = coords[i][j][1] + diffs[i][j]
                        local x, y = coords[i][j][1], coords[i][j][2]
                        self:draw_square(x, y, i, j, true)
                        self:remove_square_trail_right(x, y, diffs[i][j])
                    end
                end
            end
            steps = steps - 1
        end)
    )
end

function M:animate_left()
    -- distance each square has to travel
    local diffs = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local dest = self.destinations[i][j]
            -- up-down diff is irrelevant
            local diff = math.abs(j - dest[2])
            table.insert(tmp, diff)
        end
        table.insert(diffs, tmp)
    end

    -- coordinates of the top-right corner of each square
    local coords = {}
    for i = 1, self.board_height do
        local tmp = {}
        for j = 1, self.board_width do
            local x = j * (self._square_width + self._horizontal_padding)
            local y = self._vertical_padding
                + (i - 1) * (self._square_height + self._vertical_padding)
            table.insert(tmp, { x, y })
        end
        table.insert(coords, tmp)
    end

    local timer = (vim.uv or vim.loop).new_timer()
    local steps = self._square_width + self._horizontal_padding
    timer:start(
        0,
        self._left_right_animation_interval,
        vim.schedule_wrap(function()
            if steps == 0 then
                timer:stop()
                self:draw()
                return
            end
            -- some squares need to move less than others, so we need to speed them up so they all finish moving at the same time
            for i = 1, self.board_height do
                for j = 1, self.board_width do
                    if self.ps.values[i][j] ~= 0 and diffs[i][j] ~= 0 then
                        coords[i][j][1] = coords[i][j][1] - diffs[i][j]
                        local x, y = coords[i][j][1], coords[i][j][2]
                        self:draw_square(x - self._square_width + 1, y, i, j, true)
                        self:remove_square_trail_left(x, y, diffs[i][j])
                    end
                end
            end
            steps = steps - 1
        end)
    )
end
return M
