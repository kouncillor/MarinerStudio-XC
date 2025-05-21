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
                    VStack(alignment: .leading, spacing: 60) {
                        ForEach(filteredFlowData) { section in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(section.category)
                                    .font(.headline)
                                    .padding(.bottom, 8)
                                
                                FlowSection(section: section, onViewSelected: { node in
                                    selectedView = node
                                    showViewDetails = true
                                })
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                    }
                    .frame(minWidth: 1000, minHeight: 1000) // Minimum size to allow scrolling
                    .padding(40)
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
    
    private let nodeWidth: CGFloat = 140
    private let nodeHeight: CGFloat = 70
    private let horizontalSpacing: CGFloat = 80
    private let verticalSpacing: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Connections between nodes
            ForEach(section.connections, id: \.id) { connection in
                if let fromNode = section.nodes.first(where: { $0.id == connection.from }),
                   let toNode = section.nodes.first(where: { $0.id == connection.to }) {
                    Path { path in
                        let fromPos = nodePosition(fromNode)
                        let toPos = nodePosition(toNode)
                        
                        path.move(to: CGPoint(x: fromPos.x + nodeWidth/2, y: fromPos.y + nodeHeight/2))
                        
                        // Calculate control points for a curved path
                        let controlX = (fromPos.x + toPos.x) / 2
                        let controlY1 = fromPos.y + nodeHeight/2 + 20
                        let controlY2 = toPos.y + nodeHeight/2 - 20
                        
                        // Draw a curved path using cubic Bezier
                        if fromPos.y == toPos.y {
                            // Horizontal connection
                            path.addLine(to: CGPoint(x: toPos.x + nodeWidth/2, y: toPos.y + nodeHeight/2))
                        } else {
                            // Vertical or diagonal connection
                            path.addCurve(
                                to: CGPoint(x: toPos.x + nodeWidth/2, y: toPos.y + nodeHeight/2),
                                control1: CGPoint(x: controlX, y: controlY1),
                                control2: CGPoint(x: controlX, y: controlY2)
                            )
                        }
                    }
                    .stroke(Color.gray, lineWidth: 1.5)
                    
                    // Arrow at the end of the connection
                    let toPos = nodePosition(toNode)
                    let arrowSize: CGFloat = 6
                    
                    Path { path in
                        path.move(to: CGPoint(x: toPos.x + nodeWidth/2, y: toPos.y + nodeHeight/2))
                        path.addLine(to: CGPoint(x: toPos.x + nodeWidth/2 - arrowSize, y: toPos.y + nodeHeight/2 - arrowSize))
                        path.addLine(to: CGPoint(x: toPos.x + nodeWidth/2 - arrowSize, y: toPos.y + nodeHeight/2 + arrowSize))
                        path.closeSubpath()
                    }
                    .fill(Color.gray)
                }
            }
            
            // Nodes
            ForEach(section.nodes) { node in
                let position = nodePosition(node)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(nodeColor(for: node))
                        .frame(width: nodeWidth, height: nodeHeight)
                        .shadow(radius: 2)
                    
                    VStack {
                        Text(node.name)
                            .font(.system(size: 12, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                        
                        if !node.description.isEmpty {
                            Text(node.description)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
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
    
    // Determine color based on node type
    private func nodeColor(for node: NavigationNode) -> Color {
        switch node.type {
        case .menu:
            return Color.blue.opacity(0.2)
        case .detail:
            return Color.green.opacity(0.2)
        case .mainCategory:
            return Color.orange.opacity(0.3)
        case .list:
            return Color.purple.opacity(0.2)
        case .functional:
            return Color.red.opacity(0.2)
        }
    }
    
    // Calculate the total width needed for this section
    private func calculateWidth() -> CGFloat {
        if section.nodes.isEmpty {
            return 0
        }
        
        let maxLevel = section.nodes.map { $0.level }.max()!
        return CGFloat(maxLevel + 1) * (nodeWidth + horizontalSpacing)
    }
    
    // Calculate the total height needed for this section
    private func calculateHeight() -> CGFloat {
        if section.nodes.isEmpty {
            return 0
        }
        
        let maxPosition = section.nodes.map { $0.position }.max()!
        return CGFloat(maxPosition + 1) * (nodeHeight + verticalSpacing)
    }
}

// Detail sheet for a selected view
struct ViewDetailSheet: View {
    let node: NavigationNode
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // View name
                Text(node.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Divider()
                
                // View type
                HStack {
                    Text("Type:")
                        .fontWeight(.semibold)
                    Text(node.type.rawValue.capitalized)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(typeColor(for: node.type).opacity(0.2))
                        )
                }
                
                // View description
                if !node.description.isEmpty {
                    Text("Description:")
                        .fontWeight(.semibold)
                    Text(node.description)
                }
                
                // File path
                Text("File Path:")
                    .fontWeight(.semibold)
                Text(node.filePath)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
                
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
        case .menu:
            return Color.blue
        case .detail:
            return Color.green
        case .mainCategory:
            return Color.orange
        case .list:
            return Color.purple
        case .functional:
            return Color.red
        }
    }
}

// Preview provider
struct NavigationFlowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationFlowView()
    }
}