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
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
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
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    @ViewBuilder
    private func messageView(_ message: EyeChatViewModel.ChatMessage) -> some View {
        let background: Color
        let alignment: Alignment
        switch message.role {
        case .user:
            background = Color.accentColor.opacity(0.2)
            alignment = .trailing
        case .daemon:
            background = Color.blue.opacity(0.15)
            alignment = .leading
        case .system:
            background = Color.gray.opacity(0.1)
            alignment = .leading
        }

        HStack {
            if alignment == .trailing { Spacer(minLength: 24) }
            Text(message.text)
                .padding(10)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            if alignment == .leading { Spacer(minLength: 24) }
        }
    }
}

#Preview {
    ContentView()
}
