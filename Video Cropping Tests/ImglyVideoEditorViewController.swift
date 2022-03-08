//
//  ImglyVideoEditorViewController.swift
//  Video Cropping Tests
//
//  Created by Crystal Knight on 2/18/22.
//

import UIKit
import VideoEditorSDK
import AVFoundation

class ImglyVideoEditorViewController: UIViewController {
    // MARK: - Properties
    let videoUploadManager = VideoUploadManager()

    // Outlets
    @IBOutlet weak var includeAudio: UISwitch!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    // Actions
    @IBAction func selectVideo(_ sender: UIBarButtonItem) {
        loadingIndicator.startAnimating()
        present(videoUploadManager.picker, animated: true)
    }

    @IBAction func includeAudioChanged(_ sender: Any) {
//        player?.isMuted.toggle()
    }


    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }

//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        if videoUploadManager.videoURL != nil {
//            self.displayVideo()
//        }
//    }

    func setUpView() {
        loadingIndicator.hidesWhenStopped = true
//        includeAudio.isEnabled = self.player != nil

//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(self.loadVideo),
//            name: .videoSaved,
//            object: nil
//        )

    }
//
//    func displayVideo() {
//        if let url = videoUploadManager.videoURL {
//            let asset = AVAsset(url: url)
//            let playerItem = AVPlayerItem(asset: asset)
//            DispatchQueue.main.async {
//                self.player = AVPlayer(playerItem: playerItem)
//                self.includeAudio.isEnabled = (asset.tracks(withMediaType: .audio).count != 0)
//
//                let layer: AVPlayerLayer = AVPlayerLayer(player: self.player)
//                layer.backgroundColor = UIColor.white.cgColor
//                layer.frame = CGRect(
//                    x: 0,
//                    y: 0,
//                    width: self.imageView.frame.width,
//                    height: self.imageView.frame.height
//                )
//                layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
//                self.imageView.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
//                self.imageView.layer.addSublayer(layer)
//            }
//        }
//    }

    // MARK: - Methods


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destinationView = segue.destination as? VideoTrimmerVC else { return }
        destinationView.videoUploadManager = videoUploadManager

    }

}
