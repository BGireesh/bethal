import Foundation
import SwiftUI

/// SwiftUI-facing home shell state.
@MainActor
final class HomeShellController: ObservableObject {
    @Published private(set) var navigation: HomeNavigationState
    @Published private(set) var meetings: [MeetingIndexEntry]
    @Published private(set) var todos: [TodoItem]
    @Published private(set) var refreshError: String?
    @Published private(set) var settingsPath: String?
    @Published private(set) var settingsProvider: String
    @Published private(set) var settingsCaptureMode: String
    @Published private(set) var settingsCalendar: String
    @Published private(set) var settingsLoadError: String?
    @Published private(set) var lastOpenSucceeded: Bool?
    @Published private(set) var activeReminder: CalendarMeetingEvent?
    @Published private(set) var calendarMinutesBefore: Int
    @Published private(set) var calendarAuthLabel: String
    @Published private(set) var calendarError: String?
    @Published var pendingRecordingTitle: String?
    @Published private(set) var transcriptionProgress: TranscriptionProgress
    @Published private(set) var transcriptionError: String?
    @Published var showTranscriptionSheet: Bool
    @Published private(set) var processingProgress: ProcessingProgress
    @Published private(set) var processingError: String?
    @Published private(set) var processingProviders: [AIProviderDescriptor]
    @Published private(set) var processingAvailableProviders: [AIProviderDescriptor]
    @Published private(set) var processingPreferredID: String?
    @Published private(set) var processingEmptyHowTo: String
    @Published var showProcessingSheet: Bool
    @Published private(set) var discoveredProviders: [AIProviderDescriptor]
    @Published private(set) var askEveryTimeForProvider: Bool
    @Published private(set) var defaultAIProviderID: String?
    @Published private(set) var reviewPhase: ReviewPhase
    @Published private(set) var reviewDraft: ReviewDraft?
    @Published private(set) var reviewError: String?
    @Published private(set) var reviewAcceptedCount: Int
    @Published var showReviewSheet: Bool

    private let viewModel: HomeShellViewModel
    private let calendarReminders: CalendarReminderViewModel
    private let transcription: TranscriptionViewModel
    private let processing: ProviderChooserViewModel
    private let review: ProcessingReviewViewModel

    init(
        viewModel: HomeShellViewModel = HomeShellViewModel(),
        calendarReminders: CalendarReminderViewModel = CalendarReminderViewModel(),
        transcription: TranscriptionViewModel? = nil,
        processing: ProviderChooserViewModel? = nil,
        review: ProcessingReviewViewModel? = nil
    ) {
        self.viewModel = viewModel
        self.calendarReminders = calendarReminders
        if let transcription {
            self.transcription = transcription
        } else {
            let engine = AppleSpeechTranscriptionEngine()
            let coordinator = TranscriptionCoordinator(engine: engine)
            self.transcription = TranscriptionViewModel(coordinator: coordinator)
        }
        if let processing {
            self.processing = processing
        } else {
            let registry = AIProviderRegistry()
            let coordinator = ProcessingCoordinator(registry: registry)
            self.processing = ProviderChooserViewModel(coordinator: coordinator)
        }
        self.review = review ?? ProcessingReviewViewModel()
        self.navigation = viewModel.navigation
        self.meetings = viewModel.meetings
        self.todos = viewModel.todos
        self.refreshError = viewModel.refreshError
        self.settingsPath = viewModel.settings.workingDirectoryPath
        self.settingsProvider = viewModel.settings.defaultProviderDisplayName
        self.settingsCaptureMode = viewModel.settings.defaultCaptureModeDisplayName
        self.settingsCalendar = viewModel.settings.calendarSummary
        self.settingsLoadError = viewModel.settings.loadError
        self.lastOpenSucceeded = viewModel.settings.lastOpenSucceeded
        self.activeReminder = calendarReminders.activeReminder
        self.calendarMinutesBefore = calendarReminders.minutesBefore
        self.calendarAuthLabel = calendarReminders.authorizationStatus.displayName
        self.calendarError = calendarReminders.lastError
        self.pendingRecordingTitle = nil
        self.transcriptionProgress = self.transcription.progress
        self.transcriptionError = self.transcription.lastError
        self.showTranscriptionSheet = false
        self.processingProgress = self.processing.progress
        self.processingError = self.processing.lastError
        self.processingProviders = self.processing.providers
        self.processingAvailableProviders = self.processing.availableProviders
        self.processingPreferredID = self.processing.preferredProviderID
        self.processingEmptyHowTo = self.processing.emptyStateHowTo
        self.showProcessingSheet = false
        self.discoveredProviders = viewModel.settings.discoveredProviders
        self.askEveryTimeForProvider = viewModel.settings.appSettings.askEveryTimeForProvider
        self.defaultAIProviderID = viewModel.settings.appSettings.defaultAIProviderID
        self.reviewPhase = self.review.phase
        self.reviewDraft = self.review.draft
        self.reviewError = self.review.lastError
        self.reviewAcceptedCount = self.review.lastAcceptedCount
        self.showReviewSheet = false
    }

    var showsMeetingsEmpty: Bool { viewModel.showsMeetingsEmpty }
    var showsTodosEmpty: Bool { viewModel.showsTodosEmpty }
    var meetingsEmptyState: EmptyStateContent { viewModel.meetingsEmptyState }
    var todosEmptyState: EmptyStateContent { viewModel.todosEmptyState }
    var meetingPresentations: [MeetingListPresentation] { viewModel.meetingPresentations }
    var calendarEnabled: Bool { viewModel.settings.appSettings.calendarAutoDetectEnabled }
    var calendarMinutes: Int { viewModel.settings.appSettings.calendarRemindMinutesBefore }

    func select(_ section: AppSection) {
        viewModel.selectSection(section)
        sync()
    }

    func refresh() {
        viewModel.refresh()
        viewModel.settings.refreshDiscoveredProviders()
        sync()
    }

    func openWorkingDirectory() {
        _ = viewModel.settings.openWorkingDirectoryInFinder()
        sync()
    }

    func updateCalendarPreferences(enabled: Bool, minutesBefore: Int) {
        viewModel.settings.updateCalendarPreferences(enabled: enabled, minutesBefore: minutesBefore)
        calendarReminders.reloadSettings()
        Task { await refreshCalendar() }
        sync()
    }

    func updateAIPreferences(defaultProviderID: String?, askEveryTime: Bool) {
        viewModel.settings.updateAIPreferences(defaultProviderID: defaultProviderID, askEveryTime: askEveryTime)
        sync()
    }

    func refreshDiscoveredProviders() {
        viewModel.settings.refreshDiscoveredProviders()
        processing.refreshDiscovery()
        sync()
    }

    func requestCalendarAccess() {
        Task {
            await calendarReminders.requestCalendarAccess()
            sync()
        }
    }

    func refreshCalendar() async {
        await calendarReminders.refresh()
        sync()
    }

    func dismissReminder() {
        calendarReminders.dismissActiveReminder()
        sync()
    }

    func startRecordingFromReminder() {
        pendingRecordingTitle = calendarReminders.consumeRecordingTitle()
        viewModel.selectSection(.record)
        sync()
    }

    func clearPendingRecordingTitle() {
        pendingRecordingTitle = nil
    }

    func transcribeMeeting(id: String) {
        showTranscriptionSheet = true
        Task {
            await transcription.transcribe(meetingID: id)
            transcriptionProgress = transcription.progress
            transcriptionError = transcription.lastError
            refresh()
        }
    }

    func retryTranscription() {
        guard let id = transcriptionProgress.meetingID else { return }
        Task {
            await transcription.retry(meetingID: id)
            transcriptionProgress = transcription.progress
            transcriptionError = transcription.lastError
            refresh()
        }
    }

    func dismissTranscriptionSheet() {
        showTranscriptionSheet = false
        transcription.reset()
        transcriptionProgress = transcription.progress
        transcriptionError = nil
    }

    func processMeeting(id: String) {
        showProcessingSheet = true
        Task {
            await processing.begin(meetingID: id)
            syncProcessing()
            refresh()
            if processing.progress.phase == .completed, let meetingID = processing.progress.meetingID {
                openReview(meetingID: meetingID)
            }
        }
    }

    func selectProcessingProvider(id: String) {
        Task {
            await processing.selectProvider(id: id)
            syncProcessing()
            refresh()
            if processing.progress.phase == .completed, let meetingID = processing.progress.meetingID {
                openReview(meetingID: meetingID)
            }
        }
    }

    func retryProcessing() {
        Task {
            await processing.retry()
            syncProcessing()
            refresh()
            if processing.progress.phase == .completed, let meetingID = processing.progress.meetingID {
                openReview(meetingID: meetingID)
            }
        }
    }

    func showProcessingChooserAgain() {
        processing.showChooserAgain()
        syncProcessing()
    }

    func refreshProcessingDiscovery() {
        processing.refreshDiscovery()
        syncProcessing()
    }

    func dismissProcessingSheet() {
        showProcessingSheet = false
        processing.reset()
        syncProcessing()
    }

    func openReview(meetingID: String) {
        showProcessingSheet = false
        showReviewSheet = true
        review.load(meetingID: meetingID)
        syncReview()
    }

    func updateReviewCandidate(id: String, title: String) {
        review.updateCandidate(id: id, title: title)
        syncReview()
    }

    func removeReviewCandidate(id: String) {
        review.removeCandidate(id: id)
        syncReview()
    }

    func acceptReview() {
        review.accept()
        syncReview()
        refresh()
    }

    func discardReview() {
        review.discard()
        syncReview()
        refresh()
    }

    func dismissReviewSheet() {
        showReviewSheet = false
        review.reset()
        syncReview()
        refresh()
    }

    private func syncProcessing() {
        processingProgress = processing.progress
        processingError = processing.lastError
        processingProviders = processing.providers
        processingAvailableProviders = processing.availableProviders
        processingPreferredID = processing.preferredProviderID
        processingEmptyHowTo = processing.emptyStateHowTo
    }

    private func syncReview() {
        reviewPhase = review.phase
        reviewDraft = review.draft
        reviewError = review.lastError
        reviewAcceptedCount = review.lastAcceptedCount
    }

    private func sync() {
        navigation = viewModel.navigation
        meetings = viewModel.meetings
        todos = viewModel.todos
        refreshError = viewModel.refreshError
        settingsPath = viewModel.settings.workingDirectoryPath
        settingsProvider = viewModel.settings.defaultProviderDisplayName
        settingsCaptureMode = viewModel.settings.defaultCaptureModeDisplayName
        settingsCalendar = viewModel.settings.calendarSummary
        settingsLoadError = viewModel.settings.loadError
        lastOpenSucceeded = viewModel.settings.lastOpenSucceeded
        activeReminder = calendarReminders.activeReminder
        calendarMinutesBefore = calendarReminders.minutesBefore
        calendarAuthLabel = calendarReminders.authorizationStatus.displayName
        calendarError = calendarReminders.lastError
        transcriptionProgress = transcription.progress
        transcriptionError = transcription.lastError
        discoveredProviders = viewModel.settings.discoveredProviders
        askEveryTimeForProvider = viewModel.settings.appSettings.askEveryTimeForProvider
        defaultAIProviderID = viewModel.settings.appSettings.defaultAIProviderID
        syncProcessing()
        syncReview()
    }
}
