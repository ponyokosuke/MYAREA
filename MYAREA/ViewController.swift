//
//  ViewController.swift
//  MYAREA
//
//  Created by 山下幸助 on 2023/09/18.
//

import UIKit
import CoreLocation
import MapKit
import RealmSwift

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet var mapView: MKMapView!
    var locationManager: CLLocationManager!
    @IBOutlet weak var clickZoomin: UIButton!
    @IBOutlet weak var clickZoomout: UIButton!
    @IBOutlet weak var area: UILabel!
    
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var currentPolyline: MKPolyline?
    var resetRouteTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        area.text = "0"
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        
        locationManager.startUpdatingLocation()
        locationManager.requestAlwaysAuthorization()
        
        mapView.showsUserLocation = true
        mapView.delegate = self
        
        setupRouteResetTimer()
    }
    
    @IBAction func clickZoomin(_ sender: Any) {
        print("[DBG]clickZoomin")
        
        // 現在の地図の範囲を取得
        let region = mapView.region
        let newSpan = MKCoordinateSpan(latitudeDelta: region.span.latitudeDelta / 5.0, longitudeDelta: region.span.longitudeDelta / 5.0)
        
        // 新しい範囲をセットして地図を更新
        let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        mapView.setRegion(newRegion, animated: true)
    }
    
    @IBAction func clickZoomout(_ sender: Any) {
        print("[DBG]clickZoomout")
        
        // 現在の地図の範囲を取得
        let region = mapView.region
        let newSpan = MKCoordinateSpan(latitudeDelta: region.span.latitudeDelta * 5.0, longitudeDelta: region.span.longitudeDelta * 5.0)
        
        // 新しい範囲をセットして地図を更新
        let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        mapView.setRegion(newRegion, animated: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations:[CLLocation]) {
        guard let location = locations.last else { return }
        
        let longitude = location.coordinate.longitude
        let latitude = location.coordinate.latitude
        print("[DBG]longitude : \(longitude)")
        print("[DBG]latitude : \(latitude)")
        
        mapView.setCenter(location.coordinate, animated: true)
        
        saveLocationToRealm(longitude: longitude, latitude: latitude)
        checkArea(longitude: longitude, latitude: latitude)
        updateRouteOnMap()
    }
    
    func updateRouteOnMap() {
        if let polyline = currentPolyline {
            mapView.removeOverlay(polyline)
        }
        
        let realm = try! Realm()
        let locations = realm.objects(locationinfo.self)
        
        var coordinates: [CLLocationCoordinate2D] = []
        for location in locations {
            coordinates.append(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
        }
        
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        currentPolyline = polyline
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            let redValue: CGFloat = 140.0 / 255.0
            let greenValue: CGFloat = 86.0 / 255.0
            let blueValue: CGFloat = 194.0 / 255.0
            
            renderer.strokeColor = UIColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
            
            renderer.lineWidth = 6
            return renderer
        } else if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            let customColor = UIColor(red: 140.0/255.0, green: 86.0/255.0, blue: 194.0/255.0, alpha: 0.5)
            renderer.fillColor = customColor

            return renderer
        }
        return MKOverlayRenderer()
    }
    
//    ユーザーロケーションの色の変更
//    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//        // ユーザーロケーションのアノテーションかどうかを確認
//        if annotation is MKUserLocation {
//            let reuseIdentifier = "userLocation"
//            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
//
//            if annotationView == nil {
//                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
//                annotationView?.image = UIImage(systemName: "circle.fill") // SF Symbolsのアイコンを使用
//            } else {
//                annotationView?.annotation = annotation
//            }
//
//            let redValue: CGFloat = 140.0 / 255.0
//            let greenValue: CGFloat = 86.0 / 255.0
//            let blueValue: CGFloat = 194.0 / 255.0
//            annotationView?.tintColor = UIColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
//            return annotationView
//        }
//
//        // 他のアノテーションのカスタマイズはこちらで行う
//        return nil
//    }

    
    func setupRouteResetTimer() {
        let calendar = Calendar.current
        if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date().addingTimeInterval(24*60*60)) {
            let timeInterval = midnight.timeIntervalSince(Date())
            resetRouteTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.resetRoute()
            }
        }
    }
    
    func resetRoute() {
        routeCoordinates.removeAll()
        if let polyline = currentPolyline {
            mapView.removeOverlay(polyline)
        }
        currentPolyline = nil
        setupRouteResetTimer()
    }
    
    func saveLocationToRealm(longitude: Double, latitude: Double) {
        let currentDateTimeString = getCurrentDateTimeString()
        
        let realm = try! Realm()
        
        let newLocation = locationinfo()
        newLocation.datetime = currentDateTimeString
        newLocation.longitude = longitude
        newLocation.latitude = latitude
        
        try! realm.write {
            realm.add(newLocation)
        }
    }
    
    func checkArea(longitude: Double, latitude: Double) {
        let realm = try! Realm()
        let existingLocations = realm.objects(locationinfo.self).filter("longitude = \(longitude) AND latitude = \(latitude)")
        
        if existingLocations.count > 0 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // これは`datetime`のフォーマットに合わせる必要があります。
            
            let now = Date()
            var closestLocation: locationinfo? = nil
            var shortestTimeInterval: TimeInterval = .infinity
            
            for location in existingLocations {
                if let date = dateFormatter.date(from: location.datetime) {
                    let timeInterval = abs(date.timeIntervalSince(now))
                    if timeInterval < shortestTimeInterval {
                        shortestTimeInterval = timeInterval
                        closestLocation = location
                    }
                }
            }
            
            if let closestLocation = closestLocation {
                print("最も近い日時のlocation: \(closestLocation.datetime), 経度: \(closestLocation.longitude), 経度: \(closestLocation.latitude)")
                
                // 地球の半径 (km)
                let r: Double = 6371.0
                
                // 各点のx, y, z座標とその点が何番目のデータであるかを保存する配列
                var coordinatesData: [(x: Double, y: Double, z: Double, index: Int)] = []
                
                var index = 1
                let locationsFromClosestToNow = realm.objects(locationinfo.self).sorted(byKeyPath: "datetime", ascending: true).filter("datetime >= %@", closestLocation.datetime)
                
                for location in locationsFromClosestToNow {
                    let latitudeInRadians = location.latitude * .pi / 180.0
                    let longitudeInRadians = location.longitude * .pi / 180.0
                    
                    let x = r * cos(latitudeInRadians) * cos(longitudeInRadians)
                    let y = r * cos(latitudeInRadians) * sin(longitudeInRadians)
                    let z = r * sin(latitudeInRadians)
                    
                    coordinatesData.append((x: x, y: y, z: z, index: index))
                    index += 1
                }
                
                // 保存処理を追加するならここ。

                for data in coordinatesData {
                    print("位置: \(data.index)番目, x: \(data.x), y: \(data.y), z: \(data.z)")
                }
                
                var totalArea: Double = 0 // 累積するエリア

                for i in 1..<coordinatesData.count - 1 {
                    let A = coordinatesData[0]
                    let B = coordinatesData[i]
                    let C = coordinatesData[i + 1]
                    
                    let AB = (x: B.x - A.x, y: B.y - A.y, z: B.z - A.z)
                    let AC = (x: C.x - A.x, y: C.y - A.y, z: C.z - A.z)
                    
                    let absAB = sqrt(AB.x * AB.x + AB.y * AB.y + AB.z * AB.z)
                    let absAC = sqrt(AC.x * AC.x + AC.y * AC.y + AC.z * AC.z)
                    
                    let dotProduct = AB.x * AC.x + AB.y * AC.y + AB.z * AC.z
                    let crossProductMagnitude = sqrt((AB.y * AC.z - AB.z * AC.y) * (AB.y * AC.z - AB.z * AC.y) +
                                                     (AB.z * AC.x - AB.x * AC.z) * (AB.z * AC.x - AB.x * AC.z) +
                                                     (AB.x * AC.y - AB.y * AC.x) * (AB.x * AC.y - AB.y * AC.x))
                    
                    let angleBetween = asin(crossProductMagnitude / (absAB * absAC))
                    let result = 1/2 * absAB * absAC * sin(angleBetween)
                    
                    totalArea += result // 結果を累積
                    
                    print("位置: \(B.index)番目と\(C.index)番目の間の計算結果: \(result)")
                }
                
                print("全体の面積の合計: \(totalArea)") // 累積した結果を出力
                
                area.text = String(totalArea)
                
                var coordinates: [CLLocationCoordinate2D] = []
                for location in locationsFromClosestToNow {
                    coordinates.append(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                }
                if coordinates.count >= 3 {
                    let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
                    mapView.addOverlay(polygon)
                }
            }

        }
    }
    
    func getCurrentDateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSxxxxx"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: Date())
    }
    
    deinit {
        resetRouteTimer?.invalidate()
    }
}
