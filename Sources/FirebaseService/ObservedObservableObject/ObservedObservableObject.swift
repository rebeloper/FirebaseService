//
//  ObservedObservableObject.swift
//  
//
//  Created by Alex Nagy on 05.07.2022.
//

import Combine

/// A type of object with a set of ``AnyCancellable``s and with a publisher that emits before the object has changed.
///
/// By default an ``ObservableObject`` synthesizes an ``ObservableObject/objectWillChange-2oa5v`` publisher that emits the changed value before any of its `@Published` properties changes.
open class ObservedObservableObject: ObservableObject {
    
    public init() { }
    
    /// A Set of type-erasing cancellable objects that execute a provided closure when canceled.
    ///
    /// Subscriber implementations can use this type to provide a “cancellation token” that makes it possible for a caller to cancel a publisher, but not to use the ``Subscription`` object to request items.
    ///
    /// An ``AnyCancellable`` instance automatically calls ``Cancellable/cancel()`` when deinitialized.
    open var cancellables: Set<AnyCancellable> = []
}
