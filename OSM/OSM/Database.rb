# Contains the OSM::Database class.

require 'OSM/objects.rb'

module OSM

    # An OSM database. It holds nodes, ways, and relations in memory.
    # Contents are unordered.
    #
    # If you add an object to the database with the same ID as a previously
    # added object, the old object will be silently deleted from the database
    # and the new one will be added.
    #
    # Usage:
    #   require 'OSM/Database'
    #   db = OSM::Database.new
    #
    class Database

        @@DEFAULT_API_VERSION = '0.6'
        @@DEFAULT_XML_GENERATOR = 'Ruby-OSMLib'

        # OpenStreetMap API version of this database
        attr_accessor :version

        # a hash of all nodes
        attr_reader :nodes

        # a hash of all ways
        attr_reader :ways

        # a hash of all relations
        attr_reader :relations

        # Create an empty database.
        #
        # version:: OpenStreetMap API Version (String, Default: @@DEFAULT_API_VERSION)
        #
        # call-seq: OSM::Database.new(version) -> OSM::Database
        #
        def initialize(version = @@DEFAULT_API_VERSION)
            @version = version
            @nodes     = Hash.new
            @ways      = Hash.new
            @relations = Hash.new
        end

        # Delete all nodes, ways and relations from the database.
        # You should call this before deleting a database to break
        # internal loop references.
        #
        # call-seq: clear
        #
        def clear
            @nodes.each_value{     |obj| obj.db = nil }
            @ways.each_value{      |obj| obj.db = nil }
            @relations.each_value{ |obj| obj.db = nil }

            @nodes     = Hash.new
            @ways      = Hash.new
            @relations = Hash.new
        end

        # Add a Node to the database.
        def add_node(node)
            id = node.id.to_i
            @nodes[id].db = nil if @nodes[id] # remove old object with same id from database
            @nodes[id] = node
            node.db = self
        end

        # Add a Way to the database.
        def add_way(way)
            id = way.id.to_i
            @ways[id].db = nil if @ways[id] # remove old object with same id from database
            @ways[id] = way
            way.db = self
        end

        # Add a Relation to the database.
        def add_relation(relation)
            id = relation.id.to_i
            @relations[id].db = nil if @relations[id] # remove old object with same id from database
            @relations[id] = relation
            relation.db = self
        end

        # Get node from the database with given ID. Returns nil if there is no node
        # with this ID.
        #
        # call-seq: get_node(id) -> OSM::Node or nil
        #
        def get_node(id)
            @nodes[id.to_i]
        end

        # Get way from the database with given ID. Returns nil if there is no way
        # with this ID.
        #
        # call-seq: get_way(id) -> OSM::Way or nil
        #
        def get_way(id)
            @ways[id.to_i]
        end

        # Get relation from the database with given ID. Returns nil if there is no relation
        # with this ID.
        #
        # call-seq: get_relation(id) -> OSM::Relation or nil
        #
        def get_relation(id)
            @relations[id.to_i]
        end

        # Add an object (Node, Way, or Relation) to the database.
        #
        # call-seq: db << object -> db
        #
        # object:: object of class Node, Way, or Relation
        def <<(object)
            case object
                when OSM::Node     then add_node(object)
                when OSM::Way      then add_way(object)
                when OSM::Relation then add_relation(object)
                else raise ArgumentError.new('Can only add objects of classes OSM::Node, OSM::Way, or OSM::Relation')
            end
            self    # return self so calls can be chained
        end

        # Dump database to XML. This uses the XML Builder library
        #
        # doc:: Builder::XmlMarkup object
        # generator:: Name of generator to put in generator attribute of osm element (String, Default: @@DEFAULT_XML_GENERATOR)
        #
        # This method is used like this:
        #
        #   db = OSM::Database.new
        #   # add data to database...
        #   doc = Builder::XmlMarkup.new(:indent => 2, :target => STDOUT)
        #   doc.instruct!
        #   db.to_xml(doc, 'test')
        #
        def to_xml(doc, generator=@@DEFAULT_XML_GENERATOR)
            doc.osm(:generator => generator, :version => version) do |xml|
                nodes.each_value do |node|
                    node.to_xml(xml)
                end
                ways.each_value do |way|
                    way.to_xml(xml)
                end
                relations.each_value do |way|
                    way.to_xml(xml)
                end
            end
        end
    end

end
