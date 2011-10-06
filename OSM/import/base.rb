require "OSM/import/visualization.rb"

module OsmImport

	class Base < Sketchup::Importer

		# This method is called by SketchUp after the user has selected a file
		# to import. This is where you do the real work of opening and
		# processing the file.
		def load_file(file_path, status)
			if not File.file?(file_path)
				UI.messagebox("Sorry, non-latin characters in the file path are not supported!")
				return -1
			end
			@bbox = {"left" => 180, "bottom" => 90, "right" => -180, "top" => -90}
			@bboxOk = false
			_load_file(file_path, status)
	
			if @bboxOk==false
				UI.messagebox("Nothing to import")
				return 0
			end
			prepareSketchup(file_path)
			model = Sketchup.active_model
			# perform georeferencing only if it hasn't been performed through one of previous imports
			if model.attribute_dictionaries['OpenStreetMap'].nil?
				model.shadow_info["Latitude"] = (@bbox["bottom"] + @bbox["top"])/2
				model.shadow_info["Longitude"] = (@bbox["left"] + @bbox["right"])/2
				# create attribute dictionary
				model.attribute_dictionary "OpenStreetMap", true
			end
			commit()
			model.active_layer = @active_layer
			return 0 # 0 is the code for a successful import
		end
		
		def prepareSketchup(file_path)
			model = Sketchup.active_model
			layers = model.layers
			osm_layer = layers.add(layers.unique_name "OSM:#{File.basename(file_path)}")
			@active_layer = model.active_layer
			model.active_layer = osm_layer
			group = model.active_entities.add_group
			# attribute "OpenStreetMap" means that the model wouldn't be exported to OSM fil
			group.attribute_dictionary "OpenStreetMap", true
			$entities = group.entities
		end
		
		def updateBbox(lon, lat)
			# update bbox
			if lon < @bbox["left"]
				@bbox["left"] = lon
			elsif lon > @bbox["right"]
				@bbox["right"] = lon
			end
			if lat < @bbox["bottom"]
				@bbox["bottom"] = lat
			elsif lat > @bbox["top"]
				@bbox["top"] = lat
			end
			if @bboxOk==false
				@bboxOk = true
			end
		end
			
		protected
		def _load_file(file_path, status)
			
		end
	end

end

