# LUAWK Makefile

ifneq (4.1,$(firstword $(sort $(MAKE_VERSION) 4.1)))
$(error expected at least GNU Make 4.1, got $(MAKE_VERSION))
endif

ifeq ($(filter oneshell,$(.FEATURES)),)
$(error your version of make does not support the oneshell feature)
endif

ifeq ($(filter target-specific,$(.FEATURES)),)
$(error your version of make does not support the target-specific feature)
endif

space := $(subst ,, )

1 = $(word 1,$(subst /,$(space),$@))
2 = $(word 2,$(subst /,$(space),$@))
3 = $(word 3,$(subst /,$(space),$@))

enumerate = $(sort $(subst /,.,$(patsubst %/init,%,$(patsubst $(1)%.lua,%,$(shell find $(1) -type f -name '*.$(2)')))))
pkgencode = $(foreach pkg,$(1),$(firstword $(foreach pat,$(MOD_PATH),$(if $(patsubst $(pat),,$(pkg)),,$(subst /,.,$(patsubst $(pat),%,$(pkg)))))))
pkgdecode = $(addsuffix .o,$(basename $(foreach path,$(1),$(firstword $(wildcard $(foreach pat,$(MOD_PATH),$(patsubst %,$(pat),$(subst .,/,$(path)))))))))

PROGRAM := luawk
PREFIX := $(HOME)/.local/bin

HOST != uname -m
ARCH := $(HOST)
PLATFORM != uname -s | tr '[:upper:]' '[:lower:]'

AWK := awk
INSTALL := install
LDOC := ldoc
LUAC = $(LUABIN)/luac
LUACOV := luacov
OD := od
PROVE := prove

ERDE_VERSION := 1.0.0-1
LPEGLABEL_VERSION := 1.6.2-1
LUAPOSIX_VERSION := 36.2.1
LUA_VERSION := 5.4.6

LUABIN := build/$(ARCH)/lua/src
LUAINC := build/$(ARCH)/lua/src
LUALIB := build/$(ARCH)/lua/src

CFLAGS := -fPIC -Wall
LDFLAGS := -rdynamic -lm -ldl
INCLUDES := -I $(LUAINC)

MOD_PATH := build/$(ARCH)/bin/%/init
MOD_PATH += build/$(ARCH)/bin/%
MOD_PATH += build/$(ARCH)/lib/%/init
MOD_PATH += build/$(ARCH)/lib/%
MOD_PATH += build/$(ARCH)/erde/%/init
MOD_PATH += build/$(ARCH)/erde/%
MOD_PATH += build/$(ARCH)/lpeglabel/%/init
MOD_PATH += build/$(ARCH)/lpeglabel/%
MOD_PATH += build/$(ARCH)/luaposix/lib/%
MOD_PATH += build/$(ARCH)/luaposix/ext/%
MOD_PATH := $(foreach suffix,o c luac lua,$(addsuffix .$(suffix),$(MOD_PATH)))

MODULES := $(call enumerate,bin/,lua)
MODULES += $(call enumerate,lib/,lua)
MODULES += $(filter-out erde.cli,$(filter erde erde.%,$(call enumerate,build/$(ARCH)/erde/,lua)))
MODULES += lpeglabel
MODULES += relabel
MODULES += posix.stdio
MODULES += posix.stdlib
MODULES += posix.unistd

SOURCES := $(patsubst %.lua,build/$(ARCH)/%.c,$(shell find bin/ lib/ -type f -name '*.lua'))
SOURCES += $(patsubst %.lua,%.c,$(shell find build/$(ARCH)/erde/erde/ -type f -name '*.lua'))

.SHELLFLAGS := -ec

.ONESHELL:
.NOTINTERMEDIATE:

tmp/erde-$(ERDE_VERSION).tar.gz: URL := https://github.com/erde-lang/erde/archive/refs/tags/$(ERDE_VERSION).tar.gz
tmp/lpeglabel-$(LPEGLABEL_VERSION).tar.gz: URL := https://github.com/sqmedeiros/lpeglabel/archive/refs/tags/v$(LPEGLABEL_VERSION).tar.gz
tmp/lua-$(LUA_VERSION).tar.gz: URL := https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz: URL := https://github.com/luaposix/luaposix/archive/refs/tags/v$(LUAPOSIX_VERSION).tar.gz

build/$(ARCH)/erde/: tmp/erde-$(ERDE_VERSION).tar.gz
build/$(ARCH)/lpeglabel/: tmp/lpeglabel-$(LPEGLABEL_VERSION).tar.gz
build/$(ARCH)/lua/: tmp/lua-$(LUA_VERSION).tar.gz
build/$(ARCH)/luaposix/: tmp/luaposix-$(LUAPOSIX_VERSION).tar.gz

%/:
	mkdir -p "$@"

tmp/%.tar.gz: | tmp/
	curl -fsSL "$(URL)" -o "$@"

build/%.a:
	@echo AR $@
	$(AR) $(ARFLAGS) $@ $?

build/$(ARCH)/erde/ build/$(ARCH)/lua/ build/$(ARCH)/luaposix/ build/$(ARCH)/lpeglabel/: | build/$(ARCH)/
	tar -C $1/$2 -xzf $<
	cd $1/$2
	ln -s $3-* $3
	find $3 -exec touch {} \;

build/$(ARCH)/lua/Makefile: | build/$(ARCH)/lua/; @stat $@ >/dev/null
build/$(ARCH)/lua/src/: | build/$(ARCH)/lua/; @stat $@ >/dev/null

build/$(ARCH)/lua/src/luac build/$(ARCH)/lua/src/liblua.a: build/$(ARCH)/lua/Makefile
	$(MAKE) -s -C build/$2/lua $(PLATFORM)

build/$(ARCH)/luaposix/lib/%.lua: ; @stat $@ >/dev/null
build/$(ARCH)/luaposix/ext/%.c:   ; @stat $@ >/dev/null

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

build/$(ARCH)/lpeglabel/%.o: INCLUDES += -I build/$(ARCH)/lpeglabel

build/$(ARCH)/lpeglabel/lpeglabel.o: build/$(ARCH)/lpeglabel/lplcap.o
build/$(ARCH)/lpeglabel/lpeglabel.o: build/$(ARCH)/lpeglabel/lplcode.o
build/$(ARCH)/lpeglabel/lpeglabel.o: build/$(ARCH)/lpeglabel/lplprint.o
build/$(ARCH)/lpeglabel/lpeglabel.o: build/$(ARCH)/lpeglabel/lpltree.o
build/$(ARCH)/lpeglabel/lpeglabel.o: build/$(ARCH)/lpeglabel/lplvm.o
build/$(ARCH)/lpeglabel/lpeglabel.o:
	@echo LD $@ "($(notdir $^))"
	$(LD) -r $^ -o $@

build/$(ARCH)/bin/%.luab: bin/%.lua | $(LUAC)
	@echo GEN $@
	mkdir -p $(dir $@)
	$(LUAC) $(LUACFLAGS) -o $@ $<

build/$(ARCH)/lib/%.luab: lib/%.lua | $(LUAC)
	@echo GEN $@
	mkdir -p $(dir $@)
	$(LUAC) $(LUACFLAGS) -o $@ $<

build/$(ARCH)/%.luab: build/$(ARCH)/%.lua | $(LUAC)
	@echo GEN $@
	mkdir -p $(dir $@)
	$(LUAC) $(LUACFLAGS) -o $@ $<

build/%.o: build/%.c | $(LUAINC)/
	@echo CC $<
	$(CC) $(INCLUDES) -c $^ $(CFLAGS) -o $@

build/$(ARCH)/%.c: build/$(ARCH)/%.luab
	@echo GEN $@
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

build/$(ARCH)/preload.c:
	@echo GEN $@
	mkdir -p $(dir $@)
	exec 1>$@
	echo   '#include "lua.h"'
	echo   '#define REG(f,n) '"\\"
	echo   '  lua_pushcfunction(L, f); '"\\"
	echo   '  lua_setfield(L, -2, n);'
	printf 'LUALIB_API int luaopen_%s(lua_State *L);\n' $(subst .,_,$(MODULES))
	echo   'LUALIB_API int app_preloadlibs(lua_State *L) {'
	echo   '  lua_getglobal(L, "package");'
	echo   '  lua_getfield(L, -1, "preload");'
	printf '  REG(luaopen_%s, "%s")\n' $(foreach mod,$(MODULES),$(subst .,_,$(mod)) $(mod))
	echo   '  lua_pop(L, 2);'
	echo   '  return 0;'
	echo   '};'

build/$(ARCH)/$(PROGRAM): CFLAGS += -DAPP_OPEN=luaopen_luawk
build/$(ARCH)/$(PROGRAM): | print-modules
build/$(ARCH)/$(PROGRAM): src/bootstrap.c $(LUALIB)/liblua.a build/$(ARCH)/preload.o $(call pkgdecode,$(MODULES))
	@echo CC $<
	$(CC) $^ $(CFLAGS) -o $@ $(LDFLAGS)

.NOTPARALLEL:
.PHONY: all build clean clean-all doc help install test
.PHONY: print-parameters
.PHONY: print-packages
.PHONY: print-modules
.DEFAULT_GOAL := build

print-parameters: ;@
	printf '┌─────────────────────────────────────────────────────────────────────────────┐\n'
	printf '│ %-75s │\n' PARAMETERS
	printf '├───────────┬─────────────────────────────────────────────────────────────────┤\n'
	printf '│ %-9s │ %-63s │\n' PROGRAM "$(PROGRAM)"
	printf '│ %-9s │ %-63s │\n' PLATFORM "$(PLATFORM)"
	printf '│ %-9s │ %-63s │\n' ARCH "$(ARCH)"
	printf '│ %-9s │ %-63s │\n' HOST "$(HOST)"
	printf '│ %-9s │ %-63s │\n' PREFIX "$(PREFIX)"
	printf '├───────────┼─────────────────────────────────────────────────────────────────┤\n'
	printf '│ %-9s │ %-63s │\n' LUABIN "$(LUABIN)"
	printf '│ %-9s │ %-63s │\n' LUALIB "$(LUALIB)"
	printf '│ %-9s │ %-63s │\n' LUAINC "$(LUAINC)"
	printf '├───────────┼─────────────────────────────────────────────────────────────────┤\n'
	printf '│ %-9s │ %-63s │\n' AR "$(AR)"
	printf '│ %-9s │ %-63s │\n' CC "$(CC)"
	printf '│ %-9s │ %-63s │\n' INSTALL "$(INSTALL)"
	printf '│ %-9s │ %-63s │\n' LD "$(LD)"
	printf '│ %-9s │ %-63s │\n' LUAC "$(LUAC)"
	printf '│ %-9s │ %-63s │\n' OD "$(OD)"
	printf '├───────────┼─────────────────────────────────────────────────────────────────┤\n'
	printf '│ %-9s │ %-63s │\n' ARFLAGS "$(ARFLAGS)"
	printf '│ %-9s │ %-63s │\n' CFLAGS "$(CFLAGS)"
	printf '│ %-9s │ %-63s │\n' LDFLAGS "$(LDFLAGS)"
	printf '│ %-9s │ %-63s │\n' LUACFLAGS "$(LUACFLAGS)"
	printf '├───────────┴────────┬────────────────────────────────────────────────────────┤\n'
	printf '│ %-18s │ %-54s │\n' $(foreach pkg,LUA ERDE LUAPOSIX LPEGLABEL,$(pkg)_VERSION "$($(pkg)_VERSION)")
	printf '└────────────────────┴────────────────────────────────────────────────────────┘\n'

print-packages: ;@
	printf '┌───────────┬─────────────────────────────────────────────────────────────────┐\n'
	printf '│ %-9s │ %-63s │\n' PACKAGE VERSION
	printf '├───────────┼─────────────────────────────────────────────────────────────────┤\n'
	printf '│ %-9s │ %-63s │\n' $(foreach pkg,LUA ERDE LUAPOSIX LPEGLABEL,$(pkg) $($(pkg)_VERSION))
	printf '└───────────┴─────────────────────────────────────────────────────────────────┘\n'

print-modules: ;@
	printf '┌──────────────────────────┬──────────────────────────────────────────────────┐\n'
	printf '│ %-24s │ %-48s │\n' MODULE PATH
	printf '├──────────────────────────┼──────────────────────────────────────────────────┤\n'
	printf '│ %-24s │ %-48s │\n' $(foreach mod,$(sort $(MODULES)),$(mod) "$(call pkgdecode,$(mod))")
	printf '└──────────────────────────┴──────────────────────────────────────────────────┘\n'

help: | print-parameters print-packages print-modules

build: | print-parameters print-packages
build: | $(LUALIB)/liblua.a
build: | build/$(ARCH)/erde/
build: | build/$(ARCH)/luaposix/
build: | build/$(ARCH)/lpeglabel/
build: | build/$(ARCH)/lpeglabel/lpeglabel.o
build: | $(SOURCES)
build:
	$(MAKE) build/$(ARCH)/$(PROGRAM)

install: build
	$(INSTALL) -m 0755 -t "$(PREFIX)" build/$(ARCH)/$(PROGRAM)

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

all: build test doc
