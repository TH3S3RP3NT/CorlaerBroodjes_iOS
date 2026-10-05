import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Plaatshouder: vervang door het Corlaer-logo uit de Assets.
            Image("CorlaerLogo")
                .font(.system(size: 64))
                .foregroundStyle(Theme.purple)
                .accessibilityHidden(true)

            Text("Inloggen bij Corlaer")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Meld je aan met je schoolaccount om broodjes te bestellen")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                Task { await session.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    if session.isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                    }
                    Text("Inloggen met Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 320, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(session.isSigningIn)
            .padding(.top, 12)

            if let error = session.loginError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Foutmelding: \(error)")
            }

            Spacer()
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
