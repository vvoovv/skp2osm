# Contains the OSM::StreamParser::LibXML class.

require 'rubygems'
begin
    require 'xml/libxml'
rescue LoadError
    require 'libxml'
end

# Namespace for modules and classes related to the OpenStreetMap project.
module OSM

    # Stream parser for OpenStreetMap XML files using Libxml.
    class StreamParser::Libxml < StreamParserBase

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

            @parser = XML::SaxParser.new
            if @filename.nil?
                @parser.string = @string
            else
                @parser.filename = @filename
            end
            @parser.callbacks = @callbacks
        end

        # Run the parser. Return value is the return value of the OSM::Callbacks#result method.
        def parse
            @parser.parse
            @callbacks.result
        end

    end

end

