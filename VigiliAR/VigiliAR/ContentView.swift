//
//  ContentView.swift
//  VigiliAR
//
//  Created by Alessandro Soccol on 15/03/26.
//

import SwiftUI

struct ContentView : View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("👋🏻 Hello, \(userProfileStore.greetingName)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text("VigiliAR")
                    .font(.largeTitle).bold()

                TextField("Enter your name", text: $userProfileStore.name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)

                Spacer()

                NavigationLink(destination: VehiclesView()) {
                    Text("Veicoli Rilevati")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                NavigationLink(destination: ARTrackingView()) {
                    Text("Inizia Rilevazione")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
    }

}

#Preview {
    ContentView()
        .environmentObject(VehicleStore())
        .environmentObject(ARTrackingSceneStore())
        .environmentObject(UserProfileStore())
}
