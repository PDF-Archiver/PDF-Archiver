//
//  OnboardCard.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import DeveloperToolsSupport
import Foundation

struct OnboardCard: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let image: ImageResource
    let text: String
}
