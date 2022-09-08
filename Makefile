all: prebuild build install

.PHONY: prebuild build install

prebuild:
	cd libs/Onigmo && ./autogen.sh && ./configure

build:
	mkdir -p build
	cd build && cmake ../ && make
	cp build/textmate.so ./

install:
	mkdir -p ~/.vim/lua/vim-textmate
	cp -R ./textmate.so ~/.vim/lua/vim-textmate
	cp -R ./vim-textmate.lua ~/.vim/lua/vim-textmate

uninstall:
	rm -R ~/.vim/lua/vim-textmate*
	rm ~/.vim/lua/textmate.*

clean:
	rm -rf build

