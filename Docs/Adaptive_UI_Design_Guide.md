# Adaptive UI Design Guide for iOS/iPadOS/macOS

## Overview
This guide covers the different approaches for creating adaptive user interfaces that display different layouts for iPhone, iPad, and Mac devices in SwiftUI.

## 1. Size Classes (Most Common Approach)

Size classes are Apple's recommended way to create adaptive layouts. They automatically respond to device orientation changes and split-screen scenarios.

```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass
@Environment(\.verticalSizeClass) var verticalSizeClass

// Usage:
if horizontalSizeClass == .regular {
    // iPad/Mac layout (wider screens)
    // More columns, side-by-side content
} else {
    // iPhone layout (compact screens)
    // Fewer columns, stacked content
}
```

### Size Class Values:
- **`.compact`**: iPhone in portrait, iPhone in landscape (smaller models)
- **`.regular`**: iPad in any orientation, iPhone Plus/Max in landscape, Mac

## 2. Device Type Detection

Direct device detection for specific device-based logic:

```swift
var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

var isMac: Bool {
    UIDevice.current.userInterfaceIdiom == .mac
}

var isIPhone: Bool {
    UIDevice.current.userInterfaceIdiom == .phone
}
```

## 3. Screen Size Detection

Useful for pixel-perfect layouts or specific breakpoints:

```swift
var screenWidth: CGFloat {
    UIScreen.main.bounds.width
}

var screenHeight: CGFloat {
    UIScreen.main.bounds.height
}

// Usage:
if screenWidth > 768 {
    // Tablet/desktop layout
} else {
    // Phone layout
}
```

## 4. Combined Approach (Recommended)

The most robust solution combines multiple detection methods:

```swift
private var deviceLayout: DeviceLayout {
    if horizontalSizeClass == .regular && verticalSizeClass == .regular {
        return .ipad
    } else if UIDevice.current.userInterfaceIdiom == .mac {
        return .mac
    } else {
        return .iphone
    }
}

enum DeviceLayout {
    case iphone, ipad, mac
}

// Usage in body:
switch deviceLayout {
case .iphone:
    // iPhone-specific layout
case .ipad:
    // iPad-specific layout
case .mac:
    // Mac-specific layout
}
```

## Common UI Adaptations

### Grid Columns
- **iPhone**: 2 columns
- **iPad**: 3-4 columns
- **Mac**: 4-5 columns

```swift
var columns: [GridItem] {
    switch deviceLayout {
    case .iphone:
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    case .ipad:
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    case .mac:
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    }
}
```

### Spacing and Padding
- **iPhone**: Minimal padding (16pt)
- **iPad**: Medium padding (24pt)
- **Mac**: Generous padding (32pt)

```swift
var adaptivePadding: CGFloat {
    switch deviceLayout {
    case .iphone: return 16
    case .ipad: return 24
    case .mac: return 32
    }
}
```

### Navigation Patterns
- **iPhone**: Tab bar navigation, full-screen modals
- **iPad**: Split view, sidebar navigation, popovers
- **Mac**: Sidebar navigation, multiple windows

### Content Layout
- **iPhone**: Stack content vertically, single-column lists
- **iPad**: Side-by-side content, multi-column layouts
- **Mac**: Multi-pane interfaces, toolbars

## Implementation Example for MainView

```swift
struct MainView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var deviceLayout: DeviceLayout {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return .ipad
        } else if UIDevice.current.userInterfaceIdiom == .mac {
            return .mac
        } else {
            return .iphone
        }
    }
    
    var columns: [GridItem] {
        switch deviceLayout {
        case .iphone:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        case .ipad:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        case .mac:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    // Navigation buttons here
                }
                .padding(adaptivePadding)
            }
        }
    }
}
```

## Best Practices

1. **Use Size Classes First**: They handle orientation changes and split-screen automatically
2. **Combine Methods**: Use device detection for specific features, size classes for layout
3. **Test on All Devices**: Ensure layouts work on iPhone, iPad, and Mac
4. **Consider Accessibility**: Larger touch targets on touch devices
5. **Performance**: Avoid complex calculations in body, use computed properties
6. **Future-Proof**: Size classes adapt to new screen sizes automatically

## Testing Considerations

- Test on actual devices when possible
- Use Xcode simulator for different screen sizes
- Test landscape and portrait orientations
- Test iPad split-screen scenarios
- Verify Mac window resizing behavior

## Resources

- [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Building Adaptive User Interfaces](https://developer.apple.com/documentation/swiftui/building-adaptive-user-interfaces)
- [Size Classes Documentation](https://developer.apple.com/documentation/uikit/uiuserinterfacesizeclass)

---

*Last Updated: July 15, 2025*
*Created for: Mariner Studio XC*