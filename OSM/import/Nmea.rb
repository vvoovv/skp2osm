require "OSM/import/Gps"

module OsmImport

	class Nmea < OsmImport::Gps
	
		# This method is called by SketchUp to determine the description that
		# appears in the File > Import dialog's pulldown list of valid
		# importers. 
		def description
			return "NMEA Importer (*.txt)"
		end
		
		# This method is called by SketchUp to determine what file extension
		# is associated with your importer.
		def file_extension
			return "txt"
		end
		
		# This method is called by SketchUp to get a unique importer id.
		def id
			return "com.sketchup.importers.nmea"
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
	
		protected
		def _load_file(file_path, status)
			super(file_path, status)
			@currentWay = []
			@ways << @currentWay
			# inputFile will be automatically terminated because block is given
			File.open(file_path, 'r') do |inputFile|
				while line = inputFile.gets
					strs = line.split(',')
					header = strs[0]
					if header=='$GPRMC' and strs[2]=='A' # i.e. status==[data valid]
						lat = strs[3]
						lat = Float(lat[0..1]) + Float(lat[2..-1])/60
						if strs[4] == 'S'
							lat = -lat
						end
						lon = strs[5]
						lon = Float(lon[0..2]) + Float(lon[3..-1])/60
						if strs[6] == 'W'
							lon = -lon
						end
						processLonLat(lon, lat)
					end
				end
			end
			return 0 # 0 is the code for a successful import
		end
	
	end

end
Sketchup.register_importer(OsmImport::Nmea.new)
