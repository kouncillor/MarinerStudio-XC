

//
//  NavigationFlowView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/21/25.
//

import SwiftUI

struct NavigationFlowView: View {
    @State private var selectedSection: String = "All"
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showViewDetails: Bool = false
    @State private var selectedView: NavigationNode? = nil
    @State private var searchText: String = ""
    
    // Get all categories from the flow data
    private var categories: [String] {
        var allCategories = ["All"]
        allCategories.append(contentsOf: navigationFlowData.map { $0.category })
        return allCategories
    }
    
    // Filter flow data based on selected category and search text
    private var filteredFlowData: [NavigationFlowSection] {
        if selectedSection == "All" && searchText.isEmpty {
            return navigationFlowData
        }
        
        var filtered = navigationFlowData
        
        // Filter by category if needed
        if selectedSection != "All" {
            filtered = filtered.filter { $0.category == selectedSection }
        }
        
        // Filter by search text if present
        if !searchText.isEmpty {
            filtered = filtered.map { section in
                var newSection = section
                newSection.nodes = section.nodes.filter {
                    $0.name.lowercased().contains(searchText.lowercased())
                }
                return newSection
            }.filter { !$0.nodes.isEmpty }
        }
        
        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and category selector
            HStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search views...", text: $searchText)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.trailing, 8)
                
                // Category picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.trailing)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Flow visualization
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    // Flow sections
                    VStack(alignment: .leading, spacing: 80) {
                        ForEach(filteredFlowData) { section in
                            VStack(alignment: .leading, spacing: 20) {
                                Text(section.category)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 10)
                                
                                FlowSection(section: section, onViewSelected: { node in
                                    selectedView = node
                                    showViewDetails = true
                                })
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(15)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                    }
                    .frame(minWidth: 1200, minHeight: 1200) // Increased minimum size for larger flows
                    .padding(50)
                }
                .scaleEffect(zoomScale)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { value in
                            lastOffset = offset
                        }
                )
            }
            
            // Zoom controls
            HStack {
                Button(action: {
                    if zoomScale > 0.25 {
                        zoomScale -= 0.25
                    }
                }) {
                    Image(systemName: "minus")
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(radius: 1)
                }
                
                Button(action: {
                    zoomScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }) {
                    Text("Reset")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 1)
                }
                
                Button(action: {
                    if zoomScale < 3.0 {
                        zoomScale += 0.25
                    }
                }) {
                    Image(systemName: "plus")
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(radius: 1)
                }
            }
            .padding()
        }
        .navigationTitle("Navigation Flow")
        .sheet(isPresented: $showViewDetails) {
            if let view = selectedView {
                ViewDetailSheet(node: view)
            }
        }
    }
}

// View for a single navigation flow section
struct FlowSection: View {
    let section: NavigationFlowSection
    let onViewSelected: (NavigationNode) -> Void
    
    private let nodeWidth: CGFloat = 160  // Increased width for better readability
    private let nodeHeight: CGFloat = 80  // Increased height
    private let horizontalSpacing: CGFloat = 100  // Increased spacing
    private let verticalSpacing: CGFloat = 120    // Increased spacing
    
    var body: some View {
        ZStack {
            // Connections between nodes
            ForEach(section.connections, id: \.id) { connection in
                if let fromNode = section.nodes.first(where: { $0.id == connection.from }),
                   let toNode = section.nodes.first(where: { $0.id == connection.to }) {
                    
                    let fromPos = nodePosition(fromNode)
                    let toPos = nodePosition(toNode)
                    
                    Path { path in
                        let startX = fromPos.x + nodeWidth
                        let startY = fromPos.y + nodeHeight/2
                        let endX = toPos.x
                        let endY = toPos.y + nodeHeight/2
                        
                        path.move(to: CGPoint(x: startX, y: startY))
                        
                        // Create smooth bezier curve for connections
                        let controlPointOffset = horizontalSpacing * 0.6
                        let control1X = startX + controlPointOffset
                        let control2X = endX - controlPointOffset
                        
                        path.addCurve(
                            to: CGPoint(x: endX, y: endY),
                            control1: CGPoint(x: control1X, y: startY),
                            control2: CGPoint(x: control2X, y: endY)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    
                    // Arrow at the end of the connection
                    let arrowSize: CGFloat = 8
                    Path { path in
                        path.move(to: CGPoint(x: toPos.x, y: toPos.y + nodeHeight/2))
                        path.addLine(to: CGPoint(x: toPos.x - arrowSize, y: toPos.y + nodeHeight/2 - arrowSize/2))
                        path.addLine(to: CGPoint(x: toPos.x - arrowSize, y: toPos.y + nodeHeight/2 + arrowSize/2))
                        path.closeSubpath()
                    }
                    .fill(Color.purple.opacity(0.7))
                }
            }
            
            // Nodes
            ForEach(section.nodes) { node in
                let position = nodePosition(node)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(nodeColor(for: node))
                        .frame(width: nodeWidth, height: nodeHeight)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(nodeBorderColor(for: node), lineWidth: 2)
                        )
                    
                    VStack(spacing: 4) {
                        Text(node.name)
                            .font(.system(size: 12, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 6)
                        
                        if !node.description.isEmpty {
                            Text(node.description)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                        
                        // Node type indicator
                        Text(node.type.rawValue.uppercased())
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(nodeBorderColor(for: node))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(nodeBorderColor(for: node).opacity(0.2))
                            )
                    }
                }
                .position(x: position.x + nodeWidth/2, y: position.y + nodeHeight/2)
                .onTapGesture {
                    onViewSelected(node)
                }
            }
        }
        .frame(width: calculateWidth(), height: calculateHeight())
    }
    
    // Calculate position for a node based on its level and position
    private func nodePosition(_ node: NavigationNode) -> CGPoint {
        let x = CGFloat(node.level) * (nodeWidth + horizontalSpacing)
        let y = CGFloat(node.position) * (nodeHeight + verticalSpacing)
        return CGPoint(x: x, y: y)
    }
    
    // Determine background color based on node type
    private func nodeColor(for node: NavigationNode) -> Color {
        switch node.type {
        case .mainCategory:
            return Color.orange.opacity(0.15)
        case .menu:
            return Color.blue.opacity(0.15)
        case .list:
            return Color.purple.opacity(0.15)
        case .detail:
            return Color.green.opacity(0.15)
        case .functional:
            return Color.red.opacity(0.15)
        }
    }
    
    // Determine border color based on node type
    private func nodeBorderColor(for node: NavigationNode) -> Color {
        switch node.type {
        case .mainCategory:
            return Color.orange
        case .menu:
            return Color.blue
        case .list:
            return Color.purple
        case .detail:
            return Color.green
        case .functional:
            return Color.red
        }
    }
    
    // Calculate the total width needed for this section
    private func calculateWidth() -> CGFloat {
        if section.nodes.isEmpty {
            return nodeWidth
        }
        
        let maxLevel = section.nodes.map { $0.level }.max() ?? 0
        return CGFloat(maxLevel + 1) * (nodeWidth + horizontalSpacing)
    }
    
    // Calculate the total height needed for this section
    private func calculateHeight() -> CGFloat {
        if section.nodes.isEmpty {
            return nodeHeight
        }
        
        let maxPosition = section.nodes.map { $0.position }.max() ?? 0
        return CGFloat(maxPosition + 1) * (nodeHeight + verticalSpacing)
    }
}

// Detail sheet for a selected view
struct ViewDetailSheet: View {
    let node: NavigationNode
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // View name
                Text(node.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Divider()
                
                // View type with colored indicator
                HStack {
                    Text("Type:")
                        .fontWeight(.semibold)
                    Text(node.type.rawValue.capitalized)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(typeColor(for: node.type).opacity(0.2))
                        )
                        .foregroundColor(typeColor(for: node.type))
                        .fontWeight(.medium)
                }
                
                // View description
                if !node.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description:")
                            .fontWeight(.semibold)
                        Text(node.description)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                // Position in flow
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position in Flow:")
                        .fontWeight(.semibold)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Level: \(node.level)")
                            Text("Position: \(node.position)")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                // File path
                VStack(alignment: .leading, spacing: 8) {
                    Text("File Path:")
                        .fontWeight(.semibold)
                    Text(node.filePath)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("View Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func typeColor(for type: NodeType) -> Color {
        switch type {
        case .mainCategory:
            return Color.orange
        case .menu:
            return Color.blue
        case .list:
            return Color.purple
        case .detail:
            return Color.green
        case .functional:
            return Color.red
        }
    }
}

// Preview provider
struct NavigationFlowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NavigationFlowView()
        }
    }
}




