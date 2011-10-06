# Contains the OSM::API class

require 'net/http'
require 'OSM'
require 'OSM/objects'
require "OSM/StreamParser"

module OSM

    # Unspecified OSM API error.
    class APIError < StandardError; end

    # The API returned more than one OSM object where it should only have returned one.
    class APITooManyObjects < APIError; end

    # The API returned HTTP 400 (Bad Request).
    class APIBadRequest < APIError; end # 400

    # The API operation wasn't authorized. This happens if you didn't set the user and
    # password for a write operation.
    class APIUnauthorized < APIError; end # 401

    # The object was not found (HTTP 404). Generally means that the object doesn't exist
    # and never has.
    class APINotFound < APIError; end # 404

    # The object was not found (HTTP 410), but it used to exist. This generally means
    # that the object existed at some point, but was deleted.
    class APIGone < APIError; end # 410

    # Unspecified API server error.
    class APIServerError < APIError; end # 500

    # The OSM::API class handles all calls to the OpenStreetMap API.
    #
    # Usage:
    #   require 'OSM/API'
    #
    #   @api = OSM::API.new
    #   node = @api.get_node(3437)
    #
    # In most cases you can use the more convenient methods on the OSM::Node, OSM::Way,
    # or OSM::Relation objects.
    #
    class API

        # the default base URI for the API
        DEFAULT_BASE_URI = 'http://www.openstreetmap.org/api/0.6/'

        # Creates a new API object. Without any arguments it uses the default API at
        # DEFAULT_BASE_URI. If you want to use a different API, give the base URI
        # as parameter to this method.
        def initialize(uri=DEFAULT_BASE_URI)
            @base_uri = uri
        end

        # Get an object ('node', 'way', or 'relation') with specified ID from API.
        #
        # call-seq: get_object(type, id) -> OSM::Object
        #
        def get_object(type, id)
            raise ArgumentError.new("type needs to be one of 'node', 'way', and 'relation'") unless type =~ /^(node|way|relation)$/
            raise TypeError.new('id needs to be a positive integer') unless(id.kind_of?(Fixnum) && id > 0)
            response = get("#{type}/#{id}")
            check_response_codes(response)
            parser = OSM::StreamParser.new(:string => response.body, :callbacks => OSM::ObjectListCallbacks.new)
            list = parser.parse
            raise APITooManyObjects if list.size > 1
            list[0]
        end

        # Get a node with specified ID from API.
        #
        # call-seq: get_node(id) -> OSM::Node
        #
        def get_node(id)
            get_object('node', id)
        end

        # Get a way with specified ID from API.
        #
        # call-seq: get_node(id) -> OSM::Way
        #
        def get_way(id)
            get_object('way', id)
        end

        # Get a relation with specified ID from API.
        #
        # call-seq: get_node(id) -> OSM::Relation
        #
        def get_relation(id)
            get_object('relation', id)
        end

        # Get all ways using the node with specified ID from API.
        #
        # call-seq: get_ways_using_node(id) -> Array of OSM::Way
        #
        def get_ways_using_node(id)
            api_call(id, "node/#{id}/ways")
        end

        # Get all relations which refer to the object of specified type and with specified ID from API.
        #
        # call-seq: get_relations_referring_to_object(type, id) -> Array of OSM::Relation
        #
        def get_relations_referring_to_object(type, id)
            api_call_with_type(type, id, "#{type}/#{id}/relations")
        end

        # Get all historic versions of an object of specified type and with specified ID from API.
        #
        # call-seq: get_history(type, id) -> Array of OSM::Object
        #
        def get_history(type, id)
            api_call_with_type(type, id, "#{type}/#{id}/history")
        end

        # Get all objects in the bounding box (bbox) given by the left, bottom, right, and top
        # parameters. They will be put into a OSM::Database object which is returned.
        #
        # call-seq: get_bbox(left, bottom, right, top) -> OSM::Database
        #
        def get_bbox(left, bottom, right, top)
            raise TypeError.new('"left" value needs to be a number between -180 and 180') unless(left.kind_of?(Float) && left >= -180 && left <= 180)
            raise TypeError.new('"bottom" value needs to be a number between -90 and 90') unless(bottom.kind_of?(Float) && bottom >= -90 && bottom <= 90)
            raise TypeError.new('"right" value needs to be a number between -180 and 180') unless(right.kind_of?(Float) && right >= -180 && right <= 180)
            raise TypeError.new('"top" value needs to be a number between -90 and 90') unless(top.kind_of?(Float) && top >= -90 && top <= 90)
            response = get("map?bbox=#{left},#{bottom},#{right},#{top}")
            check_response_codes(response)
            db = OSM::Database.new
            parser = OSM::StreamParser.new(:string => response.body, :db => db)
            parser.parse
            db
        end

        private

        def api_call_with_type(type, id, path)
            raise ArgumentError.new("type needs to be one of 'node', 'way', and 'relation'") unless type =~ /^(node|way|relation)$/
            api_call(id, path)
        end

        def api_call(id, path)
            raise TypeError.new('id needs to be a positive integer') unless(id.kind_of?(Fixnum) && id > 0)
            response = get(path)
            check_response_codes(response)
            parser = OSM::StreamParser.new(:string => response.body, :callbacks => OSM::ObjectListCallbacks.new)
            parser.parse
        end

        def get(suffix)
            uri = URI.parse(@base_uri + suffix)
            request = Net::HTTP.new(uri.host, uri.port)
            request.get(uri.request_uri)
        end

        def check_response_codes(response)
            case response.code.to_i
                when 200 then return
                when 404 then raise APINotFound
                when 410 then raise APIGone
                when 500 then raise APIServerError
                else raise APIError
            end
        end

    end

end

