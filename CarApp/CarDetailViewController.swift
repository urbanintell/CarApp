//
//  CarDetailViewController.swift
//  CarApp
//
//  Created by Lusenii on 10/14/17.
//  Copyright © 2017 Marc Brown. All rights reserved.
//

import Foundation
import UIKit

class CarDetailViewController: UIViewController,UITableViewDelegate,UIImagePickerControllerDelegate{
    
    
    @IBOutlet weak var carImageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    
    
    var carName:String?
    var userZipCode:String?
    
    override func viewDidLoad() {
        
        
        print(carName!)
        
        tableView.delegate=self
        self.navigationController?.title = carName
        
        
       
        
    }
    
    
    
}
