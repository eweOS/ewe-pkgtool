PREFIX		?= /usr/local
DESTDIR		?=

BINDIR		= $(DESTDIR)/$(PREFIX)/bin
SHAREDIR	= $(DESTDIR)/$(PREFIX)/share

INSTALL		?= install
CP		?= cp
CHMOD		?= chmod
MKDIR		?= mkdir

install:
	$(INSTALL) -Dm755 ewe-pkgtool.sh $(BINDIR)/ewe-pkgtool

	$(MKDIR) -p $(SHAREDIR)/ewe-pkgtool
	$(CP) -rf templates $(SHAREDIR)/ewe-pkgtool
	$(CHMOD) 644 $(SHAREDIR)/ewe-pkgtool/templates/*
