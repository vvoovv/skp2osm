require "OSM/StreamParser"
require "OSM/import/base"

module OsmImport
	class Osm < OsmImport::Base

		attr_accessor :_nodes
		attr_accessor :_ways
	
		# This method is called by SketchUp to determine the description that
		# appears in the File > Import dialog's pulldown list of valid
		# importers. 
		def description
			return "OpenStreetMap Importer (*.osm)"
		end
	  
		# This method is called by SketchUp to determine what file extension
		# is associated with your importer.
		def file_extension
			return "osm"
		end
	  
		# This method is called by SketchUp to get a unique importer id.
		def id
			return "com.sketchup.importers.osm"
		end
	  
		# This method is called by SketchUp to determine if the "Options"
		# button inside the File > Import dialog should be enabled while your
		# importer is selected.
		def supports_options?
			return false
		end
	  
		# This method is called by SketchUp when the user clicks on the
		# "Options" button inside the File > Import dialog. You can use it to
		# gather and store settings for your importer.
		def do_options
			# In a real use you would probably store this information in an
			# instance variable.
			#my_settings = UI.inputbox(['My Import Option:'], ['1'], "Import Options")
		end
		
		def commit()
			if !@nodes.nil?
				@_nodes.each do |node|
					node.instance_eval(&@nodes)
				end
			end
			
			if !@ways.nil?
				@_ways.each do |way|
					way.instance_eval(&@ways)
				end
			end
		end

        private

		def setup()
			yield
		end
		
		def nodes(&block)
			@nodes = block
		end
		
		def ways(&block)
			@ways = block
		end
		
		def relations(&block)
			@relations = block
		end
		
		protected
		def _load_file(file_path, status)
            @_nodes = []
            @_ways = []
            @nodes = nil
            @ways = nil
            
            $db = OSM::Database.new
            # load rules
            self.instance_eval(File.read(@@osmRuleFileName), @@osmRuleFileName)
            parser = OSM::StreamParser.new(:filename => file_path, :db => $db, :callbacks => OsmImport::Callbacks.new(self))
            parser.parse()
		end
	end
	
	
    class Callbacks < OSM::Callbacks

        def initialize(mapper)
            super()
            @mapper = mapper
            @validElement = true
        end

        # This method is called by the parser whenever an OSM::Node has been parsed.
        def node(node)  # :nodoc:
            lon = Float(node.lon)
            lat = Float(node.lat)
            # update bbox
			@mapper.updateBbox(lon, lat)
            @mapper._nodes << node
            true
        end

        # This method is called by the parser whenever an OSM::Way has been parsed.
        def way(way)
            @mapper._ways << way
            false
        end
        
        def _start_node(attr_hash)
            if !attr_hash["action"].nil? && attr_hash["action"] == "delete"
                @validElement = false
            end
            super(attr_hash)
        end

        def _end_node()
            if @validElement == true
                super()
            else
                @validElement = true
            end
        end
        
        def _start_way(attr_hash)
            if !attr_hash['action'].nil? && attr_hash['action'] == "delete"
				@validElement = false
            end
            super(attr_hash)
        end

        def _end_way()
            if @validElement == true
                super()
            else
                @validElement = true
            end
        end

    end	

end
Sketchup.register_importer(OsmImport::Osm.new)
