//
//  ContentView.swift
//  FMLoopingScrollView
//
//  Created by FumingLeo on 2025/10/30.
//

import SwiftUI

struct ContentView: View {
    @State private var colors: [Color] = [.red, .green, .blue]
    @State private var currentBannerIndex: Int = 0  // 当前轮播图索引
    @StateObject private var scrollController = LoopingScrollController()
    
    var body: some View {
        VStack {
            GeometryReader {
                let items: [Item] = colors.map {
                    Item(color: $0)
                }
                BannerView(width: $0.size.width, spacing: 10, items: items, controller: scrollController, currentIndex: $currentBannerIndex) { index, item in
                    item.color
                        .clipped()
                }
                .frame(height: 200)
                .overlay(// 分页指示器：底部右下角圆点·····
                    HStack(spacing: 5) {
                        ForEach(0..<colors.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentBannerIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    , alignment: .bottomTrailing
                )
                .onChange(of: currentBannerIndex) { oldValue, newValue in
                    print("最新卡片索引：\(newValue)")
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: 220)
            
            HStack(spacing: 30) {
                // 上一张按钮
                Button {
                    scrollController.scrollToPrevious()
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
                    scrollController.scrollToNext()
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
}
