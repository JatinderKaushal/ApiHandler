//
//  DemoFile.swift


import Foundation
import SystemConfiguration
import UIKit
class HitApi {
    
    private init() {}
    static let shared = HitApi()
    
    func sendRequest<T: Decodable>(api: String, parameters: [String: Any]? = nil, showLoader:Bool = true, outputBlock: @escaping (Result<T, Error>) -> ())
    {
        print("hitting:" , BaseUrl + api)
        print("parameters:",parameters ?? ["":""])
      
        if !isConnectedToNetwork(){
            Utility().displayAlert(title: "", message: "You are not connected with internet", control: ["Ok"])
            return
        }
        
        guard let url = URL(string:BaseUrl + api) else {return}
        var request = URLRequest(url: url)
        request.setValue("application/json",forHTTPHeaderField: "Accept")
        
        if let token = UserDefaultController.shared.accessToken {
          print("Token:",token)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
       
        if let parameters = parameters {
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {return}
            request.httpBody = httpBody
            request.httpMethod = "POST"
        }
        if showLoader {
            ProgressLoader.sharedInstance.show(withTitle: "Loading.......")
        }
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            ProgressLoader.sharedInstance.hide()
         
            
            DispatchQueue.main.async {
                
                if let err = error {
                    Utility().showAlert(mesg: err.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    Utility().showAlert(mesg: "Getting Data nil from Server")
                    return
                }
                
                let abc = try? JSONSerialization.jsonObject(with: data, options: [])
                print("Response:",abc as Any)
                
                do {
                    let obj = try JSONDecoder().decode(T.self, from: data)
                    outputBlock(.success(obj))
                   // outputBlock(obj)
                } catch let jsonErr {
                    outputBlock(.failure(jsonErr))
                   // Utility().showAlert(mesg: jsonErr.localizedDescription)
                }
            }
        }.resume()
    }
    
    func sendRequestWithImages<T: Decodable>(api: String, parameters: [String: Any] = [:], video: [String:Data]? = [:], document: [String:Data]? = [:], extensionDocumentType:String? = "", outputBlock: @escaping (Result<T,Error>) -> () ) {
        print("hitting:" , api)
        print("parameters:",parameters)
        if !isConnectedToNetwork(){
            Utility().displayAlert(title: "", message: "You are not connected with internet", control: ["Ok"])
            return
        }
        
        guard let url = URL(string:BaseUrl + api) else {return}
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = UserDefaultController.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = createBody(parameters: parameters, video: video ?? [:],
                                      document: document ?? [:],
                                      boundary: boundary,
                                      extensionDocument: extensionDocumentType ?? "",
                                      mimeType: "image/jpg")
        
        ProgressLoader.sharedInstance.show(withTitle: "Loading.......")

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                
                ProgressLoader.sharedInstance.hide()
                
                if let err = error {
                    Utility().showAlert(mesg: err.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    Utility().showAlert(mesg: "Getting Date nil from Server")
                    return
                }
                
                let abc = try? JSONSerialization.jsonObject(with: data, options: [])
                print(abc as Any)
               
                do {
                    let obj = try JSONDecoder().decode(T.self, from: data)
                    outputBlock(.success(obj))
                   // outputBlock(obj)
                } catch let jsonErr {
                    outputBlock(.failure(jsonErr))
                   // Utility().showAlert(mesg: jsonErr.localizedDescription)
                }
              /*  do {
                    let obj = try JSONDecoder().decode(T.self, from: data)
                    outputBlock(obj)
                } catch let jsonErr {
                    print("Json Err: ",jsonErr)
                    Utility().showAlert(mesg: jsonErr.localizedDescription)
                }*/
            }
        }.resume()
    }
    
    private func createBody(parameters: [String: Any],
                            video:[String:Data],
                            document:[String:Data],
                            boundary: String,
                            extensionDocument:String,
                            mimeType: String) -> Data {
        var body = Data()
        
        let boundaryPrefix = "--\(boundary)\r\n"
        
        
        
        for case let (key, value as String) in parameters{
            body.appendData(boundaryPrefix)
            body.appendData("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendData("\(value)\r\n")
        }
        
        for case let (key, value as Int) in parameters{
            body.appendData(boundaryPrefix)
            body.appendData("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendData("\(value)\r\n")
        }
        
        for case let (key, value as UIImage) in parameters {
            
            body.appendData(boundaryPrefix)
            body.appendData("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(UUID().uuidString).jpg\"\r\n")
            body.appendData("Content-Type: \(mimeType)\r\n\r\n")
            body.append(value.compress_Image())
            body.appendData("\r\n")
            body.appendData("--".appending(boundary.appending("--\r\n")))
        }
        
        for case let (key, value as [UIImage]) in parameters {
            for (ind,image) in value.enumerated()
            {
            body.appendData(boundaryPrefix)
            body.appendData("Content-Disposition: form-data; name=\"\(key)[\(ind)]\"; filename=\"\(UUID().uuidString).jpg\"\r\n")
            body.appendData("Content-Type: \(mimeType)\r\n\r\n")
            body.append(image.compress_Image())
            body.appendData("\r\n")
            body.appendData("--".appending(boundary.appending("--\r\n")))
            }
            }
        
        
        
        for case let (key, value) in video {
            
            body.appendData(boundaryPrefix)
            body.appendData("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(UUID().uuidString).mp4\"\r\n")
            body.appendData("Content-Type: application/octet-stream\r\n\r\n")
            body.append(value)
            body.appendData("\r\n\r\n")
            body.appendData("--".appending(boundary.appending("--")))
        }
        
        for case let (key, value) in document {
      
            
            body.appendData(boundaryPrefix)
            body.appendData("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(UUID().uuidString).\(extensionDocument)\"\r\n")
            body.appendData("Content-Type: text/csv\r\n\r\n")
            body.append(value)
            body.appendData("\r\n\r\n")
            body.appendData("--".appending(boundary.appending("--")))
            
        }
        
        return body
    }
    
    
    //MARK: - Check Internet
    private func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        if(defaultRouteReachability == nil){
            return false
        }
        var flags : SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return (isReachable && !needsConnection)
    }
}

class UserDefaultController {
    
    static let shared = UserDefaultController()
    
    private init() {}
     
    var accessToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "accessToken")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "accessToken")
        }
    }
    
}


  extension Data {
    mutating func appendData(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}

extension UIImage {
    
    func compress_Image() -> Data {
        
        if let imgageData = self.pngData() {
            let jpegSizee: Int = imgageData.count
            let fileSizeKb = Double(jpegSizee) / 1024.0
            
            if fileSizeKb < 700 {
                //Reduce the image size
                return self.jpegData(compressionQuality: 0.8 ) ?? Data()
            }else if fileSizeKb < 1000 {
                return self.jpegData(compressionQuality: 0.7 ) ?? Data()
            }else if fileSizeKb < 2000 {
                return self.jpegData(compressionQuality: 0.6) ?? Data()
            }else if fileSizeKb < 3000 {
                return self.jpegData(compressionQuality: 0.5) ?? Data()
            }else if fileSizeKb < 4000 {
                return self.jpegData(compressionQuality: 0.4) ?? Data()
            }else if fileSizeKb < 5000 {
                return self.jpegData(compressionQuality: 0.3) ?? Data()
            }else if fileSizeKb < 6000 {
                return self.jpegData(compressionQuality: 0.25) ?? Data()
            }else if fileSizeKb < 10000 {
                return self.jpegData(compressionQuality: 0.2) ?? Data()
            }else {
                return self.jpegData(compressionQuality: 0.15) ?? Data()
            }
        }
        return Data()
    }
}


class Utility : NSObject{

    let topController = UIApplication.topMostViewController()
    
    func pushViewControl(ViewControl:String){
           let storyboard = UIStoryboard(name: "Main", bundle: nil)
           let controller = storyboard.instantiateViewController(withIdentifier: ViewControl)
         topController?.navigationController?.pushViewController(controller, animated: true)
       }
    func showAlert(mesg:String) {
        displayAlert(message: mesg.uppercased(), control: ["Ok"])
    }
func displayAlert(title:String = "" , message:String, control:[String]){
    
    let alertController = UIAlertController(title: title, message: message , preferredStyle: .alert)
    
    for str in control{
        
        let alertAction = UIAlertAction(title: str, style: .default, handler: nil)
        
        alertController.addAction(alertAction)
    }
    DispatchQueue.main.async {
        
    
        self.topController?.present(alertController, animated: true, completion: nil)
    }
}
    
    
    
    
}



extension UIViewController {
    func topMostViewController() -> UIViewController {
        if self.presentedViewController == nil {
            return self
        }
        if let navigation = self.presentedViewController as? UINavigationController {
            return navigation.visibleViewController!.topMostViewController()
        }
        if let tab = self.presentedViewController as? UITabBarController {
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            return tab.topMostViewController()
        }
        return self.presentedViewController!.topMostViewController()
    }
}

extension UIApplication {
   class func topMostViewController() -> UIViewController? {
    
            
        return UIWindow.key?.rootViewController?.topMostViewController()
    }
}

extension UIWindow {
    static var key: UIWindow? {
        if #available(iOS 13, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}
//MARK:----------------------------------
/*class LoginViewModel {
    
    func LoginSignup(url:String,param:[String:Any]? = nil,completion:@escaping(Bool,String)->()){
    
        HitApi.shared.sendRequest(api: url, parameters: param) { (result:Result<LoginSignUpModal,Error>) in
            switch result{
            case .success(let model):
                if model.token != ""
                {
              //      UserDefaultController.shared.accessToken = model.data?.token
                    completion(true, "")
                }else{
                    completion(false, model.token ?? "Server Error!")
                }
                break;
                
            case.failure(let error):
                completion(false,  error.localizedDescription)
                break;
            }
        }
    }
}



struct LoginSignUpModal: Codable {
//    let completed: Bool?
    let token: String?
  //  let data: DataClass?
}
// MARK: - DataClass
struct DataClass: Codable {
    var token,email : String?
}
func Login()  {
  /*  if txtUsername.text?.isEmpty ?? true {
        Utility().showAlert(mesg: "Please enter name")
     }else if txtPassWord.text?.isEmpty ?? true {
      Utility().showAlert(mesg: "Please enter password")
     }
    else
     {*/
objSignup.LoginSignup(url:LoginUrl,param: ["email" : "test@yopmail.com","password" : "123234"]){ status, msg in
        if status
        {
            print("Login")
         //   Utility().pushViewControl(ViewControl: "")
        }
        else
        {
            Utility().showAlert(mesg: msg)
        }
        
    }
    // }
    
}
*/



let SIZE_CONSTANT = 375.0
let screenSize: CGRect = UIScreen.main.bounds

class ProgressLoader {
    static let sharedInstance = ProgressLoader()
    
    var container = UIView(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
    var subContainer = UIView(frame: CGRect(x: 0, y: 0, width: screenSize.width / 3.0, height: screenSize.width / 4.0))
    var textLabel = UILabel()
    var activityIndicatorView = UIActivityIndicatorView()
    var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    init() {
        //Main Container
        container.backgroundColor = UIColor.clear
        
        //Sub Container
        subContainer.layer.cornerRadius = 5.0
        subContainer.layer.masksToBounds = true
        subContainer.backgroundColor = UIColor.clear
        
        //Activity Indicator
        activityIndicatorView.hidesWhenStopped = true
        
        //Text Label
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0
        textLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        textLabel.textColor = UIColor.darkGray
        
        //Blur Effect
        //always fill the view
        blurEffectView.frame = container.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    }
    
    //MARK:- Show Loader
    func show(withTitle title: String?) {
        
        container.backgroundColor = UIColor.clear
        subContainer.backgroundColor = UIColor.systemGray5
        subContainer.center = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        container.addSubview(subContainer)
        

        activityIndicatorView.style = UIActivityIndicatorView.Style.large
        activityIndicatorView.color = .darkGray
        activityIndicatorView.frame = CGRect(x: 0, y: 10, width: subContainer.bounds.width, height: subContainer.bounds.height / 3.0)
        activityIndicatorView.center = CGPoint(x: activityIndicatorView.center.x, y: activityIndicatorView.center.y)
        subContainer.addSubview(activityIndicatorView)
        
        let height: CGFloat = subContainer.bounds.height - activityIndicatorView.bounds.height - 10.0
        textLabel.frame = CGRect(x: 5, y: 10 + activityIndicatorView.bounds.height, width: subContainer.bounds.width - 10.0, height: height - 5.0)
        textLabel.text = title
        subContainer.addSubview(textLabel)
        
      textLabel.textColor = .darkGray
        
        activityIndicatorView.startAnimating()
        if let window = getKeyWindow() {
            window.addSubview(container)
        }
        
        container.alpha = 0.0
        UIView.animate(withDuration: 0.5, animations: {
            self.container.alpha = 1.0
        })
    }
 // MARK:- Hide Loader
    func hide(afterFiveSec:Bool? = false) {
        if afterFiveSec == true{
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIView.animate(withDuration: 0.5, animations: {
                    self.container.alpha = 0.0
                }) { finished in
                    self.activityIndicatorView.stopAnimating()
                    
                    self.activityIndicatorView.removeFromSuperview()
                    self.textLabel.removeFromSuperview()
                    self.subContainer.removeFromSuperview()
                    self.blurEffectView.removeFromSuperview()
                    self.container.removeFromSuperview()
                }
            }
        }else{
            UIView.animate(withDuration: 0.5, animations: {
                self.container.alpha = 0.0
            }) { finished in
                self.activityIndicatorView.stopAnimating()
                
                self.activityIndicatorView.removeFromSuperview()
                self.textLabel.removeFromSuperview()
                self.subContainer.removeFromSuperview()
                self.blurEffectView.removeFromSuperview()
                self.container.removeFromSuperview()
            }
        }
     }
    
    //MARK:- Loader Status Update
    func updateProgressTitle(_ title: String?) {
        textLabel.text = title
    }
    
    private func getKeyWindow() -> UIWindow? {
        let window = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        return window
    }
    
}
