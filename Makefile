LDOC := ldoc
LUACOV := luacov
PROVE := prove

LUA_VERSION := 5.4.6
LUA := build/lua
LUAINC := $(LUA)/src
LUALIB := $(LUA)/src
LUABIN := $(LUA)/src

LUAPOSIX_VERSION := 36.2.1
LUAPOSIX := build/luaposix

LUAPOSIX_CFLAGS := -fPIC
LUAPOSIX_CFLAGS += -DPACKAGE='"luaposix"'
LUAPOSIX_CFLAGS += -DVERSION='"luawk"'
LUAPOSIX_CFLAGS += -I$(LUAINC)
LUAPOSIX_CFLAGS += -I$(LUAPOSIX)/ext/include

.NOTINTERMEDIATE:

tmp/lua.tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix.tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/ doc/ tmp/:
	mkdir -p "$@"

tmp/%: | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/%: tmp/%.tar.gz | build/
	tar -C build/ -xzf "$<"
	cd build/ && ln -s $(notdir $@)-* $(notdir $@)
	find "$@" -exec touch {} \;

build/lua/%: | build/lua
	$(MAKE) -C build/lua posix

build/luaposix/%: build/luaposix; @: # no-op

build/luaposix/%.o: build/luaposix/%.c
	$(CC) -c "$<" $(LUAPOSIX_CFLAGS) -o "$@"

build/luawk: $(LUALIB)/liblua.a $(LUABIN)/lua $(LUAPOSIX)/ext/posix/unistd.o
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
