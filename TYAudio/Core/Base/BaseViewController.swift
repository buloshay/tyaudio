//
//  BaseViewController.swift
//  TYAudio
//
//  Base View Controller for common functionality and logging
//

import UIKit

class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[Page] \(String(describing: type(of: self))) - viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewWillAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewDidAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewWillDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("[Page] \(String(describing: type(of: self))) - viewDidDisappear")
    }
    
    deinit {
        print("[Page] \(String(describing: type(of: self))) - deinit")
    }
}
