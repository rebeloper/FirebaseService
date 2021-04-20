//
//  FirebaseError.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation

public enum FirebaseError: Error {
    case noUid
    case noQuerySnapshot
    case noDocumentSnapshot
    case documentDoesNotExist
    case noAuthDataResult
    case noProfile
    case noImageAvailable
    case noUrl
    case noData
    case somethingWentWrong
}
