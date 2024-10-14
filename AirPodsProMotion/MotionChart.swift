import SwiftUI
import Charts
import CoreMotion

class ReloadViewHelper: ObservableObject {
    func reloadView() {
        objectWillChange.send()
    }
}

class DataPoint {
    var sample: Int64
    var timestamp: TimeInterval
    var value: Double

    init(sample: Int64, timestamp: TimeInterval, value: Double) {
        self.sample = sample
        self.timestamp = timestamp
        self.value = value
    }
}

class DataCollection {

    private let SIZE = 200

    private var data: [[DataPoint]] = [
        [],[],[],
        [],[],[],
        [],[],[],
        [],[],[],[],
    ]
    private let names: [String] = [
        "Roll", "Pitch", "Yaw",
        "AccX", "AccY", "AccZ",
        "RotX", "RotY", "RotZ",
        "Qw", "Qx", "Qy", "Qz"
    ]
    private let colors: [Color] = [Color.teal, Color.orange, Color.green, Color.purple]
    
    private let groups: [[Int]] = [
        [0,1,2], [3,4,5], [6,7,8], [9,10,11,12]
    ]
    private var type: Int = 0

    var group: [Int] {
        return groups[type]
    }

    var count: Int {
        return data[0].count
    }
    
    var lowerLimit: Int64 {
        return (data[0].count == 0) ? 0 : data[0].first!.sample
    }

    var upperLimit: Int64 {
        return lowerLimit + Int64(SIZE) - 1
    }

    func get() -> [(data:[DataPoint], name:String, color:Color)] {
        var ret: [(data:[DataPoint], name:String, color:Color)] = []
        for index in 0..<group.count {
            let data = self.data[group[index]]
            let name = names[group[index]]
            let color = colors[index]
            ret.append((data:data, name:name, color:color))
        }
        return ret
    }
    
    func append(data: CMDeviceMotion) {

        let sample = (self.data[0].count == 0) ? 0 : self.data[0].last!.sample+1

        self.data[0].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.attitude.roll))
        self.data[1].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.attitude.pitch))
        self.data[2].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.attitude.yaw))
        self.data[3].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.userAcceleration.x))
        self.data[4].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.userAcceleration.y))
        self.data[5].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.userAcceleration.z))
        self.data[6].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.rotationRate.x))
        self.data[7].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.rotationRate.y))
        self.data[8].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.rotationRate.z))
        self.data[9].append(DataPoint(sample:sample,
                                      timestamp:data.timestamp, value:data.attitude.quaternion.w))
        self.data[10].append(DataPoint(sample:sample,
                                       timestamp:data.timestamp, value:data.attitude.quaternion.x))
        self.data[11].append(DataPoint(sample:sample,
                                       timestamp:data.timestamp, value:data.attitude.quaternion.y))
        self.data[12].append(DataPoint(sample:sample,
                                       timestamp:data.timestamp, value:data.attitude.quaternion.z))

        if (self.data[0].count > SIZE) {
            for index in 0..<self.data.count {
                self.data[index].removeFirst()
            }
        }
    }

    func clear() {
        for index in 0..<data.count {
            data[index].removeAll()
        }
    }

    func rotate(inc: Int) {
        type = (type + inc + groups.count) % groups.count
    }
}

struct MotionChartView: View {

    private var data = DataCollection()

    @ObservedObject var reloadViewHelper = ReloadViewHelper()

    func append(data: CMDeviceMotion) {
        self.data.append(data:data)
    }

    func clear() {
        data.clear()
    }

    func refresh() {
        reloadViewHelper.reloadView()
    }

    var body: some View {

        let drag = DragGesture()
            .onEnded { value in
                if value.startLocation.x > value.location.x + 24 {
                    // left
                    data.rotate(inc:1)
                }
                else if value.startLocation.x < value.location.x - 24 {
                    // right
                    data.rotate(inc:-1)
                }
            }

        let chartdata = data.get()
        
        Chart {
            ForEach(Array(chartdata), id: \.color) { data in
                ForEach(data.data, id: \.sample) { item in
                    LineMark(
                        x: .value("Sample", item.sample),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(by: .value("Metric", data.name))
                }
            }
        }
        .chartForegroundStyleScale(range: chartdata.map { $0.color })
        .chartLegend(.visible)
        .chartXScale(domain: ClosedRange(uncheckedBounds: (lower:data.lowerLimit,upper:data.upperLimit)))
        .padding()
        .onAppear {
            data.clear()
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(drag)
            }
        }
    }
}

class MotionChart {

    var chart = MotionChartView()
    var chartView: UIView?

    var timer: DispatchSourceTimer? = nil {
        willSet {
            timer?.cancel()
        }
    }
    
    init(parent: UIViewController) {
        let chartViewController = UIHostingController(rootView: chart)
        chartView = chartViewController.view

        if let view = chartView {
            view.isHidden = true
            parent.view.addSubview(view)
        }
        parent.addChild(chartViewController)
    }
    
    deinit {
        timer = nil
    }
    
    var view: UIView? {
        return chartView
    }
    
    func show() {
        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
            timer?.schedule(deadline: .now(), repeating: 0.2)
            timer?.setEventHandler { [weak self] in
                if self?.chartView != nil {
                    DispatchQueue.main.async {
                        self?.chart.refresh()
                    }
                }
            }
            timer?.resume()
        }
    }
    
    func hide() {
        timer = nil
        chartView?.isHidden = true
    }
    
    func add(data: CMDeviceMotion) {
        if let view = chartView {
            view.isHidden = false
            chart.append(data:data)
        }
    }
}
