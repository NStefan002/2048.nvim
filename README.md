# 2048

> Implementation of the `2048` game for Neovim.

## 📺 Showcase

![2048_showcase](https://github.com/NStefan002/2048.nvim/assets/100767853/03f72082-71e2-400a-b25b-659cbc29b14c)

https://github.com/NStefan002/2048.nvim/assets/100767853/b53c7947-c457-4b5f-814c-f07416ac182d

## 📋 Installation

[lazy](https://github.com/folke/lazy.nvim):

```lua
{
    "NStefan002/2048.nvim",
    cmd = "Play2048",
    config = true,
}
```

[packer](https://github.com/wbthomason/packer.nvim):

```lua
use({
    "NStefan002/2048.nvim",
    config = function()
        require("2048").setup()
    end,
})
```

[rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim)

`:Rocks install 2048.nvim`

## ❓ How to Play

1. `:Play2048`
2. Use the `h`, `j`, `k`, `l` to move the squares in the desired direction.
3. Squares with the same number will merge when they collide, doubling their value.
4. The goal is to create a tile with the number 2048.
5. Continue playing and try to achieve the highest score possible.
6. The game will automatically save your progress, so you can continue to play it whenever you want

## 🎮 Controls

-   `h` - move the squares to the left
-   `j` - move the squares down
-   `k` - move the squares up
-   `l` - move the squares to the right
-   `u` - undo the last move
-   `r` - restart the game
-   `n` - new game (select the board size)
-   `<CR>` - confirm in menus
-   `<Esc>` - cancel in menus

**NOTE:**

<details>
    <summary>You can change the default mappings.</summary>


```lua
require("2048").setup({
    keys = {
        up = "<Up>",
        down = "<Down>",
        left = "<Left>",
        right = "<Right>",
        undo = "<C-z>",
        restart = "R",
        new_game = "N",
        confirm = "y",
        cancel = "n",
    },
})
```
</details>
