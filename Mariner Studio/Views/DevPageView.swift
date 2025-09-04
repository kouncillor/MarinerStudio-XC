//
//  DevPageView.swift
//  Mariner Studio
//
//  Created for development tools and utilities.
//

import SwiftUI

#if DEBUG
struct DevPageView: View {
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
                        // Admin Dashboard Navigation Link
                        NavigationLink(destination: AdminDashboardView()) {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .font(.title2)
                                Text("Admin Dashboard")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.purple)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

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

                        // Upload GPX to Supabase Button
                        Button(action: {
                            viewModel.uploadGPXToSupabase()
                        }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.title2)
                                Text("Upload GPX to Supabase")
                                    .font(.headline)
                                Spacer()
                                if viewModel.isUploading {
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
                        .disabled(viewModel.isUploading)
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
            .fileImporter(
                isPresented: $viewModel.showingFilePicker,
                allowedContentTypes: [.init(filenameExtension: "gpx")!, .xml],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.processGPXForSupabase(from: url)
                    }
                case .failure(let error):
                    viewModel.statusMessage = "❌ File selection failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    DevPageView()
}
#endif
