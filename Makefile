PACKAGE = less
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

PACKAGE_VERSION = 481
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

SOURCE_URL = http://www.greenwoodsoftware.com/$(PACKAGE)/$(PACKAGE)-$(PACKAGE_VERSION).tar.gz
SOURCE_PATH = /tmp/source
SOURCE_TARBALL = /tmp/source.tar.gz

PATH_FLAGS = --prefix=/usr --sbindir=/usr/bin --sysconfdir=/etc
CONF_FLAGS = --with-regex=pcre
CFLAGS = -static -static-libgcc -Wl,-static -lc

NCURSES_VERSION = 6.0-1
NCURSES_URL = https://github.com/amylum/ncurses/releases/download/$(NCURSES_VERSION)/ncurses.tar.gz
NCURSES_TAR = /tmp/ncurses.tar.gz
NCURSES_DIR = /tmp/ncurses
NCURSES_PATH = -I$(NCURSES_DIR)/usr/include -L$(NCURSES_DIR)/usr/lib

.PHONY : default source manual container deps build version push local

default: container

source:
	rm -rf $(SOURCE_PATH) $(SOURCE_TARBALL)
	mkdir $(SOURCE_PATH)
	curl -sLo $(SOURCE_TARBALL) $(SOURCE_URL)
	tar -x -C $(SOURCE_PATH) -f $(SOURCE_TARBALL) --strip-components=1

manual:
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(NCURSES_DIR) $(NCURSES_TAR)
	mkdir $(NCURSES_DIR)
	curl -sLo $(NCURSES_TAR) $(NCURSES_URL)
	tar -x -C $(NCURSES_DIR) -f $(NCURSES_TAR)

build: source deps
	rm -rf $(BUILD_DIR)
	cp -R $(SOURCE_PATH) $(BUILD_DIR)
	cd $(BUILD_DIR) && CC=musl-gcc LDFLAGS='$(NCURSES_PATH) $(CFLAGS)' CFLAGS='$(CFLAGS)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

