PROVE := prove

LUA_VERSION := 5.4.6
LUAPOSIX_VERSION := 36.2.1

build/:
	mkdir -p build/

build/lua-$(LUA_VERSION)/: | build/
	curl -fsSL "https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz" | tar -C build/ -xzf -

build/luaposix-$(LUAPOSIX_VERSION)/: | build/ build/lua-$(LUA_VERSION)/
	curl -fsSL "https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz" | tar -C build/ -xzf -

build/lua-$(LUA_VERSION)/%.a: | build/lua-$(LUA_VERSION)/
	$(MAKE) -C build/lua-$(LUA_VERSION)/ posix

build/luaposix-$(LUAPOSIX_VERSION)/%.o: | build/luaposix-$(LUAPOSIX_VERSION)/
	$(CC) -c $(patsubst %.o,%.c,$@) -fPIC \
	  -DPACKAGE='"luaposix"' -DVERSION='"luawk"' \
	  -I build/lua-$(LUA_VERSION)/src \
	  -I build/luaposix-$(LUAPOSIX_VERSION)/ext/include \
	  -o $@

.PHONY: all clean doc test

clean:
	rm -rf -- build/

test:
	# luarocks install --local luacov
	# luarocks install --local luacov-multiple
	$(PROVE)

doc:
	mkdir -p doc/
	rm -rf -- doc/*
	ldoc .
	mkdir -p doc/examples
	cd doc/examples && ../../utils/locco/locco.lua ../../examples/**/*.luawk
	mkdir -p doc/test
	luacov

all: build/luaposix-$(LUAPOSIX_VERSION)/ext/posix/unistd.o
