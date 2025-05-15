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

final private class NowPlayingDelegate: NSObject, @unchecked Sendable {
	
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
	
	private let state = LockIsolated(NowPlayingMetadata())
	private var interruptionObserver: NSObjectProtocol?
	
	@MainActor
	func updateStaticInfo(_ info: NowPlayingClient.StaticNowPlayingInfo) async throws {
		try await MainActor.run {
			guard info.duration >= 0 else {
				throw NowPlayingError.invalidDuration
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
			
			try AVAudioSession.sharedInstance().ensureActive()
			
			MPNowPlayingInfoCenter.default().nowPlayingInfo = state.value.toDictionary()
		}
	}
	
	@MainActor
	func updateDynamicInfo(_ info: NowPlayingClient.DynamicNowPlayingInfo) async throws {
		try await MainActor.run {
			guard info.elapsedTime >= 0, info.playbackRate >= 0 else {
				throw NowPlayingError.invalidPlaybackState
			}
			
			state.withValue { metadata in
				metadata.elapsedTime = info.elapsedTime
				metadata.playbackRate = info.playbackRate
			}
			
			try AVAudioSession.sharedInstance().ensureActive()
			
			MPNowPlayingInfoCenter.default().nowPlayingInfo = state.value.toDictionary()
		}
	}
	
	func setupRemoteCommands(_ handlers: NowPlayingClient.RemoteCommandHandlers) async {
		await MainActor.run {
			let commandCenter = MPRemoteCommandCenter.shared()
			
			// Clear existing targets to prevent duplicates
			commandCenter.playCommand.removeTarget(nil)
			commandCenter.pauseCommand.removeTarget(nil)
			commandCenter.nextTrackCommand.removeTarget(nil)
			commandCenter.previousTrackCommand.removeTarget(nil)
			commandCenter.skipForwardCommand.removeTarget(nil)
			commandCenter.skipBackwardCommand.removeTarget(nil)
			commandCenter.changePlaybackPositionCommand.removeTarget(nil)
			
			// Configure play command
			commandCenter.playCommand.isEnabled = true
			commandCenter.playCommand.addTarget { _ in
				handlers.play()
				return .success
			}
			
			// Configure pause command
			commandCenter.pauseCommand.isEnabled = true
			commandCenter.pauseCommand.addTarget { _ in
				handlers.pause()
				return .success
			}
			
			// Configure next track command
			commandCenter.nextTrackCommand.isEnabled = true
			commandCenter.nextTrackCommand.addTarget { _ in
				handlers.nextTrack()
				return .success
			}
			
			// Configure previous track command
			commandCenter.previousTrackCommand.isEnabled = true
			commandCenter.previousTrackCommand.addTarget { _ in
				handlers.previousTrack()
				return .success
			}
			
			// Configure skip forward command (e.g., 15 seconds)
			commandCenter.skipForwardCommand.isEnabled = true
			commandCenter.skipForwardCommand.preferredIntervals = [15]
			commandCenter.skipForwardCommand.addTarget { _ in
				handlers.seekForward(15)
				return .success
			}
			
			// Configure skip backward command (e.g., 15 seconds)
			commandCenter.skipBackwardCommand.isEnabled = true
			commandCenter.skipBackwardCommand.preferredIntervals = [15]
			commandCenter.skipBackwardCommand.addTarget { _ in
				handlers.seekBackward(15)
				return .success
			}
			
			// Configure change playback position command
			commandCenter.changePlaybackPositionCommand.isEnabled = true
			commandCenter.changePlaybackPositionCommand.addTarget { event in
				guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
					return .commandFailed
				}
				handlers.changePlaybackPosition(positionEvent.positionTime)
				return .success
			}
			
			// Enable receiving remote control events
			UIApplication.shared.beginReceivingRemoteControlEvents()
		}
	}
	
	func remoteCommandEvents() -> AsyncStream<NowPlayingClient.RemoteCommandEvent> {
		AsyncStream { continuation in
			let commandCenter = MPRemoteCommandCenter.shared()
			
			// Play command
			commandCenter.playCommand.addTarget { _ in
				continuation.yield(.play)
				return .success
			}
			
			// Pause command
			commandCenter.pauseCommand.addTarget { _ in
				continuation.yield(.pause)
				return .success
			}
			
			// Next track command
			commandCenter.nextTrackCommand.addTarget { _ in
				continuation.yield(.nextTrack)
				return .success
			}
			
			// Previous track command
			commandCenter.previousTrackCommand.addTarget { _ in
				continuation.yield(.previousTrack)
				return .success
			}
			
			// Skip forward command
			commandCenter.skipForwardCommand.addTarget { _ in
				continuation.yield(.seekForward(15))
				return .success
			}
			
			// Skip backward command
			commandCenter.skipBackwardCommand.addTarget { _ in
				continuation.yield(.seekBackward(15))
				return .success
			}
			
			// Change playback position command
			commandCenter.changePlaybackPositionCommand.addTarget { event in
				guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
					return .commandFailed
				}
				continuation.yield(.changePlaybackPosition(positionEvent.positionTime))
				return .success
			}
			
			// Cleanup on stream termination
			continuation.onTermination = { _ in
				commandCenter.playCommand.removeTarget(nil)
				commandCenter.pauseCommand.removeTarget(nil)
				commandCenter.nextTrackCommand.removeTarget(nil)
				commandCenter.previousTrackCommand.removeTarget(nil)
				commandCenter.skipForwardCommand.removeTarget(nil)
				commandCenter.skipBackwardCommand.removeTarget(nil)
				commandCenter.changePlaybackPositionCommand.removeTarget(nil)
				
				Task {
					await UIApplication.shared.endReceivingRemoteControlEvents()
				}
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
	
	func initializeAudioSession(_ category: AVAudioSession.Category, _ mode: AVAudioSession.Mode, _ options: AVAudioSession.CategoryOptions) async throws {
		try await MainActor.run {
			let audioSession = AVAudioSession.sharedInstance()
			try audioSession.setCategory(category, mode: mode, options: options)
			try audioSession.setActive(true)
		}
	}
	
	func reset() async {
		await MainActor.run {
			state.setValue(NowPlayingMetadata(title: nil, artist: nil, album: nil, artwork: nil, artworkHash: nil, duration: 0, elapsedTime: 0, playbackRate: 0, mediaType: .audio))
			
			MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
			
			let commandCenter = MPRemoteCommandCenter.shared()
			commandCenter.playCommand.isEnabled = false
			commandCenter.pauseCommand.isEnabled = false
			commandCenter.nextTrackCommand.isEnabled = false
			commandCenter.previousTrackCommand.isEnabled = false
			commandCenter.skipForwardCommand.isEnabled = false
			commandCenter.skipBackwardCommand.isEnabled = false
			commandCenter.changePlaybackPositionCommand.isEnabled = false
			
			commandCenter.playCommand.removeTarget(nil)
			commandCenter.pauseCommand.removeTarget(nil)
			commandCenter.nextTrackCommand.removeTarget(nil)
			commandCenter.previousTrackCommand.removeTarget(nil)
			commandCenter.skipForwardCommand.removeTarget(nil)
			commandCenter.skipBackwardCommand.removeTarget(nil)
			commandCenter.changePlaybackPositionCommand.removeTarget(nil)
			
			UIApplication.shared.endReceivingRemoteControlEvents()
			
			try? AVAudioSession.sharedInstance().setActive(false)
			
			if let observer = interruptionObserver {
				NotificationCenter.default.removeObserver(observer)
				interruptionObserver = nil
			}
		}
	}
}

extension UIImage {
	func resized(to size: CGSize) -> UIImage? {
		UIGraphicsBeginImageContextWithOptions(size, false, scale)
		defer { UIGraphicsEndImageContext() }
		draw(in: CGRect(origin: .zero, size: size))
		return UIGraphicsGetImageFromCurrentImageContext()
	}
}

extension MPRemoteCommandCenter: @unchecked @retroactive Sendable {
	
}

extension MPMediaItemArtwork: @unchecked @retroactive Sendable {
	
}

enum NowPlayingError: Error, Sendable, Equatable {
	case invalidDuration
	case invalidPlaybackState
	case audioSessionInactive
}

// MARK: - AVAudioSession Extension

extension AVAudioSession {
	func ensureActive() throws {
		do {
			try setActive(true)
		} catch {
			throw NowPlayingError.audioSessionInactive
		}
	}
}

actor NowPlayingActor {
	
	private let delegate = NowPlayingDelegate()
	
	func updateStaticInfo(_ info: NowPlayingClient.StaticNowPlayingInfo) async throws {
		try await delegate.updateStaticInfo(info)
	}
	
	func updateDynamicInfo(_ info: NowPlayingClient.DynamicNowPlayingInfo) async throws {
		try await delegate.updateDynamicInfo(info)
	}
	
	func setupRemoteCommands(_ handlers: NowPlayingClient.RemoteCommandHandlers) async {
		await delegate.setupRemoteCommands(handlers)
	}
	
	func remoteCommandEvents() -> AsyncStream<NowPlayingClient.RemoteCommandEvent> {
		delegate.remoteCommandEvents()
	}
	
	func interruptionEvents() -> AsyncStream<NowPlayingClient.InterruptionEvent> {
		delegate.interruptionEvents()
	}
	
	func initializeAudioSession(_ category: AVAudioSession.Category, _ mode: AVAudioSession.Mode, _ options: AVAudioSession.CategoryOptions) async throws {
		try await delegate.initializeAudioSession(category, mode, options)
	}
	
	func reset() async {
		await delegate.reset()
	}
}
