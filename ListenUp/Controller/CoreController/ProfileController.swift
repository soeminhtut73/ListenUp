//
//  ProfileController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit

class ProfileController: UIViewController {
    
    //MARK: - Properties
    
    
    //MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
    }
    
    //MARK: - HelperFunctions
    
    private func configureUI() {
        
        view.backgroundColor = Style.viewBackgroundColor
        title = "Profile"
    }
    
    //MARK: - Selector
    

}
