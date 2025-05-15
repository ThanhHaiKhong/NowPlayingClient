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
	
	func updateStaticInfo(_ info: NowPlayingClient.StaticNowPlayingInfo) async throws {
		try await delegate.updateStaticInfo(info)
	}
	
	func updateDynamicInfo(_ info: NowPlayingClient.DynamicNowPlayingInfo) async throws {
		try await delegate.updateDynamicInfo(info)
	}
	
	func setupRemoteCommands(_ enabledCommands: Set<NowPlayingClient.RemoteCommand>, _ handlers: NowPlayingClient.RemoteCommandHandlers) async {
		await delegate.setupRemoteCommands(enabledCommands, handlers)
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
