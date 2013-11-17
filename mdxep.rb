#!/usr/bin/env ruby

# Parts of this file are copied from
#
#   https://github.com/gettalong/kramdown/blob/master/lib/kramdown/converter/html.rb
#

require 'yaml'
require "rexml/document"
require "rexml/formatters/transitive"
require "rexml/formatters/default"
require 'kramdown'
require 'kramdown/utils'
require 'cgi'

XEP_HEADER = <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE xep SYSTEM 'xep.dtd' [
	<!ENTITY % ents SYSTEM 'xep.ent'>
	%ents;
]>
<?xml-stylesheet type='text/xsl' href='xep.xsl'?>
EOF

module Kramdown
	module Converter
		class Xep < Base
			include ::Kramdown::Utils::Html
			include ::Kramdown::Parser::Html::Constants
			
			def initialize(root, options = {})
				super
				@current_level = 0
				@in_example = nil
				@metadata = $metadata
			end

			def get_title_and_abstract(document_element)
				title = nil
				abstract = nil
				next_paragraph_is_abstract = false
				indices_to_delete = []
				document_element.children.each_with_index do |el, i|
					if el.type == :header then
						if el.options[:level] == 1 then
							title = el.options[:raw_text]
						elsif el.options[:level] == 2 and el.options[:raw_text].strip == "Abstract" then
							indices_to_delete << i
							next_paragraph_is_abstract = true
						end
					elsif next_paragraph_is_abstract and el.type == :p then
						indices_to_delete << i
						abstract = convert_children(el)
						break
					end
				end
				document_element.children.slice!(indices_to_delete[0]..indices_to_delete[1])
				return title, abstract
			end

			def convert_children(el)
				result = ""
				el.children.each do |inner_el|
					result << convert(inner_el)
				end
				result
			end

			def convert(el)
				send("convert_#{el.type}", el)
			end

			def convert_root(el)
				result = XEP_HEADER 
				result << "<xep>\n"
				result << "<header>\n"
				title, abstract = get_title_and_abstract(el)
				result << "<title>#{title}</title>\n"
				result << "<abstract>#{abstract}</abstract>\n"
				['number', 'status', 'shortname'].each do |k|
					result << "<#{k}>#{$metadata[k]}</#{k}>\n"
				end
				result << "&LEGALNOTICE;\n"

				result << "<dependencies>\n"
				$metadata['dependencies'].each do |dependency|
					result << "<spec>#{dependency}</spec>\n"
				end
				result << "</dependencies>\n"

				$metadata['authors'].each do |author|
					if author.is_a?(String) 
						result << "&#{author};\n"
					else
						result << "<author>\n"
						author.each do |key, value|
							result << "<#{key}>#{value}</#{key}>\n"
						end
						result << "</author>\n"
					end
				end

				result << "<type>Standards Track</type>\n"
				result << "<sig>Standards</sig>\n"
				result << "<approver>Council</approver>\n"
				result << "<supersedes/>\n"
				result << "<supersededby/>\n"

				$metadata['revisions'].each do |revision|
					result << "<revision>"
					revision.each do |key, value|
						value = "<p>" + value + "</p>" if key == "remark"
						result << "<#{key}>#{value}</#{key}>\n"
					end
					result << "</revision>"
				end

				result << "</header>\n"
				result << convert_children(el)
				result << close_sections_until_level(1)
				result << "</xep>\n"
				result
			end

			def snake_case(text)
				::Kramdown::Utils.snake_case(text).sub(' ', '-')
			end

			def convert_header(el)
				result = ""
				header_level = el.options[:level] -1
				if header_level > 0
					result << close_sections_until_level(header_level)
					result << "<section#{@current_level} topic='#{el.options[:raw_text]}' anchor='#{snake_case(el.options[:raw_text])}'>\n"
				end
				result
			end

			def convert_blank(el)
				""
			end

			def convert_blockquote(el)
				"<blockquote>#{convert_children(el)}</blockquote>"
			end

			def convert_p(el)
				"<p>" + convert_children(el) + "</p>"
			end

			def convert_ul(el)
				"<ul>#{convert_children(el)}</ul>"
			end

			def convert_li(el)
				"<li>#{convert_children(el)}</li>"
			end

			def convert_codeblock(el)
				value = CGI.escape_html(el.value)
				if @in_example
					result = "<example caption='#{@in_example}'>#{value}</example>"
					@in_example = nil
					result
				else
					"<code>#{value}</code>"
				end
			end
			
			def convert_text(el)
				CGI.escape_html(el.value)
			end

			def convert_em(el)
				value = convert_children(el)
				if m = /^Example: (.*)/.match(value) 
					@in_example = m[1]
					return ""
				else
					"<em>#{value}</em>"
				end
			end

			def convert_strong(el)
				"<strong>#{convert_children(el)}</strong>"
			end

			def convert_img(el)
				not_implemented(el)
			end

			TYPOGRAPHIC_SYMS = {
				:mdash => [::Kramdown::Utils::Entities.entity('mdash')],
				:ndash => [::Kramdown::Utils::Entities.entity('ndash')],
				:hellip => [::Kramdown::Utils::Entities.entity('hellip')],
				:laquo_space => [
					::Kramdown::Utils::Entities.entity('laquo'), 
					::Kramdown::Utils::Entities.entity('nbsp')],
				:raquo_space => [::Kramdown::Utils::Entities.entity('nbsp'), 
				::Kramdown::Utils::Entities.entity('raquo')],
				:laquo => [::Kramdown::Utils::Entities.entity('laquo')],
				:raquo => [::Kramdown::Utils::Entities.entity('raquo')]
			}
			def convert_typographic_sym(el)
				TYPOGRAPHIC_SYMS[el.value].map {|e| entity_to_str(e)}.join('')
			end

			def convert_smart_quote(el)
				entity_to_str(smart_quote_entity(el))
			end

			def convert_a(el)
				text = convert_children(el)
				"<link url='#{el.attr['href']}'>#{text}</link> <note><link url='#{el.attr['href']}'>#{text}</link></note>"
			end

			def convert_html_element(el)
				if el.options[:category] == :span
					"<#{el.value}>#{convert_children(el)}</#{el.value}>"
				else
					raise "Unknown element: #{el.inspect}"
				end
			end

			def convert_br(el)
				"<br/>"
			end

			def close_sections_until_level(level)
				result = ""
				while @current_level >= level
					result << "</section#{@current_level}>\n"
					@current_level -= 1
				end
				@current_level += 1
				result
			end

			def convert_xml_comment(el)
				""
			end

			def not_implemented(el)
				raise "#{el.inspect}"
			end
		end
	end
end

data = File.read(ARGV[0]).split(/^---/)
$metadata = YAML.load(data[1])
content = data[2]

raw_xep = Kramdown::Document.new(content).to_xep
File.open(ARGV[1], 'w') { |f| f.write(raw_xep) }

# out = ""
# REXML::Formatters::Transitive.new().write(REXML::Document.new(raw_xep), out)
# puts out
