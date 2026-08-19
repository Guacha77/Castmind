import Foundation
import UIKit

@MainActor
final class PerformanceManager: ObservableObject {
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var batteryLevel: Float = UIDevice.current.batteryLevel

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.thermalState = ProcessInfo.processInfo.thermalState }
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.batteryLevel = UIDevice.current.batteryLevel }
        }
    }

    func adjusted(_ settings: GenerationSettings, mode: PerformanceMode) -> GenerationSettings {
        var result = settings
        let effectiveMode: PerformanceMode
        if mode == .automatic {
            switch thermalState {
            case .serious, .critical: effectiveMode = .battery
            case .fair: effectiveMode = .balanced
            default: effectiveMode = .maximum
            }
        } else {
            effectiveMode = mode
        }

        switch effectiveMode {
        case .maximum:
            result.recentContextMessages = min(12, max(6, settings.recentContextMessages))
        case .balanced:
            result.maxTokens = min(settings.maxTokens, 180)
            result.recentContextMessages = min(settings.recentContextMessages, 8)
        case .battery:
            result.maxTokens = min(settings.maxTokens, 120)
            result.recentContextMessages = min(settings.recentContextMessages, 6)
        case .automatic:
            break
        }
        return result
    }

    var thermalLabel: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Templado"
        case .serious: return "Caliente"
        case .critical: return "Muy caliente"
        @unknown default: return "Desconocido"
        }
    }
}
