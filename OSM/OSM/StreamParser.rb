require 'OSM/objects'
require 'OSM/Database'

# Namespace for modules and classes related to the OpenStreetMap project.
module OSM

    @@XMLPARSER = ENV['OSMLIB_XML_PARSER'] || 'REXML'

    def self.XMLParser
        @@XMLPARSER
    end

    if OSM.XMLParser == 'REXML'
        require 'rexml/parsers/sax2parser'
        require 'rexml/sax2listener'
    elsif OSM.XMLParser == 'Libxml'
        require 'rubygems'
        begin
            require 'xml/libxml'
        rescue LoadError
            require 'libxml'
        end
    elsif OSM.XMLParser == 'Expat'
        require 'rubygems'
        require 'xmlparser'
    end

    # This exception is raised by OSM::StreamParser when the OSM file
    # has an unknown version.
    class VersionError < StandardError
    end

    # This exception is raised when you try to use an unknown XML parser
    # by setting the environment variable OSMLIB_XML_PARSER to an unknown
    # value.
    class UnknownParserError < StandardError
    end

    # Implements the callbacks called by OSM::StreamParser while parsing the OSM
    # XML file.
    #
    # To create your own behaviour, create a subclass of this class and (re)define
    # the following methods:
    #
    #   node(node) - see below
    #   way(way) - see below
    #   relation(relation) - see below
    #
    #   start_document() - called once at start of document
    #   end_document() - called once at end of document
    #
    #   result() - see below
    #
    class Callbacks

        case OSM.XMLParser
            when 'REXML' then include REXML::SAX2Listener
            when 'Libxml' then include XML::SaxParser::Callbacks
            when 'Expat' then
            else
                raise UnknownParserError
        end

        # the OSM::Database used to store objects in
        attr_accessor :db

        # Overwrite this in a derived class. The default behaviour is to do nothing
        # but to store all node objects in a OSM::Database if one was supplied when
        # creating the OSM::StreamParser object.
        def node(node)
            true
        end

        # Overwrite this in a derived class. The default behaviour is to do nothing
        # but to store all way objects in a OSM::Database if one was supplied when
        # creating the OSM::StreamParser object.
        def way(way)
            true
        end

        # Overwrite this in a derived class. The default behaviour is to do nothing
        # but to store all relation objects in a OSM::Database if one was supplied when
        # creating the OSM::StreamParser object.
        def relation(relation)
            true
        end

        # Overwrite this in a derived class. Whatever this method returns will be
        # returned from the OSM::StreamParser#parse method.
        def result
        end

        def on_start_document   # :nodoc:
            start_document if respond_to?(:start_document)
        end

        def on_end_document     # :nodoc:
            end_document if respond_to?(:end_document)
        end

        def on_start_element(name, attr_hash)   # :nodoc:
            case name
                when 'osm'      then _start_osm(attr_hash)
                when 'node'     then _start_node(attr_hash)
                when 'way'      then _start_way(attr_hash)
                when 'relation' then _start_relation(attr_hash)
                when 'tag'      then _tag(attr_hash)
                when 'nd'       then _nd(attr_hash)
                when 'member'   then _member(attr_hash)
            end
        end

        def on_end_element(name)    # :nodoc:
            case name
                when 'node'     then _end_node()
                when 'way'      then _end_way()
                when 'relation' then _end_relation()
            end
        end

        # used by REXML
        def start_element(uri, name, qname, attr_hash)   # :nodoc:
            on_start_element(name, attr_hash)
        end

        # used by REXML
        def end_element(uri, name, qname)    # :nodoc:
            on_end_element(name)
        end

        private

        def _start_osm(attr_hash)
            if attr_hash['version'] != '0.5' && attr_hash['version'] != '0.6'
                raise OSM::VersionError, 'OSM::StreamParser only understands OSM file version 0.5 and 0.6'
            end
        end

        def _start_node(attr_hash)
            @context = OSM::Node.new(attr_hash['id'], attr_hash['user'], attr_hash['timestamp'], attr_hash['lon'], attr_hash['lat'])
        end

        def _end_node()
            @db << @context if node(@context) && ! @db.nil?
        end

        def _start_way(attr_hash)
            @context = OSM::Way.new(attr_hash['id'], attr_hash['user'], attr_hash['timestamp'])
        end

        def _end_way()
            @db << @context if way(@context) && ! @db.nil?
        end

        def _start_relation(attr_hash)
            @context = OSM::Relation.new(attr_hash['id'], attr_hash['user'], attr_hash['timestamp'])
        end

        def _end_relation()
            @db << @context if relation(@context) && ! @db.nil?
        end

        def _nd(attr_hash)
            @context.nodes << attr_hash['ref']
        end

        def _tag(attr_hash)
            if respond_to?(:tag)
                return unless tag(@context, attr_hash['k'], attr_value['v'])
            end
            @context.add_tags( attr_hash['k'] => attr_hash['v'] )
        end

        def _member(attr_hash)
            new_member = OSM::Member.new(attr_hash['type'], attr_hash['ref'], attr_hash['role'])
            if respond_to?(:member)
                return unless member(@context, new_member)
            end
            @context.members << new_member
        end

    end    

    # This callback class for OSM::StreamParser collects all objects found in the XML in
    # an array and the OSM::StreamParser#parse method returns this array.
    #
    #   cb = OSM::ObjectListCallbacks.new
    #   parser = OSM::StreamParser.new(:filename => 'filename.osm', :callbacks => cb)
    #   objects = parser.parse
    #
    class ObjectListCallbacks < Callbacks

        def start_document
            @list = []
        end

        def node(node)
            @list << node
        end

        def way(way)
            @list << way
        end

        def relation(relation)
            @list << relation
        end

        def result
            @list
        end

    end

    # This is the base class for the OSM::StreamParser::REXML, OSM::StreamParser::Libxml, and
    # OSM::StreamParser::Expat classes. Do not instantiate this class!
    class StreamParserBase

        # Byte position within the input stream. This is only updated by the Expat parser.
        attr_reader :position

        def initialize(options) # :nodoc:
            @filename = options[:filename]
            @string = options[:string]
            @db = options[:db]
            @context = nil
            @position = 0

            if (@filename.nil? && @string.nil?) || ((!@filename.nil?) && (!@string.nil?))
                raise ArgumentError.new('need either :filename or :string argument')
            end

            @callbacks = options[:callbacks].nil? ? OSM::Callbacks.new : options[:callbacks]
            @callbacks.db = @db
        end

    end

    # Class to parse XML files. This is a factory class. When calling OSM::StreamParser.new()
    # an object of one of the following classes is created and returned:
    # OSM::StreamParser::REXML, OSM::StreamParser::Libxml, OSM::StreamParser::Expat.
    #
    # Usage:
    #   ENV['OSMLIB_XML_PARSER'] = 'Libxml'
    #   require 'OSM/StreamParser'
    #   parser = OSM::Streamparser.new(:filename => 'file.osm')
    #   result = parser.parse
    #
    class StreamParser

        # Create new StreamParser object. Only argument is a hash.
        #
        # call-seq: OSM::StreamParser.new(:filename => 'filename.osm')
        #           OSM::StreamParser.new(:string => '...')
        #
        # The hash keys:
        #   :filename  => name of XML file
        #   :string    => XML string
        #   :db        => an OSM::Database object
        #   :callbacks => an OSM::Callbacks object (or more likely from a derived class)
        #                 if none was given a new OSM:Callbacks object is created
        #
        # You can only use :filename or :string, not both.
        def self.new(options)
            eval "OSM::StreamParser::#{OSM.XMLParser}.new(options)"
        end

    end

end

require "OSM/StreamParser/#{OSM.XMLParser}"

