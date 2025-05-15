//
//  Extensions.swift
//  NowPlayingClient
//
//  Created by Thanh Hai Khong on 15/5/25.
//

import UIKit
import AVKit
import MediaPlayer
import NowPlayingClient

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

extension AVAudioSession {
	func ensureActive() throws {
		do {
			try setActive(true)
		} catch {
			throw NowPlayingClient.NowPlayingError.audioSessionInactive
		}
	}
}
