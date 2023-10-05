LUA_VERSION := 5.4.6
LUAPOSIX_VERSION := 36.2.1

build/lua-$(LUA_VERSION)/:
	mkdir -p build/
	curl -fsSL "https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz" | tar -C build/ -xvzf -

build/luaposix-$(LUAPOSIX_VERSION)/:
	mkdir -p build/
	curl -fsSL "https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz" | tar -C build/ -xvzf -

build/lua-$(LUA_VERSION)/%.a: | build/lua-$(LUA_VERSION)/
	$(MAKE) -C build/lua-$(LUA_VERSION)/ posix

build/luaposix-$(LUAPOSIX_VERSION)/%.o: | build/luaposix-$(LUAPOSIX_VERSION)/ build/lua-$(LUA_VERSION)/src/liblua.a
	$(CC) -c $(patsubst %.o,%.c,$@) -fPIC \
	  -DPACKAGE='"luaposix"' -DVERSION='"luawk"' \
	  -I build/lua-$(LUA_VERSION)/src \
	  -I build/luaposix-$(LUAPOSIX_VERSION)/ext/include \
	  -o $@

.PHONY: all
all: build/luaposix-$(LUAPOSIX_VERSION)/ext/posix/unistd.o
