//
//  Actor.swift
//  NowPlayingClient
//
//  Created by Thanh Hai Khong on 15/5/25.
//

import NowPlayingClient
import AVKit

actor NowPlayingActor {
	
	private let delegate = NowPlayingDelegate()
	
	func initializeAudioSession(_ category: AVAudioSession.Category, _ mode: AVAudioSession.Mode, _ options: AVAudioSession.CategoryOptions) async throws {
		try await delegate.initializeAudioSession(category, mode, options)
	}
	
	func setupRemoteCommands(_ handlers: NowPlayingClient.RemoteCommandHandlers) async {
		await delegate.setupRemoteCommands(handlers)
	}

	func remoteCommandEvents(_ enabledCommands: Set<NowPlayingClient.RemoteCommand>) -> AsyncStream<NowPlayingClient.RemoteCommandEvent> {
		delegate.remoteCommandEvents(enabledCommands)
	}
	
	func interruptionEvents() -> AsyncStream<NowPlayingClient.InterruptionEvent> {
		delegate.interruptionEvents()
	}
	
	func updateStaticInfo(_ info: NowPlayingClient.StaticNowPlayingInfo) async throws {
		try await delegate.updateStaticInfo(info)
	}
	
	func updateDynamicInfo(_ info: NowPlayingClient.DynamicNowPlayingInfo) async throws {
		try await delegate.updateDynamicInfo(info)
	}
	
	func reset() async {
		await delegate.reset()
	}
}
