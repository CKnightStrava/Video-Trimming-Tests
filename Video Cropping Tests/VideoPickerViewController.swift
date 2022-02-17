//
//  VideoUploadManager.swift
//  Video Cropping Tests
//
//  Created by Crystal Knight on 2/15/22.
//

import UIKit
import Photos
import PhotosUI


class VideoUploadManager: PHPickerViewControllerDelegate {
    // MARK: - Properties
    private var configuration = PHPickerConfiguration(photoLibrary: .shared())
    var picker: PHPickerViewController
    var selection = [String: PHPickerResult]()
    var selectedAssetIdentifiers = [String]()
    var selectedAssetIdentifierIterator: IndexingIterator<[String]>?
    var currentAssetIdentifier: String?
    var progress: Progress?
    var videoURL: URL?

    // MARK: - Initializer
    init() {
        configuration.filter = .videos
        configuration.selection = .ordered
        configuration.preferredAssetRepresentationMode = .compatible
        configuration.selectionLimit = 1
        configuration.preselectedAssetIdentifiers = selectedAssetIdentifiers
        self.picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
    }

    // MARK: - Methods
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        self.picker.dismiss(animated: true) {
            let existingSelection = self.selection
            var newSelection = [String: PHPickerResult]()
            for result in results {
                let identifier = result.assetIdentifier!
                newSelection[identifier] = existingSelection[identifier] ?? result
            }

            // Track the selection in case the user deselects it later.
            self.selection = newSelection
            self.selectedAssetIdentifiers = results.map(\.assetIdentifier!)
            self.selectedAssetIdentifierIterator = self.selectedAssetIdentifiers.makeIterator()

            if self.selection.isEmpty {
                    print("Selection is empty")
            } else {
                print("\(self.selection.count) items selected.")
                guard let assetIdentifier = self.selectedAssetIdentifierIterator?.next() else { return }
                self.currentAssetIdentifier = assetIdentifier

                let itemProvider = self.selection[assetIdentifier]!.itemProvider

                if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    self.progress = itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        do {
                            guard let url = url, error == nil else {
                                throw error ?? NSError(domain: NSFileProviderErrorDomain, code: -1, userInfo: nil)
                            }
                            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                            try? FileManager.default.removeItem(at: localURL)
                            try FileManager.default.copyItem(at: url, to: localURL)

                            self.handleCompletion(assetIdentifier: assetIdentifier, object: localURL)

                        } catch let fileError {
                            self.handleCompletion(assetIdentifier: assetIdentifier, object: nil, error: fileError)
                        }
                    }
                } else {
                    self.progress = nil
                }
            }
        }
    }

    func handleCompletion(assetIdentifier: String, object: Any?, error: Error? = nil) {
        DispatchQueue.main.async { 
            print("Handling completion")
            guard self.currentAssetIdentifier == assetIdentifier else { return }
            if let url = object as? URL {
                self.videoURL = url
                NotificationCenter.default.post(name: .videoSaved, object: nil)
            } else if let error = error {
                print("Couldn't display \(assetIdentifier) with error: \(error)")
            } else {
                print("Unknown error")
            }
        }
    }
}
