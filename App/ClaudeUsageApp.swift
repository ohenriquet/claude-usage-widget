import SwiftUI
import ServiceManagement
import WidgetKit

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Sem Dock (LSUIElement); presença visível só na barra de menu.
        MenuBarExtra {
            MenuBarPanel(model: .shared)
        } label: {
            MenuBarLabel(model: .shared)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let scheduler = NSBackgroundActivityScheduler(identifier: "com.henrique.claudeusage.refresh")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }

        Task { await Refresher.refresh() }

        // Timer comum sofre App Nap em agentes de background; este scheduler não.
        scheduler.interval = 300
        scheduler.tolerance = 60
        scheduler.repeats = true
        scheduler.schedule { completion in
            Task {
                await Refresher.refresh()
                completion(.finished)
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { await Refresher.refresh() }
        }
    }
}

enum Refresher {
    /// Ciclo completo: Keychain → endpoint de usage → scan dos JSONL → snapshot → reload do widget.
    /// Qualquer etapa pode falhar sem derrubar as outras; em falha mantém os dados anteriores.
    static func refresh() async {
        var snapshot = SnapshotStore.load() ?? UsageSnapshot()
        let previous = snapshot

        if let token = KeychainReader.readAccessToken() {
            do {
                let plan = try await UsageFetcher.fetch(accessToken: token)
                snapshot.fiveHour = plan.fiveHour
                snapshot.sevenDay = plan.sevenDay
                snapshot.sevenDayOpus = plan.sevenDayOpus
                snapshot.sevenDaySonnet = plan.sevenDaySonnet
                snapshot.planFetchSucceeded = true
                snapshot.fetchedAt = Date()
            } catch {
                NSLog("ClaudeUsage: fetch de usage falhou: \(error)")
                snapshot.planFetchSucceeded = false
            }
        } else {
            NSLog("ClaudeUsage: token não encontrado no Keychain")
            snapshot.planFetchSucceeded = false
        }

        snapshot.today = TranscriptScanner.scanToday()

        SnapshotStore.save(snapshot)

        let updated = snapshot
        await MainActor.run { UsageModel.shared.snapshot = updated }

        // Reload só quando muda algo visível — poupa o budget diário do WidgetKit.
        if !snapshot.materiallyEquals(previous) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
