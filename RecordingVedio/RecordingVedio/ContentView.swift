
// MARK: -- Vedio Recording
import AVFoundation
import Photos
import SwiftUI
import AVKit


struct CameraPreview: UIViewRepresentable {
  @Binding var session: AVCaptureSession

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
      layer.session = session
      layer.frame = uiView.bounds
    }
  }
}

struct ContentView: View {
  @StateObject private var recorder = Recorder()

    @State private var showPreview = false
    
  var body: some View {
    VStack {
      CameraPreview(session: $recorder.session)
        .frame(height: 400) // Adjust the height to your needs
      HStack {
        Button(action: {
          recorder.startRecording()
        }) {
          Text("Start Recording")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(recorder.isRecording)

        Button(action: {
          recorder.stopRecording()
        }) {
          Text("Stop Recording")
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(!recorder.isRecording)
      }

      if recorder.isRecording {
        Text("Recording...")
          .foregroundColor(.red)
      }
        
        if let videoURL = recorder.videoURL {
            Button(action: {
                showPreview = true
            }) {
                Text("Preview")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .sheet(isPresented: $showPreview) {
                VideoPlayerView(url: videoURL)
            }
        }
    
    }
  }
}

class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate, ObservableObject {
  @Published var session = AVCaptureSession() // session is now @Published
  @Published var isRecording = false
  private let movieOutput = AVCaptureMovieFileOutput()

    //
    @Published var videoURL: URL? = nil
    //
    
  override init() {
    super.init()
    addAudioInput()
    addVideoInput()
    if session.canAddOutput(movieOutput) {
      session.addOutput(movieOutput)
    }
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.session.startRunning()
    }
  }

  private func addAudioInput() {
    guard let device = AVCaptureDevice.default(for: .audio) else { return }
    guard let input = try? AVCaptureDeviceInput(device: device) else { return }
    if session.canAddInput(input) {
      session.addInput(input)
    }
  }

  private func addVideoInput() {
    guard let device = AVCaptureDevice.default(for: .video) else { return }
    guard let input = try? AVCaptureDeviceInput(device: device) else { return }
    if session.canAddInput(input) {
      session.addInput(input)
    }
  }

  func startRecording() {
    guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("video.mp4") else { return }
    if movieOutput.isRecording == false {
      if FileManager.default.fileExists(atPath: url.path) {
        try? FileManager.default.removeItem(at: url)
      }
      movieOutput.startRecording(to: url, recordingDelegate: self)
      isRecording = true
    }
  }

  func stopRecording() {
    if movieOutput.isRecording {
      movieOutput.stopRecording()
      isRecording = false
    }
  }

  func fileOutput(_ output: AVCaptureFileOutput,
                  didStartRecordingTo fileURL: URL,
                  from connections: [AVCaptureConnection]) {
    // Handle actions when recording starts
  }

  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    // Check for recording error
    if let error = error {
      print("Error recording: \(error.localizedDescription)")
      return
    }

    // Save video to Photos
    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
    }) { saved, error in
      if saved {
//        print("Successfully saved video to Photos.")
          DispatchQueue.main.async { [weak self] in
                     self?.videoURL = outputFileURL
                     print("Successfully saved video to Photos.")
                 }
      } else if let error = error {
        print("Error saving video to Photos: \(error.localizedDescription)")
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

struct VideoPlayerView: View {
    var url: URL
    private var player: AVPlayer { AVPlayer(url: url) }
    
    var body: some View {
        AVPlayerViewControllerRepresentable(player: player)
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed as the player remains the same
    }
}
