# Contains classes for OpenStreetMap objects: OSM::OSMObject
# (virtual parent class), OSM::Node, OSM::Way, OSM::Relation, and OSM::Member

# Namespace for modules and classes related to the OpenStreetMap project.
module OSM

    # This error is raised when an object is not associated with a
    # OSM::Database but database access is needed.
    class NoDatabaseError < StandardError
    end

    # This error is raised when a way that should be closed (i.e.
    # first node equals last node) but isn't.
    class NotClosedError < StandardError
    end

    # This error is raised when an OSM object is not associated with a geometry.
    class NoGeometryError < StandardError
    end

    # This error is raised when an OSM object can't be turned into
    # a proper geometry. Happens if way has not enough nodes.
    class GeometryError < StandardError
    end

    # An object was not found in the database.
    class NotFoundError < StandardError
    end

    # This is a virtual parent class for the OSM objects Node, Way and Relation.
    class OSMObject

        # To give out unique IDs to the objects we keep a counter that
        # gets decreased every time we use it. See the _next_id method.
        @@id = 0

        # Unique ID
        attr_reader :id

        # The version of this object (as read from file, it
        # is not updated by operations to this object)
        # API 0.6 and above only
        attr_accessor :version

        # The user who last edited this object (as read from file, it
        # is not updated by operations to this object)
        attr_accessor :user

        # The user id of the user who last edited this object (as read from file, it
        # is not updated by operations to this object)
        # API 0.6 and above only
        attr_accessor :uid

        # Last change of this object (as read from file, it is not
        # updated by operations to this object)
        attr_reader :timestamp

        # Tags for this object
        attr_reader :tags

        # The OSM::Database this object is in (if any)
        attr_accessor :db

        # Get OSM::OSMObject from API
        def self.from_api(id, api=OSM::API.new) #:nodoc:
            raise NotImplementedError.new('OSMObject is a virtual base class for the Node, Way, and Relation classes') if self.class == OSM::OSMObject
            api.get_object(type, id)
        end

        def initialize(id, user, timestamp, uid=-1, version=1) #:nodoc:
            raise NotImplementedError.new('OSMObject is a virtual base class for the Node, Way, and Relation classes') if self.class == OSM::OSMObject

            @id = id.nil? ? _next_id : _check_id(id)
            @version = version
            @uid = uid
            @user = user
            @timestamp = _check_timestamp(timestamp) unless timestamp.nil?
            @db = nil
            @tags = Tags.new
        end

        # Create an error when somebody tries to set the ID.
        # (We need this here because otherwise method_missing will be called.)
        def id=(id) # :nodoc:
            raise NotImplementedError.new('id can not be changed once the object was created')
        end

        # Set timestamp for this object.
        def timestamp=(timestamp)
            @timestamp = _check_timestamp(timestamp)
        end

        # The list of attributes for this object
        def attribute_list # :nodoc:
            [:id, :version, :uid, :user, :timestamp]
        end

        # Returns a hash of all non-nil attributes of this object.
        #
        # Keys of this hash are <tt>:id</tt>, <tt>:user</tt>,
        # and <tt>:timestamp</tt>. For a Node also <tt>:lon</tt>
        # and <tt>:lat</tt>.
        #
        # call-seq: attributes -> Hash
        #
        def attributes
            attrs = Hash.new
            attribute_list.each do |attribute|
                value = self.send(attribute)
                attrs[attribute] = value unless value.nil?
            end
            attrs
        end

        # Get tag value
        def [](key)
            tags[key]
        end

        # Set tag
        def []=(key, value)
            tags[key] = value
        end

        # Add one or more tags to this object.
        #
        # call-seq: add_tags(Hash) -> OSMObject
        #
        def add_tags(new_tags)
            new_tags.each do |k, v|
                self.tags[k.to_s] = v
            end
            self    # return self so calls can be chained
        end

        # Has this object any tags?
        #
        # call-seq: is_tagged?
        #
        def is_tagged?
            ! @tags.empty?
        end

        # Create a new GeoRuby::Shp4r::ShpRecord with the geometry of
        # this object and the given attributes.
        #
        # This only works if the GeoRuby library is included.
        #
        # geom:: Geometry
        # attributes:: Hash with attributes
        #
        # call-seq: shape(attributes) -> GeoRuby::Shp4r::ShpRecord
        #
        # Example:
        #   require 'rubygems'
        #   require 'geo_ruby'
        #   node = Node(nil, nil, nil, 7.84, 54.34)
        #   g = node.point
        #   node.shape(g, :type => 'Pharmacy', :name => 'Hyde Park Pharmacy')
        #
        def shape(geom, attributes)
            fields = Hash.new
            attributes.each do |key, value|
                fields[key.to_s] = value
            end
            GeoRuby::Shp4r::ShpRecord.new(geom, fields)
        end

        # Get all relations from the API that have his object as members.
        #
        # The optional parameter is an OSM::API object. If none is specified
        # the default OSM API is used.
        #
        # Returns an array of Relation objects or an empty array.
        #
        def get_relations_from_api(api=OSM::API.new)
            api.get_relations_referring_to_object(type, self.id.to_i)
        end

        # Get the history of this object from the API.
        #
        # The optional parameter is an OSM::API object. If none is specified
        # the default OSM API is used.
        #
        # Returns an array of OSM::Node, OSM::Way, or OSM::Relation objects
        # with all the versions.
        def get_history_from_api(api=OSM::API.new)
            api.get_history(type, self.id.to_i)
        end

        # All other methods are mapped so its easy to access tags: For
        # instance obj.name is the same as obj.tags['name']. This works
        # for getting and setting tags.
        #
        #   node = OSM::Node.new
        #   node.add_tags( 'highway' => 'residential', 'name' => 'Main Street' )
        #   node.highway                   #=> 'residential'
        #   node.highway = 'unclassified'  #=> 'unclassified'
        #   node.name                      #=> 'Main Street'
        #
        # In addition methods of the form <tt>key?</tt> are used to
        # check boolean tags. For instance +oneway+ can be 'true' or
        # 'yes' or '1', all meaning the same.
        #
        #   way.oneway?
        #
        # will check this. It returns true if the value of this key is
        # either 'true', 'yes' or '1'.
        def method_missing(method, *args)
            methodname = method.to_s
            if methodname.slice(-1, 1) == '='
                if args.size != 1
                    raise ArgumentError.new("wrong number of arguments (#{args.size} for 1)")
                end
                tags[methodname.chop] = args[0]
            elsif methodname.slice(-1, 1) == '?'
                if args.size != 0
                    raise ArgumentError.new("wrong number of arguments (#{args.size} for 0)")
                end
                tags[methodname.chop] =~ /^(true|yes|1)$/
            else
                if args.size != 0
                    raise ArgumentError.new("wrong number of arguments (#{args.size} for 0)")
                end
                tags[methodname]
            end
        end
 
        private

        # Return next free ID
        def _next_id
            @@id -= 1
            @@id
        end

        def _check_id(id)
            if id.kind_of?(Integer)
                return id
            elsif id.kind_of?(String)
                raise ArgumentError, "ID must be an integer" unless id =~ /^-?[0-9]+$/
                return id.to_i
            else
                raise ArgumentError, "ID must be integer or string with integer"
            end
        end

        def _check_timestamp(timestamp)
            if timestamp !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|([+-][0-9]{2}:[0-9]{2}))$/
                raise ArgumentError, "Timestamp is in wrong format (must be 'yyyy-mm-ddThh:mm:ss(Z|[+-]mm:ss)')"
            end
            timestamp
        end

        def _check_lon(lon)
            if lon.kind_of?(Numeric)
                return lon.to_s
            elsif lon.kind_of?(String)
                return lon
            else
                raise ArgumentError, "'lon' must be number or string containing number"
            end
        end

        def _check_lat(lat)
            if lat.kind_of?(Numeric)
                return lat.to_s
            elsif lat.kind_of?(String)
                return lat
            else
                raise ArgumentError, "'lat' must be number or string containing number"
            end
        end

    end

    # OpenStreetMap Node.
    #
    # To create a new OSM::Node object:
    #   node = OSM::Node.new(17, 'someuser', '2007-10-31T23:48:54Z', 7.4, 53.2)
    #
    # To get a node from the API:
    #   node = OSM::Node.from_api(17)
    #
    class Node < OSMObject

        # Longitude in decimal degrees
        attr_reader :lon
        
        # Latitude in decimal degrees
        attr_reader :lat

        # Create new Node object.
        #
        # If +id+ is +nil+ a new unique negative ID will be allocated.
        def initialize(id=nil, user=nil, timestamp=nil, lon=nil, lat=nil, uid=-1, version=1)
            @lon = _check_lon(lon) unless lon.nil?
            @lat = _check_lat(lat) unless lat.nil?
            super(id, user, timestamp, uid, version)
        end

        def type
            'node'
        end

        # Set longitude.
        def lon=(lon)
            @lon = _check_lon(lon)
        end

        # Set latitude.
        def lat=(lat)
            @lat = _check_lat(lat)
        end

        # List of attributes for a Node
        def attribute_list
            [:id, :version, :uid, :user, :timestamp, :lon, :lat]
        end

        # Add one or more tags to this node.
        #
        # The argument can be one of the following:
        #
        # * If the argument is a Hash or an OSM::Tags object, those tags are added.
        # * If the argument is an Array the function is called recursively, i.e. all items in the Array are added.
        #
        # Returns the node to allow chaining.
        #
        # call-seq: node << something -> Node
        #
        def <<(stuff)
            case stuff
                when Array  # call this method recursively
                    stuff.each do |item|
                        self << item
                    end
                else
                    tags.merge!(stuff)
            end
            self    # return self to allow chaining
        end

        # Create object of class GeoRuby::SimpleFeatures::Point with
        # the coordinates of this node.
        # Raises an OSM::GeometryError exception if the coordinates are not set.
        #
        # Only works if the GeoRuby library is loaded.
        #
        #   require 'rubygems'
        #   require 'geo_ruby'
        #   geometry = OSM::Node.new(nil, nil, nil, 10.1, 20.2).point
        #
        # call-seq: geometry ->  GeoRuby::SimpleFeatures::Point
        #
        def point
            raise OSM::GeometryError.new("coordinates missing") if lon.nil? || lat.nil? || lon == '' || lat == ''
            GeoRuby::SimpleFeatures::Point.from_lon_lat(lon.to_f, lat.to_f)
        end

        alias :geometry :point

        # Return string version of this node.
        # 
        # call-seq: to_s -> String
        #
        def to_s
            "#<OSM::Node id=\"#{@id}\" user=\"#{@user}\" timestamp=\"#{@timestamp}\" lon=\"#{@lon}\" lat=\"#{@lat}\">"
        end

        # Return XML for this node. This method uses the XML Builder
        # library. The only parameter is the builder object.
        def to_xml(xml)
            xml.node(attributes) do
                tags.to_xml(xml)
            end
        end

        # Get all ways using this node from the API.
        #
        # The optional parameter is an OSM::API object. If none is specified
        # the default OSM API is used.
        #
        # Returns an array of OSM::Way objects.
        def get_ways_using_node_from_api(api=OSM::API.new)
            api.get_ways_using_node(self.id.to_i)
        end

    end

    # OpenStreetMap Way.
    #
    # To create a new OSM::Way object:
    #   way = OSM::Way.new(1743, 'user', '2007-10-31T23:51:17Z')
    #
    # To get a way from the API:
    #   way = OSM::Way.from_api(17)
    #
    class Way < OSMObject

        # Array of node IDs in this way.
        attr_reader :nodes

        # Create new Way object.
        #
        # id:: ID of this way. If +nil+ a new unique negative ID will be allocated.
        # user:: Username
        # timestamp:: Timestamp of last change
        # nodes:: Array of Node objects and/or node IDs
        def initialize(id=nil, user=nil, timestamp=nil, nodes=[], uid=-1, version=1)
            @nodes = nodes.collect{ |node| node.kind_of?(OSM::Node) ? node.id : node }
            super(id, user, timestamp, uid, version)
        end

        def type
            'way'
        end

        # Add one or more tags or nodes to this way.
        #
        # The argument can be one of the following:
        #
        # * If the argument is a Hash or an OSM::Tags object, those tags are added.
        # * If the argument is an OSM::Node object, its ID is added to the list of node IDs.
        # * If the argument is an Integer or String containing an Integer, this ID is added to the list of node IDs.
        # * If the argument is an Array the function is called recursively, i.e. all items in the Array are added.
        #
        # Returns the way to allow chaining.
        #
        # call-seq: way << something -> Way
        #
        def <<(stuff)
            case stuff
                when Array  # call this method recursively
                    stuff.each do |item|
                        self << item
                    end
                when OSM::Node
                    nodes << stuff.id
                when String
                    nodes << stuff.to_i
                when Integer
                    nodes << stuff
                else
                    tags.merge!(stuff)
            end
            self    # return self to allow chaining
        end

        # Is this way closed, i.e. are the first and last nodes the same?
        #
        # Returns false if the way doesn't contain any nodes or only one node.
        #
        # call-seq: is_closed? -> true or false
        #
        def is_closed?
            return false if nodes.size < 2
            nodes[0] == nodes[-1]
        end

        # Return an Array with all the node objects that are part of this way.
        #
        # Only works if the way and nodes are part of an OSM::Database.
        #
        # call-seq: node_objects -> Array of OSM::Node objects
        #
        def node_objects
            raise OSM::NoDatabaseError.new("can't get node objects if the way is not in a OSM::Database") if @db.nil?
            nodes.collect do |id|
                @db.get_node(id)
            end
        end

        # Create object of class GeoRuby::SimpleFeatures::LineString with the
        # coordinates of the node in this way.
        # Raises a OSM::GeometryError exception if the way contain less than
        # two nodes. Raises an OSM::NoDatabaseError exception if this way
        # is not associated with an OSM::Database.
        #
        # Only works if the GeoRuby library is loaded.
        #
        # call-seq: linestring ->  GeoRuby::SimpleFeatures::LineString or nil
        #
        def linestring
            raise OSM::GeometryError.new("way with less then two nodes can't be turned into a linestring") if nodes.size < 2
            raise OSM::NoDatabaseError.new("can't create LineString from way if the way is not in a OSM::Database") if @db.nil?
            GeoRuby::SimpleFeatures::LineString.from_coordinates(node_objects.collect{ |node| [node.lon.to_f, node.lat.to_f] })
        end

        # Create object of class GeoRuby::SimpleFeatures::Polygon with
        # the coordinates of the node in this way.
        # Raises a OSM::GeometryError exception if the way contain less
        # than three nodes.
        # Raises an OSM::NoDatabaseError exception if this way is not
        # associated with an OSM::Database.
        # Raises an OSM::NotClosedError exception if this way is not closed.
        #
        # Only works if the GeoRuby library is loaded.
        #
        # call-seq: polygon ->  GeoRuby::SimpleFeatures::Polygon or nil
        #
        def polygon
            raise OSM::GeometryError.new("way with less then three nodes can't be turned into a polygon") if nodes.size < 3
            raise OSM::NoDatabaseError.new("can't create Polygon from way if the way is not in a OSM::Database") if @db.nil?
            raise OSM::NotClosedError.new("way is not closed so it can't be represented as Polygon") unless is_closed?
            GeoRuby::SimpleFeatures::Polygon.from_coordinates([node_objects.collect{ |node| [node.lon.to_f, node.lat.to_f] }])
        end

        # Currently the same as the linestring method. This might change in
        # the future to return a Polygon in some cases.
        #
        # Only works if the GeoRuby library is loaded.
        #
        # call-seq: geometry ->  GeoRuby::SimpleFeatures::LineString or nil
        #
        def geometry
            linestring
        end

        # Return string version of this Way object.
        # 
        # call-seq: to_s -> String
        #
        def to_s
            "#<OSM::Way id=\"#{@id}\" user=\"#{@user}\" timestamp=\"#{@timestamp}\">"
        end

        # Return XML for this way. This method uses the Builder library.
        # The only parameter ist the builder object.
        def to_xml(xml)
            xml.way(attributes) do
                nodes.each do |node|
                    xml.nd(:ref => node.id)
                end
                tags.to_xml(xml)
            end
        end

    end

    # OpenStreetMap Relation.
    #
    # To create a new OSM::Relation object:
    #   relation = OSM::Relation.new(331, 'user', '2007-10-31T23:51:53Z')
    #
    # To get a relation from the API:
    #   relation = OSM::Relation.from_api(17)
    #
    class Relation < OSMObject

        # Array of Member objects
        attr_reader :members

        # Create new Relation object.
        #
        # If +id+ is +nil+ a new unique negative ID will be allocated.
        def initialize(id=nil, user=nil, timestamp=nil, members=[], uid=-1, version=1)
            @members = members
            super(id, user, timestamp, uid, version)
        end

        def type
            'relation'
        end

        # Add one or more tags or members to this relation.
        #
        # The argument can be one of the following:
        #
        # * If the argument is a Hash or an OSM::Tags object, those tags are added.
        # * If the argument is an OSM::Member object, it is added to the relation
        # * If the argument is an Array the function is called recursively, i.e. all items in the Array are added.
        #
        # Returns the relation to allow chaining.
        #
        # call-seq: relation << something -> Relation
        #
        def <<(stuff)
            case stuff
                when Array  # call this method recursively
                    stuff.each do |item|
                        self << item
                    end
                when OSM::Member
                    members << stuff
                else
                    tags.merge!(stuff)
            end
            self    # return self to allow chaining
        end


        # Raises a NoGeometryError.
        #
        # Future versions of this library may recognize certain relations
        # that do have a geometry (such as Multipolygon relations) and do
        # the right thing.
        def geometry
            raise NoGeometryError.new("Relations don't have a geometry")
        end

        # Returns a polygon made up of all the ways in this relation. This
        # works only if it is tagged with 'polygon' or 'multipolygon'.
        def polygon
            raise OSM::NoDatabaseError.new("can't create Polygon from relation if it is not in a OSM::Database") if @db.nil?
            raise OSM::NoDatabaseError.new("can't create Polygon from relation if it does not represent a polygon") if self['type'] != 'multipolygon' and self['type'] != 'polygon'

            c = []
            member_objects.each do |way|
                raise TypeError.new("member is not a way so it can't be represented as Polygon") unless way.kind_of? OSM::Way
                raise OSM::NotClosedError.new("way is not closed so it can't be represented as Polygon") unless way.is_closed?
                raise OSM::GeometryError.new("way with less then three nodes can't be turned into a polygon") if way.nodes.size < 3
                c << way.node_objects.collect{ |node| [node.lon.to_f, node.lat.to_f] }
            end
            GeoRuby::SimpleFeatures::Polygon.from_coordinates(c)
        end

        # Return all the member objects of this relation.
        def member_objects
            members.collect do |member|
                obj = case member.type
                    when :node,     'node'     then @db.get_node(member.ref)
                    when :way,      'way'      then @db.get_way(member.ref)
                    when :relation, 'relation' then @db.get_relation(member.ref)
                end
                raise OSM::NotFoundError.new("not in database: #{member.type} #{member.ref}") unless obj
                obj
            end
        end

        # Return string version of this Relation object.
        # 
        # call-seq: to_s -> String
        #
        def to_s
            "#<OSM::Relation id=\"#{@id}\" user=\"#{@user}\" timestamp=\"#{@timestamp}\">"
        end

        # Return the member with a specified type and id. Returns nil
        # if not found.
        #
        # call-seq: member(type, id) -> OSM::Member
        #
        def member(type, id)
            members.select{ |member| member.type == type && member.ref == id }[0]
        end

        # Return XML for this relation. This method uses the Builder library.
        # The only parameter ist the builder object.
        def to_xml(xml)
            xml.relation(attributes) do
                members.each do |member|
                    member.to_xml(xml)
                end
                tags.to_xml(xml)
            end
        end

    end

    # A member of an OpenStreetMap Relation.
    class Member

        # Role this member has in the relationship
        attr_accessor :role

        # Type of referenced object (can be 'node', 'way', or 'relation')
        attr_reader :type

        # ID of referenced object
        attr_reader :ref

        # Create a new Member object. Type can be one of 'node', 'way' or
        # 'relation'. Ref is the ID of the corresponding Node, Way, or
        # Relation. Role is a freeform string and can be empty.
        def initialize(type, ref, role='')
            if type !~ /^(node|way|relation)$/
                raise ArgumentError.new("type must be 'node', 'way', or 'relation'")
            end
            if ref.to_s !~ /^[0-9]+$/
                raise ArgumentError
            end
            @type = type
            @ref  = ref.to_i
            @role = role
        end

        # Return XML for this way. This method uses the Builder library.
        # The only parameter ist the builder object.
        def to_xml(xml)
            xml.member(:type => type, :ref => ref, :role => role)
        end

    end

    # A collection of OSM tags which can be attached to a Node, Way,
    # or Relation.
    # It is a subclass of Hash.
    class Tags < Hash

        # Return XML for these tags. This method uses the Builder library.
        # The only parameter ist the builder object.
        def to_xml(xml)
            each do |key, value|
                xml.tag(:k => key, :v => value)
            end
        end

        # Return string with comma separated key=value pairs.
        #
        # call-seq: to_s -> String
        #
        def to_s
            sort.collect{ |k, v| "#{k}=#{v}" }.join(', ')
        end

    end

end

