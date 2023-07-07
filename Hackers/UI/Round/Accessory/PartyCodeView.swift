//
//  PartyCodeView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/23.
//

import SwiftUI

struct PartyCodeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: RoundViewModel
    
    @State private var code: String = ""
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    private var shareText: String {
        let names = viewModel.session?.playerNames ?? "Players"
        let game = viewModel.sideGame.name
        return "Your Hackers golf party code is: \(viewModel.partyCode)"// \(names) are waiting to play \(game)!"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Party code")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            
            Group {
                Text("Set your ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("party code")
                    .foregroundColor(Color.systemHackersGreen)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" so that others can join this round live from their own devices.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .alignLeading()
            
            TextField("Party code (recommended)", text: $code)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.return)
                .focused($focusedField, equals: .field)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))
            
            Text("Your party code is 100% made up by you, so pick something short and fun. Rounds only last 24 hours.")
                .foregroundColor(Color.systemGray)
                .font(.dmSans(size: 13, weight: .regular))
                .multilineTextAlignment(.leading)
                .alignLeading()
                .padding(.top, -10)
            
            errorBanners
            
            if !self.code.isEmpty || !viewModel.partyCode.isEmpty {
                ShareLink(items: [shareText]) {
                    Text("Share this code")
                        .foregroundColor(Color.systemHackersGreen)
                        .font(.dmSans(size: 15, weight: .bold))
                        .alignCenter()
                }
                .onTapGesture {
                    Haptics.fire(.light)
                }
            }
            
            Spacer(minLength: 0)
            
            VStack(spacing: 20) {
                Divider()

                BigButton(
                    title: "Save party code",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: .false,
                    isLoading: $viewModel.isUpdatingPartyCode
                )
                .onTapAsync {
                    await viewModel.updatePartyCode(to: code)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.systemViewBackground)
        .onAppear() {
            self.code = viewModel.partyCode
        }
        .onReceive(viewModel.$partyCodeUpdated, perform: { value in
            if value { dismiss() }
        })
        .onChange(of: code, perform: { _ in
            viewModel.partyCodeTaken = false
            viewModel.partyCodeNotSaved = false
        })
    }
    
    private var errorBanners: some View {
        Group {
            if viewModel.partyCodeTaken {
                ErrorBanner(
                    title: "Already in use",
                    subtitle: "Someone else beat you to this code for the next 24 hours. Sorry!",
                    onTap: {
                        Haptics.fire(.light)
                        viewModel.partyCodeTaken = false
                    }
                )
            }

            if viewModel.partyCodeNotSaved {
                ErrorBanner(
                    title: "Party code not saved",
                    subtitle: "Something went wrong on our side. Please try again.",
                    onTap: {
                        Haptics.fire(.light)
                        viewModel.partyCodeNotSaved = false
                    }
                )
            }
        }
    }
}

struct PartyCodeView_Previews: PreviewProvider {
    static var vm = RoundViewModel()
    
    static var previews: some View {
        EditPlayersView(viewModel: vm)
            .onAppear() { vm.partyCode = "" }
            .holisticPreview()
    }
}
