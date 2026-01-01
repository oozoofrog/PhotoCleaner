//
//  PhotoPermissionService.swift
//  PhotoCleaner
//
//  Photos 프레임워크 권한 요청 및 상태 관리
//

import Photos
import SwiftUI

/// 사진 접근 권한 상태
enum PhotoPermissionStatus: Equatable {
    case notDetermined  // 아직 요청 안함
    case authorized     // 전체 접근 허용
    case limited        // 제한된 사진만 허용
    case denied         // 거부됨
    case restricted     // 기기 제한

    var canAccess: Bool {
        self == .authorized || self == .limited
    }

    var displayTitle: String {
        switch self {
        case .notDetermined: "권한 필요"
        case .authorized: "전체 접근"
        case .limited: "제한된 접근"
        case .denied: "접근 거부됨"
        case .restricted: "접근 제한됨"
        }
    }

    var displayDescription: String {
        switch self {
        case .notDetermined:
            "사진첩에 접근하려면 권한이 필요합니다."
        case .authorized:
            "모든 사진에 접근할 수 있습니다."
        case .limited:
            "선택한 사진에만 접근할 수 있습니다."
        case .denied:
            "설정에서 사진 접근을 허용해 주세요."
        case .restricted:
            "이 기기에서는 사진 접근이 제한되어 있습니다."
        }
    }
}

/// 사진 권한 관리 서비스
@MainActor
@Observable
final class PhotoPermissionService {

    // MARK: - Properties

    private(set) var status: PhotoPermissionStatus = .notDetermined

    // MARK: - Initialization

    init() {
        updateStatus()
    }

    // MARK: - Public Methods

    /// 현재 권한 상태 업데이트
    func updateStatus() {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        status = mapAuthorizationStatus(authStatus)
    }

    /// 권한 요청
    func requestAuthorization() async {
        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        status = mapAuthorizationStatus(authStatus)
    }

    /// 제한된 사진 선택 UI 표시 (Limited 상태일 때)
    func presentLimitedLibraryPicker() {
        guard status == .limited else { return }

        // iOS 14+에서 제한된 라이브러리 피커 표시
        // iOS 26에서는 PhotosPicker를 사용하거나 설정으로 이동
        openSettings()
    }

    /// 설정 앱으로 이동
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Private Methods

    private func mapAuthorizationStatus(_ status: PHAuthorizationStatus) -> PhotoPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        case .limited: .limited
        @unknown default: .denied
        }
    }
}
