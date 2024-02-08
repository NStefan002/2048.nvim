# 2048

> Implementation of the `2048` game for Neovim.

## 📋 Installation

[lazy](https://github.com/folke/lazy.nvim):

```lua
{
    "NStefan002/2048.nvim",
    cmd = "Play2048",
    opts = {
    -- your config
    }
}
```

[packer](https://github.com/wbthomason/packer.nvim):

```lua
use({
    "NStefan002/2048.nvim",
    config = function()
        require("2048").setup({
            -- your config
        })
    end,
})
```

## ❓ How to Play

1. `:Play2048`
2. Use the `h`, `j`, `k`, `l` to move the squares in the desired direction.
3. Squares with the same number will merge when they collide, doubling their value.
4. The goal is to create a tile with the number 2048.
5. Continue playing and try to achieve the highest score possible.

## 🎮 Controls

-   `h` - move the squares to the left
-   `j` - move the squares down
-   `k` - move the squares up
-   `l` - move the squares to the right
-   `u` - undo the last move
-   `r` - restart (new game)
