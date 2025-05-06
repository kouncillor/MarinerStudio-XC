import MapKit

// Optimized version of the ClusterAnnotationView with caching
class MapClusterAnnotationView: MKAnnotationView {
    // Cache for rendered cluster images - static so it persists for the app lifetime
    private static var imageCache: [String: UIImage] = [:]
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        centerOffset = CGPoint(x: 0, y: -10) // Offset center point to animate better with marker annotations
        
        // Performance optimizations
        displayPriority = .defaultHigh
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        
        // Get counts of each type in the most efficient way
        let (navUnitCount, tidalHeightCount, tidalCurrentCount) = getCounts(from: cluster)
        let totalCount = cluster.memberAnnotations.count
        
        // Create a cache key based on the counts
        let cacheKey = "\(navUnitCount)-\(tidalHeightCount)-\(tidalCurrentCount)-\(totalCount)"
        
        // Check if we already have this image cached
        if let cachedImage = MapClusterAnnotationView.imageCache[cacheKey] {
            self.image = cachedImage
        } else {
            // Generate and cache the image
            let newImage: UIImage
            
            if navUnitCount > 0 {
                newImage = drawNavUnitCount(count: totalCount) // Renamed method
            } else {
                newImage = drawRatioTidalCurrentToTidalHeight(tidalCurrentCount, to: totalCount) // Renamed method
            }
            
            // Cache the new image
            MapClusterAnnotationView.imageCache[cacheKey] = newImage
            self.image = newImage
        }
        
        // Set display priority based on types - giving navunits lower priority
        // so other annotations are more visible when zoomed out
        if navUnitCount > 0 {
            displayPriority = .defaultLow
        } else {
            displayPriority = .defaultHigh
        }
    }

    // Renamed from drawRatioBicycleToTricycle
    private func drawRatioTidalCurrentToTidalHeight(_ currentCount: Int, to totalCount: Int) -> UIImage {
        return drawRatio(currentCount, to: totalCount,
                        fractionColor: UIColor.systemRed, // Changed to Red (Tidal Current)
                        wholeColor: UIColor.systemGreen) // Changed to Green (Tidal Height)
    }

    // Renamed from drawUnicycleCount
    private func drawNavUnitCount(count: Int) -> UIImage {
        return drawRatio(0, to: count, fractionColor: nil,
                        wholeColor: UIColor.systemBlue) // Changed to Blue (NavUnit)
    }

    private func drawRatio(_ fraction: Int, to whole: Int, fractionColor: UIColor?, wholeColor: UIColor?) -> UIImage {
        // For extremely large clusters, cap the displayed number to improve performance
        let displayCount = min(whole, 999)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        return renderer.image { _ in
            // Fill full circle with wholeColor
            wholeColor?.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 40, height: 40)).fill()

            // Fill pie with fractionColor
            if let fractionColor = fractionColor, fraction > 0 {
                fractionColor.setFill()
                let piePath = UIBezierPath()
                piePath.addArc(withCenter: CGPoint(x: 20, y: 20), radius: 20,
                               startAngle: 0, endAngle: (CGFloat.pi * 2.0 * CGFloat(fraction)) / CGFloat(whole),
                               clockwise: true)
                piePath.addLine(to: CGPoint(x: 20, y: 20))
                piePath.close()
                piePath.fill()
            }

            // Fill inner circle with white color
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 24, height: 24)).fill()

            // Finally draw count text vertically and horizontally centered
            // Use smaller font for large numbers
            let fontSize: CGFloat = displayCount < 100 ? 20 : 16
            let attributes = [ NSAttributedString.Key.foregroundColor: UIColor.black,
                              NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: fontSize)]
            
            // Format the text with a + for very large numbers
            let text = displayCount < 999 ? "\(displayCount)" : "999+"
            let size = text.size(withAttributes: attributes)
            let rect = CGRect(x: 20 - size.width / 2, y: 20 - size.height / 2, width: size.width, height: size.height)
            text.draw(in: rect, withAttributes: attributes)
        }
    }

    // Optimized method to count different types of annotations
    private func getCounts(from cluster: MKClusterAnnotation) -> (navUnits: Int, tidalHeight: Int, tidalCurrent: Int) {
        var navUnitCount = 0
        var tidalHeightCount = 0
        var tidalCurrentCount = 0
        
        // Use a faster approach without extra allocations
        for case let navObject as NavObject in cluster.memberAnnotations {
            switch navObject.type {
            case .navunit:
                navUnitCount += 1
            case .tidalheightstation:
                tidalHeightCount += 1
            case .tidalcurrentstation:
                tidalCurrentCount += 1
            }
        }
        
        return (navUnitCount, tidalHeightCount, tidalCurrentCount)
    }
}
