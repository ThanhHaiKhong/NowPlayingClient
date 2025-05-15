//
//  Live.swift
//  NowPlayingClient
//
//  Created by Thanh Hai Khong on 14/5/25.
//

import Dependencies
import NowPlayingClient

extension NowPlayingClient: DependencyKey {
	public static let liveValue: NowPlayingClient = {
		let actor = NowPlayingActor()
		
		return NowPlayingClient(
			updateStaticInfo: { info in
				try await actor.updateStaticInfo(info)
			},
			updateDynamicInfo: { info in
				try await actor.updateDynamicInfo(info)
			},
			setupRemoteCommands: { handlers in
				await actor.setupRemoteCommands(handlers)
			},
			remoteCommandEvents: {
				await actor.remoteCommandEvents()
			},
			interruptionEvents: {
				await actor.interruptionEvents()
			},
			initializeAudioSession: { category, mode, options in
				try await actor.initializeAudioSession(category, mode, options)
			},
			reset: {
				await actor.reset()
			}
		)
	}()
}
