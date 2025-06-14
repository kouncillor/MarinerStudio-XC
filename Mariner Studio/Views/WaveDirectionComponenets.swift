//
//  WaveDirectionComponents.swift
//  Mariner Studio
//
//  Shared components for wave direction compass displays
//

import SwiftUI

// MARK: - Wave Direction Arrow (Cyan, points inward)
struct WaveArrowView: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Arrow Shaft
                Rectangle()
                    .frame(width: 3, height: 50)
                    .foregroundColor(.cyan)

                // Arrow Head using SF Symbol
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
            }
        }
        // Offset so arrow tail starts just inside compass ring
        .offset(y: -70)
    }
}

// MARK: - Vessel Heading Arrow (Green, points outward)
struct VesselHeadingArrowView: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Arrow Head
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                // Arrow Shaft
                Rectangle()
                    .frame(width: 3, height: 58)
                    .foregroundColor(.green)
            }
            
            // Course Steered True label
            Text("CST°")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .rotationEffect(.degrees(-90)) // Makes text vertical
                .offset(x: -11, y: 5) // Positions text left of shaft
        }
        // Offset so arrow base is at center of compass
        .offset(y: -77)
    }
}

// MARK: - Compass Marker Data Structure
struct Marker: Hashable {
    let degrees: Double
    let label: String

    init(degrees: Double, label: String = "") {
        self.degrees = degrees
        self.label = label
    }

    func degreeText() -> String {
        return String(format: "%.0f", self.degrees)
    }

    static func markers() -> [Marker] {
        return [
            Marker(degrees: 0),
            Marker(degrees: 30),
            Marker(degrees: 60),
            Marker(degrees: 90),
            Marker(degrees: 120),
            Marker(degrees: 150),
            Marker(degrees: 180),
            Marker(degrees: 210),
            Marker(degrees: 240),
            Marker(degrees: 270),
            Marker(degrees: 300),
            Marker(degrees: 330)
        ]
    }
}

// MARK: - Individual Compass Marker View
struct CompassMarkerView: View {
    let marker: Marker
    let compassDegrees: Double

    var body: some View {
        VStack {
            // Show degree numbers for non-cardinal directions
            if marker.label.isEmpty {
                Text(marker.degreeText())
                    .fontWeight(.light)
                    .rotationEffect(textAngle()) // Counter-rotate to stay upright
            }

            // Marker line
            Capsule()
                .frame(width: capsuleWidth(), height: capsuleHeight())
                .foregroundColor(capsuleColor())
                .padding(.bottom, 120)

            // Show cardinal direction labels (N, S, E, W)
            Text(marker.label)
                .fontWeight(.bold)
                .rotationEffect(textAngle()) // Counter-rotate to stay upright
                .padding(.bottom, 80)
        }
        .rotationEffect(Angle(degrees: marker.degrees))
    }
    
    // MARK: - Private Helper Methods
    
    private func capsuleWidth() -> CGFloat {
        // Make cardinal direction markers slightly wider
        return marker.label.isEmpty ? 2 : 3
    }
    
    private func capsuleHeight() -> CGFloat {
        // Make North marker taller, other cardinals slightly taller
        if marker.degrees == 0 { return 40 }
        if !marker.label.isEmpty { return 30 }
        return 20
    }
    
    private func capsuleColor() -> Color {
        return marker.degrees == 0 ? .red : .gray
    }
    
    // Counter-rotate text to keep it level with horizon
    private func textAngle() -> Angle {
        return Angle(degrees: compassDegrees - marker.degrees)
    }
}
