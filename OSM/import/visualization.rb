module OsmImport

	module_function
    def solidLine(way, width=0, material=nil)
		if width > 0
			width = width/2
			point1 = nil
			way.nodes.each do |node|
				node = $db.get_node(node)
				point2 = Sketchup.active_model.latlong_to_point [Float(node.lon), Float(node.lat)]
				if !point1.nil?
					lineVector = Geom::Vector3d.new point2[0]-point1[0], point2[1]-point1[1], 0
					# vectorP is perpendicular to lineVector, its length is equal to width
					vectorP = Geom::Vector3d.new lineVector.y, -lineVector.x, 0
					vectorP.length = width
					t1 = Geom::Transformation.translation vectorP
					t2 = Geom::Transformation.translation vectorP.reverse
					face = $entities.add_face point1.transform(t1), point2.transform(t1), point2.transform(t2), point1.transform(t2)
					if !face.nil?
						# hide face edges
						for edge in face.edges
							edge.hidden = true
						end
						if !material.nil?
							face.material = material
							face.back_material = material
						end
					end
				end
				point1 = point2
			end
		else
			sketchupLine(way)
		end
    end
    
    def sketchupLine(way)
        point1 = nil
        way.nodes.each do |node|
            node = $db.get_node(node)
            point2 = Sketchup.active_model.latlong_to_point [Float(node.lon), Float(node.lat)]
            if !point1.nil?
                line = $entities.add_line point1,point2
            end
            point1 = point2
        end
    end

    def face(way, material=nil)
		vertices = []
        way.nodes.each do |node|
            node = $db.get_node(node)
            point = Sketchup.active_model.latlong_to_point [Float(node.lon), Float(node.lat)]
            if !point.nil?
                vertices << point
            end
        end
        face = $entities.add_face vertices
		if !face.nil?
			# hide face edges
			for edge in face.edges
				edge.hidden = true
			end
			if !material.nil?
				face.material = material
				face.back_material = material
			end
		end
	end
end
