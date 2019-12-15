//
//  IntroView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import PaperOnboarding
import SwiftUI

struct IntroView: UIViewControllerRepresentable {

    class Coordinator: NSObject {
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<IntroView>) -> IntroViewController {
        return IntroViewController()
    }

    func makeCoordinator() -> IntroView.Coordinator {
        return Coordinator()
    }

    func updateUIViewController(_ uiViewController: IntroViewController, context: UIViewControllerRepresentableContext<IntroView>) {
    }
}

struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        IntroView()
    }
}
