//import SwiftUI

import SwiftUI

struct WaveDirectionDisplayView: View {
    @State private var vesselCourse: String = ""
    @State private var directionWavesFrom: String = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Compass
            ZStack {
                // Compass markers
                ForEach(Marker.markers(), id: \.self) { marker in
                    CompassMarkerView(marker: marker, compassDegrees: 0)
                }
            }
            .frame(width: 300, height: 300)
            
            // Labels and input boxes
            VStack(spacing: 20) {
                // Vessel Course
                HStack {
                    Text("Vessel Course")
                        .font(.headline)
                        .frame(width: 150, alignment: .leading)
                    
                    TextField("Enter course", text: $vesselCourse)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                }
                
                // Direction Waves From
                HStack {
                    Text("Direction Waves From")
                        .font(.headline)
                        .frame(width: 150, alignment: .leading)
                    
                    TextField("Enter direction", text: $directionWavesFrom)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Wave Direction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

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

struct CompassMarkerView: View {
    let marker: Marker
    let compassDegrees: Double

    var body: some View {
        VStack {
            Text(marker.degreeText())
                .fontWeight(.light)
                .rotationEffect(self.textAngle())

            Capsule()
                .frame(width: self.capsuleWidth(),
                       height: self.capsuleHeight())
                .foregroundColor(self.capsuleColor())
                .padding(.bottom, 120)

            Text(marker.label)
                .fontWeight(.bold)
                .rotationEffect(self.textAngle())
                .padding(.bottom, 80)
        }
        .rotationEffect(Angle(degrees: marker.degrees))
    }
    
    private func capsuleWidth() -> CGFloat {
        return self.marker.degrees == 0 ? 7 : 3
    }
    
    private func capsuleHeight() -> CGFloat {
        return self.marker.degrees == 0 ? 45 : 30
    }
    
    private func capsuleColor() -> Color {
        return self.marker.degrees == 0 ? .red : .gray
    }
    
    private func textAngle() -> Angle {
        return Angle(degrees: -self.compassDegrees - self.marker.degrees)
    }
}

#Preview {
    WaveDirectionDisplayView()
}
