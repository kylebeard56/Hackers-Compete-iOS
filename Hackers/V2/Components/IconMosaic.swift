//
//  IconMosaic.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/23.
//

import SwiftUI

struct IconMosaicGrid: View {
    var primary: Color
    var secondary: Color
    
    // Cards, team, player(s)
    var icons: [String] = ["f091", "31", "32", "33", "34"]
    
    private var gradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .top, endPoint: .bottom)
    }
    
    let w: CGFloat = 60
    let h: [CGFloat] = [0, -120, -75, 105, 180].reversed()
    let v: [CGFloat] = [0, -15, 75, -45, 45].reversed()
    
    var body: some View {
        ZStack {
            ForEach(0..<icons.count, id: \.self, content: { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.systemCard)
                        .frame(width: w, height: w)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(gradient.opacity(0.05))
                        .frame(width: w, height: w)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.systemCard, lineWidth: 2)
                        .frame(width: w, height: w)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(gradient.opacity(0.5), lineWidth: 3)
                        .frame(width: w, height: w)
                    AwesomeImage(
                        rawIcon: icons.reversed()[i].unicode,
                        style: .regular,
                        size: w/2,
                        color: primary,
                        secondaryColor: secondary
                    )
                }
                .padding(.leading, h[i])
                .padding(.top, v[i])
            })
        }
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 0)
        .background(Color.systemGray6)
    }
}

struct IconMosaicGrid_Previews: PreviewProvider {
    static var view: some View {
        ScrollView {
            VStack(spacing: 8) {
                IconMosaicGrid(
                    primary: Color.systemPurple.opacity(0.6),
                    secondary: Color.systemPink.opacity(0.6)//,
                    //icons: ["31", "e4df"]
                )
                IconMosaicGrid(
                    primary: Color.systemPurple.opacity(0.6),
                    secondary: Color.systemPink.opacity(0.6)//,
                    //icons: ["31", "32", "e4df"]
                )
                IconMosaicGrid(
                    primary: Color.systemPurple.opacity(0.6),
                    secondary: Color.systemPink.opacity(0.6)//,
                    //icons: ["31", "32", "33", "e4df"]
                )
                IconMosaicGrid(
                    primary: Color.systemPurple.opacity(0.6),
                    secondary: Color.systemPink.opacity(0.6)//,
                    //icons: ["31", "32", "33", "34", "e4df"]
                )
            }
            .padding(.horizontal, 32)
        }
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
