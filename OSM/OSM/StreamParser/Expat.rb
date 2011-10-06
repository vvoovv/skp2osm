# Contains the OSM::StreamParser::Expat class.

require 'rubygems'
require 'xmlparser'

# Namespace for modules and classes related to the OpenStreetMap project.
module OSM

    # Stream parser for OpenStreetMap XML files using Expat.
    class StreamParser::Expat < StreamParserBase

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
        def initialize(options)
            super(options)

            @parser = XML::Parser.new
            if @filename.nil?
                @data = @string
            else
                @data = File.open(@filename)
            end
        end

        # Run the parser. Return value is the return value of the OSM::Callbacks#result method.
        def parse
            @callbacks.on_start_document
            @parser.parse(@data) do |type, name, data|
                @position += @parser.byteCount
                @callbacks.on_start_element(name, data) if type == :START_ELEM
                @callbacks.on_end_element(name) if type == :END_ELEM
            end
            @callbacks.on_end_document
            @callbacks.result
        end

    end

end

