// The Swift Programming Language
// https://docs.swift.org/swift-book

import DependenciesMacros
import AVKit

@DependencyClient
public struct NowPlayingClient: Sendable {
	public var updateStaticInfo: @Sendable (_ info: NowPlayingClient.StaticNowPlayingInfo) async throws -> Void
	public var updateDynamicInfo: @Sendable (_ info: NowPlayingClient.DynamicNowPlayingInfo) async throws -> Void
	public var setupRemoteCommands: @Sendable (_ handlers: NowPlayingClient.RemoteCommandHandlers) async -> Void
	public var remoteCommandEvents: @Sendable () async -> AsyncStream<NowPlayingClient.RemoteCommandEvent> = { AsyncStream { _ in } }
	public var interruptionEvents: @Sendable () async -> AsyncStream<NowPlayingClient.InterruptionEvent> = { AsyncStream { _ in } }
	public var initializeAudioSession: @Sendable (_ category: AVAudioSession.Category, _ mode: AVAudioSession.Mode, _ options: AVAudioSession.CategoryOptions) async throws -> Void
	public var reset: @Sendable () async -> Void
}
