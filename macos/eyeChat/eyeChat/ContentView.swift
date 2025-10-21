//
//  ContentView.swift
//  eyeChat
//
//  Created by Bruno Pinto on 16/10/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EyeChatViewModel()

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageView(message)
                                .id(message.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    guard newValue > oldValue, let last = viewModel.messages.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            HStack {
                TextField("Type a command…", text: $viewModel.input, onCommit: viewModel.sendCurrentInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!viewModel.isConnected)

                Button("Send") {
                    viewModel.sendCurrentInput()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.isConnected)
            }
            .padding()
        }
        .padding(.vertical)
        .task {
            viewModel.start()
        }
    }

    @ViewBuilder
    private func messageView(_ message: EyeChatViewModel.ChatMessage) -> some View {
        let configuration = bubbleConfiguration(for: message.role)

        HStack {
            if configuration.isTrailingAligned {
                Spacer(minLength: 24)
            }

            Text(message.text)
                .padding(10)
                .background(configuration.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if !configuration.isTrailingAligned {
                Spacer(minLength: 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: configuration.isTrailingAligned ? .trailing : .leading)
    }

    private func bubbleConfiguration(for role: EyeChatViewModel.MessageRole) -> (backgroundColor: Color, isTrailingAligned: Bool) {
        switch role {
        case .user:
            return (Color.accentColor.opacity(0.2), true)
        case .daemon:
            return (Color.blue.opacity(0.15), false)
        case .system:
            return (Color.gray.opacity(0.1), false)
        }
    }
}

#Preview {
    ContentView()
}
