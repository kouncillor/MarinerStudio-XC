//
//  CreateRouteView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/23/25.
//

import SwiftUI

struct CreateRouteView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var routeName: String = ""
    @State private var showingMapView = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)

                    Text("Create New Route")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)

                Text("Plan your navigation route by selecting waypoints on an interactive nautical chart with heading and distance calculations.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color.white)

            Spacer()

            // Route Name Input
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route Name")
                        .font(.headline)
                        .foregroundColor(.primary)

                    TextField("Enter route name (e.g., 'Baltimore to Annapolis')", text: $routeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .onChange(of: routeName) { oldValue, newValue in
                            print("📝 CreateRouteView: Route name changed from '\(oldValue)' to '\(newValue)'")
                            print("📝 CreateRouteView: Trimmed route name: '\(newValue.trimmingCharacters(in: .whitespacesAndNewlines))'")
                        }
                }

                Button("Start Creating Route") {
                    let trimmedName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🚀 CreateRouteView: Start Creating Route button tapped")
                    print("🚀 CreateRouteView: Route name validation - original: '\(routeName)', trimmed: '\(trimmedName)', isEmpty: \(trimmedName.isEmpty)")

                    if !trimmedName.isEmpty {
                        print("✅ CreateRouteView: Route name validation passed - proceeding to map view")
                        showingMapView = true
                    } else {
                        print("❌ CreateRouteView: Route name validation failed - empty route name")
                    }
                }
                .disabled(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding()
                .frame(maxWidth: .infinity)
                .background(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
                .onChange(of: routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { _, newValue in
                    print("🎛️ CreateRouteView: Button enabled state changed - disabled: \(newValue)")
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Enhanced Instructions with Leg Information
            VStack(spacing: 12) {
                Text("Features:")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(
                        icon: "map.fill",
                        text: "Official NOAA nautical charts with depths & hazards"
                    )

                    InstructionRow(
                        icon: "hand.tap.fill",
                        text: "Tap anywhere on the map to add waypoints"
                    )

                    InstructionRow(
                        icon: "ruler.fill",
                        text: "View true headings and distances between waypoints"
                    )

                    InstructionRow(
                        icon: "pencil.circle.fill",
                        text: "Name and reorder waypoints as needed"
                    )

                    InstructionRow(
                        icon: "square.and.arrow.up.fill",
                        text: "Export as GPX file when complete"
                    )
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("Create Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.orange, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        .navigationDestination(isPresented: $showingMapView) {
            RouteCreationMapView(routeName: routeName, serviceProvider: serviceProvider)
        }
        .onAppear {
            print("📍 CreateRouteView: View appeared")
            print("📍 CreateRouteView: Current route name: '\(routeName)'")
            print("📍 CreateRouteView: Service provider available: \(serviceProvider != nil)")
        }
        .onDisappear {
            print("📍 CreateRouteView: View disappeared")
        }
    }
}

// MARK: - Helper Views

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)

            Text(text)
                .foregroundColor(.primary)

            Spacer()
        }
        .onAppear {
            print("📋 InstructionRow: Displayed instruction - icon: '\(icon)', text: '\(text)'")
        }
    }
}
