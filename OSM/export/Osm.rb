require 'builder'
require 'rexml/document'
require 'OSM/objects'
require 'OSM/Database'


module OsmExport

    class Osm

        def initialize()
            @entities = Sketchup.active_model.entities
        end

        def commit()
			pathToSaveTo = UI.savepanel "Save file as", "", "from_sketchup.osm"
			if pathToSaveTo.nil?
				# cancel pressed
				return
			end
			if not File.exist?(File.dirname(pathToSaveTo))
				UI.messagebox("Sorry, non-latin characters in the file path are not supported!")
				return -1
			end
            @db = OSM::Database.new
            @nodes_by_coordinate = Hash.new
            # count faces that can be exported
            @numEntities = 0
            processEntities(@entities)
            if @numEntities>0
                outputFile = File.new(pathToSaveTo, "w")
                doc = Builder::XmlMarkup.new(:indent => 2, :target => outputFile)
                doc.instruct!
                @db.to_xml(doc)
                outputFile.close
            end
            UI.messagebox("Success! Now you can open the .osm file in JOSM editor")
        end
        
        protected
        def processEntities(entities)
            for e in entities
                if e.typename == "Face"
					# check if the face is parallel to the XY plane
					z1 = e.vertices[0].position.z
					z2 = e.vertices[1].position.z
					z3 = e.vertices[2].position.z
					if z1 == z2 and z1 == z3
						new_object = OSM::Way.new
						new_object.source = "skp2osm"
						new_object.building = "yes"
						@db << new_object
						firstNode = nil
						for v in e.vertices
							lonlat = Sketchup.active_model.point_to_latlong v.position
							lon = lonlat[0].to_f
							lat = lonlat[1].to_f
							node = @nodes_by_coordinate["#{lon}:#{lat}"]
							if node.nil?
								node = OSM::Node.new(nil, nil, nil, lon, lat)
								@nodes_by_coordinate["#{lon}:#{lat}"] = node
								@db << node
							end
							new_object.nodes << node
							if firstNode.nil?
								firstNode = node
							end
						end
						new_object.nodes << firstNode
						@numEntities = @numEntities + 1
                    end
                elsif e.typename == "Group" and (e.attribute_dictionaries.nil? or e.attribute_dictionaries["OpenStreetMap"].nil?)
					# the last condition means: the group doesn't contain any imported OSM or GPS-track
					processEntities(e.entities)
                end
            end
        end

    end

end