//
//  PhantomViewModifiers.swift
//  
//
//  Created by Julian Kahnert on 08.11.20.
//

import SwiftUI

#if os(macOS)
extension View {
    func navigationBarHidden(_ value: Bool) -> some View {
        self
    }

    func navigationBarTitle(_ title: Text, displayMode: NavigationBarItem.TitleDisplayMode = .inline) -> some View {
        self
    }

    func navigationBarItems<L, T>(leading: L, trailing: T) -> some View where L: View, T: View {
        self
    }

    func navigationBarItems<L>(leading: L) -> some View where L: View {
        self
    }

    func navigationBarItems<T>(trailing: T) -> some View where T: View {
        self
    }
}

enum NavigationBarItem {
    enum TitleDisplayMode {
        case inline
    }
}
#endif
