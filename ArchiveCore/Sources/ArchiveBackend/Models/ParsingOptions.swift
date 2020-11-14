//
//  File.swift
//  
//
//  Created by Julian Kahnert on 17.07.20.
//

public struct ParsingOptions: OptionSet {
    public let rawValue: Int

    public static let date = ParsingOptions(rawValue: 1 << 0)
    public static let tags = ParsingOptions(rawValue: 1 << 1)

    public static let mainThread = ParsingOptions(rawValue: 1 << 2)

    public static let all: ParsingOptions = [.date, .tags]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
