$: << File.expand_path(File.dirname(__FILE__) + "/OSM")

require "sketchup.rb"

# basic settings
require "OSM/settings/basic"
# user specific settings
require "OSM/settings/user"

# importers
require "OSM/import/Osm"
require "OSM/import/Nmea"
require "OSM/import/Gpx"

# export stuff
require "OSM/export/Osm"
@@exporter = OsmExport::Osm.new()
UI.menu("File").add_item("Export to OpenStreetMap file...") do
  @@exporter.commit()
end