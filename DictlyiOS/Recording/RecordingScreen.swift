import SwiftUI
import SwiftData
import AVFoundation
import OSLog
import DictlyModels
import DictlyTheme

private let logger = Logger(subsystem: "com.dictly.ios", category: "recording")

/// Full-screen modal presented when recording starts.
/// Layout (top to bottom): RecordingStatusBar, system-interruption banner (conditional),
/// LiveWaveform, pause/resume button, placeholder for tag palette (Story 2.4),
/// placeholder for stop bar (Story 2.7).
struct RecordingScreen: View {
    let session: Session

    @Environment(SessionRecorder.self) private var sessionRecorder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: RecordingViewModel?
    @State private var taggingService: TaggingService?
    @State private var micPermissionDenied = false
    @State private var recordingFailed = false
    @State private var isShowingStopConfirmation = false
    @State private var isShowingSessionSummary = false

    var body: some View {
        ZStack {
            DictlyColors.background.ignoresSafeArea()

            VStack(spacing: DictlySpacing.md) {
                if let vm = viewModel {
                    RecordingStatusBar(
                        recordingState: vm.recordingState,
                        formattedElapsedTime: vm.formattedElapsedTime,
                        tagCount: session.tags.count
                    )

                    if vm.recordingState == .systemInterrupted {
                        interruptionBanner(vm: vm)
                    }

                    LiveWaveform(
                        isPaused: sessionRecorder.isPaused,
                        audioLevel: sessionRecorder.currentAudioLevel
                    )

                    if vm.recordingState == .recording || vm.recordingState == .paused {
                        pauseResumeButton(vm: vm)
                    }
                }

                Spacer()

                // Tag palette (Story 2.4)
                if let vm = viewModel, let ts = taggingService {
                    TagPalette(
                        session: session,
                        taggingService: ts,
                        isInteractive: vm.isRecording
                    )
                }

                // Stop Recording bar (Story 2.7)
                if let vm = viewModel {
                    stopRecordingButton(vm: vm)
                }
            }
            .padding(.horizontal, DictlySpacing.md)
            .padding(.top, DictlySpacing.md)
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("End session?", isPresented: $isShowingStopConfirmation, titleVisibility: .visible) {
            Button("Stop Recording", role: .destructive) {
                viewModel?.stopRecording()
            }
        }
        .onChange(of: viewModel?.didStopRecording ?? false) { _, newValue in
            if newValue {
                isShowingSessionSummary = true
            }
        }
        .sheet(isPresented: $isShowingSessionSummary, onDismiss: { dismiss() }) {
            SessionSummarySheet(session: session, onDismiss: { isShowingSessionSummary = false })
        }
        .task {
            await checkMicrophonePermission()
        }
        .alert("Recording Failed", isPresented: $recordingFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unable to start recording. Please try again.")
        }
        .alert("Microphone Access Required", isPresented: $micPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dictly needs microphone access to record sessions. Please enable it in Settings.")
        }
    }

    // MARK: - Subviews

    private func stopRecordingButton(vm: RecordingViewModel) -> some View {
        Button {
            isShowingStopConfirmation = true
        } label: {
            HStack(spacing: DictlySpacing.sm) {
                Image(systemName: "stop.circle")
                Text("Stop Recording")
            }
            .font(DictlyTypography.body)
            .foregroundStyle(DictlyColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DictlySpacing.minTapTarget)
            .background(DictlyColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!vm.isRecording)
        .accessibilityLabel("Stop Recording")
        .accessibilityHint("Double-tap to end session.")
    }

    private func interruptionBanner(vm: RecordingViewModel) -> some View {
        VStack(spacing: DictlySpacing.sm) {
            Text("Recording Paused — Phone Call")
                .font(DictlyTypography.h3)
                .foregroundStyle(DictlyColors.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                logger.info("User resumed recording from system interruption")
                vm.resumeFromInterruption()
            } label: {
                Text("Resume Recording")
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: DictlySpacing.minTapTarget)
            }
            .buttonStyle(.bordered)
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.warning)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pauseResumeButton(vm: RecordingViewModel) -> some View {
        Button {
            vm.togglePause()
        } label: {
            Image(systemName: vm.recordingState == .recording ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DictlyColors.recordingActive)
        }
        .frame(width: DictlySpacing.minTapTarget, height: DictlySpacing.minTapTarget)
    }

    // MARK: - Microphone Permission

    private func checkMicrophonePermission() async {
        let permission = AVAudioApplication.shared.recordPermission
        switch permission {
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            if granted {
                logger.info("Microphone permission granted")
                startRecording()
            } else {
                logger.error("Microphone permission denied — cannot start recording")
                micPermissionDenied = true
            }
        case .denied:
            logger.error("Microphone permission denied — cannot start recording")
            micPermissionDenied = true
        case .granted:
            logger.info("Microphone permission granted")
            startRecording()
        @unknown default:
            logger.error("Microphone permission unknown state — cannot start recording")
            micPermissionDenied = true
        }
    }

    private func startRecording() {
        logger.info("Recording screen presented for session \(session.uuid.uuidString, privacy: .private)")
        do {
            try sessionRecorder.startRecording(session: session, context: modelContext)
            viewModel = RecordingViewModel(sessionRecorder: sessionRecorder)
            taggingService = TaggingService(sessionRecorder: sessionRecorder)
        } catch {
            logger.error("Failed to start recording: \(error, privacy: .public)")
            recordingFailed = true
        }
    }
}
