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
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Create New Route")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Plan your navigation route by selecting waypoints on an interactive map.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
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
                }
                
                Button("Start Creating Route") {
                    showingMapView = true
                }
                .disabled(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding()
                .frame(maxWidth: .infinity)
                .background(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Instructions
            VStack(spacing: 12) {
                Text("Next Steps:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(
                        icon: "hand.tap.fill",
                        text: "Tap anywhere on the map to add waypoints"
                    )
                    
                    InstructionRow(
                        icon: "pencil.circle.fill",
                        text: "Name each waypoint as you create it"
                    )
                    
                    InstructionRow(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Reorder or delete waypoints as needed"
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
        .withHomeButton()
        .navigationDestination(isPresented: $showingMapView) {
            RouteCreationMapView(routeName: routeName, serviceProvider: serviceProvider)
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
    }
}
