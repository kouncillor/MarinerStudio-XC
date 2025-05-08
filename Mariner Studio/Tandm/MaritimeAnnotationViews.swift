import MapKit

private let tidalStationClusterID = "tidalStation"

class NavUnitAnnotationView: MKMarkerAnnotationView {
    static let ReuseID = "navunitAnnotation"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "navunit"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .defaultLow
        markerTintColor = UIColor.systemBlue // Changed to Blue
        
        // Use the n.circle.fill SF Symbol
        glyphImage = UIImage(systemName: "n.square")
    }
    
}

class TidalHeightStationAnnotationView: MKMarkerAnnotationView {
    static let ReuseID = "tidalheightstationAnnotation"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = tidalStationClusterID
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .defaultLow
        markerTintColor = UIColor.systemGreen // Changed to Blue
        
        // Use the n.circle.fill SF Symbol
        glyphImage = UIImage(systemName: "t.square")
    }
    
}

class TidalCurrentStationAnnotationView: MKMarkerAnnotationView {
    static let ReuseID = "tidalcurrentstationAnnotation"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = tidalStationClusterID
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .defaultHigh
        markerTintColor = UIColor.systemRed // Changed to Red
        glyphImage = UIImage(systemName: "c.square")
        
    }
}

// Also include the ClusterAnnotationView
class MaritimeClusterAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        centerOffset = CGPoint(x: 0, y: -10) // Offset center point to animate better with marker annotations
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        if let cluster = annotation as? MKClusterAnnotation {
            let totalStations = cluster.memberAnnotations.count
            
            if count(maritimeType: .navunit) > 0 {
                image = drawNavUnitCount(count: totalStations) // Renamed method
            } else {
                let tidalCurrentCount = count(maritimeType: .tidalcurrentstation)
                image = drawRatioTidalCurrentToTidalHeight(tidalCurrentCount, to: totalStations) // Renamed method
            }
            
            if count(maritimeType: .navunit) > 0 {
                displayPriority = .defaultLow
            } else {
                displayPriority = .defaultHigh
            }
        }
    }

    private func drawRatioTidalCurrentToTidalHeight(_ currentCount: Int, to totalCount: Int) -> UIImage {
        return drawRatio(currentCount, to: totalCount,
                        fractionColor: UIColor.systemRed, // Changed to Red (Tidal Current)
                        wholeColor: UIColor.systemGreen) // Changed to Green (Tidal Height)
    }

    
    private func drawNavUnitCount(count: Int) -> UIImage {
        return drawRatio(0, to: count, fractionColor: nil,
                        wholeColor: UIColor.systemBlue) // Changed to Blue (NavUnit)
    }

    private func drawRatio(_ fraction: Int, to whole: Int, fractionColor: UIColor?, wholeColor: UIColor?) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        return renderer.image { _ in
            // Fill full circle with wholeColor
            wholeColor?.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 40, height: 40)).fill()

            // Fill pie with fractionColor
            fractionColor?.setFill()
            let piePath = UIBezierPath()
            piePath.addArc(withCenter: CGPoint(x: 20, y: 20), radius: 20,
                           startAngle: 0, endAngle: (CGFloat.pi * 2.0 * CGFloat(fraction)) / CGFloat(whole),
                           clockwise: true)
            piePath.addLine(to: CGPoint(x: 20, y: 20))
            piePath.close()
            piePath.fill()

            // Fill inner circle with white color
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 24, height: 24)).fill()

            // Finally draw count text vertically and horizontally centered
            let attributes = [ NSAttributedString.Key.foregroundColor: UIColor.black,
                               NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20)]
            let text = "\(whole)"
            let size = text.size(withAttributes: attributes)
            let rect = CGRect(x: 20 - size.width / 2, y: 20 - size.height / 2, width: size.width, height: size.height)
            text.draw(in: rect, withAttributes: attributes)
        }
    }

    private func count(maritimeType type: NavObject.NavObjectType) -> Int {
        guard let cluster = annotation as? MKClusterAnnotation else {
            return 0
        }

        return cluster.memberAnnotations.filter { member -> Bool in
            guard let bike = member as? NavObject else {
                fatalError("Found unexpected annotation type")
            }
            return bike.type == type
        }.count
    }
}

