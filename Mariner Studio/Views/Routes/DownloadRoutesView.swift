//
//  DownloadRoutesView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/23/25.
//


import SwiftUI

struct DownloadRoutesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Download Routes")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This feature will allow you to download pre-planned routes from various sources.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Coming Soon:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Download routes from online repositories")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Import from popular navigation platforms")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Browse community-shared routes")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Sync with cloud storage services")
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
        .navigationTitle("Download Routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}