require 'rake/clean'

XEPS = %w(whiteboarding xep-0146)

task :default => :all

def build(xep) 
	ruby "mdxep.rb #{xep}.md xml/#{xep}.xml"
	sh "xsltproc xml/xep.xsl xml/#{xep}.xml > html/extensions/#{xep}.html"
end

task :all do
	XEPS.each { |xep| build xep }
end

XEPS.each do |xep|
	desc "Build #{xep} XEP"
	task xep do
		build(xep)
	end

	CLEAN.include ["xml/#{xep}.xml", "html/extensions/#{xep}.html"]
end
