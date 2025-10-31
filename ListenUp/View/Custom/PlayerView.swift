//
//  PlayerView.swift
//  ListenUp
//
//  Created by S M H  on 15/09/2025.
//

import Foundation
import UIKit
import AVFoundation

final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}
