//
//  ViewController.swift
//
//  Created by Jacob Jarecki on 11/2/14.
//  Copyright (c) 2014 Jacob Jarecki. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    // Usher App Constants
    let screenWidth = UIScreen.mainScreen().bounds.width
    let screenHeight = UIScreen.mainScreen().bounds.height

    let MAX_FANS = 9
    let MAX_FAN_GROUPS = 1
    let DEBUG_VIEW_MAX_LINES = 8
    
    // UI Elements Added Programmatically
    var scanSwitch : UISwitch!
    //var ticketNumberLabel :UILabel!
    var appTitleLabel :UILabel!
    var collectionView : UICollectionView!
    var scanSwitchLabel : UILabel!
    var activityIndicator: UIActivityIndicatorView!

    // Modifiable Class Elements
    var debugTextView : UITextView!
    var ticketID : String = ""
    var eventName : String = ""
    var nextCell : Int = 0
    var debugCount : Int = 0
    var centralManager : CBCentralManager!
    var peripheralUser : [CBPeripheral!] = []
    var availableColors : [Int] = [0,1,2,3,4,5,6,7,8]
    
    //// UI Functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Bluetooth
        centralManager = CBCentralManager(delegate: self, queue:nil)

        // Initialize Collection View
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: CGFloat(screenHeight/5), left: CGFloat(screenWidth/20), bottom: CGFloat(0), right: CGFloat(screenWidth/20))
        layout.itemSize = CGSize(width: screenWidth/4, height: screenWidth/4)
        collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.registerClass(CollectionViewCell.self, forCellWithReuseIdentifier: "CollectionViewCell")
        collectionView.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(collectionView)

        // Add Title Label
        appTitleLabel = UILabel()
        appTitleLabel.frame = CGRectMake(0, screenHeight/20, screenWidth, screenHeight/10)
        appTitleLabel.textAlignment = NSTextAlignment.Center
        appTitleLabel.numberOfLines = 1
        appTitleLabel.font = UIFont(name: "Helvetica", size: 40.0)
        appTitleLabel.text = "Ticketmaster"
        self.view.addSubview(appTitleLabel)

        if (DEBUG){
            // Add debugging log (good for on-phone testing)
            debugTextView = UITextView()
            debugTextView.frame = CGRectMake(0, screenHeight/2 + screenHeight/4, screenWidth, screenHeight/2)
            debugTextView.text = "Debug Log:"
            self.view.addSubview(debugTextView)
        }

        //Add label for scan switch
        scanSwitchLabel = UILabel()
        scanSwitchLabel.frame = CGRectMake(0, screenHeight/2 + (20*screenHeight/64), screenWidth, screenHeight/10)
        scanSwitchLabel.textAlignment = NSTextAlignment.Center
        scanSwitchLabel.numberOfLines = 1
        scanSwitchLabel.font = UIFont(name: "Helvetica", size: 14.0)
        scanSwitchLabel.text = "Start Scan"
        self.view.addSubview(scanSwitchLabel)

        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray) 
        activityIndicator.frame = CGRectMake(screenWidth/2, screenHeight/2 + (13*screenHeight/32), 0, 0)
        activityIndicator.transform = CGAffineTransformMakeScale(2, 2)
        activityIndicator.stopAnimating()
        self.view.addSubview(activityIndicator)

        // Add scan switch
        scanSwitch = UISwitch()
        scanSwitch.frame = CGRectMake(screenWidth/2 - (scanSwitch.frame.size.width/2), screenHeight/2 + (20.5*screenHeight/64), 0, 0)
        scanSwitch.setOn(false, animated: false);
        scanSwitch.addTarget(self, action: "startScan:", forControlEvents: .ValueChanged);
        self.view.addSubview(scanSwitch);

    }
    
    override func didReceiveMemoryWarning(){
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startScan(sender: AnyObject){
        if (scanSwitch.on){
            let services = [TM_FAN_CLIENT_COMMS_SERVICE]
            centralManager.scanForPeripheralsWithServices(services, options: nil)
            //centralManager.scanForPeripheralsWithServices(nil, options: nil)
            scanSwitchLabel.text = "Stop Scan"
            activityIndicator.startAnimating()
            debugPrint("Scan for peripherals started")
        }
        else{
            centralManager.stopScan()
            scanSwitchLabel.text = "Start Scan"
            activityIndicator.stopAnimating()
            debugPrint("Scan for peripherals stopped")
        }
    }

    func debugPrint(text : String){
        if (DEBUG){
            if (debugCount > DEBUG_VIEW_MAX_LINES){
                debugTextView.text = "Debug Log:" + "\n>  " + text
                debugCount = 0
            }
            else {
                debugTextView.text = debugTextView.text! + "\n>  " + text
                debugCount++
            }
        }
        println(text)
    }
    
    //// Collection View Delegate
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("CollectionViewCell", forIndexPath: indexPath) as CollectionViewCell
        cell.backgroundColor = UIColor.lightGrayColor()
        cell.textLabel?.text = "\(cell.eventName)"
        return cell
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return MAX_FAN_GROUPS
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return MAX_FANS
    }

    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath){
        var cell = collectionView.cellForItemAtIndexPath(indexPath) as CollectionViewCell
        let alert = UIAlertController(title: "Validate Ticket?", message: "Are you sure you want to validate ticket number: \(cell.ticketID) for \(cell.eventName)?", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Validate", style: UIAlertActionStyle.Default, handler: {(action: UIAlertAction!) in self.validateTicket(cell)}))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        presentViewController(alert, animated: true, completion: nil)

        debugPrint("Selected: \(cell.ticketID)");
    }
    
    func validateTicket(cell: CollectionViewCell){
        if (cell.peripheral != nil){
            if (cell.recievedValidatedColor){
                cell.peripheral!.writeValue(stringToData(VALIDATE_STRING), forCharacteristic: cell.ticketValidatedCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
            }
        }
    }
    
    //// CBDelegateManager Functions
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        if (nextCell < MAX_FANS){
            for peripherals in peripheralUser{
                if(peripheral.identifier == peripherals.identifier){
                    return
                }
            }
            peripheralUser.append(peripheral)
            println(peripheral)
            println(advertisementData)
            centralManager.delegate = self
            debugPrint("Discovered peripheral")
            centralManager.connectPeripheral(peripheralUser[nextCell], options: nil)
            debugPrint("Tried to connect")
            
        }
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        println("Failed to connect")
    }
    

    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println(peripheral)
        peripheralUser[nextCell].delegate = self
        debugPrint("Connected to discovered peripheral: \(peripheralUser[nextCell].name)")
        if (nextCell < MAX_FANS){
            var indexPath = NSIndexPath(forRow: nextCell, inSection: 0)
            var cell = collectionView.cellForItemAtIndexPath(indexPath) as CollectionViewCell
            cell.peripheral = peripheralUser[nextCell]
            cell.cellIndex = nextCell
            //cell.colorID = getNextColorID()
            var random = Int(arc4random_uniform(UInt32(availableColors.count)))
            cell.colorID = availableColors[random]
            availableColors.removeAtIndex(random)
            cell.backgroundColor = getColor(cell.colorID)
            nextCell++
            peripheral.discoverServices([TM_FAN_CLIENT_COMMS_SERVICE])
        }
    }

    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        debugPrint("Connection failed")
        var cell = getCell(peripheral)!
        removePeripheral(cell.cellIndex)
        centralManager.stopScan()
        centralManager.scanForPeripheralsWithServices([TM_FAN_CLIENT_COMMS_SERVICE], options: nil)
    }

    func removePeripheral(index: Int){
        var curPath = NSIndexPath(forRow: index, inSection: 0)
        var cell = collectionView.cellForItemAtIndexPath(curPath) as CollectionViewCell
        availableColors.append(cell.colorID)
        debugPrint("Removing peripheral: " + cell.ticketID)
        reuseColorID(cell.colorID)
        cell.resetCell()
        nextCell--

        peripheralUser.removeAtIndex(index)
        // Shift other peripherals up
        for i in index...MAX_FANS-1 {
            var curPath = NSIndexPath(forRow: i, inSection: 0)
            var nextPath = NSIndexPath(forRow: i+1, inSection: 0)
            if (i != MAX_FANS-1){
                var cell = collectionView.cellForItemAtIndexPath(curPath) as CollectionViewCell
                var adjCell = collectionView.cellForItemAtIndexPath(nextPath) as CollectionViewCell
                cell.copyCell(adjCell)
            }
        }
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        switch centralManager.state {
        case .PoweredOff:
            debugPrint("Bluetooth is powered off")
            break
        case .PoweredOn:
            debugPrint("Bluetooth is powered on")
            break
        case .Resetting:
            debugPrint("Bluetooth is currently resetting")
            break
        case .Unauthorized:
            debugPrint("Bluetooth access is unauthorized")
            break
        case .Unknown:
            debugPrint("Bluetooth status is unknown")
            break
        case .Unsupported:
            debugPrint("Bluetooth is not supported on this device")
            break
        default:
            debugPrint("Device is a potato")
            break
        }
    }

    func getCell(peripheral: CBPeripheral!) -> CollectionViewCell? {
        for i in 0...MAX_FANS-1 {
            var curPath = NSIndexPath(forRow: i, inSection: 0)
            var cell = collectionView.cellForItemAtIndexPath(curPath) as CollectionViewCell
            if (cell.peripheral!.identifier == peripheral!.identifier){
                return cell
            }
        }
        return nil
    }

    func getNextColorID() -> Int{
        return availableColors.removeAtIndex(0)
    }

    func reuseColorID(color : Int){
        return availableColors.insert(color, atIndex: 0)
    }

    func validate(eventName : String, ticketID : String) -> Bool {
        return true
    }

    //// CBPeripheralDelegate Functions
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        debugPrint("Services found!")
        for service in peripheral.services {
            peripheral.discoverCharacteristics([TM_FAN_CLIENT_EVENT_NAME_CHARACTERISTIC, TM_FAN_CLIENT_TICKET_ID_CHARACTERISTIC, TM_FAN_CLIENT_VALIDATION_COLOR_CHARACTERISTIC, TM_FAN_CLIENT_TICKET_VALIDATED_CHARACTERISTIC], forService: service as CBService)
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        for characteristic in service.characteristics {
            var downcastCharacteristic = characteristic as CBCharacteristic
            println(downcastCharacteristic)
            peripheral.readValueForCharacteristic(characteristic as CBCharacteristic)
            var cell : CollectionViewCell = getCell(peripheral)!
            if(downcastCharacteristic.UUID == TM_FAN_CLIENT_VALIDATION_COLOR_CHARACTERISTIC){
                peripheral.writeValue(stringToData(String(cell.colorID)), forCharacteristic: downcastCharacteristic, type: CBCharacteristicWriteType.WithResponse)
            }
            if(downcastCharacteristic.UUID == TM_FAN_CLIENT_TICKET_VALIDATED_CHARACTERISTIC){
                cell.ticketValidatedCharacteristic = downcastCharacteristic
            }
        }
    }

    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        var cell : CollectionViewCell = getCell(peripheral)!
        var charName : String = ""
        switch characteristic.UUID {
            case TM_FAN_CLIENT_VALIDATION_COLOR_CHARACTERISTIC:
                charName = "VALIDATION_COLOR"
                break
            case TM_FAN_CLIENT_TICKET_VALIDATED_CHARACTERISTIC:
                charName = "TICKET_VALIDATED"
                break
            default:
                break
        }

        if (error != nil){
            debugPrint("Failed to write: " + charName)
            // TODO: try again?
        }
        else {
            debugPrint("Succesful write of: " + charName)

            if (charName == "TICKET_VALIDATED"){
                removePeripheral(cell.cellIndex)
                centralManager.cancelPeripheralConnection(peripheral)
                centralManager.stopScan()
                centralManager.scanForPeripheralsWithServices([TM_FAN_CLIENT_COMMS_SERVICE], options: nil)
            }
            else if (charName == "VALIDATION_COLOR"){
                cell.recievedValidatedColor = true
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!){
        var cell : CollectionViewCell = getCell(peripheral)!
        if characteristic.properties == CBCharacteristicProperties.Read {
            var dataString = dataToString(characteristic.value)
            switch characteristic.UUID {
                case TM_FAN_CLIENT_EVENT_NAME_CHARACTERISTIC:
                    debugPrint("Recieved CLIENT_EVENT_NAME" + dataString)
                    cell.eventName = dataString
                    self.eventName = dataString
                    break
                case TM_FAN_CLIENT_TICKET_ID_CHARACTERISTIC:
                    debugPrint("Recieved CLIENT_TICKET_ID" + dataString)
                    cell.ticketID = dataString
                    self.ticketID = dataString
                    break
                default:
                    break
            }
        }
        
    }
}

