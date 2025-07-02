//
//  DevPageView.swift
//  Mariner Studio
//
//  Created for development tools and utilities.
//

import SwiftUI

#if DEBUG
struct DevPageView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    @StateObject private var viewModel = DevPageViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "gear.badge")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Development Tools")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Debug utilities and development features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Development Actions
                    VStack(spacing: 16) {
                        // Sign Out Button
                        Button(action: {
                            Task {
                                await authViewModel.signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.minus")
                                    .font(.title2)
                                Text("Sign Out (Dev)")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Load GPX Files Button
                        Button(action: {
                            viewModel.loadGPXFiles()
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .font(.title2)
                                Text("Load GPX Files to Database")
                                    .font(.headline)
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal)
                    
                    // Status/Result Section
                    if !viewModel.statusMessage.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(viewModel.statusMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Dev Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DevPageView()
        .environmentObject(AuthenticationViewModel())
        .environmentObject(ServiceProvider())
}
#endif