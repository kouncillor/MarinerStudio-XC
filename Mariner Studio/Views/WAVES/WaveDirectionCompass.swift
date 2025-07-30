//
//  WaveDirectionCompass.swift
//  Mariner Studio
//
//  Compact wave direction compass for route details
//

import SwiftUI

struct WaveDirectionCompass: View {
    let vesselCourse: Double
    let waveDirection: Double
    let compassSize: CGFloat

    // Default initializer with standard size
    init(vesselCourse: Double, waveDirection: Double, compassSize: CGFloat = 120) {
        self.vesselCourse = vesselCourse
        self.waveDirection = waveDirection
        self.compassSize = compassSize
    }

    // Computed property to format the course display
    private var formattedCourse: String {
        let courseValue = Int(vesselCourse)
        return String(format: "%03d", courseValue)
    }

    var body: some View {
        ZStack {
            // Rotating compass elements (markers and wave arrow)
            ZStack {
                // Compass markers
                ForEach(Marker.markers(), id: \.self) { marker in
                    CompassMarkerView(marker: marker, compassDegrees: vesselCourse)
                }

                // Wave direction arrow (cyan, rotates with compass)
                WaveArrowView()
                    .rotationEffect(.degrees(waveDirection))
            }
            .rotationEffect(Angle(degrees: -vesselCourse)) // Rotate entire compass ring

            // Centered course display (stationary)
            VStack(spacing: 2) {
                Text("\(formattedCourse)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(.green)
            .padding(12)
            .background(
                Circle()
                    .stroke(Color.orange, lineWidth: 3)
            )

            // Vessel heading arrow (green, stationary, points up)
            VesselHeadingArrowView()
        }
        .frame(width: compassSize, height: compassSize)
        .overlay(
            Circle()
                .stroke(Color.gray, lineWidth: 3)
        )
    }
}
