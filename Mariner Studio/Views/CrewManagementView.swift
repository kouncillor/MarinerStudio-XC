import SwiftUI

struct CrewManagementView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "person.3.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            // Title
            Text("Crew Management")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("This page will be set up for managing crews in the future.")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Additional info
            Text("Features will include crew scheduling, contact management, and assignment tracking.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Crew Management")
        .withHomeButton()
    }
}

#Preview {
    NavigationView {
        CrewManagementView()
    }
}
