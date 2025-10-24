//
//  ThumbnailStripView.swift
//  ListenUp
//
//  Created by S M H  on 21/10/2025.
//

import UIKit
import AVFoundation


public protocol ThumbnailStripViewDelegate: AnyObject {
    func strip(_ strip: ThumbnailStripView, didChangeStartTime start: TimeInterval)
}

public final class ThumbnailStripView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public weak var delegate: ThumbnailStripViewDelegate?

    public var clipLength: TimeInterval = 30
    public var numberOfThumbs: Int = 20

    private var asset: AVAsset?
    private var duration: TimeInterval = 0
    private var generator: AVAssetImageGenerator?
    private var images: [UIImage?] = []
    private var times: [NSValue] = []

    private let selectionView = UIView()
    private var pan: UIPanGestureRecognizer!

    private let layout = UICollectionViewFlowLayout()
    private lazy var collection: UICollectionView = {
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .secondarySystemBackground
        cv.dataSource = self
        cv.delegate = self
        cv.isScrollEnabled = false
        cv.register(ThumbCell.self, forCellWithReuseIdentifier: "cell")
        return cv
    }()

    private(set) var startTime: TimeInterval = 0

    public override init(frame: CGRect) {
        super.init(frame: frame); commonInit()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder); commonInit()
    }

    private func commonInit() {
        layer.cornerRadius = 8
        clipsToBounds = true

        addSubview(collection)
        collection.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: topAnchor),
            collection.bottomAnchor.constraint(equalTo: bottomAnchor),
            collection.leadingAnchor.constraint(equalTo: leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        selectionView.layer.borderColor = UIColor.systemBlue.cgColor
        selectionView.layer.borderWidth = 2
        selectionView.layer.cornerRadius = 6
        selectionView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        addSubview(selectionView)

        pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        selectionView.addGestureRecognizer(pan)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layout.itemSize = CGSize(width: bounds.height * 0.6, height: bounds.height)
        updateSelectionFrame()
    }

    // Public API
    public func setAsset(_ asset: AVAsset, clipLength seconds: TimeInterval = 30) {
        self.asset = asset
        self.clipLength = seconds

        duration = max(0, CMTimeGetSeconds(asset.duration))

        // Evenly spaced times
        let frames = max(1, numberOfThumbs)
        times = (0..<frames).map { i in
            let t = duration * Double(i) / Double(max(1, frames - 1))
            return NSValue(time: CMTime(seconds: t, preferredTimescale: 600))
        }
        images = Array(repeating: nil, count: times.count)
        collection.reloadData()

        // Thumbs
        generator?.cancelAllCGImageGeneration()
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 160, height: 160)
        generator = gen

        gen.generateCGImagesAsynchronously(forTimes: times) { [weak self] requestedTime, cg, _, _, _ in
            guard let self = self, let cg = cg else { return }
            if let idx = self.times.firstIndex(where: { CMTimeCompare($0.timeValue, requestedTime) == 0 }) {
                let img = UIImage(cgImage: cg)
                DispatchQueue.main.async {
                    self.images[idx] = img
                    self.collection.reloadItems(at: [IndexPath(item: idx, section: 0)])
                }
            }
        }

        setStartTime(0, notify: true)
    }

    public func setStartTime(_ t: TimeInterval, notify: Bool) {
        guard duration > 0 else { return }
        let maxStart = max(0, duration - clipLength)
        startTime = min(max(0, t), maxStart)
        updateSelectionFrame()
        if notify { delegate?.strip(self, didChangeStartTime: startTime) }
    }

    // Selection geometry
    private func selectionWidth() -> CGFloat {
        guard duration > 0 else { return bounds.width }
        let ratio = clipLength / duration
        return bounds.width * CGFloat(min(max(ratio, 0), 1))
    }

    private func xForStart(_ t: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        let maxStart = max(0, duration - clipLength)
        let ratio = maxStart > 0 ? (t / maxStart) : 0
        let usable = max(0, bounds.width - selectionWidth())
        return CGFloat(ratio) * usable
    }

    private func startForX(_ x: CGFloat) -> TimeInterval {
        guard duration > 0 else { return 0 }
        let usable = max(1, bounds.width - selectionWidth())
        let ratio = max(0, min(1, x / usable))
        let maxStart = max(0, duration - clipLength)
        return TimeInterval(ratio) * maxStart
    }

    private func updateSelectionFrame() {
        let w = selectionWidth()
        let x = xForStart(startTime)
        selectionView.frame = CGRect(x: x, y: 0, width: w, height: bounds.height)
        selectionView.isUserInteractionEnabled = (w < bounds.width - 0.5)
    }

    // Pan
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        g.setTranslation(.zero, in: self)

        var f = selectionView.frame
        f.origin.x += t.x
        f.origin.x = max(0, min(f.origin.x, bounds.width - f.width))
        selectionView.frame = f

        startTime = startForX(f.origin.x)
        delegate?.strip(self, didChangeStartTime: startTime)
    }

    // Collection
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }
    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ThumbCell
        cell.imageView.image = images[indexPath.item] ?? cell.placeholder
        return cell
    }
}

public final class ThumbCell: UICollectionViewCell {
    public let imageView = UIImageView()
    public let placeholder = UIImage(systemName: "photo")?.withRenderingMode(.alwaysTemplate)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.tintColor = .tertiaryLabel
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    public required init?(coder: NSCoder) { fatalError() }
}
