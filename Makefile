# LUAWK Makefile

space := $(subst ,, )
modlocate = $(sort $(subst /,.,$(patsubst %/init,%,$(patsubst $(1)%.lua,%,$(shell find $(1) -name '*.$(2)')))))
bldpkg = $(patsubst build/%/,%,$@)

PROGRAM := luawk
PLATFORM := $(if $(findstring $(shell uname -s),Linux),linux,posix)

LDOC := ldoc
LUA := lua
LUACOV := luacov
PROVE := prove

LUA_VERSION := 5.4.6
LUAPOSIX_VERSION := 36.2.1

LUABIN := build/lua/src
LUAINC := build/lua/src
LUALIB := build/lua/src

CFLAGS := -fPIC
LDFLAGS := -rdynamic -lm -ldl

MOD_PATH := src/?.lua
MOD_PATH += src/?/init.lua

MODULES := $(call modlocate,src/,lua)
MODULES += posix.stdlib
MODULES += posix.unistd

.SHELLFLAGS := -ec

.PHONY: all clean clean-all doc test

.ONESHELL:
.NOTINTERMEDIATE:

tmp/lua-$(LUA_VERSION).tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/lua/: tmp/lua-$(LUA_VERSION).tar.gz
build/luaposix/: tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz

%/:
	mkdir -p "$@"

tmp/%.tar.gz: | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/lua/ build/luaposix/: | build/
	tar -C build/ -xzf "$<"
	cd build/
	ln -s $(bldpkg)-* $(bldpkg)
	find $(bldpkg) -exec touch {} \;

build/lua/Makefile build/lua/src/: | build/lua/; @stat $@ >/dev/null 

build/lua/src/liblua.a build/lua/src/lua build/lua/src/luac: build/lua/Makefile
	$(MAKE) -C build/lua $(PLATFORM)
	stat $@ >/dev/null 

build/luaposix/lib/%.lua: | build/luaposix/; @stat $@ >/dev/null 
build/luaposix/ext/%.c:   | build/luaposix/; @stat $@ >/dev/null 

build/luaposix/%.o: CFLAGS += -Ibuild/luaposix/ext/include
build/luaposix/%.o: CFLAGS += -DPACKAGE='"luaposix"'
build/luaposix/%.o: CFLAGS += -DVERSION='"$(LUAPOSIX_VERSION)"'
build/luaposix/%.o: CFLAGS += -D_POSIX_C_SOURCE=200809L
build/luaposix/%.o: CFLAGS += -D_XOPEN_SOURCE=700
ifeq ($(PLATFORM),linux)
build/luaposix/%.o: CFLAGS += -D_BSD_SOURCE=1
build/luaposix/%.o: CFLAGS += -D_DEFAULT_SOURCE=1
endif

build/%.o: CFLAGS += -I$(LUAINC)
build/%.o: build/%.c | $(LUAINC)/
	$(CC) -c $^ $(CFLAGS) -o $@

# build/shell.lua: | $(LUABIN)/lua
# 	echo '#!$(abspath $(LUABIN)/lua)' > $@
# 	echo 'print(assert(assert((loadstring or load)(arg[2]:gsub("\\\n", "\n")))()))' >> $@
# 	chmod +x $@

# build/lua/%: | lua; test -f $@

# .PHONY: modlocate
# modlocate: private SHELL := build/shell.lua
# modlocate: | build/shell.lua
# 	file = ('posix.unistd'):gsub("%.", "/")
# 	for tmpl in ('$(MOD_PATH)'):gmatch("%S+") do
# 		path = tmpl:gsub("?", file)
# 		if io.open(path, "r") then return path end
# 	end

# build/%/Makefile: private SHELL := build/shell.lua
# build/%/Makefile: | build/shell.lua build/%
# 	loadfile "$(wildcard $(dir $@)/*.rockspec)" () \
# 	function P(...) io.open("$@", "w"):write(string.format(...)):close() end \
# 	function E(str) return str:gsub('%\n', '$$\\\n') end \
# 	assert(build.type == 'command') \
# 	P('.PHONY: all install\nall:;%s\ninstall:;%s', \
# 	  E(build.build_command or 'make all'),\
# 	  E(build.install_command or 'make install'))
# 
# build/lua/src/lua build/lua/src/luac: | lua
# 
# lua: | build/lua
# 	$(MAKE) -C build/lua $(PLATFORM)
# 
# luaposix: export CFLAGS := $(CFLAGS) -fPIC
# luaposix: export LIB_EXTENSION := so
# luaposix: export OBJ_EXTENSION := o
# luaposix: | build/luaposix build/luaposix/Makefile
# 
# $(PACKAGES): | $(LUABIN)/lua
# 	set -e; \
# 	mkdir -p build/pkg; \
# 	export LIBFLAG="-c";\
# 	export LUA="$(abspath $(LUABIN)/lua)"; \
# 	export LUALIB="$(abspath $(LUALIB)/liblua.a)"; \
# 	export LUA_LIBDIR="$(abspath $(LUALIB))"; \
# 	export LUA_BINDIR="$(abspath $(LUABIN))"; \
# 	export LUA_INCDIR="$(abspath $(LUAINC))"; \
# 	export PREFIX="../pkg"; \
# 	export BINDIR="../pkg"; \
# 	export LIBDIR="../pkg"; \
# 	export LUADIR="../pkg"; \
# 	export CONFDIR="../pkg"; \
# 	$(MAKE) -C build/$@ -f Makefile all; \
# 	$(MAKE) -C build/$@ -f Makefile install

build/%.luab: %.lua | $(LUABIN)/luac
	@mkdir -p $(dir $@)
	$(LUABIN)/luac -o $@ $<

# luawk: src/luawk.c $(LUALIB)/liblua.a $(patsubst %.c,%.o,$(wildcard $(LUAPOSIX)/ext/posix/*.c))
# 	$(CC) $^ $(LUAWK_CFLAGS) -o $@ $(LUAWK_LDFLAGS)

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
