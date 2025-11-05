//
//  AnimatedImageView.swift
//  FMAnimatedImageView
//
//  Created by FumingLeo on 2025/11/5.
//

import SwiftUI
import UIKit

public struct SwiftUIAnimatedImageView: UIViewRepresentable {
    let image: String
    
    public func makeUIView(context: Context) -> AnimatedImageView {
        let view = AnimatedImageView()
        return view
    }
    
    public func updateUIView(_ uiView: AnimatedImageView, context: Context) {
        uiView.setImage(image)
    }
}

public final class AnimatedImageView: UIView {
    private var switchDuration: CGFloat = 0.35
    private var scaleDuration: CGFloat = 14
    
    private var currentImgView = UIImageView()
    private var willShowImgView = UIImageView()
    private var shouldContinueScaling = false
    private var originalBounds: CGRect = .zero
    private var smallBounds: CGRect = .zero
    private var bigBounds: CGRect = .zero
    
    private var pendingImages: [String] = []
    var isSwitching = false
    var firstImgSource = "" // 首张图片源（可以是URL或本地图片名称）
    var hasFirstImgSource = false
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.15 // 延时加载图片
    
    /// 设置图片（支持网络URL或本地图片名称）
    /// - Parameter source: 图片源，可以是网络URL（http://或https://开头）或本地图片名称
    func setImage(_ source: String) {
        if hasFirstImgSource == false {
            // 首次设置图片时，currentImgView.frame是0，改为在layoutSubviews加载图片和缩放
            firstImgSource = source
            hasFirstImgSource = true
            return
        }
        
        // 增加防抖，禁止快速修改图片
        debounceWorkItem?.cancel()
        
        // 清空待处理队列，只保留最新的图片源，忽略中间的设置
        pendingImages.removeAll()
        pendingImages.append(source)
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isSwitching {
                self.showNextImage()
            }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initImages()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initImages()
    }
    
    // 创建图片
    private func initImages() {
        willShowImgView.contentMode = .scaleAspectFill
        willShowImgView.clipsToBounds = true
        addSubview(willShowImgView)
        
        currentImgView.contentMode = .scaleAspectFill
        currentImgView.clipsToBounds = true
        addSubview(currentImgView)
    }
    
    // 设置图片大小
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let sigleScale = 0.05
        let doubleScale = 1.0 + sigleScale * 2
        let width = bounds.width
        let height = bounds.height
        
        let x = -width * sigleScale
        let y = -height * sigleScale
        let imgWidth = width * doubleScale
        let imgHeight = height * doubleScale
        
        currentImgView.frame = CGRect(x: x, y: y, width: imgWidth, height: imgHeight)
        willShowImgView.frame = currentImgView.frame
        
        // 记录初始 bounds
        if originalBounds == .zero {
            originalBounds = currentImgView.frame
            // 小尺寸
            let smallScale = 0.10
            smallBounds = self.originalBounds.insetBy(dx: self.originalBounds.width*(smallScale/2.0), dy: self.originalBounds.height*(smallScale/2.0))
            
            // 大尺寸
            let bigScale = 0.25
            bigBounds = originalBounds.insetBy(dx: -originalBounds.width*(bigScale/2.0), dy: -originalBounds.height*(bigScale/2.0))
            
            // 加载首张图片
            if firstImgSource.isEmpty {
                currentImgView.image = getDefaultImage()
                self.startScaleAnimation()
            }
            else {
                loadImage(from: firstImgSource) { [weak self] image in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.currentImgView.image = image ?? self.getDefaultImage()
                        self.startScaleAnimation()
                    }
                }
            }
        }
    }
    
    /// 判断是否是网络URL
    private func isNetworkURL(_ string: String) -> Bool {
        return string.hasPrefix("http://") || string.hasPrefix("https://")
    }
    
    /// 加载图片（支持网络URL和本地图片名称）
    private func loadImage(from source: String, completion: @escaping (UIImage?) -> Void) {
        // 判断是网络URL还是本地图片名称
        if isNetworkURL(source) {
            // 加载网络图片
            guard let url = URL(string: source) else {
                completion(nil)
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("网络图片加载失败: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                
                completion(image)
            }.resume()
        }
        else {
            // 加载本地图片
            DispatchQueue.global(qos: .userInitiated).async {
                let image = UIImage(named: source)
                if image == nil {
                    print("本地图片加载失败: \(source)")
                }
                completion(image)
            }
        }
    }
    
    private func showNextImage() {
        guard !pendingImages.isEmpty else { return }
        
        let nextSource = pendingImages.removeFirst()
        
        if nextSource.isEmpty {
            willShowImgView.image = getDefaultImage()
            animateSwitch {
                self.isSwitching = false
                self.startScaleAnimation()
                self.showNextImage() // 继续处理队列
            }
            return
        }
        
        isSwitching = true
        stopScaleAnimation()
        
        loadImage(from: nextSource) { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.willShowImgView.image = image ?? self.getDefaultImage()
                self.animateSwitch {
                    self.isSwitching = false
                    self.startScaleAnimation()
                    self.showNextImage() // 继续处理队列
                }
            }
        }
    }
    
    private func animateSwitch(completion: @escaping () -> Void) {
        // currentImgView动画
        let shrinkAnim = CABasicAnimation(keyPath: "bounds")
        shrinkAnim.fromValue = originalBounds
        shrinkAnim.toValue = bigBounds
        shrinkAnim.duration = switchDuration-0.15
        shrinkAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shrinkAnim.fillMode = .forwards
        shrinkAnim.isRemovedOnCompletion = false
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1
        fadeAnim.toValue = 0
        fadeAnim.duration = switchDuration-0.15
        fadeAnim.fillMode = .forwards
        fadeAnim.isRemovedOnCompletion = false
        
        // willShowImgView动画
        let expandAnim = CABasicAnimation(keyPath: "bounds")
        expandAnim.fromValue = smallBounds
        expandAnim.toValue = originalBounds
        expandAnim.duration = switchDuration
        expandAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        expandAnim.fillMode = .forwards
        expandAnim.isRemovedOnCompletion = false
        
        let unfadeAnim = CABasicAnimation(keyPath: "opacity")
        unfadeAnim.fromValue = 0
        unfadeAnim.toValue = 1.0
        unfadeAnim.duration = switchDuration
        unfadeAnim.fillMode = .forwards
        unfadeAnim.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 完成后更新状态
            self.currentImgView.image = self.willShowImgView.image
            self.currentImgView.layer.removeAllAnimations()
            self.currentImgView.bounds = self.originalBounds
            
            self.willShowImgView.image = nil
            self.willShowImgView.layer.removeAllAnimations()
            self.willShowImgView.bounds = self.smallBounds
            
            completion()
        }
        
        currentImgView.layer.add(shrinkAnim, forKey: "shrinkAnim")
        currentImgView.layer.add(fadeAnim, forKey: "fadeAnim")
        willShowImgView.layer.add(expandAnim, forKey: "expandAnim")
        willShowImgView.layer.add(unfadeAnim, forKey: "unfadeAnim")
        
        CATransaction.commit()
    }
    
    // 无限缩放动画
    private func startScaleAnimation() {
        shouldContinueScaling = true
        addScaleAnimation()
    }
    
    private func addScaleAnimation() {
        guard shouldContinueScaling else { return }
        
        let scaleDownBounds = originalBounds
        let scaleUpBounds = bigBounds
        
        let anim = CABasicAnimation(keyPath: "bounds")
        anim.fromValue = scaleDownBounds
        anim.toValue = scaleUpBounds
        anim.duration = scaleDuration
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        currentImgView.layer.add(anim, forKey: "scaleLoop")
    }
    
    private func stopScaleAnimation() {
        shouldContinueScaling = false
        
        currentImgView.layer.removeAllAnimations()
        willShowImgView.layer.removeAllAnimations()
        
        currentImgView.bounds = originalBounds
        currentImgView.layer.opacity = 1
        
        willShowImgView.bounds = smallBounds
        willShowImgView.layer.opacity = 0
    }
    
    private func createGradientImage(topColor: UIColor, bottomColor: UIColor, size: CGSize) -> UIImage? {
        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.colors = [topColor.cgColor, bottomColor.cgColor]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    private var gradientPlaceholderImage: UIImage?
    private func getDefaultImage() -> UIImage {
        if gradientPlaceholderImage == nil {
            gradientPlaceholderImage = createGradientImage(
                topColor: .black,
                bottomColor: .black.withAlphaComponent(0.2),
                size: willShowImgView.bounds.size
            )
        }
        return gradientPlaceholderImage!
    }
}
