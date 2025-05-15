//
//  NowPlayingActor.swift
//  NowPlayingClient
//
//  Created by Thanh Hai Khong on 14/5/25.
//

import MediaPlayer
import ConcurrencyExtras
import NowPlayingClient
import CryptoKit

final internal class NowPlayingDelegate: NSObject, @unchecked Sendable {
	private let commandCenter = MPRemoteCommandCenter.shared()
	private let state = LockIsolated(NowPlayingMetadata())
	private var interruptionObserver: NSObjectProtocol?
}

// MARK: - Public Methods {

extension NowPlayingDelegate {
	
	func initializeAudioSession(_ category: AVAudioSession.Category, _ mode: AVAudioSession.Mode, _ options: AVAudioSession.CategoryOptions) async throws {
		try await MainActor.run {
			let audioSession = AVAudioSession.sharedInstance()
			try audioSession.setCategory(category, mode: mode, options: options)
			try audioSession.setActive(true)
		}
	}
	
	func setupRemoteCommands(_ enabledCommands: Set<NowPlayingClient.RemoteCommand>, _ handlers: NowPlayingClient.RemoteCommandHandlers) async {
		await MainActor.run {
			invalidAllRemoteCommands()
			
			for command in enabledCommands {
				configure(command: command, handlers: handlers)
			}
			
			if !enabledCommands.isEmpty {
				UIApplication.shared.beginReceivingRemoteControlEvents()
			} else {
				UIApplication.shared.endReceivingRemoteControlEvents()
			}
		}
	}
	
	func interruptionEvents() -> AsyncStream<NowPlayingClient.InterruptionEvent> {
		AsyncStream { continuation in
			let observer = NotificationCenter.default.addObserver(
				forName: AVAudioSession.interruptionNotification,
				object: AVAudioSession.sharedInstance(),
				queue: .main
			) { notification in
				guard let userInfo = notification.userInfo,
					  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
					  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
					return
				}
				
				switch type {
				case .began:
					continuation.yield(.began)
					
				case .ended:
					let shouldResume = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt)
						.map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
					continuation.yield(.ended(shouldResume: shouldResume))
					
				@unknown default:
					break
				}
			}
			
			self.interruptionObserver = observer
			
			continuation.onTermination = { [weak self] _ in
				guard let `self` else {
					return
				}
				
				if let observer = self.interruptionObserver {
					NotificationCenter.default.removeObserver(observer)
					self.interruptionObserver = nil
				}
			}
		}
	}
	
	@MainActor
	func updateStaticInfo(_ info: NowPlayingClient.StaticNowPlayingInfo) async throws {
		try await MainActor.run {
			guard info.duration >= 0 else {
				throw NowPlayingClient.NowPlayingError.invalidDuration
			}
			
			state.withValue { metadata in
				let newArtworkHash = NowPlayingMetadata.computeArtworkHash(info.artwork)
				metadata.title = info.title
				metadata.artist = info.artist
				metadata.album = info.album
				metadata.duration = info.duration
				metadata.mediaType = info.mediaType
				
				if newArtworkHash != metadata.artworkHash {
					metadata.artwork = info.artwork
					metadata.artworkHash = newArtworkHash
				}
			}
			
			try AVAudioSession.sharedInstance().setActive(true)
			
			MPNowPlayingInfoCenter.default().nowPlayingInfo = state.value.toDictionary()
		}
	}
	
	@MainActor
	func updateDynamicInfo(_ info: NowPlayingClient.DynamicNowPlayingInfo) async throws {
		try await MainActor.run {
			guard info.elapsedTime >= 0, info.playbackRate >= 0 else {
				throw NowPlayingClient.NowPlayingError.invalidPlaybackState
			}
			
			state.withValue { metadata in
				metadata.elapsedTime = info.elapsedTime
				metadata.playbackRate = info.playbackRate
			}
			
			try AVAudioSession.sharedInstance().setActive(true)
			
			MPNowPlayingInfoCenter.default().nowPlayingInfo = state.value.toDictionary()
		}
	}
	
	func reset() async {
		await MainActor.run {
			state.setValue(NowPlayingMetadata(title: nil, artist: nil, album: nil, artwork: nil, artworkHash: nil, duration: 0, elapsedTime: 0, playbackRate: 0, mediaType: .audio))
			
			MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
			
			invalidAllRemoteCommands()
			
			UIApplication.shared.endReceivingRemoteControlEvents()
			
			try? AVAudioSession.sharedInstance().setActive(false)
			
			if let observer = interruptionObserver {
				NotificationCenter.default.removeObserver(observer)
				interruptionObserver = nil
			}
		}
	}
}

// MARK: - Supporting Methods

extension NowPlayingDelegate {
	
	@MainActor
	private func invalidAllRemoteCommands() {
		commandCenter.playCommand.isEnabled = false
		commandCenter.pauseCommand.isEnabled = false
		commandCenter.stopCommand.isEnabled = false
		commandCenter.togglePlayPauseCommand.isEnabled = false
		commandCenter.enableLanguageOptionCommand.isEnabled = false
		commandCenter.disableLanguageOptionCommand.isEnabled = false
		commandCenter.changePlaybackRateCommand.isEnabled = false
		commandCenter.changeRepeatModeCommand.isEnabled = false
		commandCenter.changeShuffleModeCommand.isEnabled = false
		commandCenter.nextTrackCommand.isEnabled = false
		commandCenter.previousTrackCommand.isEnabled = false
		commandCenter.skipForwardCommand.isEnabled = false
		commandCenter.skipBackwardCommand.isEnabled = false
		commandCenter.changePlaybackPositionCommand.isEnabled = false
		commandCenter.ratingCommand.isEnabled = false
		commandCenter.likeCommand.isEnabled = false
		commandCenter.dislikeCommand.isEnabled = false
		commandCenter.bookmarkCommand.isEnabled = false
		
		commandCenter.playCommand.removeTarget(nil)
		commandCenter.pauseCommand.removeTarget(nil)
		commandCenter.stopCommand.removeTarget(nil)
		commandCenter.togglePlayPauseCommand.removeTarget(nil)
		commandCenter.enableLanguageOptionCommand.removeTarget(nil)
		commandCenter.disableLanguageOptionCommand.removeTarget(nil)
		commandCenter.changePlaybackRateCommand.removeTarget(nil)
		commandCenter.changeRepeatModeCommand.removeTarget(nil)
		commandCenter.changeShuffleModeCommand.removeTarget(nil)
		commandCenter.nextTrackCommand.removeTarget(nil)
		commandCenter.previousTrackCommand.removeTarget(nil)
		commandCenter.skipForwardCommand.removeTarget(nil)
		commandCenter.skipBackwardCommand.removeTarget(nil)
		commandCenter.changePlaybackPositionCommand.removeTarget(nil)
		commandCenter.ratingCommand.removeTarget(nil)
		commandCenter.likeCommand.removeTarget(nil)
		commandCenter.dislikeCommand.removeTarget(nil)
		commandCenter.bookmarkCommand.removeTarget(nil)
	}
	
	private func configure(command: NowPlayingClient.RemoteCommand, handlers: NowPlayingClient.RemoteCommandHandlers) {
		let remoteCommand = command.toMPRemoteCommand()
		remoteCommand.isEnabled = true
		remoteCommand.addTarget { rawEvent in
			let handler = handlers.handler(for: command)
			switch handler {
			case let .action(action):
				return action()
				
			case let .boolAction(action):
				if let event = rawEvent as? MPFeedbackCommandEvent {
					return action(event.isNegative)
				}
				return .noSuchContent
				
			case let .intAction(action):
				if let event = rawEvent as? MPChangeRepeatModeCommandEvent {
					return action(event.repeatType.rawValue)
				}
				
				if let event = rawEvent as? MPChangeShuffleModeCommandEvent {
					return action(event.shuffleType.rawValue)
				}
				
				return .noSuchContent
				
			case let .floatAction(action):
				if let event = rawEvent as? MPChangePlaybackRateCommandEvent {
					return action(event.playbackRate)
				}
				
				if let event = rawEvent as? MPRatingCommandEvent {
					return action(event.rating)
				}
				return .noSuchContent
				
			case let .timeIntervalAction(action):
				if let event = rawEvent as? MPChangePlaybackPositionCommandEvent {
					return action(event.positionTime)
				}
				
				if let event = rawEvent as? MPSkipIntervalCommandEvent {
					return action(event.interval)
				}
				return .noSuchContent
			}
		}
	}
}

// MARK: - Model

extension NowPlayingDelegate {
	
	private struct NowPlayingMetadata: Sendable {
		var title: String?
		var artist: String?
		var album: String?
		var artwork: UIImage?
		var artworkHash: Data?
		var duration: TimeInterval = .zero
		var elapsedTime: TimeInterval = .zero
		var playbackRate: Float = 0.0
		var mediaType: MPNowPlayingInfoMediaType = .audio
		
		func toDictionary() -> [String: Any] {
			var dict: [String: Any] = [
				MPMediaItemPropertyTitle: title ?? "Unknown",
				MPMediaItemPropertyArtist: artist ?? "Unknown",
				MPMediaItemPropertyAlbumTitle: album ?? "",
				MPMediaItemPropertyPlaybackDuration: duration,
				MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
				MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
				MPNowPlayingInfoPropertyMediaType: mediaType.rawValue
			]
			
			if let artworkImage = artwork {
				let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
				dict[MPMediaItemPropertyArtwork] = artwork
			}
			
			return dict
		}
		
		static func computeArtworkHash(_ image: UIImage?) -> Data? {
			guard let image = image,
				  let resizedImage = image.resized(to: CGSize(width: 100, height: 100)),
				  let data = resizedImage.jpegData(compressionQuality: 0.8) else { return nil }
			return Data(SHA256.hash(data: data))
		}
	}
}
