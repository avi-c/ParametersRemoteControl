//
//  CodableTweak.swift
//  SwiftTweaks
//
//  Created by Avi Cieplinski on 9/25/18.
//  Copyright © 2018 Khan Academy. All rights reserved.
//

import SwiftTweaks
import UIKit

public struct CodeableTweak : Codable {
	var collectionName: String
	var groupName: String
	var tweakName: String
	var tweakType: Int
	public var doubleValue: Double
	public var cgFloatValue: CGFloat
	public var intValue: Int
	public var boolValue: Bool
	public var stringValue: String

	public init(tweak: AnyTweak) {
		collectionName = tweak.collectionName
		groupName = tweak.groupName
		tweakName = tweak.tweakName
		tweakType = tweak.tweakViewDataType.rawValue
		doubleValue = Double(-1.0)
		cgFloatValue = CGFloat(-1.0)
		intValue = Int(-1)
		boolValue = false
		stringValue = ""
	}

	enum CodingKeys: String, CodingKey {
		case collectionName
		case groupName
		case tweakName
		case tweakType
		case doubleValue
		case cgFloatValue
		case intValue
		case boolValue
		case stringValue
	}

	public init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		collectionName = try values.decode(String.self, forKey: .collectionName)
		groupName = try values.decode(String.self, forKey: .groupName)
		tweakName = try values.decode(String.self, forKey: .tweakName)
		let tweakTypeIndex = try values.decode(Int.self, forKey: .tweakType)
		let tweakDataType = TweakViewDataType.allTypes[tweakTypeIndex]
		tweakType = tweakDataType.rawValue
		cgFloatValue = -1.0
		doubleValue = -1.0
		intValue = -1
		boolValue = false
		stringValue = ""

		if tweakDataType == .cgFloat {
			cgFloatValue = try values.decode(CGFloat.self, forKey: .cgFloatValue)
		} else if tweakDataType == .double {
			doubleValue = try values.decode(Double.self, forKey: .doubleValue)
		} else if tweakDataType == .integer {
			intValue = try values.decode(Int.self, forKey: .intValue)
		} else if tweakDataType == .boolean {
			boolValue = try values.decode(Bool.self, forKey: .boolValue)
		} else if tweakDataType == .string {
            stringValue = try values.decode(String.self, forKey: .stringValue)
        }
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(collectionName, forKey: .collectionName)
		try container.encode(groupName, forKey: .groupName)
		try container.encode(tweakName, forKey: .tweakName)
		try container.encode(doubleValue, forKey: .doubleValue)
		try container.encode(cgFloatValue, forKey: .cgFloatValue)
		try container.encode(intValue, forKey: .intValue)
		try container.encode(boolValue, forKey: .boolValue)
		try container.encode(stringValue, forKey: .stringValue)
	}
}
