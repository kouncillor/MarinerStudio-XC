


import Foundation
import MapKit

// MARK: - NavObject Extensions

extension NavObject {
    // Helper property to get a unique identifier for the annotation
    var uniqueIdentifier: String {
        return "\(type.rawValue)-\(coordinate.latitude)-\(coordinate.longitude)"
    }
    
    // Helper property to get a human-readable title
    var title: String? {
        switch type {
        case .navunit:
            if let annotation = self as? NavUnitAnnotation {
                return annotation.navUnit.navUnitName
            }
        case .tidalheightstation:
            if let annotation = self as? TidalHeightStationAnnotation {
                return annotation.station.name
            }
        case .tidalcurrentstation:
            if let annotation = self as? TidalCurrentStationAnnotation {
                return annotation.station.name
            }
        }
        return nil
    }
    
    // Helper property to get a human-readable subtitle
    var subtitle: String? {
        switch type {
        case .navunit:
            if let annotation = self as? NavUnitAnnotation {
                return annotation.navUnit.cityOrTown
            }
        case .tidalheightstation:
            if let annotation = self as? TidalHeightStationAnnotation {
                return annotation.station.state
            }
        case .tidalcurrentstation:
            if let annotation = self as? TidalCurrentStationAnnotation {
                return annotation.station.state
            }
        }
        return nil
    }
    
    // Helper method to check if an annotation is visible in a map region
    func isVisibleIn(region: MKCoordinateRegion) -> Bool {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon && coordinate.longitude <= maxLon
    }
}

// MARK: - Hashable Conformance

extension NavObject: Hashable {
    static func == (lhs: NavObject, rhs: NavObject) -> Bool {
        return lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueIdentifier)
    }
}

// MARK: - Performance Optimizations

extension Array where Element == NavObject {
    // Filter annotations by type efficiently
    func filterByType(_ type: NavObject.NavObjectType) -> [NavObject] {
        return self.filter { $0.type == type }
    }
    
    // Filter annotations by region efficiently
    func visibleIn(region: MKCoordinateRegion) -> [NavObject] {
        return self.filter { $0.isVisibleIn(region: region) }
    }
    
    // Calculate visible center point efficiently
    func calculateVisibleCenter() -> CLLocationCoordinate2D? {
        guard !self.isEmpty else { return nil }
        
        var totalLat: Double = 0
        var totalLon: Double = 0
        
        for annotation in self {
            totalLat += annotation.coordinate.latitude
            totalLon += annotation.coordinate.longitude
        }
        
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(self.count),
            longitude: totalLon / Double(self.count)
        )
    }
    
    // Calculate the appropriate zoom level (span) for the annotations
    func calculateAppropriateSpan(edgePadding: Double = 0.1) -> MKCoordinateSpan? {
        guard !self.isEmpty else { return nil }
        
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        for annotation in self {
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLon = min(minLon, annotation.coordinate.longitude)
            maxLon = max(maxLon, annotation.coordinate.longitude)
        }
        
        let latDelta = maxLat - minLat
        let lonDelta = maxLon - minLon
        
        return MKCoordinateSpan(
            latitudeDelta: max(latDelta * (1 + edgePadding), 0.01),
            longitudeDelta: max(lonDelta * (1 + edgePadding), 0.01)
        )
    }
    
    // Create a region that contains all annotations
    func calculateRegion(edgePadding: Double = 0.1) -> MKCoordinateRegion? {
        guard let center = calculateVisibleCenter(),
              let span = calculateAppropriateSpan(edgePadding: edgePadding) else {
            return nil
        }
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

