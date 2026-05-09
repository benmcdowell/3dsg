PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
INSTALL ?= install

PRODUCT := 3dsg
RELEASE_BINARY := .build/release/$(PRODUCT)

.PHONY: build test install uninstall clean

build:
	swift build -c release --product $(PRODUCT)

test:
	swift test

install: build
	mkdir -p "$(BINDIR)"
	$(INSTALL) -m 0755 "$(RELEASE_BINARY)" "$(BINDIR)/$(PRODUCT)"

uninstall:
	rm -f "$(BINDIR)/$(PRODUCT)"

clean:
	swift package clean
	rm -rf dist
