XEPS=\
	whiteboarding \
	xep-0146
XEPS_HTML=$(patsubst %, html/extensions/%.html, $(XEPS))
XEPS_XML=$(patsubst %, xml/%.xml, $(XEPS))

all: $(XEPS_XML) $(XEPS_HTML)

xml/%.xml: %.md mdxep.rb
	$(RB_RUNNER) ./mdxep.rb $< $@

html/extensions/%.html: xml/%.xml
	xsltproc --output $@ xml/xep.xsl $<

clean:	
	-rm -rf $(XEPS_HTML) $(XEPS_XML)
