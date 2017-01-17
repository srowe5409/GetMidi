//
//  ViewController.swift
//  GetMidi
//
//  Created by Stephen Rowe on 1/13/17.
//  Copyright © 2017 Stephen Rowe. All rights reserved.
//

import UIKit
import CoreMIDI
import AudioToolbox
//import AVFoundation
//import AVKit
import AudioKit

var outPort:MIDIPortRef = 0;
var midReceiveText:Array = [""]
var sampler = AKMIDISampler()

var points = Array<CGPoint>()


var font = ["JR__pad", "JR_analog", "JR_bells", "JR_church",
            "JR_backgr", "JR_Bignoise", "JR_bulles2", "JR_Cosmic",
            "JR_effect2k", "JR_effects2", "JR_elepiano", "JR_Ethnic trumpets",
            "JR_Ethnic voice", "JR_flute electronique", "JR_galboro", "JR_ligeti",
            "JR_loops2k", "JR_male", "JR_mood", "JR_noises2", "JR_organ", "JR_pad_cloches","JR_pad_voice", "JR_PADstring", "JR_popol", "JR_sax", "JR_String2", "JR_SynthString1",
            "JR_SynthString2", "JR_vibra", "JR_voice2", "pads"
]
class ViewController: UIViewController , UIPickerViewDelegate, UIPickerViewDataSource{
    
    @IBOutlet var preset: UISegmentedControl!
    var presetNum:UInt8 = 0
    @IBAction func presetChanged(_ sender: Any) {
        presetNum = UInt8(preset.selectedSegmentIndex)
        let row = fontSelector.selectedRow(inComponent: 0)
        sampler.loadMelodicSoundFont(font[row], preset: Int(presetNum))
    }
    @IBOutlet var plotView: UIView!
    
    @IBOutlet var volume: UISlider!
    @IBOutlet var fontSelector: UIPickerView!
    
    @IBAction func volChanged(_ sender: Any) {
        sampler.volume = Double(volume.value)
        print(volume.value)
    }
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return font.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return font[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        sampler.loadMelodicSoundFont(font[row], preset: Int(presetNum))
    }
    
    
    
    
    
    
    var midiClient: MIDIClientRef = 0;
    var midi:AKMIDIInstrument = AKMIDIInstrument()
    var inPort:MIDIPortRef = 0
    var dest:MIDIEndpointRef = 0
    var packet1:MIDIPacket = MIDIPacket()
    var musicPlayer:MusicPlayer!
    var mandolin = AKMandolin()
    var aengine = AVAudioEngine()
    var plot: AKNodeOutputPlot!
    let mic = AKMicrophone()
    
    
    var oscillator = AKOscillator()
    
    
    @IBOutlet var displayText: UITextView!
    @IBAction func refresh(_ sender: Any) {
        let destinationNames = getDestinationNames()
        for (index,destName) in destinationNames.enumerated()
        {
            print("Destination #\(index): \(destName)")
            displayText.text = "Destination #\(index): \(destName)"
        }
        let sources = getSourceNames()
        for (index,source) in sources.enumerated()
        {
            print("Source #\(index): \(source)")
            displayText.text = "Source #\(index): \(source)"
        }
        
        
        packet1 = MIDIPacket();
        packet1.timeStamp = 0;
        packet1.length = 3;
        packet1.data.0 = 0x90 + 0; // Note On event channel 1
        packet1.data.1 = 0x3C; // Note C3
        packet1.data.2 = 100; // Velocity
         var packetList:MIDIPacketList = MIDIPacketList(numPackets: 1, packet: packet1);
        let destNum = 1
        
        dest = MIDIGetDestination(destNum);
        
        MIDISend(outPort, dest, &packetList);
        AKSettings.audioInputEnabled = true
        
        tracker = AKFrequencyTracker.init(mic)
        silence = AKBooster(tracker, gain: 0)
        plot = AKNodeOutputPlot(mic, frame: plotView.bounds)
        plot.plotType = .buffer
        
        plot.shouldFill = false
        plot.shouldMirror = false
        plot.color = #colorLiteral(red: 0, green: 0.9768045545, blue: 0, alpha: 1)
        plot.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        
        plot.autoresizingMask = .flexibleWidth
        plotView.addSubview(plot)
       
       
        
        
    }
    
    var tracker: AKFrequencyTracker!
    var silence: AKBooster!
    var array = [UInt8(10),UInt8(10)]
    
    
    
    func enableNetwork() ->MIDINetworkSession{
        let session = MIDINetworkSession.default()
        session.isEnabled = true
        session.connectionPolicy = .anyone
        print("net session enabled \(MIDINetworkSession.default().isEnabled)")
        return session
    }
    override func viewDidAppear(_ animated: Bool) {
        
    }
    @IBAction func ampChanged(_ sender: Any) {
        sampler.amplitude = Double(amp.value)
    }
    func runTimerCode(){
        
        for str in midReceiveText{
            displayText.insertText(str + "\n")
           
        }
        midReceiveText.removeAll()
        
        displayText.contentOffset.y = displayText.contentSize.height - displayText.frame.height //scroll to bottom
        
        
    }
    
    @IBOutlet var amp: UISlider!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        
        
        
        fontSelector.delegate = self
        fontSelector.dataSource = self
        amp.maximumValue = 2
        amp.minimumValue = -10
        amp.value = 0
        volume.minimumValue = 0
        volume.maximumValue = 1.5
        volume.value = 1.5
        
        
        
        AudioKit.output = sampler
        
        
        sampler.loadMelodicSoundFont("JR_voice2", preset: 0)
        
        
        AudioKit.start()
        
        oscillator.amplitude = random(0.5, 1)
        oscillator.frequency = random(220, 880)
        //oscillator.start()
        
        
        MIDIClientCreate("MidiTestClient" as CFString, nil, nil, &midiClient);
        
        MIDIOutputPortCreate(midiClient, "MidiTest_OutPort" as CFString, &outPort);
        
        
        midi.avAudioNode = mandolin.avAudioNode
        
        Timer.scheduledTimer(timeInterval: 0.0001, target: self, selector: #selector(runTimerCode), userInfo: nil, repeats: true)
        
        
        let destNames = getDestinationNames();
        
        print("Number of MIDI Destinations: \(destNames.count)");
        for destName in destNames
        {
            print("  Destination: \(destName)");
        }
        
        let sourceNames = getSourceNames();
        
        print("\nNumber of MIDI Sources: \(sourceNames.count)");
        for sourceName in sourceNames
        {
            print("  Source: \(sourceName)");
        }
        
        
        
        
        packet1 = MIDIPacket();
        packet1.timeStamp = 0;
        packet1.length = 3;
        packet1.data.0 = 0x90 + 0; // Note On event channel 1
        packet1.data.1 = 0x3C; // Note C3
        packet1.data.2 = 100; // Velocity
        
       
        
        let destinationNames = getDestinationNames()
        for (index,destName) in destinationNames.enumerated()
        {
            print("Destination #\(index): \(destName)")
        }
        
        
        
        var src:MIDIEndpointRef = MIDIGetSource(0)
        
        
        MIDIInputPortCreate(midiClient, "MidiTest_InPort" as CFString, MyMIDIReadProc, nil, &inPort)
        
        MIDIPortConnectSource(inPort, src, &src)
        sampler.enableMIDI(midiClient, name: "AKMIDISampler")
        

    }


}




func getDisplayName(_ obj: MIDIObjectRef) -> String
{
    var param: Unmanaged<CFString>?
    var name: String = "Error"
    
    let err: OSStatus = MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &param)
    if err == OSStatus(noErr)
    {
        name =  param!.takeRetainedValue() as String
    }
    
    return name
}

func getDestinationNames() -> [String]
{
    var names:[String] = [];
    
    let count: Int = MIDIGetNumberOfDestinations();
    for i in 0..<count {
        let endpoint:MIDIEndpointRef = MIDIGetDestination(i);
        
        if (endpoint != 0)
        {
            names.append(getDisplayName(endpoint));
        }
    }
    return names;
}

func getSourceNames() -> [String]
{
    var names:[String] = [];
    
    let count: Int = MIDIGetNumberOfSources();
    for i in 0..<count {
        let endpoint:MIDIEndpointRef = MIDIGetSource(i);
        if (endpoint != 0)
        {
            names.append(getDisplayName(endpoint));
        }
    }
    return names;
}

func MyMIDIReadProc(pktList: UnsafePointer<MIDIPacketList>,
                    readProcRefCon: UnsafeMutableRawPointer?, srcConnRefCon: UnsafeMutableRawPointer?) -> Void
{
   
    var packetList:MIDIPacketList = pktList.pointee
    let srcRef:MIDIEndpointRef = srcConnRefCon!.load(as: MIDIEndpointRef.self)
    
    //print("MIDI Received From Source: \(getDisplayName(srcRef))")
    
    var packet:MIDIPacket = packetList.packet
    for _ in 1...packetList.numPackets
    {
        let bytes = Mirror(reflecting: packet.data).children
        var dumpStr = ""
        
        // bytes mirror contains all the zero values in the ridiulous packet data tuple
        // so use the packet length to iterate.
        var i = packet.length
        for (_, attr) in bytes.enumerated()
        {
            dumpStr += String(format:"%d ", attr.value as! UInt8)
            i -= 1
            if (i <= 0)
            {
                break
            }
        }
        print(dumpStr)
        if packet.data.0 == 0xf8{
            //clockM = packet.timeStamp
            //if isRecording { clockR += 1 }
            //if isPlaying { return }
        }
        if (packet.data.0 >= 0x80) && (packet.data.0 <= 0x9f){
            
            //arrayMidiIn.updateValue(dumpStr, forKey: clockM)
            //if isRecording {
            //    arrayMidiSave.updateValue(dumpStr, forKey: clockM)
            //}
            sampler.play(noteNumber: MIDINoteNumber(packet.data.1), velocity: MIDIVelocity(packet.data.2), channel: 1)
            
        }
        
        var packet1:MIDIPacket = MIDIPacket()
        var packetList:MIDIPacketList = MIDIPacketList(numPackets: 1, packet: packet1);
         var dest = MIDIGetDestination(0);
        
        if (packet.data.0 & 0xf0) == 0x90 || (packet.data.0 & 0xf0) == 0x80{
            
            packet1 = MIDIPacket();
            packet1.timeStamp = packet.timeStamp;
            packet1.length = 3;
            packet1.data.0 = packet.data.0; // Note On event channel 1
            packet1.data.1 = packet.data.1; // Note C3
            packet1.data.2 = packet.data.2; // Velocity
            packetList = MIDIPacketList(numPackets: 1, packet: packet1);
            
            
            MIDISend(outPort, dest, &packetList);
            
            print(dumpStr)
            midReceiveText.append(dumpStr)
        }
        packet = MIDIPacketNext(&packet).pointee
    }
}



