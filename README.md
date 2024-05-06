<br/>
<p align="center">
  <h3 align="center">vim-textmate</h3>

  <p align="center">
A textmate-based syntax highlighter to vim, compatible with VScode themes and grammars
    <br/>
    <br/>
  </p>
</p>

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/icedman)

# Install

```sh
git clone http://github.com/icedman/vim-textmate
cd vim-textmate
make
```
*.vimrc*

```sh
luafile ~/.vim/lua/vim-textmate/vim-textmate.lua
```

To preset a theme
```sh
lua txmt_set_theme("Dracula")
```
# via Plugged

Add to your .vimrc:

```sh
Plug 'icedman/vim-textmate'
```

And also:

```sh
luafile ~/.vim/plugged/vim-textmate/vim-textmate.lua
```

# Themes and Grammars 

 Theme and grammar packages will be searched in the following locations:

```sh
~/.vim/lua/vim-textmate/extensions/
~/.vscode/extensions/
~/.editor/extensions/
```

# Commands

* TxmtInfo
* TxmtInfoLanguages
* TxmtInfoThemes
* TxmtSetTheme
* TxmtEnable
* TxmtDisable
* TxmtDebugScopes

## Warning

* This plugin is just a proof of concept - from a novice lua coder, and much worse - from a novice vim user
* This also requires Lua and some C compilation
