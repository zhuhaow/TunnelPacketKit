//
//  LinkedList.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/22.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class LinkedList<T> {
    var item: T
    var next: LinkedList<T>?
    var last: LinkedList<T> {
        var n = self
        while n.next != nil {
            n = n.next!
        }
        return n
    }

    init(item: T) {
        self.item = item
    }

    func append(list: LinkedList<T>) {
        last.next = list
    }

    func takeOffNext() -> LinkedList<T>? {
        let head = next
        next = nil
        return head
    }

    func insertAfter(list: LinkedList<T>) {
        let n = next
        next = list
        list.last.next = n
    }
}
