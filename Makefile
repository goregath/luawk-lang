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

CFLAGS := -Wall -fPIC -I$(LUAINC)
LDFLAGS := -rdynamic -lm -ldl

PACKAGES := lua luaposix

.NOTINTERMEDIATE:

tmp/lua.tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix.tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/lua: tmp/lua.tar.gz
build/luaposix: tmp/luaposix.tar.gz

build/ doc/ tmp/:
	mkdir -p "$@"

$(patsubst %,tmp/%.tar.gz,$(PACKAGES)): | tmp/
	curl -fsSL "$(URL)" -o "$@"

$(patsubst %,build/%,$(PACKAGES)): | build/
	tar -C build/ -xzf "$<"
	cd build/ && ln -s $(notdir $@)-* $(notdir $@)
	find "$@" -exec touch {} \;

build/lua/%: | build/lua
	$(MAKE) -C build/lua $(if $(findstring $(shell uname -s),Linux),linux,posix)

build/%/Makefile: | $(LUABIN)/lua build/%
	LUA_PATH="$(wildcard $(dir $@)/*.rockspec)" $(LUABIN)/lua >$@ -l? -e "\
		function P(...) print(string.format(...)) end \
		function E(str) return str:gsub('%\n', '$$\\\n') end \
		P('.PHONY: all install\nall:;%s\ninstall:;%s', E(build.build_command), E(build.install_command))"

build/%.luab: src/%.lua | $(LUABIN)/luac
	@mkdir -p $(dir $@)
	$(LUABIN)/luac -o $@ $<

# luawk: src/luawk.c $(LUALIB)/liblua.a $(patsubst %.c,%.o,$(wildcard $(LUAPOSIX)/ext/posix/*.c))
# 	$(CC) $^ $(CFLAGS) -o $@ $(LDFLAGS)

.PHONY: all clean clean-all doc test
.NOTPARALLEL:

clean:
	rm -rf -- build/ doc/

clean-all: clean
	rm -rf -- tmp/

test:
	$(PROVE)

doc: | doc/
	mkdir -p doc/examples doc/test
	cd doc/examples && ../../utils/locco/locco.lua ../../examples/*.luawk ../../examples/*/*.luawk
	$(LDOC) .
	$(LUACOV)

all: luawk test doc
