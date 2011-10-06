require "OSM/rexml/document"
require "OSM/import/Gps"

module OsmImport

	class Gpx < OsmImport::Gps
	
		# This method is called by SketchUp to determine the description that
		# appears in the File > Import dialog's pulldown list of valid
		# importers. 
		def description
			return "GPX Importer (*.gpx)"
		end
		
		# This method is called by SketchUp to determine what file extension
		# is associated with your importer.
		def file_extension
			return "gpx"
		end
		
		# This method is called by SketchUp to get a unique importer id.
		def id
			return "com.sketchup.importers.gpx"
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
			doc = REXML::Document.new File.new(file_path)
			doc.elements.each("gpx/trk/trkseg") do |singleTrack|
				@currentWay = []
				singleTrack.elements.each("trkpt") do |node|
					lon = Float(node.attributes["lon"])
					lat = Float(node.attributes["lat"])
					processLonLat(lon, lat)
				end
				if @currentWay.length > 1
					@ways << @currentWay
				end
			end
			return 0 # 0 is the code for a successful import
		end
	
	end

end
Sketchup.register_importer(OsmImport::Gpx.new)
