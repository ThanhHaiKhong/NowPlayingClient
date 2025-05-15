//
//  Mocks.swift
//  NowPlayingClient
//
//  Created by Thanh Hai Khong on 14/5/25.
//

import Dependencies

extension DependencyValues {
	public var nowPlayingClient: NowPlayingClient {
		get { self[NowPlayingClient.self] }
		set { self[NowPlayingClient.self] = newValue }
	}
}

extension NowPlayingClient: TestDependencyKey {
	public static var testValue: NowPlayingClient {
		NowPlayingClient()
	}
	
	public static var previewValue: NowPlayingClient {
		NowPlayingClient()
	}
}
