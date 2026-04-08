import SwiftUI

struct ContentView: View {
    @AppStorage("tutorialCompleted") private var tutorialCompleted = false

    var body: some View {
        if tutorialCompleted {
            MainTabView()
        } else {
            TutorialView {
                tutorialCompleted = true
            }
        }
    }
}

#Preview {
    ContentView()
}
