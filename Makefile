LDOC := ldoc
LUACOV := luacov
PROVE := prove

LUA_VERSION := 5.4.6
LUA := build/lua-$(LUA_VERSION)
LUAINC := $(LUA)/src
LUALIB := $(LUA)/src
LUABIN := $(LUA)/src

LUAPOSIX_VERSION := 36.2.1
LUAPOSIX := build/luaposix-$(LUAPOSIX_VERSION)
LUAPOSIXINC := $(LUAPOSIX)/ext/include
LUAPOSIX_CFLAGS := -fPIC -Wall
LUAPOSIX_CFLAGS += -DPACKAGE='"luaposix"'
LUAPOSIX_CFLAGS += -DVERSION='"luawk"'
LUAPOSIX_CFLAGS += -I$(LUAINC)
LUAPOSIX_CFLAGS += -I$(LUAPOSIXINC)

tmp/lua-%: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix-%: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/ doc/ tmp/:
	mkdir -p "$@"

tmp/%: | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/%: tmp/%.tar.gz | build/
	tar -C build/ -xzf "$<" -- "$(patsubst build/%,%,$@)"
	find "$@" -exec touch {} \;

build/lua-$(LUA_VERSION)/%: | build/lua-$(LUA_VERSION)
	$(MAKE) -C build/lua-$(LUA_VERSION)/ posix

build/luaposix-%.o: build/luaposix-%.c | build/luaposix-$(LUAPOSIX_VERSION)/
	$(CC) -c "$<" $(LUAPOSIX_CFLAGS) -o "$@"

build/luawk: | $(LUALIB)/liblua.a $(LUABIN)/lua $(LUAPOSIX)/ext/posix/unistd.o
	$(LUABIN)/lua utils/luastatic/luastatic.lua

.PHONY: all clean clean-all doc test

clean:
	rm -rf -- build/ doc/

clean-all: clean
	rm -rf -- tmp/

test: build/luawk
	$(PROVE)

doc: | doc/
	mkdir -p doc/examples doc/test
	cd doc/examples && ../../utils/locco/locco.lua ../../examples/*.luawk ../../examples/*/*.luawk
	$(LDOC) .
	$(LUACOV)

all: test doc
