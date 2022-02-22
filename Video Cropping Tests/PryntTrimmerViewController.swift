//
//  PryntTrimmerViewController.swift
//  Video Cropping Tests
//
//  Created by Crystal Knight on 2/14/22.
//

import UIKit
import AVFoundation
import AVKit
import MobileCoreServices
import PryntTrimmerView
import Photos
import PhotosUI

class PryntTrimmerViewController: UIViewController {
    // MARK: - Properties
    // Upload
//    var fetchResult: PHFetchResult<PHAsset>?
    var videoUploadManager = VideoUploadManager()

    // Player
    var player: AVPlayer?
    var playbackTimeCheckerTimer: Timer?

    // Trimming
    var trimmerPositionChangedTimer: Timer?
    typealias TrimCompletion = (Error?) -> ()
    typealias TrimPoints = [(CMTime, CMTime)]

    // Outlets
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var trimmerView: TrimmerView!
    @IBOutlet weak var scrollBack: UIImageView!
    @IBOutlet weak var scrollForward: UIImageView!
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
            startPlaybackTimeChecker()
        } else {
            pause()
            stopPlaybackTimeChecker()
        }
    }

    @IBAction func includeAudioChanged(_ sender: Any) {
        player?.isMuted.toggle()
    }

    @IBAction func trimVideo(_ sender: UIButton) {
        if let url = videoUploadManager.videoURL {
            pause()
            trim(
                originalURL: url,
                startTime: CMTimeGetSeconds(trimmerView.startTime!),
                endTime: CMTimeGetSeconds(trimmerView.endTime!)
            )
        }
    }

    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    private func setupView() {
        DispatchQueue.main.async {
            self.loadingIndicator.hidesWhenStopped = true
            self.trimmerView.delegate = self
            self.trimmerView.minDuration = 5
            self.trimmerView.maxDuration = 30
            self.trimmerView.positionBarColor = .orange
            self.trimmerView.mainColor = .orange
            self.trimmerView.handleColor = .red
            self.scrollBack.layer.opacity = 0
            self.scrollForward.layer.opacity = 0
            self.includeAudio.isEnabled = self.player != nil

            self.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            self.playButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
            self.playButton.isSelected = false

            // Update view when video is done loading.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.loadVideo),
                name: .videoSaved,
                object: nil
            )
        }
    }

    // MARK: - Methods
    // Upload
    @objc func loadVideo() {
        if let url = videoUploadManager.videoURL {
            let asset = AVAsset(url: url)
            DispatchQueue.main.async {
                // Add video to imageView
                self.addVideoPlayer(with: asset, playerView: self.imageView)
                // Add video to trimmerView
                self.trimmerView.asset = asset

                if asset.duration.seconds > 30 {
                    self.scrollForward.layer.opacity = 1
                }

                self.loadingIndicator.stopAnimating()
            }
        }
    }

    private func addVideoPlayer(with asset: AVAsset, playerView: UIView) {
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        includeAudio.isEnabled = (asset.tracks(withMediaType: .audio).count != 0)

        NotificationCenter.default.addObserver(self, selector: #selector(PryntTrimmerViewController.itemDidFinishPlaying(_:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)

        let layer: AVPlayerLayer = AVPlayerLayer(player: player)
        layer.backgroundColor = UIColor.white.cgColor
        layer.frame = CGRect(
            x: 0,
            y: 0,
            width: playerView.frame.width,
            height: playerView.frame.height
        )
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        playerView.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
        playerView.layer.addSublayer(layer)
    }

    // Player
    @objc func itemDidFinishPlaying(_ notification: Notification) {
        if let startTime = trimmerView.startTime {
            player?.seek(to: startTime)
            if (player?.isPlaying != true) {
                play()
            }
        }
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

    func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(PryntTrimmerViewController.onPlaybackTimeChecker),
            userInfo: nil,
            repeats: true)
    }

    func stopPlaybackTimeChecker() {
        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }

    @objc func onPlaybackTimeChecker() {
        guard let startTime = trimmerView.startTime,
                let endTime = trimmerView.endTime,
                let player = player else { return }

        if startTime > .zero {
            scrollBack.layer.opacity = 1
        } else {
            scrollBack.layer.opacity = 0
        }

        if let duration = player.currentItem?.duration, endTime < duration {
            scrollForward.layer.opacity = 1
        } else {
            scrollForward.layer.opacity = 0
        }

        let playBackTime = player.currentTime()
        trimmerView.seek(to: playBackTime)

        if playBackTime >= endTime {
            player.seek(to: startTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            trimmerView.seek(to: startTime)
        }
    }

    // Trimming
    func trimVideo(
        sourceURL: URL,
        destinationURL: URL,
        trimPoints: TrimPoints,
        completion: TrimCompletion?
    ) {
        guard sourceURL.isFileURL, destinationURL.isFileURL else { return }


        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]

        let asset = AVURLAsset(url: sourceURL, options: options)
        let preferredPreset = AVAssetExportPresetPassthrough

        if verifyPresetForAsset(preset: preferredPreset, asset: asset) {
            let composition = AVMutableComposition()
            let videoCompTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: CMPersistentTrackID()
            )

            let audioCompTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: CMPersistentTrackID()
            )

            guard let assetVideoTrack: AVAssetTrack = asset.tracks(withMediaType: .video).first,
                    let assetAudioTrack: AVAssetTrack = asset.tracks(withMediaType: .audio).first else { return }


            let size = assetVideoTrack.naturalSize
            let txf = assetVideoTrack.preferredTransform

            var recordType = ""
            if (size.width == txf.tx && size.height == txf.ty) {
                recordType = .landScapeRight
            } else if (txf.tx == 0 && txf.ty == 0) {
                recordType = .landScapeLeft
            } else if (txf.tx == 0 && txf.ty == size.width) {
                recordType = .portraitUpsideDown
            } else {
                recordType = .portrait
            }

            if recordType == .portrait {
                let t1: CGAffineTransform = CGAffineTransform(translationX: assetVideoTrack.naturalSize.height, y: -(assetVideoTrack.naturalSize.width - assetVideoTrack.naturalSize.height)/2)
                let t2: CGAffineTransform = t1.rotated(by: CGFloat(Double.pi / 2))
                let finalTransform: CGAffineTransform = t2
                videoCompTrack!.preferredTransform = finalTransform
            } else if recordType == .landScapeRight {
                let t1: CGAffineTransform = CGAffineTransform(translationX: assetVideoTrack.naturalSize.height, y: -(assetVideoTrack.naturalSize.width - assetVideoTrack.naturalSize.height)/2)
                let t2: CGAffineTransform = t1.rotated(by: -CGFloat(Double.pi))
                let finalTransform: CGAffineTransform = t2
                videoCompTrack!.preferredTransform = finalTransform
            } else if recordType == .portraitUpsideDown {
                let t1: CGAffineTransform = CGAffineTransform(translationX: assetVideoTrack.naturalSize.height, y: -(assetVideoTrack.naturalSize.width - assetVideoTrack.naturalSize.height)/2)
                let t2: CGAffineTransform = t1.rotated(by: -CGFloat(Double.pi/2))
                let finalTransform: CGAffineTransform = t2
                videoCompTrack!.preferredTransform = finalTransform
            }

            var accumulatedTime = CMTime.zero
            for (startTimeForCurrentSlice, endTimeForCurrentSlice) in trimPoints {
                let durationOfCurrentSlice = CMTimeSubtract(endTimeForCurrentSlice, startTimeForCurrentSlice)
                let timeRangeForCurrentSlice = CMTimeRangeMake(start: startTimeForCurrentSlice, duration: durationOfCurrentSlice)

                do {
                    try videoCompTrack!.insertTimeRange(timeRangeForCurrentSlice, of: assetVideoTrack, at: accumulatedTime)

                    if includeAudio.isOn {
                        try audioCompTrack!.insertTimeRange(timeRangeForCurrentSlice, of: assetAudioTrack, at: accumulatedTime)
                        accumulatedTime = CMTimeAdd(accumulatedTime, durationOfCurrentSlice)
                    }
                } catch let compError {
                    completion?(compError)
                }
            }

            guard let exportSession = AVAssetExportSession(asset: composition, presetName: preferredPreset) else { return }

            exportSession.outputURL = destinationURL as URL
            exportSession.outputFileType = AVFileType.m4v
            exportSession.shouldOptimizeForNetworkUse = true

            removeFileAtURLIfExists(url: destinationURL as URL)

            exportSession.exportAsynchronously {
                completion?(exportSession.error)
            }
        } else {
            print("TrimVideo - Could not find a suitable export preset for the input video")
            let error = NSError(domain: "com.bighug.ios", code: -1, userInfo: nil)
            completion?(error)
        }
    }


    func trim(originalURL:URL,startTime:Float64,endTime:Float64) {
        var outputURL = URL(
            fileURLWithPath: NSSearchPathForDirectoriesInDomains(
                FileManager.SearchPathDirectory.documentDirectory,
                FileManager.SearchPathDomainMask.userDomainMask,
                true
            ).last!
        )
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print(error)
        }
        outputURL.appendPathComponent("output.mp4")

        // Remove existing file
        do {
            try fileManager.removeItem(at: outputURL)
        } catch let error {
            print(error)
        }
        let asset = AVAsset(url: originalURL)
        let playerTimescale = asset.duration.timescale
        let start = CMTime(seconds: startTime, preferredTimescale: playerTimescale)
        let duration =  CMTime(seconds: endTime, preferredTimescale: playerTimescale)

        trimVideo(sourceURL: originalURL, destinationURL: outputURL, trimPoints: [(start,duration)]) { (error) in
            if error != nil{
                print("Video trim failed. Please retry.")
            } else {
                print("Succesfully trimmed")
                print(outputURL.absoluteString)
                DispatchQueue.main.async {
                    self.videoUploadManager.videoURL = outputURL
                    self.loadVideo()
                }
            }
        }
    }

    func verifyPresetForAsset(preset: String, asset: AVAsset) -> Bool {
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let filteredPresets = compatiblePresets.filter { $0 == preset }
        return filteredPresets.count > 0 || preset == AVAssetExportPresetPassthrough
    }

    func removeFileAtURLIfExists(url: URL) {

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch let error {
            print("TrimVideo - Couldn't remove existing destination file: \(String(describing: error))")
        }
    }
}


// MARK: - Delegate
extension PryntTrimmerViewController: TrimmerViewDelegate {
    func positionBarStoppedMoving(_ playerTime: CMTime) {
        player?.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        play()
        startPlaybackTimeChecker()
    }

    func didChangePositionBar(_ playerTime: CMTime) {
        stopPlaybackTimeChecker()
        pause()
        player?.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
}


extension AVPlayer {
    var isPlaying: Bool {
        return self.rate != 0 && self.error == nil
    }

    var isAudioAvailable: Bool {
        return self.currentItem?.tracks.filter({$0.assetTrack!.mediaType == AVMediaType.audio}).count != 0
    }
}

extension Notification.Name {
    static let videoSaved = Notification.Name("videoSaved")
}

extension String {
    static let landScapeLeft = "UIInterfaceOrientationLandscapeLeft"
    static let landScapeRight = "UIInterfaceOrientationLandscapeRight"
    static let portrait = "UIInterfaceOrientationPortrait"
    static let portraitUpsideDown = "UIInterfaceOrientationPortraitUpsideDown"
}
