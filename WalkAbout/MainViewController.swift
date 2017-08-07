//
//  MainViewController.swift
//  WalkAbout
//
//  Created by Scott Grant on 8/2/17.
//  Copyright © 2017 Scott Grant. All rights reserved.
//
//

import UIKit
import CoreLocation
import MapKit

class MainViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet var mapView: MKMapView!
    @IBOutlet var mapStyleSegControl: UISegmentedControl!
    
    var locationManager:CLLocationManager!
    var currentLocation:CLLocation?
    let locationCheckInterval:TimeInterval = 6 // seconds...
    let headingCheckInterval:TimeInterval = 1.5 // Set this and above value to whatever makes sense for your app...
    var isUpdatingLocation = false
    var isUpdatingHeading = false
    var cancelDispatches = false  // DispatchQueue.global.afterAsync has no cancel option, 
                                  // so we need to add a flag...
    var headingImageView:UIImageView?
    let kNotFirstRun = "NotFirstRunKey"
    
    
    //
    // MARK: View Lifecycle
    //
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        self.mapView.delegate = self
        
        // Add a gesture recognizer
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(MainViewController.receivedLongPressGesture(_:)))
        gesture.minimumPressDuration = 1.0
        self.mapView.addGestureRecognizer(gesture)
        
        // Set up notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MainViewController.applicationWillResignActive(notification:)),
                                               name: .UIApplicationWillResignActive,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MainViewController.applicationDidBecomeActive(notification:)),
                                               name: .UIApplicationDidBecomeActive,
                                               object: nil)
        
        // We're using CLLocationManager for updates to our map...
        // You also have to turn on the Background stuff in the Capabilities of
        // your project, select Location updates as well as set the NSLocation...
        self.locationManager = CLLocationManager()
        if (self.locationManager == nil) {
            self.showError(title: "kFailAlertTitle", message:"kFailInitializationAlertMessage")
            return
        }
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.distanceFilter = 25 // meters
        self.locationManager.headingFilter = 5 // angles before generating updates
        self.locationManager.activityType = .otherNavigation
        
        if UserDefaults.standard.bool(forKey:kNotFirstRun) {
            self.startLocationUpdates()
            self.startHeadingUpdates()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Not our first launch...
        if !UserDefaults.standard.bool(forKey: kNotFirstRun)  {
            let alert = self.createSimpleAlert(title: NSLocalizedString("kIntroductionAlertTitle", comment: ""),
                                               message: NSLocalizedString("kIntroductionAlertMessage", comment: "")) { [weak self] (alertAction) in
                guard let strongSelf = self else {
                    return
                }
                // We hold off starting updates while our alert is on screen on the first
                // run so that it doesn't overlap with the system alerts for permissions
                // for the location services...
                UserDefaults.standard.set(true, forKey: strongSelf.kNotFirstRun)
                strongSelf.startLocationUpdates()
                strongSelf.startHeadingUpdates()
            }
            self.present(alert, animated:true)
        }
    }
    
    // 
    // MARK: Notifications
    //
    
    func applicationWillResignActive(notification:Notification) {
        // Suspend updates during a phone call, etc...
        print("applicationWillResignActive...")
        self.cancelDispatches = true
        self.locationManager.stopUpdatingLocation()
        self.locationManager.stopUpdatingHeading()
    }
    
    func applicationDidBecomeActive(notification:Notification) {
        // Check our state, resume updates...
        print("applicationDidBecomeActive...")
        
        if UserDefaults.standard.bool(forKey: kNotFirstRun) {
            self.cancelDispatches = false
            self.startLocationUpdates()
            self.startHeadingUpdates()
        }
    }
    
    //
    // MARK: Gestures
    //
    
    func receivedLongPressGesture(_ gestureRecognizer : UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let destinationCoordinate = self.mapView.convert(touchPoint, toCoordinateFrom: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = destinationCoordinate
            
            // Remove the old annoation..
            if self.mapView.annotations.count > 1 {
                let alert = UIAlertController(title: NSLocalizedString("kRemovePreviousDestinationTitle", comment: ""),
                                              message: NSLocalizedString("kRemovePreviousDestinationMessage", comment: ""),
                                              preferredStyle: .alert)
                let yesAction = UIAlertAction(title: NSLocalizedString("kYesButtonText", comment: ""), style: .default, handler: { (action) in
                    self.mapView.removeAnnotations(self.mapView.annotations)
                    self.mapView.removeOverlays(self.mapView.overlays)
                    self.mapView.addAnnotation(annotation)
                    self.addDirectionsToMap(destinationAnnotation: annotation)
                })
                alert.addAction(yesAction)
                let cancelAction = UIAlertAction(title: NSLocalizedString("kCancelButtonText", comment: ""), style: .cancel, handler: nil)
                alert.addAction(cancelAction)
                self.present(alert, animated: true)
            } else {
                // Add the new destination...
                self.mapView.addAnnotation(annotation)
                self.addDirectionsToMap(destinationAnnotation: annotation)
            }
        }
    }
    
    // 
    // MARK: Actions
    //
    
    @IBAction func segmentValueChanged(_ sender: Any) {
        guard let segCtrl = sender as? UISegmentedControl,
            segCtrl === self.mapStyleSegControl else {
            return
        }
        
        switch (segCtrl.selectedSegmentIndex) {
            case 0:
                self.mapView.mapType = .standard
                self.mapStyleSegControl.tintColor = UIColor.red
                break
            case 1:
                self.mapView.mapType = .satellite
                self.mapStyleSegControl.tintColor = UIColor.white
                break
            case 2:
                self.mapView.mapType = .hybrid
                self.mapStyleSegControl.tintColor = UIColor.white
                break
            default:
                break
        }
    }
    
    //
    // MARK: Map View
    //
    
    func addDirectionsToMap(destinationAnnotation destAnnotation: MKAnnotation) {
        
        let userAnnotation = self.mapView.userLocation
        let request = MKDirectionsRequest()
        request.transportType = .walking
        request.requestsAlternateRoutes = true
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userAnnotation.coordinate, addressDictionary: nil))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destAnnotation.coordinate, addressDictionary: nil))
        
        let dir = MKDirections(request: request)
        
        // Add our calculated route as an overlay...
        dir.calculate { [weak self] (response, error) in
            guard let directions = response,
                let strongSelf = self else {
                return
            }
            
            if (directions.routes.count > 0) {
                strongSelf.mapView.add(directions.routes[0].polyline)
            }
        }
    }
    
    //
    // MARK: MKMapViewDelegate Methods
    //
    
    
    // Some of the code for adding the header image to the user location annotationView 
    // is code I modified from this example: https://stackoverflow.com/a/40808645
    // Also, because of the design of the image I picked for showing the heading, I adjusted 
    // the anchor point of the image view's layer to position the vertex of the image over 
    // the center of the user location.
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        if views.last?.annotation is MKUserLocation {
            if let _ = self.headingImageView {
                return
            }
            
            if let annotationView = views.last,
                let img = UIImage(named: "userHeading") {
                
                let imgView = UIImageView(image: img)
                imgView.frame = CGRect(x: (annotationView.frame.size.width - img.size.width) / 2,
                                       y: (annotationView.frame.size.height - img.size.height) / 2,
                                       width: img.size.width,
                                       height: img.size.height)
                annotationView.insertSubview(imgView, at: 0)
                imgView.layer.anchorPoint = CGPoint(x:0.5, y:0.95)
                imgView.isHidden = true
                self.headingImageView = imgView
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKPointAnnotation {
            print("point annotation")
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "destinationPin")
            annotationView.animatesDrop = true
            return annotationView
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.lineWidth = 3
            renderer.strokeColor = UIColor.blue
            return renderer
        }
        return MKPolylineRenderer()
    }
    
    //
    // MARK: Location & Heading
    //
    
    func startLocationUpdates() {
        // Reset our update state...
        self.isUpdatingLocation = false
        
        // Always check, the user may have disabled permissions...
        self.locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() &&
            (CLLocationManager.authorizationStatus() != .denied) {
            self.locationManager.requestLocation()
        } else {
            self.showError(title: "kPermissionDeniedTitle", message: "kPermissionDeniedMessage")
        }
    }
    
    func startHeadingUpdates() {
        self.isUpdatingHeading = false
        self.locationManager.startUpdatingHeading()
    }
    
    
    //
    // MARK: CLLocationManagerDelegate Methods
    //
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // You sometimes get multiple updates delivered close together, we only need one.
        if self.isUpdatingLocation {
            return
        }
        self.isUpdatingLocation = true
        
        // Stop the location and heading updates...
        self.locationManager.stopUpdatingLocation()
        
        //
        // Print our last location - some apps may
        // want the old location as well as the latest...
        if let lastLoc = self.currentLocation {
            // This was our last location...
            print("Last location: \(lastLoc)")
        }
        
        // Grab and store the latest location.
        if let loc = locations.last {
            // Update to our latest location.
            print("New location: \(loc)")
            self.currentLocation = loc
        }
        
        // Update our mapView...
        if let curLoc = self.currentLocation {
            let mapCenter = CLLocationCoordinate2D(latitude: curLoc.coordinate.latitude, longitude: curLoc.coordinate.longitude)
            let mapRegion = MKCoordinateRegion(center: mapCenter, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            self.mapView.setRegion(mapRegion, animated: true)
        }
        
        // One way to gain better battery efficiency is to control starting and stopping
        // location updates yourself. Stop updates when you enter the didUpdateLocation method
        // and then resume them after a slight delay, this will reduce accuracy, so it depends upon
        // the type of app. Since our app is for walking our interval won't make much differnece, 
        // we could probably set it for an even longer interval.
        DispatchQueue.main.asyncAfter(deadline: .now() + self.locationCheckInterval) {
            if !self.cancelDispatches {
                self.startLocationUpdates()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if self.isUpdatingHeading {
            return
        }
        self.isUpdatingHeading = true
        self.locationManager.stopUpdatingHeading()
        // Update our mapView...
        if newHeading.headingAccuracy > 0 {
            // Get the appropriate heading...
            let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            print("Updated to heading: \(heading)")
            // Rotate our heading image view to our new heading...
            if let imgView = self.headingImageView {
                imgView.isHidden = false
                imgView.transform = CGAffineTransform(rotationAngle: CGFloat(heading/180 * Double.pi))
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + self.headingCheckInterval) {
            if !self.cancelDispatches {
                self.startHeadingUpdates()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.locationManager.stopUpdatingLocation()
        NSLog("+++ERROR: Location manager failed with error - \(error.localizedDescription)")
        DispatchQueue.main.asyncAfter(deadline: .now() + self.locationCheckInterval) {
            if !self.cancelDispatches {
                self.startLocationUpdates()
            }
        }
    }
    
    // 
    // MARK: Helper Methods
    //
    
    func showError(title: String, message: String) {
        let alert = self.createSimpleAlert(title: NSLocalizedString(title, comment:""),
                                     message: NSLocalizedString(message, comment:""),
                                     completion: nil)
        self.present(alert, animated: true)
    }
    
    func createSimpleAlert(title:String, message:String, completion:((UIAlertAction) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: NSLocalizedString("kOKButtonText", comment:""),
                                   style: .default,
                                   handler: completion)
        alert.addAction(action)
        return alert
    }
}
