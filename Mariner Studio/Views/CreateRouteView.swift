//
//  CreateRouteView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/23/25.
//


import SwiftUI

struct CreateRouteView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "plus.circle")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Create New Route")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Plan and create custom navigation routes with waypoints, estimated times, and route optimization.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Planned Features:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.orange)
                        Text("Interactive waypoint selection on map")
                    }
                    
                    HStack {
                        Image(systemName: "clock.circle.fill")
                            .foregroundColor(.orange)
                        Text("Automatic ETA calculations")
                    }
                    
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .foregroundColor(.orange)
                        Text("Route optimization algorithms")
                    }
                    
                    HStack {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .foregroundColor(.orange)
                        Text("Export to GPX format")
                    }
                    
                    HStack {
                        Image(systemName: "water.waves.circle.fill")
                            .foregroundColor(.orange)
                        Text("Integration with tide and weather data")
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Create Route")
        .navigationBarTitleDisplayMode(.inline)
    }
}