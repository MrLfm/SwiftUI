//
//  ContentView.swift
//  FMAnimatedImageView
//
//  Created by FumingLeo on 2025/11/5.
//

import SwiftUI

struct ContentView: View {
    @State private var currentIndex: Int = 1
    private let minIndex = 1
    private let maxIndex = 5
    
    private var imageSource: String {
        String(currentIndex)
    }
    
    var body: some View {
        SwiftUIAnimatedImageView(image: imageSource)
            .ignoresSafeArea()
            .overlay {
                HStack(spacing: 30) {
                    // 上一张按钮
                    Button {
                        previousImage()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("上一张")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.gradient)
                        )
                    }
                    
                    // 下一张按钮
                    Button {
                        nextImage()
                    } label: {
                        HStack(spacing: 8) {
                            Text("下一张")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.gradient)
                        )
                    }
                }
            }
    }
    
    /// 上一张：1->5->4->3->2->1循环
    private func previousImage() {
        if currentIndex <= minIndex {
            currentIndex = maxIndex
        } else {
            currentIndex -= 1
        }
    }
    
    /// 下一张：1->2->3->4->5->1循环
    private func nextImage() {
        if currentIndex >= maxIndex {
            currentIndex = minIndex
        } else {
            currentIndex += 1
        }
    }
}
