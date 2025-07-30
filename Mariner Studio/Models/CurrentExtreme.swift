// CurrentExtreme.swift

import Foundation

class CurrentExtreme: ObservableObject, Identifiable {
    let id = UUID()

    @Published var time: Date
    @Published var event: String
    @Published var speed: Double
    @Published var isNextEvent: Bool
    @Published var isMostRecentPast: Bool

    init(time: Date, event: String, speed: Double, isNextEvent: Bool = false, isMostRecentPast: Bool = false) {
        self.time = time
        self.event = event
        self.speed = speed
        self.isNextEvent = isNextEvent
        self.isMostRecentPast = isMostRecentPast
    }
}
