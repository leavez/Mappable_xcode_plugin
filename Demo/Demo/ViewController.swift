//
//  ViewController.swift
//  Demo
//
//  Created by Gao on 6/20/18.
//  Copyright © 2018 leavez. All rights reserved.
//

import UIKit

class ViewController: UIViewController, Mappable{


    required init(map: Mapper) throws {

    }
}

import Mappable

class A {
    let a: Int
    let bdalfj: String
    let cd: A

}

struct A : Mappable{
    let a: Int
    let bdalfj: String
    let cd: A
}

