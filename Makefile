LDOC := ldoc
LUACOV := luacov
PROVE := prove

# luarocks environment
# For building:
#     CFLAGS - flags for the C compiler
#     LIBFLAG - the flags needed for the linker to create shared libraries
#     LUA_LIBDIR - where to find the lua libraries
#     LUA_BINDIR - where to find the lua binary
#     LUA_INCDIR - where to find the lua headers
#     LUALIB - the name of the lua library. This is not available nor needed on all platforms.
#     LUA - the name of the lua interpreter
# For installing:
#     PREFIX - basic installation prefix for the module
#     BINDIR - where to put user callable programs or scripts
#     LIBDIR - where to put the shared libraries
#     LUADIR - where to put the lua files
#     CONFDIR - where to put your modules configuration


LUA_VERSION := 5.4.6
LUA := build/lua
LUAINC := $(LUA)/src
LUALIB := $(LUA)/src
LUABIN := $(LUA)/src

LUAPOSIX_VERSION := 36.2.1
LUAPOSIX := build/luaposix

LUAWK_CFLAGS := -Wall -fPIC -I$(LUAINC)
LUAWK_LDFLAGS := -rdynamic -lm -ldl

PLATFORM := $(if $(findstring $(shell uname -s),Linux),linux,posix)
PACKAGES := luaposix

VPATH := src build/root

$(info $(VPATH))

.NOTINTERMEDIATE:

tmp/lua.tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix.tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/lua: tmp/lua.tar.gz
build/luaposix: tmp/luaposix.tar.gz

build/ doc/ tmp/:
	mkdir -p "$@"

tmp/lua.tar.gz $(patsubst %,tmp/%.tar.gz,$(PACKAGES)): | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/lua $(patsubst %,build/%,$(PACKAGES)): | build/
	tar -C build/ -xzf "$<"
	cd build/ && ln -s $(notdir $@)-* $(notdir $@)
	find "$@" -exec touch {} \;

build/lua/%: | lua; test -f $@

build/%/Makefile: | $(LUABIN)/lua build/%
	LUA_PATH="$(wildcard $(dir $@)/*.rockspec)" \
	$(LUABIN)/lua >$@ -l? -e "\
	  function P(...) print(string.format(...)) end \
	  function E(str) return str:gsub('%\n', '$$\\\n') end \
	  P('.PHONY: all install\nall:;%s\ninstall:;%s', \
	    E(build.build_command or 'make all'),\
		E(build.install_command or 'make install'))"

.PHONY: lua $(PACKAGES)

luaposix: | build/luaposix build/luaposix/Makefile

lua: | build/lua build/lua/Makefile
	$(MAKE) -C build/lua $(PLATFORM)

$(PACKAGES): | $(LUABIN)/lua
	set -e; \
	mkdir -p build/pkg; \
	export CFLAGS="$(CFLAGS) -fPIC"; \
	export LIBFLAG="-c";\
	export LUA="$(abspath $(LUABIN)/lua)"; \
	export LUALIB="$(abspath $(LUALIB)/liblua.a)"; \
	export LUA_LIBDIR="$(abspath $(LUALIB))"; \
	export LUA_BINDIR="$(abspath $(LUABIN))"; \
	export LUA_INCDIR="$(abspath $(LUAINC))"; \
	export PREFIX="../pkg"; \
	export BINDIR="../pkg"; \
	export LIBDIR="../pkg"; \
	export LUADIR="../pkg"; \
	export CONFDIR="../pkg"; \
	export LIB_EXTENSION="so"; \
	export OBJ_EXTENSION="o"; \
	$(MAKE) -C build/$@ -f Makefile all; \
	$(MAKE) -C build/$@ -f Makefile install

build/%.luab: %.lua | $(LUABIN)/luac
	@mkdir -p $(dir $@)
	$(LUABIN)/luac -o $@ $<

# luawk: src/luawk.c $(LUALIB)/liblua.a $(patsubst %.c,%.o,$(wildcard $(LUAPOSIX)/ext/posix/*.c))
# 	$(CC) $^ $(LUAWK_CFLAGS) -o $@ $(LUAWK_LDFLAGS)

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
