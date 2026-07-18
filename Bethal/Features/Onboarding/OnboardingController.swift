import Foundation
import SwiftUI

/// SwiftUI-facing wrapper around the pure `OnboardingViewModel`.
@MainActor
final class OnboardingController: ObservableObject {
    @Published private(set) var flow: OnboardingFlowState
    @Published private(set) var sessionPreferences: AppSessionPreferences

    private let viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel = OnboardingViewModel()) {
        self.viewModel = viewModel
        self.flow = viewModel.flow
        self.sessionPreferences = viewModel.sessionPreferences
    }

    var needsOnboarding: Bool { viewModel.needsOnboarding && !flow.isComplete }

    var providerOptions: [KnownAIProviderOption] { KnownAIProviderOption.catalog }

    func selectDirectory(_ url: URL) {
        viewModel.selectDirectory(url: url)
        sync()
    }

    func selectProvider(id: String?) {
        viewModel.selectProvider(id: id)
        sync()
    }

    func goBack() {
        _ = viewModel.goBack()
        sync()
    }

    func continueOrFinish() {
        _ = viewModel.continueOrFinish()
        sync()
    }

    private func sync() {
        flow = viewModel.flow
        sessionPreferences = viewModel.sessionPreferences
    }
}
