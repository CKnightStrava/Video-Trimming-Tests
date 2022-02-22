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
    var videoEditorConfiguration: Configuration?
    var player: AVPlayer?
    let videoUploadManager = VideoUploadManager()

    // Outlets
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var imageView: UIView!
    @IBOutlet weak var includeAudio: UISwitch!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    // Actions
    @IBAction func selectVideo(_ sender: UIBarButtonItem) {
        loadingIndicator.startAnimating()
        present(videoUploadManager.picker, animated: true)
    }

    @IBAction func play(_ sender: Any) {
        guard let player = player else { return }
        playButton.isSelected.toggle()
        if !player.isPlaying {
            play()
        } else {
            pause()
        }
    }

    @IBAction func includeAudioChanged(_ sender: Any) {
        player?.isMuted.toggle()
    }


    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if videoUploadManager.videoURL != nil {
            self.displayVideo()
        }
    }

    func setUpView() {
        loadingIndicator.hidesWhenStopped = true
        includeAudio.isEnabled = self.player != nil
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
        playButton.isSelected = false
        videoEditorConfiguration = Configuration { builder in
            builder.theme.tintColor = .orange
            builder.configureTrimToolController { builder in
                builder.maximumDuration = 30
            }
            builder.configureVideoEditViewController { options in
                options.menuItems = createMenu()
                options.forceTrimMode = .ifNeeded
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.loadVideo),
            name: .videoSaved,
            object: nil
        )

    }

    @objc func loadVideo() {
        if let config = videoEditorConfiguration, let url = videoUploadManager.videoURL {
            let video = Video(url: url)
            let videoEditVC = VideoEditViewController(videoAsset: video, configuration: config)
            videoEditVC.delegate = self
            videoEditVC.modalPresentationStyle = .fullScreen
            present(videoEditVC, animated: true)

            self.displayVideo()
            self.loadingIndicator.stopAnimating()
        }
    }

    func displayVideo() {
        if let url = videoUploadManager.videoURL {
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            DispatchQueue.main.async {
                self.player = AVPlayer(playerItem: playerItem)
                self.includeAudio.isEnabled = (asset.tracks(withMediaType: .audio).count != 0)

                let layer: AVPlayerLayer = AVPlayerLayer(player: self.player)
                layer.backgroundColor = UIColor.white.cgColor
                layer.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: self.imageView.frame.width,
                    height: self.imageView.frame.height
                )
                layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                self.imageView.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
                self.imageView.layer.addSublayer(layer)
            }
        }
    }

    // MARK: - Methods
    func createMenu() -> [PhotoEditMenuItem] {
        let menuItems: [MenuItem?] = [
            ToolMenuItem.createTrimToolItem()
        ]

        let photoEditMenuItems: [PhotoEditMenuItem] = menuItems.compactMap { menuItem in
            switch menuItem {
            case let menuItem as ToolMenuItem:
                return .tool(menuItem)
            case let menuItem as ActionMenuItem:
                return .action(menuItem)
            default:
                return nil
            }
        }

        return photoEditMenuItems
    }

    func play() {
        if !includeAudio.isOn {
            player?.isMuted = true
        } else {
            player?.isMuted = false
        }

        player?.play()
        playButton.isSelected = true
    }

    func pause() {
        player?.pause()
        playButton.isSelected = false
    }
}

extension ImglyVideoEditorViewController: VideoEditViewControllerDelegate {
    func videoEditViewController(_ videoEditViewController: VideoEditViewController, didFinishWithVideoAt url: URL?) {
        DispatchQueue.main.async {
            self.videoUploadManager.videoURL = url
        }

        if let navigationVC = videoEditViewController.navigationController {
            navigationVC.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    func videoEditViewControllerDidFailToGenerateVideo(_ videoEditViewController: VideoEditViewController) {
        if let navigationVC = videoEditViewController.navigationController {
            navigationVC.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
        if let navigationVC = videoEditViewController.navigationController {
            navigationVC.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }


}
