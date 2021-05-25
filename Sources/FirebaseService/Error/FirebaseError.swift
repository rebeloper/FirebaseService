//
//  FirebaseError.swift
//  
//
//  Created by Alex Nagy on 20.04.2021.
//

import Foundation

public enum FirebaseError: String, Error {
    case alreadySignedIn = "Already signed in"
    case noUid = "No Uid"
    case noQuerySnapshot = "No query snapshot"
    case noDocumentSnapshot = "No document snapshot"
    case documentDoesNotExist = "Document does not exist"
    case noAuthDataResult = "No auth data result"
    case noProfile = "No profile"
    case noImageAvailable = "No image available"
    case noUrl = "No URL"
    case noData = "No data"
    case somethingWentWrong = "Something went wrong"
}
