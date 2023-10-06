PROVE := prove

LUAPOSIX_VERSION := 36.2.1

LUA_VERSION := 5.4.6
LUA := build/lua-$(LUA_VERSION)

LUAINC := $(LUA)/src
LUALIB := $(LUA)/src
LUABIN := $(LUA)/src

# TODO download archives to tmp/, add clean-all to clear dl-cache too

build/:
	mkdir -p build/

build/lua-$(LUA_VERSION)/: | build/
	curl -fsSL "https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz" | tar -C build/ -xzf -

build/luaposix-$(LUAPOSIX_VERSION)/: | build/ build/lua-$(LUA_VERSION)/
	curl -fsSL "https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz" | tar -C build/ -xzf -

build/lua-$(LUA_VERSION)/%: | build/lua-$(LUA_VERSION)/
	$(MAKE) -C build/lua-$(LUA_VERSION)/ posix

build/luaposix-$(LUAPOSIX_VERSION)/%.o: | build/luaposix-$(LUAPOSIX_VERSION)/
	$(CC) -c $(patsubst %.o,%.c,$@) -fPIC \
	  -DPACKAGE='"luaposix"' -DVERSION='"luawk"' \
	  -I build/lua-$(LUA_VERSION)/src \
	  -I build/luaposix-$(LUAPOSIX_VERSION)/ext/include \
	  -o $@

build/luawk: | $(LUALIB)/liblua.a $(LUABIN)/lua build/luaposix-$(LUAPOSIX_VERSION)/ext/posix/unistd.o
	$(LUABIN)/lua utils/luastatic/luastatic.lua

.PHONY: all clean doc test

clean:
	rm -rf -- build/ doc/

test: build/luawk
	# luarocks install --local luacov
	# luarocks install --local luacov-multiple
	$(PROVE)

doc:
	rm -rf -- doc/
	mkdir -p doc/
	ldoc .
	mkdir -p doc/examples
	cd doc/examples && ../../utils/locco/locco.lua ../../examples/**/*.luawk
	mkdir -p doc/test
	luacov

all: test doc
