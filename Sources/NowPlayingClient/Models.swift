//
//  Models.swift
//  NowPlayingClient
//
//  Created by Thanh Hai Khong on 14/5/25.
//

import MediaPlayer
import UIKit
import AVFoundation

extension NowPlayingClient {
	
	// MARK: - NowPlayingInfo
	
	public struct StaticNowPlayingInfo: Sendable, Equatable {
		public var title: String?
		public var artist: String?
		public var album: String?
		public var artwork: UIImage?
		public var duration: TimeInterval
		public var mediaType: MPNowPlayingInfoMediaType
		
		public static let empty = StaticNowPlayingInfo(
			title: nil, artist: nil, album: nil, artwork: nil, duration: 0, mediaType: .audio
		)
	}
	
	public struct DynamicNowPlayingInfo: Sendable, Equatable {
		public var elapsedTime: TimeInterval
		public var playbackRate: Float
		
		public static let empty = DynamicNowPlayingInfo(elapsedTime: 0, playbackRate: 0.0)
	}
	
	// MARK: - RemoteCommand
	 
	public enum RemoteCommand: Sendable, Equatable, Hashable {
		case play
		case pause
		case stop
		case togglePlayPause
		case changeLanguageOption(isEnabled: Bool)
		case changePlaybackRate(rates: [Float])
		case changeRepeatMode
		case changeShuffleMode
		case nextTrack
		case previousTrack
		case skipForward(intervals: [Float])
		case skipBackward(intervals: [Float])
		case changePlaybackPosition
		case rating(min: Float, max: Float)
		case like(isActive: Bool, title: String)
		case dislike(isActive: Bool, title: String)
		case bookmark(isActive: Bool, title: String)
	}
	
	// MARK: - RemoteCommandHandlers
	
	public struct RemoteCommandHandlers: Sendable {
		public enum Handler: Sendable {
			case action(@Sendable () -> MPRemoteCommandHandlerStatus)
			case boolAction(@Sendable (Bool) -> MPRemoteCommandHandlerStatus)
			case intAction(@Sendable (Int) -> MPRemoteCommandHandlerStatus)
			case floatAction(@Sendable (Float) -> MPRemoteCommandHandlerStatus)
			case timeIntervalAction(@Sendable (TimeInterval) -> MPRemoteCommandHandlerStatus)
		}
		
		private let handlers: [RemoteCommand: Handler]
		
		public init(handlers: [RemoteCommand: Handler] = [:]) {
			self.handlers = handlers
		}
		
		public func handler(for command: RemoteCommand) -> Handler {
			handlers[command] ?? .action {
				return .noSuchContent
			}
		}
		
		public func withHandler(_ command: RemoteCommand, _ handler: Handler) -> Self {
			var newHandlers = handlers
			newHandlers[command] = handler
			return Self(handlers: newHandlers)
		}
	}
	
	// MARK: - InterruptionEvent
	
	public enum InterruptionEvent: Sendable, Equatable {
		case began
		case ended(shouldResume: Bool)
	}
	
	// MARK: - Error
	
	public enum NowPlayingError: Error, Sendable, Equatable {
		case invalidDuration
		case invalidPlaybackState
		case audioSessionInactive
	}
}

extension NowPlayingClient.RemoteCommand {
	public func toMPRemoteCommand() -> MPRemoteCommand {
		let commandCenter = MPRemoteCommandCenter.shared()
		switch self {
		case .play:
			return commandCenter.playCommand
		case .pause:
			return commandCenter.pauseCommand
		case .stop:
			return commandCenter.stopCommand
		case .togglePlayPause:
			return commandCenter.togglePlayPauseCommand
		case let .changeLanguageOption(isEnabled):
			if isEnabled {
				return commandCenter.enableLanguageOptionCommand
			} else {
				return commandCenter.disableLanguageOptionCommand
			}
		case let .changePlaybackRate(rates):
			let playbackRateCommand = commandCenter.changePlaybackRateCommand
			playbackRateCommand.supportedPlaybackRates = rates.map { NSNumber(value: $0) }
			return playbackRateCommand
		case .changeRepeatMode:
			return commandCenter.changeRepeatModeCommand
		case .changeShuffleMode:
			return commandCenter.changeShuffleModeCommand
		case .nextTrack:
			return commandCenter.nextTrackCommand
		case .previousTrack:
			return commandCenter.previousTrackCommand
		case let .skipForward(intervals):
			let skipForwardCommand = commandCenter.skipForwardCommand
			skipForwardCommand.preferredIntervals = intervals.map { NSNumber(value: $0) }
			return skipForwardCommand
		case let .skipBackward(intervals):
			let skipBackwardCommand = commandCenter.skipBackwardCommand
			skipBackwardCommand.preferredIntervals = intervals.map { NSNumber(value: $0) }
			return skipBackwardCommand
		case .changePlaybackPosition:
			return commandCenter.changePlaybackPositionCommand
		case let .rating(min, max):
			let ratingCommand = commandCenter.ratingCommand
			ratingCommand.minimumRating = min
			ratingCommand.maximumRating = max
			return ratingCommand
		case let .like(isActive, title):
			let likeCommand = commandCenter.likeCommand
			likeCommand.isActive = isActive
			likeCommand.localizedTitle = title
			return likeCommand
		case let .dislike(isActive, title):
			let dislikeCommand = commandCenter.dislikeCommand
			dislikeCommand.isActive = isActive
			dislikeCommand.localizedTitle = title
			return dislikeCommand
		case let .bookmark(isActive, title):
			let bookmarkCommand = commandCenter.bookmarkCommand
			bookmarkCommand.isActive = isActive
			bookmarkCommand.localizedTitle = title
			return bookmarkCommand
		}
	}
}
