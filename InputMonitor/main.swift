//
//  main.swift
//  InputMonitor
//
//  Created by Gervasio Marchand on 12/30/20.
//

import Foundation
import AVFoundation

func addListenerBlock( listenerBlock: @escaping AudioObjectPropertyListenerBlock, onAudioObjectID: AudioObjectID, selector: AudioObjectPropertySelector) {
    var forPropertyAddress = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    
   if (kAudioHardwareNoError != AudioObjectAddPropertyListenerBlock(onAudioObjectID, &forPropertyAddress, nil, listenerBlock)) {
       print("Error calling: AudioObjectAddPropertyListenerBlock") }
}

addListenerBlock(listenerBlock: defaultInputModified,
                 onAudioObjectID: AudioObjectID(bitPattern: kAudioObjectSystemObject),
                 selector: kAudioHardwarePropertyDefaultInputDevice)

addListenerBlock(listenerBlock: devicesModified,
                 onAudioObjectID: AudioObjectID(bitPattern: kAudioObjectSystemObject),
                 selector: kAudioHardwarePropertyDevices)

func devicesModified (numberAddresses: UInt32, addresses: UnsafePointer<AudioObjectPropertyAddress>) {
    NSAppleScript(source:"tell application \"Keyboard Maestro Engine\" to do script \"Devices changed\"")!.executeAndReturnError(nil)
}

func defaultInputModified (numberAddresses: UInt32, addresses: UnsafePointer<AudioObjectPropertyAddress>) {
   var index: UInt32 = 0
   while index < numberAddresses {
       let address: AudioObjectPropertyAddress = addresses[0]
       switch address.mSelector {
       case kAudioHardwarePropertyDefaultInputDevice:
           usleep(50000)
           updateFile()
       default:
           print("We didn't expect this!")
       }
       index += 1
  }
}

func updateFile () {
    var devicePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var deviceID: AudioObjectID = 0
    var dataSize = UInt32(truncatingIfNeeded: MemoryLayout<AudioDeviceID>.stride)
    let systemObjectID = AudioObjectID(bitPattern: kAudioObjectSystemObject)
    if (kAudioHardwareNoError != AudioObjectGetPropertyData(systemObjectID, &devicePropertyAddress, 0, nil, &dataSize, &deviceID)) {
        print("Could not get the device id")
    }
    
    var name: CFString = "" as CFString
    var propertySize = UInt32(MemoryLayout<CFString>.stride)
    var deviceNamePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    if (kAudioHardwareNoError != AudioObjectGetPropertyData(deviceID, &deviceNamePropertyAddress, 0, nil, &propertySize, &name)) {
        print("Could not get the device name")
    }
    
    let filename = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("activeInputDevice.txt")
    do {
        let nameStr = name as String
        NSAppleScript(source:"tell application \"Keyboard Maestro Engine\" to do script \"Input device changed\" with parameter \"" + nameStr + "\"")!.executeAndReturnError(nil)
        try nameStr.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
    }
}

updateFile()
let sema = DispatchSemaphore(value: 0)
sema.wait()
