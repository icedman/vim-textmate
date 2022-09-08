# vim-textmate
A textmate-based syntax highlighter to vim, compatible with VScode themes and grammars

# install

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

# grammars and themes

Copy grammar packages from vscode to the following directories:

```sh
~/.editor/extensions/
~/.vim/lua/vim-textmate/extensions/
```

# commands

* TxmtInfo
* TxmtInfoLanguages
* TxmtInfoThemes
* TxmtSetTheme
* TxmtEnable
* TxmtDisable
* TxmtDebugScopes

# warning

* This plugin is just a proof of concept - from a novice lua coder, and much worse - from a novice vim user
* This also requires Lua and some C compilation
