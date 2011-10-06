require "OSM/import/base"

module OsmImport
	
	class Gps < OsmImport::Base
	
		def processLonLat(lon, lat)
			updateBbox(lon, lat)
			@currentWay << {'lon'=>lon, 'lat'=>lat}
		end
		
		def commit()
			point1 = nil
			for way in @ways
				for node in way
					point2 = Sketchup.active_model.latlong_to_point [Float(node['lon']), Float(node['lat'])]
					if !point1.nil?
						line = $entities.add_line point1,point2
					end
					point1 = point2
				end
			end
		end
		
		protected
		def _load_file(file_path, status)
			super(file_path, status)
			# each way is an array on nodes
			@ways = []
			@currentWay = nil
		end
	end

end

