
import SwiftUI

// A view to draw the wave direction arrow (cyan, points inward)
struct WaveArrowView: View {
    var body: some View {
        // This ZStack layers the arrow and the icon together, so they move as one unit.
        ZStack {
            // This is the original arrow structure
            VStack(spacing: 0) {
                // Arrow Shaft
                Rectangle()
                    .frame(width: 3, height: 50) // length of the arrow
                    .foregroundColor(.cyan)

                // Arrow Head using a system image
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
            }

        }
        // Offset the whole arrow group so its tail starts just inside the compass ring
        .offset(y: -70)
    }
}

// NEW: A view to draw the vessel's heading arrow (green, points outward)
struct VesselHeadingArrowView: View {
    var body: some View {
        // This ZStack layers the arrow and the text label together
        ZStack {
            // This view draws a static arrow pointing outwards from the center.
            // It does not rotate.
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
            
            // New label for "Course Steered True"
            Text("CST°")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .rotationEffect(.degrees(-90)) // Makes text vertical
                // *** CHANGED: The x offset is now negative to move the label to the left side ***
                .offset(x: -11, y: 5)         // Positions the text left of and along the shaft
        }
        // Offset the arrow so its base is at the center of the compass
        .offset(y: -77)
    }
}


struct WaveDirectionDisplayView: View {
    @State private var vesselCourse: String = ""
    @State private var directionWavesFrom: String = ""
    @FocusState private var isInputFocused: Bool
    
    // Computed property to get vessel course as Double for rotation
    private var vesselCourseValue: Double {
        return Double(vesselCourse) ?? 0.0
    }
    
    // Computed property to get the wave direction as Double for the arrow's rotation
    private var waveDirectionValue: Double? {
        // Return nil if the string is empty or not a valid number
        return Double(directionWavesFrom)
    }
    
    // Computed property to format the course display
    private var formattedCourse: String {
        let courseValue = Int(vesselCourseValue)
        return String(format: "%03d", courseValue)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Compass
            ZStack {
                // This ZStack contains all the elements that rotate with the vessel's course
                ZStack {
                    // Compass markers (rotated)
                    ForEach(Marker.markers(), id: \.self) { marker in
                        CompassMarkerView(marker: marker, compassDegrees: vesselCourseValue)
                    }
                    
                    // Wave direction arrow (cyan, rotates with compass)
                    if let waveDirection = waveDirectionValue {
                        WaveArrowView()
                            .rotationEffect(.degrees(waveDirection))
                    }
                }
                .rotationEffect(Angle(degrees: -vesselCourseValue)) // Rotate entire compass ring
                
                // Centered course display (stationary)
                VStack(spacing: 2) {
                    // The vessel's course, with the degree symbol removed
                    Text("\(formattedCourse)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.green)
                .padding(20) // 1. Adds space around the text
                .background(   // 2. Adds a layer behind the text
                    Circle()   // 3. The shape of the background is a circle
                        .stroke(Color.orange, lineWidth: 4) // 4. Style the circle as a 2-point gray line
                )
                
                // NEW: Vessel heading arrow (green, stationary, points up)
                VesselHeadingArrowView()
            }
            .frame(width: 300, height: 300)
            // Add a gray border around the entire compass ZStack
            .overlay(
                Circle()
                    .stroke(Color.gray, lineWidth: 5)
            )
            
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
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                }
                
                // Direction Waves From
                HStack {
                    Text("Direction Waves From")
                        .font(.headline)
                        .frame(width: 150, alignment: .leading)
                    
                    TextField("Enter direction", text: $directionWavesFrom)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                }
            }
            .padding(.horizontal)
            // Add a toolbar with a "Done" button for the keyboard
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                }
            }
            
            Spacer()
        }
        .navigationTitle("Wave Direction")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            isInputFocused = false
        }
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
            // Only show degree text if a cardinal label doesn't exist
            if marker.label.isEmpty {
                Text(marker.degreeText())
                    .fontWeight(.light)
                    .rotationEffect(self.textAngle()) // Counter-rotates to stay upright
            }

            Capsule()
                .frame(width: self.capsuleWidth(),
                       height: self.capsuleHeight())
                .foregroundColor(self.capsuleColor())
                .padding(.bottom, 120)

            // Show cardinal direction labels (N, S, E, W)
            Text(marker.label)
                .fontWeight(.bold)
                .rotationEffect(self.textAngle()) // Counter-rotates to stay upright
                .padding(.bottom, 80)
        }
        .rotationEffect(Angle(degrees: marker.degrees))
    }
    
    private func capsuleWidth() -> CGFloat {
        // Make cardinal direction markers slightly wider
        return marker.label.isEmpty ? 2 : 3
    }
    
    private func capsuleHeight() -> CGFloat {
        // Make the North marker taller and other cardinal markers slightly taller
        if marker.degrees == 0 { return 40 }
        if !marker.label.isEmpty { return 30 }
        return 20
    }
    
    private func capsuleColor() -> Color {
        return self.marker.degrees == 0 ? .red : .gray
    }
    
    // FIX: Correctly counter-rotates the text to keep it level with the horizon
    private func textAngle() -> Angle {
        return Angle(degrees: self.compassDegrees - self.marker.degrees)
    }
}

#Preview {
    // Wrap in a NavigationView for better previewing
    NavigationView {
        WaveDirectionDisplayView()
    }
}
