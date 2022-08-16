//
//  StorageService.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import SwiftUI
import FirebaseStorage

public class StorageService {
    
    public static func save(image: UIImage, folderPath: String, compressionQuality: CGFloat, completion: @escaping (Result<URL, Error>) -> ()) {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            completion(.failure(FirebaseError.noImageAvailable))
            return
        }
        save(data: imageData, folderPath: folderPath, completion: completion)
    }
    
    public static func put(image: UIImage, folderPath: String, compressionQuality: CGFloat, completion: @escaping (Result<String, Error>) -> ()) {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            completion(.failure(FirebaseError.noImageAvailable))
            return
        }
        put(data: imageData, folderPath: folderPath, completion: completion)
    }
    
    public static func delete(at url: String, completion: @escaping (Result<Bool, Error>) -> ()) {
        let imageReference = Storage.storage().reference(forURL: url)
        imageReference.delete { (err) in
            if let err = err {
                guard err._code == StorageErrorCode.objectNotFound.rawValue else {
                    completion(.failure(err))
                    return
                }
                completion(.success(false))
                return
            }
            completion(.success(true))
        }
    }
    
    public static func handleImageChange(newImage: UIImage, folderPath: String, compressionQuality: CGFloat, oldImageUrl: String, completion: @escaping (Result<URL, Error>) -> ()) {
        guard oldImageUrl.contains("https") else {
            print("StorageService: Old image url does not contain https. No image to delete")
            save(image: newImage, folderPath: folderPath, compressionQuality: compressionQuality, completion: completion)
            return
        }
        delete(at: oldImageUrl) { (result) in
            switch result {
            case .success(let objectFound):
                print("StorageService: Object to be deleted was found: \(objectFound)")
                if objectFound {
                    save(image: newImage, folderPath: folderPath, compressionQuality: compressionQuality, completion: completion)
                } else {
                    completion(.failure(FirebaseError.failedToDeleteAsset))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public static func put(newImage: UIImage, folderPath: String, compressionQuality: CGFloat, oldImageUrl: String, completion: @escaping (Result<String, Error>) -> ()) {
        guard oldImageUrl.contains("https") else {
            print("StorageService: Old image url does not contain https. No image to delete")
            put(image: newImage, folderPath: folderPath, compressionQuality: compressionQuality, completion: completion)
            return
        }
        delete(at: oldImageUrl) { (result) in
            switch result {
            case .success(let objectFound):
                print("StorageService: Object to be deleted was found: \(objectFound)")
                if objectFound {
                    put(image: newImage, folderPath: folderPath, compressionQuality: compressionQuality, completion: completion)
                } else {
                    completion(.failure(FirebaseError.failedToDeleteAsset))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public static func handleDataChange(newData: Data, folderPath: String, oldDataUrl: String, completion: @escaping (Result<URL, Error>) -> ()) {
        guard oldDataUrl.contains("https") else {
            print("StorageService: Old data url does not contain https. No data to delete")
            save(data: newData, folderPath: folderPath, completion: completion)
            return
        }
        delete(at: oldDataUrl) { (result) in
            switch result {
            case .success(let objectFound):
                print("StorageService: Object to be deleted was found: \(objectFound)")
                if objectFound {
                    save(data: newData, folderPath: folderPath, completion: completion)
                } else {
                    completion(.failure(FirebaseError.failedToDeleteAsset))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public static func put(newData: Data, folderPath: String, oldDataUrl: String, completion: @escaping (Result<String, Error>) -> ()) {
        guard oldDataUrl.contains("https") else {
            print("StorageService: Old data url does not contain https. No data to delete")
            put(data: newData, folderPath: folderPath, completion: completion)
            return
        }
        delete(at: oldDataUrl) { (result) in
            switch result {
            case .success(let objectFound):
                print("StorageService: Object to be deleted was found: \(objectFound)")
                if objectFound {
                    put(data: newData, folderPath: folderPath, completion: completion)
                } else {
                    completion(.failure(FirebaseError.failedToDeleteAsset))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public static func save(data: Data, folderPath: String, completion: @escaping (Result<URL, Error>) -> ()) {
        
        let fileName = UUID().uuidString
        
        let reference = Storage.storage().reference()
            .child(folderPath)
            .child(fileName)
        
        reference.putData(data, metadata: nil) { (metadata, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            
            reference.downloadURL { (url, err) in
                if let err = err {
                    completion(.failure(err))
                    return
                }
                guard let url = url else {
                    completion(.failure(FirebaseError.noUrl))
                    return
                }
                completion(.success(url))
            }
            
        }
    }
    
    public static func put(data: Data, folderPath: String, completion: @escaping (Result<String, Error>) -> ()) {
        
        let fileName = UUID().uuidString
        
        let reference = Storage.storage().reference()
            .child(folderPath)
            .child(fileName)
        
        reference.putData(data, metadata: nil) { (metadata, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            completion(.success(reference.description))
        }
    }
    
    private static var downloadUrls = [String]()
    private static var currentUploadTask: StorageUploadTask?
    
    public static func batchUpload(images: [UIImage], atPath path: StorageReference, oldImageUrls: [String], compressionQuality: CGFloat = 1.0, completion: @escaping (Result<[String], Error>) -> ()) {
        if images.count == 0 { completion(.success([])) }
        var datas = [Data]()
        images.forEach { (image) in
            if let data = image.jpegData(compressionQuality: compressionQuality) {
                datas.append(data)
            }
        }
        batchUpload(datas: datas, atPath: path, oldDataUrls: oldImageUrls, completion: completion)
    }
    
    public static func batchUpload(datas: [Data], atPath path: StorageReference, oldDataUrls: [String], completion: @escaping (Result<[String], Error>) -> ()) {
        if datas.count == 0 {
            completion(.failure(FirebaseError.noData))
            return
        }
        
        batchDelete(oldDataUrls) { (result) in
            switch result {
            case .success(let finished):
                if finished {
                    self.downloadUrls = [String]()
                    uploadData(forIndex: 0, datas: datas, atPath: path, completion: completion)
                } else {
                    completion(.failure(FirebaseError.somethingWentWrong))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    public static func uploadData(forIndex index:Int, datas: [Data], atPath path: StorageReference, completion: @escaping (Result<[String], Error>) -> ()) {
        
        if index < datas.count {
            
            let data = datas[index]
            let fileName = UUID().uuidString
            
            upload(data: data, withName: fileName, atPath: path) { (result) in
                switch result {
                case .success(let url):
                    downloadUrls.append(url)
                case .failure(let err):
                    print(err.localizedDescription)
                }
                
                self.uploadData(forIndex: index + 1, datas: datas, atPath: path, completion: completion)
            }
            return
        }
        completion(.success(downloadUrls))
    }
    
    public static func upload(data: Data, withName fileName: String, atPath path: StorageReference, completion: @escaping (Result<String, Error>) -> Void) {
        let reference = path.child(fileName)
        
        self.currentUploadTask = reference.putData(data, metadata: nil) { (metadata, err) in
            if let err = err {
                completion(.failure(err))
                return
            }
            reference.downloadURL { (url, err) in
                if let err = err {
                    completion(.failure(err))
                }
                guard let url = url else {
                    completion(.failure(FirebaseError.noUrl))
                    return
                }
                completion(.success(url.absoluteString))
            }
        }
    }
    
    public static func cancel() {
        self.currentUploadTask?.cancel()
    }
    
    public static func batchDelete(_ urls: [String], completion: @escaping (Result<Bool, Error>) -> ()) {
        delete(forIndex: 0, urls: urls, completion: completion)
    }
    
    public static func delete(forIndex index:Int, urls: [String], completion: @escaping (Result<Bool, Error>) -> ()) {
        if index < urls.count {
            let url = urls[index]
            if url == "" {
                print("StorageService: Delete url is empty string - skipping delete")
                completion(.success(true))
                return
            }
            delete(at: url) { (result) in
                switch result {
                case .success(let finished):
                    print("StorageService: Deleted at url: \(url) - \(finished)")
                case .failure(let err):
                    completion(.failure(err))
                }
                delete(forIndex: index + 1, urls: urls, completion: completion)
            }
            return
        }
        completion(.success(true))
    }
    
    public static func downloadFrom(url: String, maxSizeInMB size: Int64 = 1.MB(), completion: @escaping (Result<Data, Error>) -> ()) {
        let reference = Storage.storage().reference(forURL: url)
        reference.getData(maxSize: size) { data, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(FirebaseError.noData))
                return
            }
            completion(.success(data))
        }
    }
    
    // MARK: - Async functions
    
    @MainActor
    public static func save(image: UIImage, folderPath: String, compressionQuality: CGFloat) async throws -> URL {
        try await withCheckedThrowingContinuation({ continuation in
            save(image: image, folderPath: folderPath, compressionQuality: compressionQuality) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func put(image: UIImage, folderPath: String, compressionQuality: CGFloat) async throws -> String {
        try await withCheckedThrowingContinuation({ continuation in
            put(image: image, folderPath: folderPath, compressionQuality: compressionQuality) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    @discardableResult
    public static func delete(at url: String) async throws -> Bool {
        try await withCheckedThrowingContinuation({ continuation in
            delete(at: url) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func handleImageChange(newImage: UIImage, folderPath: String, compressionQuality: CGFloat, oldImageUrl: String) async throws -> URL {
        try await withCheckedThrowingContinuation({ continuation in
            handleImageChange(newImage: newImage, folderPath: folderPath, compressionQuality: compressionQuality, oldImageUrl: oldImageUrl) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func put(newImage: UIImage, folderPath: String, compressionQuality: CGFloat, oldImageUrl: String) async throws -> String {
        try await withCheckedThrowingContinuation({ continuation in
            put(newImage: newImage, folderPath: folderPath, compressionQuality: compressionQuality, oldImageUrl: oldImageUrl) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func handleDataChange(newData: Data, folderPath: String, oldDataUrl: String) async throws -> URL {
        try await withCheckedThrowingContinuation({ continuation in
            handleDataChange(newData: newData, folderPath: folderPath, oldDataUrl: oldDataUrl) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func put(newData: Data, folderPath: String, oldDataUrl: String) async throws -> String {
        try await withCheckedThrowingContinuation({ continuation in
            put(newData: newData, folderPath: folderPath, oldDataUrl: oldDataUrl) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func save(data: Data, folderPath: String) async throws -> URL {
        try await withCheckedThrowingContinuation({ continuation in
            save(data: data, folderPath: folderPath) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func put(data: Data, folderPath: String) async throws -> String {
        try await withCheckedThrowingContinuation({ continuation in
            put(data: data, folderPath: folderPath) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func batchUpload(images: [UIImage], atPath path: StorageReference, oldImageUrls: [String], compressionQuality: CGFloat = 1.0) async throws -> [String] {
        try await withCheckedThrowingContinuation({ continuation in
            batchUpload(images: images, atPath: path, oldImageUrls: oldImageUrls, compressionQuality: compressionQuality) { result in
                switch result {
                case .success(let urls):
                    continuation.resume(returning: urls)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func batchUpload(datas: [Data], atPath path: StorageReference, oldDataUrls: [String]) async throws -> [String] {
        try await withCheckedThrowingContinuation({ continuation in
            batchUpload(datas: datas, atPath: path, oldDataUrls: oldDataUrls) { result in
                switch result {
                case .success(let urls):
                    continuation.resume(returning: urls)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    @discardableResult
    public static func batchDelete(_ urls: [String]) async throws -> Bool {
        try await withCheckedThrowingContinuation({ continuation in
            batchDelete(urls) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
    
    @MainActor
    public static func downloadFrom(url: String, maxSizeInMB size: Int64 = 1.MB()) async throws -> Data {
        try await withCheckedThrowingContinuation({ continuation in
            downloadFrom(url: url, maxSizeInMB: size) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        })
    }
}
