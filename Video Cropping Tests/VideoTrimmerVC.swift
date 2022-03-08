//
//  VideoTrimmerVC.swift
//  Video Cropping Tests
//
//  Created by Crystal Knight on 3/8/22.
//

import UIKit
import VideoEditorSDK
import AVFoundation

class VideoTrimmerVC: VideoEditViewController {
    var videoUploadManager: VideoUploadManager?

    init() {
        let configuration = Configuration { builder in
                builder.theme.tintColor = .orange
                builder.configureTrimToolController { builder in
                    builder.maximumDuration = 30
                }
                builder.configureVideoEditViewController { options in
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

                    options.menuItems = photoEditMenuItems
                    options.forceTrimMode = .ifNeeded
                }
            }

        super.init(videoAsset: Video(), configuration: configuration, photoEditModel: PhotoEditModel())
        self.delegate = self
    }

    required init(videoAsset: Video, configuration: Configuration = Configuration(), photoEditModel: PhotoEditModel = PhotoEditModel()) {
        fatalError("init(videoAsset:configuration:photoEditModel:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        setUpView()
    }

    func setUpView() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.loadVideo),
            name: .videoSaved,
            object: nil
        )

        if videoUploadManager?.videoURL != nil {
            loadVideo()
        }
    }

    @objc func loadVideo() {
        if let manager = videoUploadManager,
            let url = manager.videoURL,
            let id = manager.currentAssetIdentifier {
            let avAsset = AVAsset(url: url)
            let videoAsset = VideoAsset(asset: avAsset, userInfo: nil)
            self.assetManager.setVideoAsset(videoAsset, forIdentifier: id)
        }
    }
}

extension VideoTrimmerVC: VideoEditViewControllerDelegate {
    func videoEditViewController(_ videoEditViewController: VideoEditViewController, didFinishWithVideoAt url: URL?) {

        DispatchQueue.main.async {
            self.videoUploadManager?.videoURL = url
        }
    }

    func videoEditViewControllerDidFailToGenerateVideo(_ videoEditViewController: VideoEditViewController) {

    }

    func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {

    }


}
