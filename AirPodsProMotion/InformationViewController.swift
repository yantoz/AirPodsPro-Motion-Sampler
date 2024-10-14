//
//  ViewController.swift
//  AirPodsProMotion
//
//  Created by Yoshio on 2020/09/22.
//

import UIKit
import CoreMotion

class CenteredTextView: UITextView {

    private var centerH: Bool = true
    private var centerV: Bool = true

    func centerHorz(center: Bool) {
        centerH = center
    }

    func centerVert(center: Bool) {
        centerV = center
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = layoutManager.usedRect(for: textContainer)
        let leftInset = centerH ? (bounds.size.width - rect.width) / 2.0 : 0
        let topInset = centerV ? (bounds.size.height - rect.height) / 2.0 : 0
        textContainerInset.top = max(0, topInset)
        textContainerInset.left = max(0, leftInset)
    }
}

class InformationViewController: UIViewController, CMHeadphoneMotionManagerDelegate {

    lazy var textView: CenteredTextView = {
        let view = CenteredTextView()
        view.font = view.font?.withSize(14)
        view.isEditable = false
        view.textContainerInset = UIEdgeInsets(top:5, left:20, bottom:5, right:20)
        return view
    }()
    
    var chart: MotionChart?

    //AirPods Pro => APP :)
    let APP = CMHeadphoneMotionManager()

    override func viewDidLoad() {

        super.viewDidLoad()
        view.layoutMargins = UIEdgeInsets(top:10, left:10, bottom:10, right:10);
        title = "Information View"
        view.backgroundColor = .systemBackground

        let statusHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let navHeight = navigationController!.navigationBar.frame.height
        
        let topMargin = statusHeight + navHeight
        let chartHeight = view.bounds.width*0.65

        textView.text = "Looking for AirPods Pro"
        textView.centerHorz(center: true)
        textView.frame = CGRect(x: 0, y: topMargin,
                                width: view.bounds.width,
                                height: view.bounds.height-chartHeight)
        view.addSubview(textView)

        chart = MotionChart(parent: self)

        if let view = chart?.view {
            view.frame = CGRect(x: 0, y: self.view.bounds.height-chartHeight,
                                width: self.view.bounds.width,
                                height: chartHeight)
        }

        APP.delegate = self

        guard APP.isDeviceMotionAvailable else {
            AlertView.alert(self, "Sorry", "Your device is not supported.")
            textView.text = "Sorry, Your device is not supported."
            return
        }

        APP.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {[weak self] motion, error  in
            guard let motion = motion, error == nil else { return }
            self?.printData(motion)
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        self.viewDidLoad()
        chart?.show()
    }

    override func viewWillDisappear(_ animated: Bool) {
        chart?.hide()
        APP.stopDeviceMotionUpdates()
    }

    func printData(_ data: CMDeviceMotion) {
        var loc: String
        switch data.sensorLocation {
        case .default:
            loc = "Default"
        case .headphoneLeft:
            loc = "Left"
        case .headphoneRight:
            loc = "Right"
        default:
            loc = "Unknown ("+String(data.sensorLocation.rawValue)+")"
        }
        textView.centerHorz(center:false)
        textView.text = """
            Source: \(loc)
            Quaternion:
                x: \(data.attitude.quaternion.x.formatted(.number.rounded(increment: 0.0001)))
                y: \(data.attitude.quaternion.y.formatted(.number.rounded(increment: 0.0001)))
                z: \(data.attitude.quaternion.z.formatted(.number.rounded(increment: 0.0001)))
                w: \(data.attitude.quaternion.w.formatted(.number.rounded(increment: 0.0001)))
            Attitude:
                pitch: \(data.attitude.pitch.formatted(.number.rounded(increment: 0.0001)))
                roll: \(data.attitude.roll.formatted(.number.rounded(increment: 0.0001)))
                yaw: \(data.attitude.yaw.formatted(.number.rounded(increment: 0.0001)))
            Gravitational Acceleration:
                x: \(data.gravity.x.formatted(.number.rounded(increment: 0.0001)))
                y: \(data.gravity.y.formatted(.number.rounded(increment: 0.0001)))
                z: \(data.gravity.z.formatted(.number.rounded(increment: 0.0001)))
            Rotation Rate:
                x: \(data.rotationRate.x.formatted(.number.rounded(increment: 0.0001)))
                y: \(data.rotationRate.y.formatted(.number.rounded(increment: 0.0001)))
                z: \(data.rotationRate.z.formatted(.number.rounded(increment: 0.0001)))
            Acceleration:
                x: \(data.userAcceleration.x.formatted(.number.rounded(increment: 0.0001)))
                y: \(data.userAcceleration.y.formatted(.number.rounded(increment: 0.0001)))
                z: \(data.userAcceleration.z.formatted(.number.rounded(increment: 0.0001)))
            Magnetic Field:
                field: \(data.magneticField.field)
                accuracy: \(data.magneticField.accuracy.rawValue)
            Heading: \(data.heading)
            """
        chart?.add(data: data)
    }
}
