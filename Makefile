all:
	./mdxep.rb whiteboarding.md xml/whiteboarding.xml
	xsltproc xml/xep.xsl xml/whiteboarding.xml > html/extensions/whiteboarding.html

clean:
	-rm -rf xml/whiteboarding.xml html/extensions/whiteboarding.html
