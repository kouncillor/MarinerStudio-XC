

import SwiftUI

struct TugDetailsView: View {
    // MARK: - Properties
    @StateObject var viewModel: TugDetailsViewModel
    
    // MARK: - Initialization
    init(tug: Tug, vesselService: VesselDatabaseService) {
        _viewModel = StateObject(wrappedValue: TugDetailsViewModel(
            tug: tug,
            vesselService: vesselService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading details...")
                        .padding()
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 20) {
                    // Error Message
                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    // Tug Header Card
                    VStack(spacing: 10) {
                        // Action Buttons
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                viewModel.showNotes()
                            }) {
                                Image(systemName: "text.bubble")
                                    .frame(width: 44, height: 44)
                            }
                            
                            Button(action: {
                                viewModel.shareTug()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        // Tug Name Header
                        VStack {
                            Text(viewModel.tug?.vesselName ?? "")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Divider()
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(.lightGray), lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    )
                    
                    // Photos Section
                    photosSection
                    
                    // Primary Info Card
                    primaryInfoCard
                    
                    // Vessel Info Card
                    vesselInfoCard
                    
                    // Equipment Info Card
                    if let equipment1 = viewModel.tug?.equipment1, !equipment1.isEmpty {
                        equipmentInfoCard
                    }
                    
                    // Additional Info Card
                    additionalInfoCard
                }
                .padding()
            }
        }
        .navigationTitle("Tug Details")
    }
    
    // MARK: - View Components
    
    // Photos Section
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Photos")
                .font(.headline)
                .fontWeight(.bold)
            
            Button("Take Photo") {
                // Photo functionality placeholder
                print("Take photo button tapped")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Text("No photos yet")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    // Primary Info Card
    private var primaryInfoCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Primary Information")
                .font(.headline)
                .fontWeight(.bold)
            
            infoRow(title: "Vessel Number:", value: viewModel.tug?.vesselNumber ?? "")
            infoRow(title: "CG Number:", value: viewModel.tug?.cgNumber ?? "")
            infoRow(title: "Horsepower:", value: viewModel.formattedHorsepower)
            infoRow(title: "Dimensions:", value: viewModel.formattedDimensions)
            infoRow(title: "Draft:", value: viewModel.formattedDraft)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    // Vessel Info Card
    private var vesselInfoCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Vessel Information")
                .font(.headline)
                .fontWeight(.bold)
            
            infoRow(title: "Year:", value: viewModel.formattedYear)
            infoRow(title: "Operator:", value: viewModel.tug?.operator_ ?? "")
            infoRow(title: "Base Port:", value: viewModel.tug?.basePort1 ?? "")
            infoRow(title: "State:", value: viewModel.tug?.state ?? "")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    // Equipment Info Card
    private var equipmentInfoCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Equipment")
                .font(.headline)
                .fontWeight(.bold)
            
            if let equipment1 = viewModel.tug?.equipment1, !equipment1.isEmpty {
                infoRow(title: "Equipment 1:", value: equipment1)
            } else {
                infoRow(title: "Equipment 1:", value: "Not available")
            }
            
            if let equipment2 = viewModel.tug?.equipment2, !equipment2.isEmpty {
                infoRow(title: "Equipment 2:", value: equipment2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    // Additional Info Card
    private var additionalInfoCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Additional Information")
                .font(.headline)
                .fontWeight(.bold)
            
            infoRow(title: "VTCC:", value: viewModel.tug?.vtcc ?? "")
            infoRow(title: "ICST:", value: viewModel.tug?.icst ?? "")
            infoRow(title: "NRT:", value: viewModel.tug?.nrt ?? "")
            infoRow(title: "Fleet Year:", value: viewModel.tug?.fleetYear ?? "")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    // Helper function for creating info rows
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .fontWeight(.bold)
                .frame(width: 120, alignment: .leading)
            
            Text(value.isEmpty ? "Not available" : value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
