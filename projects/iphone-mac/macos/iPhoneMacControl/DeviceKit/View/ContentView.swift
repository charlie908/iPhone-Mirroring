import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.blue)

            Text("iPhone Mac Control")
                .font(.title2.weight(.semibold))

            Text("Les commandes du Mac sont prêtes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
