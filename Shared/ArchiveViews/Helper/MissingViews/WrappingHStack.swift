//
//  WrappingHStack.swift
//  
//
//  Created by Julian Kahnert on 26.12.20.
//
// Source: https://stackoverflow.com/a/62103264/10026834

import SwiftUI

public struct WrappingHStack<Item: Identifiable & Hashable, Content: View>: View {
    var items: [Item]

    @State private var totalHeight
          = CGFloat.zero       // << variant for ScrollView/List
    //    = CGFloat.infinity   // << variant for VStack

    private let content: (Item) -> Content
    public init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    public var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)// << variant for ScrollView/List
        // .frame(maxHeight: totalHeight) // << variant for VStack
    }

    private func generateContent(in proxy: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading) { dimensions in
                        if abs(width - dimensions.width) > proxy.size.width {
                            width = 0
                            height -= dimensions.height
                        }
                        let result = width
                        if let lastItem = self.items.last,
                           item == lastItem {
                            width = 0 // last item
                        } else {
                            width -= dimensions.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if let lastItem = self.items.last,
                           item == lastItem {
                            height = 0 // last item
                        }
                        return result
                    }
            }
        }.background(viewHeightReader($totalHeight))
    }

    private func item(for text: String) -> some View {
        Text(text)
            .padding(.all, 5)
            .font(.body)
            .background(Color.blue)
            .foregroundColor(Color.white)
            .cornerRadius(5)
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

#if DEBUG
struct WrappingHStack_Previews: PreviewProvider {
    static var previews: some View {
        WrappingHStack(items: ["Nintendo", "XBox", "PlayStation", "PlayStation 2", "PlayStation 3", "PlayStation 4"]) { text in
            TagView(tagName: text, isEditable: true, tapHandler: { print($0) })
//            Label(text, systemImage: "tag")
//                .padding(.all, 5)
                .font(.body)
                .fixedSize()
                .background(Color.blue)
                .foregroundColor(Color.white)
                .cornerRadius(5)
        }
    }
}
#endif
