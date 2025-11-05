//
//  BannerView.swift
//  FMLoopingScrollView
//
//  Created by FumingLeo on 2025/10/30.
//

import SwiftUI

struct Item: Identifiable {
    var id: UUID = .init()// 注意！此id需改为唯一id，防止SwiftUI重复创建
    var color: Color
}

struct BannerView<Content: View, Item: RandomAccessCollection>: View where Item.Element: Identifiable {
    var width: CGFloat
    var spacing: CGFloat = 0
    var items: Item
    var controller: LoopingScrollController? = nil  // 可选的控制器
    @Binding var currentIndex: Int  // 当前显示的索引
    @ViewBuilder var content: (Int, Item.Element) -> Content  // 传递索引和 item
    
    @State private var hasAppear = false
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            let itemsArray = Array(items)
            
            // 确保 itemsArray 不为空，避免除0错误
            guard !itemsArray.isEmpty, width > 0 else {
                return AnyView(EmptyView())
            }
            
            // 计算需要重复的次数，至少需要2倍来保证无缝循环
            let repeatingCount = max(Int((size.width / width).rounded()) + 2, 2)
            
            return AnyView(
                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        // 原始卡片
                        ForEach(Array(itemsArray.enumerated()), id: \.element.id) { index, item in
                            content(index, item)
                                .frame(width: width)
                        }
                        
                        // 复制的卡片 - 使用唯一的 id 来避免与原始卡片冲突
                        ForEach(0 ..< repeatingCount, id: \.self) { repeatIndex in
                            let actualIndex = repeatIndex % itemsArray.count
                            let item = itemsArray[actualIndex]
                            content(actualIndex, item)
                                .frame(width: width)
                                .id("repeat_\(repeatIndex)_\(item.id)") // 为重复卡片添加唯一标识
                        }
                    }
                    .background() {
                        ScrollViewHelper(width: width, spacing: spacing, itemsCount: items.count, repeatingCount: repeatingCount, controller: controller, currentIndex: $currentIndex)
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard hasAppear == false else { return }
                    hasAppear = true
                    controller?.startAutoScroll()// 自动切换
                }
            )
        }
    }
}

fileprivate struct ScrollViewHelper: UIViewRepresentable {
    var width: CGFloat
    var spacing: CGFloat
    var itemsCount: Int
    var repeatingCount: Int
    var controller: LoopingScrollController?
    @Binding var currentIndex: Int
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(width: width, spacing: spacing, itemsCount: itemsCount, repeatingCount: repeatingCount, currentIndex: $currentIndex)
        coordinator.controller = controller
        controller?.coordinator = coordinator
        return coordinator
    }
    
    func makeUIView(context: Context) -> UIView {
        return .init()
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        // 尝试立即初始化，如果失败则稍后重试
        if !context.coordinator.isAdded {
            if let scrollView = uiView.superview?.superview?.superview as? UIScrollView {
                scrollView.delegate = context.coordinator
                scrollView.decelerationRate = .fast // 设置快速减速，配合吸附效果
                context.coordinator.scrollView = scrollView
                context.coordinator.isAdded = true
            } else {
                // 只在第一次失败时延迟重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    if let scrollView = uiView.superview?.superview?.superview as? UIScrollView, !context.coordinator.isAdded {
                        scrollView.delegate = context.coordinator
                        scrollView.decelerationRate = .fast // 设置快速减速，配合吸附效果
                        context.coordinator.scrollView = scrollView
                        context.coordinator.isAdded = true
                    }
                }
            }
        } else {
            // 即使已经添加过，也要确保 decelerationRate 保持为 .fast
            // 因为某些情况下系统可能会重置这个值
            if let scrollView = context.coordinator.scrollView {
                scrollView.decelerationRate = .fast
            }
        }
        
        // 立即更新参数
        context.coordinator.width = width
        context.coordinator.spacing = spacing
        context.coordinator.itemsCount = itemsCount
        context.coordinator.repeatingCount = repeatingCount
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var width: CGFloat
        var spacing: CGFloat
        var itemsCount: Int
        var repeatingCount: Int
        weak var scrollView: UIScrollView?
        weak var controller: LoopingScrollController?  // 引用控制器以便重启定时器
        @Binding var currentIndex: Int  // 当前索引的绑定
        var isProgrammaticScrolling: Bool = false  // 标记是否正在进行手动控制滚动
        var isUserScrolling: Bool = false  // 标记用户是否正在手动滑动
        
        init(width: CGFloat, spacing: CGFloat, itemsCount: Int, repeatingCount: Int, currentIndex: Binding<Int>) {
            self.width = width
            self.spacing = spacing
            self.itemsCount = itemsCount
            self.repeatingCount = repeatingCount
            self._currentIndex = currentIndex
        }
        
        var isAdded: Bool = false
        
        // 滚动到下一张
        func scrollToNext(animated: Bool) {
            guard let scrollView = scrollView, itemsCount > 0, isAdded else { 
                print("⚠️ BannerView scrollToNext 被调用，但 scrollView 尚未就绪")
                return 
            }
            let itemWidth = width + spacing
            let sumLength = CGFloat(itemsCount) * (width + spacing)
            let currentOffset = scrollView.contentOffset.x
            
            // 先找到当前最接近的卡片位置（四舍五入到最近的卡片）
            let currentIndex = round(currentOffset / itemWidth)
            let alignedCurrentOffset = currentIndex * itemWidth
            
            // 从对齐后的位置计算下一张
            let nextOffset = alignedCurrentOffset + itemWidth
            
            // 提前设置标志，避免瞬间跳转时触发边界检查
            isProgrammaticScrolling = true
            
            // 检查是否会超出边界（需要循环）
            if nextOffset > sumLength {
                // 需要循环：计算对齐位置在主区域 [0, sumLength) 中的等价位置
                let normalizedAligned = alignedCurrentOffset.truncatingRemainder(dividingBy: sumLength)
                let actualAligned = normalizedAligned < 0 ? normalizedAligned + sumLength : normalizedAligned
                
                // 跳转到主区域的等价位置
                scrollView.contentOffset.x = actualAligned
                
                // 然后从新位置滚动到下一张
                let finalOffset = actualAligned + itemWidth
                scrollView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: animated)
            } else {
                // 正常滚动，先对齐到当前卡片（如果需要），再滚动到下一张
                if abs(currentOffset - alignedCurrentOffset) > 0.5 {
                    scrollView.contentOffset.x = alignedCurrentOffset
                }
                scrollView.setContentOffset(CGPoint(x: nextOffset, y: 0), animated: animated)
            }
            
            if !animated {
                isProgrammaticScrolling = false
            }
            // 注意：animated 的情况下，标志位会在 scrollViewDidEndScrollingAnimation 中重置
        }
        
        // 滚动到上一张
        func scrollToPrevious(animated: Bool) {
            guard let scrollView = scrollView, itemsCount > 0, isAdded else { 
                print("⚠️ BannerView scrollToPrevious 被调用，但 scrollView 尚未就绪")
                return 
            }
            let itemWidth = width + spacing
            let sumLength = CGFloat(itemsCount) * (width + spacing)
            let currentOffset = scrollView.contentOffset.x
            
            // 先找到当前最接近的卡片位置（四舍五入到最近的卡片）
            let currentIndex = round(currentOffset / itemWidth)
            let alignedCurrentOffset = currentIndex * itemWidth
            
            // 从对齐后的位置计算上一张
            let previousOffset = alignedCurrentOffset - itemWidth
            
            print("🔍 scrollToPrevious - original: \(currentOffset), aligned: \(alignedCurrentOffset), target: \(previousOffset)")
            
            // 提前设置标志，避免瞬间跳转时触发边界检查
            isProgrammaticScrolling = true
            
            // 检查是否会小于0（需要循环）
            if previousOffset < 0 {
                // 需要循环：计算对齐位置在主区域 [0, sumLength) 中的等价位置
                let normalizedAligned = alignedCurrentOffset.truncatingRemainder(dividingBy: sumLength)
                let actualAligned = normalizedAligned < 0 ? normalizedAligned + sumLength : normalizedAligned
                
                // 跳转到重复区域的等价位置
                let repeatAreaOffset = actualAligned + sumLength
                print("🔄 循环模式 - actualAligned: \(actualAligned), repeatArea: \(repeatAreaOffset)")
                scrollView.contentOffset.x = repeatAreaOffset - spacing
                
                // 然后从新位置滚动到上一张
                let finalOffset = repeatAreaOffset - itemWidth
                print("📍 最终目标: \(finalOffset)")
                scrollView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: animated)
            } else {
                // 正常滚动，先对齐到当前卡片（如果需要），再滚动到上一张
                if abs(currentOffset - alignedCurrentOffset) > 0.5 {
                    print("⚙️ 先对齐当前位置: \(alignedCurrentOffset)")
                    scrollView.contentOffset.x = alignedCurrentOffset
                }
                print("➡️ 正常滚动模式，目标: \(previousOffset)")
                scrollView.setContentOffset(CGPoint(x: previousOffset, y: 0), animated: animated)
            }
            
            if !animated {
                isProgrammaticScrolling = false
            }
            // 注意：animated 的情况下，标志位会在 scrollViewDidEndScrollingAnimation 中重置
        }
        
        // 滚动到指定索引
        func scrollToIndex(_ index: Int, animated: Bool) {
            guard let scrollView = scrollView, itemsCount > 0, isAdded else { 
                print("⚠️ BannerView scrollToIndex 被调用，但 scrollView 尚未就绪")
                return 
            }
            let itemWidth = width + spacing
            var targetOffset = CGFloat(index) * itemWidth
            
            // 确保索引在有效范围内
            let sumLength = CGFloat(itemsCount) * (width + spacing)
            targetOffset = targetOffset.truncatingRemainder(dividingBy: sumLength)
            if targetOffset < 0 {
                targetOffset += sumLength
            }
            
            isProgrammaticScrolling = true
            
            if animated {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    scrollView.contentOffset.x = targetOffset
                }, completion: { [weak self] _ in
                    self?.isProgrammaticScrolling = false
                })
            } else {
                scrollView.contentOffset.x = targetOffset
                isProgrammaticScrolling = false
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard itemsCount > 0 else { return }
            let minX = scrollView.contentOffset.x
            let mainContentSize = CGFloat(itemsCount) * width
            let spacingSize = CGFloat(itemsCount) * spacing
            let sumLength = mainContentSize + spacingSize
            
            // 手动控制滚动期间，跳过边界检查，避免干扰动画
            if !isProgrammaticScrolling {
                if minX > sumLength {
                    scrollView.contentOffset.x -= sumLength
                }
                if minX < 0 {
                    scrollView.contentOffset.x += sumLength
                }
            }
            
            // 更新当前索引（对 itemsCount 取模，返回实际的索引）
            let itemWidth = width + spacing
            if itemWidth > 0 {
                let rawIndex = Int((scrollView.contentOffset.x / itemWidth).rounded())
                currentIndex = rawIndex % itemsCount
            }
        }
        
        // setContentOffset(_:animated:true) 动画完成时调用
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            // 动画完成后进行微调检查，snapToNearestItem 会自动管理标志位
            snapToNearestItem(scrollView, resetFlag: true)
        }
        
        // 用户开始拖拽时调用
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrolling = true
            // 用户开始滑动时，暂停定时器（但保持自动滚动状态）
            controller?.pauseTimer()
        }
        
        // 用户即将结束拖拽时调用，可以修改目标偏移量实现自定义吸附
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard itemsCount > 0, width > 0 else { return }
            
            let itemWidth = width + spacing
            let targetX = targetContentOffset.pointee.x
            
            // 计算最近的卡片索引（考虑速度方向）
            var targetIndex = round(targetX / itemWidth)
            
            // 如果速度较大，倾向于滑动到下一张/上一张
            if abs(velocity.x) > 0.5 {
                if velocity.x > 0 {
                    targetIndex = ceil(targetX / itemWidth)
                } else {
                    targetIndex = floor(targetX / itemWidth)
                }
            }
            
            // 计算应该吸附到的位置
            let snapOffset = targetIndex * itemWidth
            
            // 修改目标偏移量
            targetContentOffset.pointee.x = snapOffset
        }
        
        // 用户结束拖拽时调用
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                // 如果不会继续减速，直接标记为结束，进行微调并重启定时器
                isUserScrolling = false
                snapToNearestItem(scrollView, resetFlag: true)
                restartAutoScrollIfNeeded()
            }
        }
        
        // 减速结束时调用
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserScrolling = false
            // 确保最终位置居中对齐
            snapToNearestItem(scrollView, resetFlag: true)
            // 滑动完全结束后，重启自动滚动
            restartAutoScrollIfNeeded()
        }
        
        // 辅助方法：将 scrollView 吸附到最近的卡片位置
        private func snapToNearestItem(_ scrollView: UIScrollView, resetFlag: Bool = true) {
            guard itemsCount > 0, width > 0 else { return }
            
            let itemWidth = width + spacing
            let currentOffset = scrollView.contentOffset.x
            
            // 找到最近的卡片索引
            let nearestIndex = round(currentOffset / itemWidth)
            let targetOffset = nearestIndex * itemWidth
            
            // 如果当前位置与目标位置有偏差，进行微调
            let offsetDifference = abs(currentOffset - targetOffset)
            if offsetDifference > 0.5 { // 允许0.5像素的误差
                // 如果需要设置标志（从用户滑动结束调用时）
                if resetFlag && !isProgrammaticScrolling {
                    isProgrammaticScrolling = true
                }
                
                UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                    scrollView.contentOffset.x = targetOffset
                }, completion: { [weak self] finished in
                    if finished {
                        self?.isProgrammaticScrolling = false
                    }
                })
            } else if resetFlag && isProgrammaticScrolling {
                // 不需要微调，但需要重置标志
                isProgrammaticScrolling = false
            }
        }
        
        // 辅助方法：如果之前是自动滚动状态，重新启动定时器
        private func restartAutoScrollIfNeeded() {
            if let controller = controller, controller.shouldAutoScroll {
                controller.restartAutoScroll()
            }
        }
    }
}

// 滚动控制器，用于外部控制滚动行为
class LoopingScrollController: ObservableObject {
    fileprivate weak var coordinator: ScrollViewHelper.Coordinator?
    private var timer: Timer?
    private var autoScrollInterval: TimeInterval = 3.0
    @Published var isAutoScrolling: Bool = false
    
    // 防抖相关属性
    private var lastScrollToNextTime: Date?
    private var lastScrollToPreviousTime: Date?
    private let debounceInterval: TimeInterval = 0.3  // 防抖时间间隔（秒）
    
    // 记录是否应该自动滚动（用于判断用户滑动后是否需要重启）
    var shouldAutoScroll: Bool {
        return isAutoScrolling
    }
    
    // 滚动到下一张
    func scrollToNext(animated: Bool = true) {
        // 防抖：检查是否有动画正在进行或用户正在滑动
        guard let coordinator = coordinator else { return }
        
        if coordinator.isProgrammaticScrolling || coordinator.isUserScrolling {
            // 动画正在进行中或用户正在滑动，忽略此次调用
            return
        }
        
        // 时间防抖：检查是否在防抖时间间隔内
        let currentTime = Date()
        if let lastTime = lastScrollToNextTime {
            let timeInterval = currentTime.timeIntervalSince(lastTime)
            if timeInterval < debounceInterval {
                // 在防抖时间间隔内，忽略此次调用
                return
            }
        }
        
        // 更新最后执行时间
        lastScrollToNextTime = currentTime
        
        // 执行滚动
        coordinator.scrollToNext(animated: animated)
    }
    
    // 滚动到上一张
    func scrollToPrevious(animated: Bool = true) {
        // 防抖：检查是否有动画正在进行或用户正在滑动
        guard let coordinator = coordinator else { return }
        
        if coordinator.isProgrammaticScrolling || coordinator.isUserScrolling {
            // 动画正在进行中或用户正在滑动，忽略此次调用
            return
        }
        
        // 时间防抖：检查是否在防抖时间间隔内
        let currentTime = Date()
        if let lastTime = lastScrollToPreviousTime {
            let timeInterval = currentTime.timeIntervalSince(lastTime)
            if timeInterval < debounceInterval {
                // 在防抖时间间隔内，忽略此次调用
                return
            }
        }
        
        // 更新最后执行时间
        lastScrollToPreviousTime = currentTime
        
        // 执行滚动
        coordinator.scrollToPrevious(animated: animated)
    }
    
    // 滚动到指定索引
    func scrollToIndex(_ index: Int, animated: Bool = true) {
        coordinator?.scrollToIndex(index, animated: animated)
    }
    
    // 开始自动滚动
    func startAutoScroll(interval: TimeInterval = 3.0) {
        autoScrollInterval = interval
        restartAutoScroll()
    }
    
    // 内部方法：重启自动滚动
    fileprivate func restartAutoScroll() {
        stopTimer() // 先停止现有的定时器
        isAutoScrolling = true
        timer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { [weak self] _ in
            self?.scrollToNext(animated: true)
        }
    }
    
    // 停止自动滚动（完全停止，包括标记为不再自动滚动）
    func stopAutoScroll() {
        stopTimer()
        isAutoScrolling = false
    }
    
    // 暂停定时器（用于用户滑动时，保持 isAutoScrolling 状态以便稍后恢复）
    fileprivate func pauseTimer() {
        stopTimer()
    }
    
    // 私有方法：只停止定时器，不改变 isAutoScrolling 状态
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopAutoScroll()
    }
}
