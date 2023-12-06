//
//  Models.swift
//  Audible Assistant
//
//  Created by Andrew Blumenthal on 12/5/23.
//

import Foundation

enum VoiceType: String, Codable, Hashable, Sendable, CaseIterable {
    case alloy
    case echo
    case fable
    case onyx
    case shimmer
}
enum VoiceChatState{
    case idle
    case recordingSpeech
    case processingSpeech
    case playingSpeech
    case error(Error)
}

