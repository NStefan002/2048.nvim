local Highlights = {}

function Highlights.setup()
    local ns_id = vim.api.nvim_create_namespace("2048")
    vim.api.nvim_set_hl(ns_id, "2048_Value0", { fg = "#000000", bg = "#cdc1b4", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value2", { fg = "#000000", bg = "#eee4da", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value4", { fg = "#000000", bg = "#eddcc8", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value8", { fg = "#ffffff", bg = "#f2b179", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value16", { fg = "#ffffff", bg = "#f59563", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value32", { fg = "#ffffff", bg = "#f67c5f", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value64", { fg = "#ffffff", bg = "#f65e3b", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value128", { fg = "#ffffff", bg = "#edcf72", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value256", { fg = "#ffffff", bg = "#edcc61", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value512", { fg = "#ffffff", bg = "#edc850", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value1024", { fg = "#ffffff", bg = "#edc53f", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value2048", { fg = "#ffffff", bg = "#edc22e", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value4096", { fg = "#ffffff", bg = "#000000", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value8192", { fg = "#ffffff", bg = "#000000", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value16384", { fg = "#ffffff", bg = "#000000", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value32768", { fg = "#ffffff", bg = "#000000", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value65536", { fg = "#ffffff", bg = "#000000", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Value131072", { fg = "#ffffff", bg = "#000000", bold = true })
    vim.api.nvim_set_hl(ns_id, "2048_Background", { fg = "#aa9c8f", bg = "#aa9c8f", bold = true })
end

return Highlights
