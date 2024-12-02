//
//  MessageBubble.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//


import SwiftUI
import PhotosUI

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let showUsername: Bool
    @State private var showFullScreenImage = false
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if showUsername {
                    Text(message.username)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                    
                
                ZStack(alignment: .bottomTrailing) {
                    switch message.type {
                    case "image":
                        if let imageData = Data(base64Encoded: message.image ?? ""),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200)
                                .cornerRadius(16)
                                .onTapGesture {
                                    showFullScreenImage = true
                                }
                        }
                    case "audio":
                        if let audioData = Data(base64Encoded: message.audio ?? ""),
                           let duration = message.duration {
                            AudioMessageView(audioData: audioData, duration: duration)
                        }
                    case "video":
                        if let videoData = Data(base64Encoded: message.video ?? "") {
                            VideoMessageView(videoData: videoData)
                        }
                    default:
                        Text(message.message)
                            .padding(.bottom, isCurrentUser ? 20 : 10)
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                            .background(isCurrentUser ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                    
                    if isCurrentUser {
                        MessageStatusIndicator(status: message.status)
                            .padding([.trailing, .bottom], 6)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, showUsername ? 8 : 2)
            .fullScreenCover(isPresented: $showFullScreenImage) {
                FullScreenImageView(imageBase64: message.image ?? "", isShowing: $showFullScreenImage)
            }
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}

struct FullScreenImageView: View {
    let imageBase64: String
    @Binding var isShowing: Bool
    @State private var offset = CGSize.zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let imageData = Data(base64Encoded: imageBase64),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .offset(y: offset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                            .onEnded { gesture in
                                if abs(offset.height) > 100 {
                                    isShowing = false
                                } else {
                                    offset = .zero
                                }
                            }
                    )
                
                
                
            }
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    isShowing = false
                }
        )
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let completion: (UIImage?) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            self.parent.image = image
                            self.parent.completion(image)
                        }
                    }
                }
            }
        }
    }
}






struct MessageStatusIndicator: View {
    let status: MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(Color(.systemGray2))
            case .delivered:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundColor(Color(.systemGray2))
            case .read:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundColor(.blue)
            }
        }
        .font(.caption2)
    }
}
