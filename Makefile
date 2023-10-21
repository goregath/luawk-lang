# LUAWK Makefile

space := $(subst ,, )

1 = $(word 1,$(subst /,$(space),$@))
2 = $(word 2,$(subst /,$(space),$@))
3 = $(word 3,$(subst /,$(space),$@))

enumerate = $(sort $(subst /,.,$(patsubst %/init,%,$(patsubst $(1)%.lua,%,$(shell find $(1) -type f -name '*.$(2)')))))
pkgencode = $(foreach pkg,$(1),$(firstword $(foreach pat,$(MOD_PATH),$(if $(patsubst $(pat),,$(pkg)),,$(subst /,.,$(patsubst $(pat),%,$(pkg)))))))
pkgdecode = $(addsuffix .o,$(basename $(foreach path,$(1),$(firstword $(wildcard $(foreach pat,$(MOD_PATH),$(patsubst %,$(pat),$(subst .,/,$(path)))))))))

PROGRAM := luawk

HOST != uname -m
ARCH := $(HOST)
PLATFORM != uname -s | tr '[:upper:]' '[:lower:]'

AWK := awk
LDOC := ldoc
LUAC = $(LUABIN)/luac
LUACOV := luacov
OD := od
PROVE := prove

LUA_VERSION := 5.4.6
LUAPOSIX_VERSION := 36.2.1
ERDE_VERSION := 1.0.0-1

LUABIN := build/$(ARCH)/lua/src
LUAINC := build/$(ARCH)/lua/src
LUALIB := build/$(ARCH)/lua/src

CFLAGS := -fPIC -Wall
LDFLAGS := -rdynamic -lm -ldl
INCLUDES := -I $(LUAINC)

MOD_PATH := build/$(ARCH)/src/%/init
MOD_PATH += build/$(ARCH)/src/%
MOD_PATH += build/$(ARCH)/erde/%/init
MOD_PATH += build/$(ARCH)/erde/%
MOD_PATH += build/$(ARCH)/luaposix/lib/%
MOD_PATH += build/$(ARCH)/luaposix/ext/%

MOD_PATH := $(addsuffix .c,$(MOD_PATH)) $(addsuffix .luac,$(MOD_PATH)) $(addsuffix .lua,$(MOD_PATH))

MODULES := $(filter-out erde.cli,$(filter erde erde.%,$(call enumerate,build/$(ARCH)/erde/,lua)))
MODULES += $(filter-out luawk,$(call enumerate,src/,lua))
MODULES += posix.stdlib
MODULES += posix.unistd

SOURCES := $(patsubst %.lua,build/$(ARCH)/%.c,$(shell find src/ -type f -name '*.lua'))
SOURCES += $(patsubst %.lua,%.c,$(shell find build/$(ARCH)/erde/erde/ -type f -name '*.lua'))

.SHELLFLAGS := -ec

.ONESHELL:
.NOTINTERMEDIATE:

tmp/erde-$(ERDE_VERSION).tar.gz: URL := https://github.com/erde-lang/erde/archive/refs/tags/$(ERDE_VERSION).tar.gz
tmp/lua-$(LUA_VERSION).tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/$(ARCH)/erde/: tmp/erde-$(ERDE_VERSION).tar.gz
build/$(ARCH)/lua/: tmp/lua-$(LUA_VERSION).tar.gz
build/$(ARCH)/luaposix/: tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz

%/:
	mkdir -p "$@"

tmp/%.tar.gz: | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/$(ARCH)/erde/ build/$(ARCH)/lua/ build/$(ARCH)/luaposix/: | build/$(ARCH)/
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

build/$(ARCH)/luaposix/%.o: CFLAGS := -fPIC
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_POSIX_C_SOURCE=200809L
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_XOPEN_SOURCE=700
ifeq ($(PLATFORM),linux)
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_BSD_SOURCE=1
build/$(ARCH)/luaposix/%.o: CFLAGS += -D_DEFAULT_SOURCE=1
endif
build/$(ARCH)/luaposix/%.o: CFLAGS += -DPACKAGE='"luaposix"'
build/$(ARCH)/luaposix/%.o: CFLAGS += -DVERSION='"$(LUAPOSIX_VERSION)"'
build/$(ARCH)/luaposix/%.o: INCLUDES += -I build/$(ARCH)/luaposix/ext/include

build/$(ARCH)/src/%.luab: src/%.lua | $(LUAC)
	mkdir -p $(dir $@)
	$(LUAC) -o $@ $<

build/$(ARCH)/%.luab: build/$(ARCH)/%.lua | $(LUAC)
	mkdir -p $(dir $@)
	$(LUAC) -o $@ $<

build/%.o: build/%.c | $(LUAINC)/
	$(CC) $(INCLUDES) -c $^ $(CFLAGS) -o $@

build/$(ARCH)/%.c: build/$(ARCH)/%.luab ;@ $(info generating $@)
	mkdir -p $(dir $@)
	exec 1>$@
	echo '#include "lua.h"'
	echo '#include "lauxlib.h"'
	echo 'static const char module[] = {'
	$(OD) -vtx1 -An -w16 $< | $(AWK) -vOFS=',0x' '{ NF=NF; print "0x"$$0"," }'
	echo '};'
	echo 'int luaopen_$(subst .,_,$(call pkgencode,$@))(lua_State *L) {'
	echo '  luaL_loadbuffer(L, module, sizeof(module), "$(call pkgencode,$@)");'
	echo '  lua_call(L, 0, 1);'
	echo '  return 1;'
	echo '};'

build/$(ARCH)/preload.c: ;@ $(info generating $@)
	mkdir -p $(dir $@)
	exec 1>$@
	echo   '#include "lua.h"'
	echo   '#define REG(f,n) '"\\"
	echo   '  lua_pushcfunction(L, f); '"\\"
	echo   '  lua_setfield(L, -2, n);'
	printf 'LUALIB_API int luaopen_%s(lua_State *L);\n' $(subst .,_,$(MODULES))
	echo   'LUALIB_API int luawk_preload(lua_State *L) {'
	echo   '  lua_getglobal(L, "package");'
	echo   '  lua_getfield(L, -1, "preload");'
	printf '  REG(luaopen_%s, "%s")\n' $(foreach mod,$(MODULES),$(subst .,_,$(mod)) $(mod))
	echo   '  lua_pop(L, 2);'
	echo   '  return 0;'
	echo   '};'

build/$(ARCH)/luawk: | info
build/$(ARCH)/luawk: src/luawk.c
build/$(ARCH)/luawk: $(LUALIB)/liblua.a
build/$(ARCH)/luawk: build/$(ARCH)/preload.o
build/$(ARCH)/luawk: $(call pkgdecode,luawk $(MODULES))
	$(CC) $^ $(CFLAGS) -o $@ $(LDFLAGS)

.NOTPARALLEL:
.PHONY: all clean clean-all doc info test luawk

info: ;@
	printf 'Module: %-24s %s\n' $(foreach mod,luawk $(MODULES),$(mod) "$(call pkgdecode,$(mod))")

luawk: | build/$(ARCH)/erde/
luawk: | build/$(ARCH)/luaposix/
luawk: | $(SOURCES)
luawk: | $(LUALIB)/liblua.a
luawk: | info
	$(MAKE) build/$(ARCH)/luawk

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
