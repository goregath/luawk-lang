# LUAWK Makefile

space := $(subst ,, )

1 = $(word 1,$(subst /,$(space),$@))
2 = $(word 2,$(subst /,$(space),$@))
3 = $(word 3,$(subst /,$(space),$@))

pkgencode := $(sort $(subst /,.,$(patsubst %/init,%,$(patsubst $(1)%.lua,%,$(shell find $(1) -name '*.$(2)')))))
pkgsearch := $(foreach mod,$(1),$(firstword $(wildcard $(subst ?,$(subst .,/,$(mod)),$(MOD_PATH)))))

PROGRAM := luawk

HOST != uname -m
ARCH := $(HOST)
PLATFORM != uname -s | tr '[:upper:]' '[:lower:]'

LDOC := ldoc
LUAC := build/$(ARCH)/lua/src/luac
LUACOV := luacov
PROVE := prove

LUA_VERSION := 5.4.6
LUAPOSIX_VERSION := 36.2.1

LUABIN := build/$(ARCH)/lua/src
LUAINC := build/$(ARCH)/lua/src
LUALIB := build/$(ARCH)/lua/src

CFLAGS := -fPIC
LDFLAGS := -rdynamic -lm -ldl
INCLUDES := -I$(LUAINC)

MOD_PATH := build/$(ARCH)/src/?.o
MOD_PATH += build/$(ARCH)/src/?/init.o
MOD_PATH += build/$(ARCH)/luaposix/ext/posix/?.o

MODULES := $(call pkgencode,src/,lua)
MODULES += posix.stdlib
MODULES += posix.unistd

.SHELLFLAGS := -ec

.PHONY: all clean clean-all doc test

.ONESHELL:
.NOTINTERMEDIATE:

tmp/lua-$(LUA_VERSION).tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/$(ARCH)/lua/: tmp/lua-$(LUA_VERSION).tar.gz
build/$(ARCH)/luaposix/: tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz

%/:
	mkdir -p "$@"

tmp/%.tar.gz: | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/$(ARCH)/lua/ build/$(ARCH)/luaposix/: | build/$(ARCH)/
	tar -C $1/$2 -xzf $<
	cd $1/$2
	ln -s $3-* $3
	find $3 -exec touch {} \;

build/$(ARCH)/lua/Makefile: | build/$(ARCH)/lua/; @stat $@ >/dev/null
build/$(ARCH)/lua/src/: | build/$(ARCH)/lua/; @stat $@ >/dev/null

build/$(ARCH)/lua/src/luac build/$(ARCH)/lua/src/liblua.a: build/$(ARCH)/lua/Makefile
	$(MAKE) -C build/$2/lua $(PLATFORM)

build/$(ARCH)/luaposix/lib/%.lua: | build/$(ARCH)/luaposix/; @stat $@ >/dev/null 
build/$(ARCH)/luaposix/ext/%.c:   | build/$(ARCH)/luaposix/; @stat $@ >/dev/null 

build/$(ARCH)/luaposix/%.o: CFLAGS += -D_POSIX_C_SOURCE=200809L
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_XOPEN_SOURCE=700
ifeq ($(PLATFORM),linux)
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_BSD_SOURCE=1
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_DEFAULT_SOURCE=1
endif
build/$(ARCH)/luaposix/%.o: CFLAGS += -DPACKAGE='"luaposix"'
build/$(ARCH)/luaposix/%.o: CFLAGS += -DVERSION='"$(LUAPOSIX_VERSION)"'
build/$(ARCH)/luaposix/%.o: INCLUDES += -Ibuild/$(ARCH)/luaposix/ext/include

build/$(ARCH)/%.luab: %.lua | $(LUABIN)/luac
	mkdir -p $(dir $@)
	$(LUABIN)/luac -o $@ $<

build/%.o: build/%.c | $(LUAINC)/
	$(CC) $(INCLUDES) -c $^ $(CFLAGS) -o $@

build/%.o: build/%.luab
	false $@ $<

# build/shell.lua: | $(LUABIN)/lua
# 	echo '#!$(abspath $(LUABIN)/lua)' > $@
# 	echo 'print(assert(assert((loadstring or load)(arg[2]:gsub("\\\n", "\n")))()))' >> $@
# 	chmod +x $@

# build/lua/%: | lua; test -f $@

# .PHONY: pkgencode
# pkgencode: private SHELL := build/shell.lua
# pkgencode: | build/shell.lua
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
