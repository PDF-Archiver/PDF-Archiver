//
//  OnboardCard.swift
//  Onboarding
//
//  Created by Stewart Lynch on 2020-06-27.
//

import Foundation

struct OnboardCard: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let image: String
    let text: String
}
