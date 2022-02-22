//
//  ViewController.swift
//  Video Cropping Tests
//
//  Created by Crystal Knight on 2/18/22.
//

import UIKit
import Photos

class ViewController: UIViewController {

    var fetchResult: PHFetchResult<PHAsset>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadLibrary()
    }

    private func loadLibrary() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                self.fetchResult = PHAsset.fetchAssets(with: .video, options: nil)
            }
        }
    }
}
