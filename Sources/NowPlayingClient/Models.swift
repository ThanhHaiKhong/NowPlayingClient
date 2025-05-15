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
	 
	public enum RemoteCommand: Sendable, Equatable {
		case play
		case pause
		case stop
		case togglePlayPause
		case enableLanguageOption
		case disableLanguageOption
		case changePlaybackRate(Float)
		case changeRepeatMode
		case changeShuffleMode
		case nextTrack
		case previousTrack
		case skipForward(TimeInterval)
		case skipBackward(TimeInterval)
		case changePlaybackPosition(TimeInterval)
		case rating
		case like
		case dislike
		case bookmark
	}
	
	// MARK: - RemoteCommandHandlers
	
	public struct RemoteCommandHandlers: Sendable {
		public var play: @Sendable () -> Void
		public var pause: @Sendable () -> Void
		public var nextTrack: @Sendable () -> Void
		public var previousTrack: @Sendable () -> Void
		public var seekForward: @Sendable (TimeInterval) -> Void
		public var seekBackward: @Sendable (TimeInterval) -> Void
		public var changePlaybackPosition: @Sendable (TimeInterval) -> Void
	}
	
	// MARK: - RemoteCommandEvent
	
	public enum RemoteCommandEvent: Sendable, Equatable {
		case play
		case pause
		case nextTrack
		case previousTrack
		case seekForward(TimeInterval)
		case seekBackward(TimeInterval)
		case changePlaybackPosition(TimeInterval)
	}
	
	// MARK: - InterruptionEvent
	
	public enum InterruptionEvent: Sendable, Equatable {
		case began
		case ended(shouldResume: Bool)
	}
}
