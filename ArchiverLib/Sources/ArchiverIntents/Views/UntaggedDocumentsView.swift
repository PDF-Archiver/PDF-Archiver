//
//  UntaggedDocumentsView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import Shared
import SwiftUI

public struct UntaggedDocumentsView: View {
    public enum Size {
        case small, medium, large
    }

    let untaggedDocuments: Int
    let size: Size

    public init(untaggedDocuments: Int, size: Size) {
        self.untaggedDocuments = untaggedDocuments
        self.size = size
    }

    var actionButtons: some View {
         HStack {
            if untaggedDocuments <= 0 {

                Link(destination: DeepLink.scan.url) {
                    Label("Scan", systemImage: "document.viewfinder")
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(
                    Capsule().fill(Color.paRedAsset)
                )
                .foregroundColor(.white)

            } else {
                Link(destination: DeepLink.scan.url) {
                    Image(systemName: "doc.viewfinder")
                }
                .padding(10)
                .background(Circle().fill(Color.gray.opacity(0.3)))

                Link(destination: DeepLink.tag.url) {
                    Label("Tag", systemImage: "tag")
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                }
                .padding(10)
                .background(Capsule().fill(Color.paRedAsset))
                .foregroundColor(.white)

            }
         }
        .padding(.top, 8)
    }

    public var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading) {
                if untaggedDocuments > 0 {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(untaggedDocuments, format: .number)
                                .fontWeight(.black)
                                .foregroundStyle(.primary)

                            Image(systemName: "document.on.document")
                                .foregroundStyle(Color.paRedAsset)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color.paRedAsset.opacity(0.4))
                            .padding([.top, .trailing], -40)

                        Text("All documents are tagged. 🎉")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                actionButtons
            }

        case .medium:
            VStack(alignment: .leading) {
                if untaggedDocuments > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(untaggedDocuments, format: .number)
                            .font(.system(size: 48, weight: .black))

                        Image(systemName: "document.on.document")
                            .foregroundStyle(Color.paRedAsset)
                            .symbolRenderingMode(.hierarchical)
                            .font(.title)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)

                        Spacer()
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color.paRedAsset.opacity(0.4))
                            .padding([.top, .trailing], -40)

                        Text("All documents are tagged. 🎉")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                    }
                }

                Spacer()

                actionButtons
            }
        case .large:
            VStack(alignment: .leading) {
                if untaggedDocuments > 0 {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(untaggedDocuments, format: .number)
                                .fontWeight(.black)

                            Image(systemName: "document.on.document")
                                .foregroundStyle(Color.paRedAsset)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Untagged Documents")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color.paRedAsset.opacity(0.4))
                            .padding([.top, .trailing], -40)

                        Text("All documents are tagged. 🎉")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                    }
                }

                Spacer()

                actionButtons
            }
        }
    }
}

#Preview("Small") {
    Group {
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .small)
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .small)
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .small)
    }
}

#Preview("Medium") {
    Group {
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .medium)
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .medium)
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .medium)
    }
}

#Preview("Large") {
    Group {
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .large)
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .large)
        UntaggedDocumentsView(untaggedDocuments: 0,
                              size: .large)
    }
}
