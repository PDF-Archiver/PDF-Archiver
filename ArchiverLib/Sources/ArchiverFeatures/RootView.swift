import ComposableArchitecture
import SwiftUI

public struct RootView: View {
    let store = Store(initialState: ArchiveList.State(documents: [
        .mock(url: .temporaryDirectory.appending(component: "file1.pdf")),
        .mock(url: .temporaryDirectory.appending(component: "file2.pdf"), downloadStatus: 1),
    ])) {
        ArchiveList()
            ._printChanges()
    }

    public init() {}
    
    public var body: some View {
        NavigationStack {
            ArchiveListView(store: store)
        }
    }
}

#Preview {
  RootView()
}
