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
            case .fair: effectiveMode = .battery
            default: effectiveMode = .balanced
            }
        } else {
            effectiveMode = mode
        }

        switch effectiveMode {
        case .maximum:
            result.maxTokens = min(settings.maxTokens, 160)
            result.recentContextMessages = min(8, max(4, settings.recentContextMessages))
        case .balanced:
            result.maxTokens = min(settings.maxTokens, 128)
            result.recentContextMessages = min(settings.recentContextMessages, 6)
        case .battery:
            result.maxTokens = min(settings.maxTokens, 96)
            result.recentContextMessages = min(settings.recentContextMessages, 4)
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
