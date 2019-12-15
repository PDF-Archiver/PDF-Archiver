//
//  SearchField.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct SearchField: View {
    @Binding var searchText: String
    @Binding var scopes: [String]
    @Binding var selectionIndex: Int
    var placeholder: LocalizedStringKey
    var body: some View {
        VStack {
            search
            segmentedControl
        }
    }

    var search: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.secondary)
            TextField(placeholder, text: $searchText)
            Button(action: {
                self.searchText = ""
                self.selectionIndex = 0
            }, label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.secondary)
                    .opacity(self.searchText.isEmpty ? 0.0 : 1.0)
            })
        }
        .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 1)
        )
        .padding(EdgeInsets(top: 0.0, leading: 2.0, bottom: 0.0, trailing: 2.0))
    }

    var segmentedControl: some View {
        Picker(selection: $selectionIndex, label: Text("")) {
            ForEach(0..<self.scopes.count) { index in
                Text(LocalizedStringKey(self.scopes[index])).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct SearchField_Previews: PreviewProvider {
    private static let array = ["John", "Lena", "Steve", "Chris", "Catalina"]
    @State private static var searchText = ""
    @State private static var years = ["All", "2019", "2018", "2017"]
    @State private static var selection = 0

    static var previews: some View {
        NavigationView {
            VStack {
                SearchField(searchText: $searchText, scopes: $years, selectionIndex: $selection, placeholder: "Search")
                    .padding(EdgeInsets(top: 0.0, leading: 16.0, bottom: 0.0, trailing: 16.0))
                List {
                    ForEach(array.filter { $0.hasPrefix(searchText) || searchText.isEmpty }, id: \.self) { searchText in
                        Text(searchText)
                    }
                }
            }
            .navigationBarTitle(Text("Search"))
        }
    }
}
