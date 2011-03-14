# use GNU Make to run tests in parallel, and without depending on RubyGems
all::
RSYNC_DEST := rubyforge.org:/var/www/gforge-projects/rainbows
rfproject := rainbows
rfpackage := rainbows

man-rdoc: man html
	$(MAKE) -C Documentation comparison.html
	for i in $(man1_rdoc); do echo > $$i; done
doc:: man-rdoc
include pkg.mk
ifneq ($(VERSION),)
release::
	$(RAKE) raa_update VERSION=$(VERSION)
	$(RAKE) publish_news VERSION=$(VERSION)
	$(RAKE) fm_update VERSION=$(VERSION)
endif

base_bins := rainbows
bins := $(addprefix bin/, $(base_bins))
man1_rdoc := $(addsuffix _1, $(base_bins))
man1_bins := $(addsuffix .1, $(base_bins))
man1_paths := $(addprefix man/man1/, $(man1_bins))

clean:
	-$(MAKE) -C Documentation clean

man html:
	$(MAKE) -C Documentation install-$@

pkg_extra += $(man1_paths)

doc::
	cat Documentation/comparison.css >> doc/rdoc.css
	$(RM) $(man1_rdoc)

all:: test
test:
	$(MAKE) -C t

.PHONY: man html
