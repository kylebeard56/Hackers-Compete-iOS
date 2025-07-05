//
//  SuggestionBoxView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/27/23.
//

import Introspect
import SwiftUI

struct SuggestionBoxView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = SuggestionBoxViewModel()
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, suggestion }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                ZStack {
                    Text("Suggestion Box")
                        .font(.dmSans, size: 20, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()

                    BackButton( icon: .xmark, onTap: { dismiss() })
                        .alignTrailing()
                }
                .padding(.bottom, 10)
                .padding(.horizontal, 20)
                
                ScrollView {
                    content
                }
            }
            .padding(.top, 20)
            
            if focusedField != nil {
                KeyboardDismissalButton()
                    .alignBottom()
                    .alignTrailing()
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            } else {
                buttons
                    .alignBottom()
                    .ignoresSafeArea(.keyboard)
            }
        }
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                focusedField = .suggestion
            })
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Group {
                Text("Please provide any ")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
                + Text("**suggestions or ideas**")
                    .foregroundColor(Color.systemHackersGreen)
                    //.font(.dmSans, size: 17, weight: .bold)
                + Text(" about how we could improve Hackers.")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
            }
            .font(.dmSans, size: 17)
            .alignLeading()
            
            if viewModel.showErrorBanner {
                ErrorBanner(
                    title: "Something went wrong",
                    subtitle: "We couldn't send your suggestion. Please try again.",
                    onTap: { viewModel.showErrorBanner = false }
                )
            }
            
            fields
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
    
    private var fields: some View {
        VStack(spacing: 20) {
            TextField(
                "Write your idea or suggestion...",
                text: $viewModel.text,
                axis: .vertical
            )
            .lineLimit(8, reservesSpace: true)
            .font(.dmSans, size: 17, weight: .regular)
            .keyboardType(.alphabet)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.return)
            .focused($focusedField, equals: .suggestion)
            .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
            .modifier(BorderedTextFieldModifier(isActive: focusedField == .suggestion))
            
            TextField("Feedback email (optional)", text: $viewModel.email)
                .font(.dmSans, size: 17, weight: .regular)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.none)
                .submitLabel(.return)
                .focused($focusedField, equals: .email)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .email))
            
            Text("Someone from our team may reach out to you.")
                .foregroundColor(Color.systemGray)
                .font(.dmSans, size: 13, weight: .regular)
                .multilineTextAlignment(.leading)
                .alignLeading()
                .padding(.top, -10)
        }
    }
    
    private var buttons: some View {
        VStack(spacing: 20) {
            Divider()
            
            if viewModel.submitted {
                VStack(spacing: 10) {
                    AwesomeImage(rawIcon: "f772".unicode, style: .regular, size: 40, color: .white)
                    Text("Your suggestion has been sent.")
                        .font(.dmSans, size: 20, weight: .bold)
                        .foregroundColor(.white)
                        .alignCenter()
                    
                    Text("Tap to dismiss.")
                        .font(.dmSans, size: 15, weight: .regular)
                        .foregroundColor(.white)
                        .alignCenter()
                }
                .padding(.horizontal, 20)
            } else {
                BigButton(
                    title: "Submit",
                    isDisabled: .constant(viewModel.text.isEmpty),
                    isLoading: $viewModel.submitting
                )
                .onTapAsync {
                    await viewModel.post()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(viewModel.submitted ? Color.systemHackersGreen : Color.systemViewBackground)
        .onTapGesture {
            if viewModel.submitted {
                Haptics.fire(.light)
                dismiss()
            }
        }
    }
}

struct SuggestionBoxView_Previews: PreviewProvider {
    static var previews: some View {
        VStack { }.sheet(isPresented: .true) {
            SuggestionBoxView()
                .presentationDragIndicator(.visible)
        }
        .holisticPreview()
    }
}
