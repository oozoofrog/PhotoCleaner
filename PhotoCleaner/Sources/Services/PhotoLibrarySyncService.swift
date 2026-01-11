//
//  PhotoLibrarySyncService.swift
//  PhotoCleaner
//

import Foundation
import Photos

protocol PhotoLibraryProviding: Sendable {
    func fetchAllAssetIdentifiers() async -> Set<String>
    func fetchAssetInfo(for identifiers: Set<String>) async -> [NewAssetInfo]
    func currentChangeToken() async -> Data?
}

struct RealPhotoLibraryProvider: PhotoLibraryProviding {
    
    func fetchAllAssetIdentifiers() async -> Set<String> {
        await MainActor.run {
            let fetchOptions = PHFetchOptions()
            fetchOptions.includeHiddenAssets = false
            fetchOptions.includeAllBurstAssets = false
            
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var identifiers = Set<String>()
            identifiers.reserveCapacity(allPhotos.count)
            
            allPhotos.enumerateObjects { asset, _, _ in
                identifiers.insert(asset.localIdentifier)
            }
            
            return identifiers
        }
    }
    
    func fetchAssetInfo(for identifiers: Set<String>) async -> [NewAssetInfo] {
        guard !identifiers.isEmpty else { return [] }
        
        return await MainActor.run {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(identifiers), options: nil)
            var infos: [NewAssetInfo] = []
            infos.reserveCapacity(fetchResult.count)
            
            fetchResult.enumerateObjects { asset, _, _ in
                infos.append(NewAssetInfo(
                    localIdentifier: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    mediaSubtypes: asset.mediaSubtypes.rawValue
                ))
            }
            
            return infos
        }
    }
    
    func currentChangeToken() async -> Data? {
        await MainActor.run {
            let token = PHPhotoLibrary.shared().currentChangeToken
            return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        }
    }
}

actor PhotoLibrarySyncService {
    private let cacheStore: PhotoCacheStoreProtocol
    private let libraryProvider: PhotoLibraryProviding
    
    init(cacheStore: PhotoCacheStoreProtocol, libraryProvider: PhotoLibraryProviding) {
        self.cacheStore = cacheStore
        self.libraryProvider = libraryProvider
    }
    
    func performFullSync() async {
        let libraryIdentifiers = await libraryProvider.fetchAllAssetIdentifiers()
        let cachedIdentifiers = await cacheStore.fetchAllIdentifiers()
        
        let newIdentifiers = libraryIdentifiers.subtracting(cachedIdentifiers)
        let deletedIdentifiers = cachedIdentifiers.subtracting(libraryIdentifiers)
        
        if !deletedIdentifiers.isEmpty {
            await cacheStore.deleteAssets(withIdentifiers: deletedIdentifiers)
        }
        
        if !newIdentifiers.isEmpty {
            let assetInfos = await libraryProvider.fetchAssetInfo(for: newIdentifiers)
            await cacheStore.insertNewAssets(assetInfos)
        }
        
        if let token = await libraryProvider.currentChangeToken() {
            await cacheStore.saveSyncToken(token)
        }
    }
    
    func performIncrementalSync(from previousToken: Data) async {
        await performFullSync()
    }
}
