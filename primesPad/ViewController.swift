//
//  ViewController.swift
//  primesPad
//
//  Created by Kyle Mccarthy on 2/26/17.
//  Copyright © 2017 Kyle Mccarthy. All rights reserved.
//

import UIKit
import RtSwift

class SinOsc {
    var phase: Float = 0
    var freq: Float = 60
    var gain: Float = 1
    
    func tick() -> Float {
        // calculate sample
        let samp = sinf(phase*2*Float(M_PI))*gain
        
        // update phase
        phase += freq/Float(RtSwift.sampleRate)
        if phase > 1 {
            phase -= 1
        }
        
        return samp*gain
    }
}

class SawOsc {
    var phase: Float = 0
    var freq: Float = 60
    var gain: Float = 1
    
    func tick() -> Float {
        // calculate sample
        let samp = 1-2*phase
        
        // update phase
        phase += freq/Float(RtSwift.sampleRate)
        if phase > 1 {
            phase -= 1
        }
        
        return samp*gain
    }
}

class SquareOsc {
    var phase: Float = 0
    var freq: Float = 60
    var gain: Float = 1
    
    func tick() -> Float {
        // calculate sample
        var samp: Float = 0.0
        if phase < 0.5 {
            samp = 1
        }
        else {
            samp = -1
        }
        
        // update phase
        phase += freq/Float(RtSwift.sampleRate)
        if phase > 1 {
            phase -= 1
        }
        
        return samp*gain
    }
}

class Envelope {
    
    var duration: Float // in seconds
    var value: Float // actual value of envelope right now
    
    enum State {
        case KEY_ON
        case KEY_OFF
    }
    
    var state = State.KEY_OFF
    
    // constructor
    init(duration: Float = 0.1) {
        self.duration = duration
        value = 0
    }
    
    func tick() -> Float {
        // should go from 0 to 1 in N samples
        let N = duration*Float(RtSwift.sampleRate)
        
        // if we are in the ON state
        if state == State.KEY_ON {
            // count up to 1
            if value < 1 {
                value += 1/N
            }
            
            // ensure we dont shoot past 1
            if value > 1 {
                value = 1
            }
        }
        else if state == State.KEY_OFF {
            // count down to 0
            if value > 0 {
                value -= 1/N
            }
            
            // ensure we dont shoot past 0
            if value < 0 {
                value = 0
            }
        }
        
        return value
    }
    
    func keyOn() {
        // turn envelope on
        state = State.KEY_ON
    }
    
    func keyOff() {
        // turn envelope off
        state = State.KEY_OFF
    }
    
}

class ADSR {
    
    var attack: Float, decay: Float, sustain: Float, release: Float
    var value: Float
    
    enum State {
        case OFF
        case ATTACK
        case DECAY
        case SUSTAIN
        case RELEASE
    }
    
    var state = State.OFF
    
    init(attack: Float = 0.1, decay: Float = 0.1,
         sustain: Float = 0.1, release: Float = 0.1) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.value = 0
    }
    
    func tick() -> Float {
        if state == State.ATTACK {
            // count up 0 to 1 over attack*Float(RtSwift.sampleRate) samples
            value += 0.8/(attack*Float(RtSwift.sampleRate))
            if value >= 0.8 {
                value = 0.8
                state = State.DECAY
            }
        }
        else if state == State.DECAY {
            // count down 1 to sustain over decay*Float(RtSwift.sampleRate) samples
            value -= (1-sustain)/(decay*Float(RtSwift.sampleRate))
            if value <= sustain {
                value = sustain
                state = State.SUSTAIN
            }
        }
        else if state == State.SUSTAIN {
            // do nothing
        }
        else if state == State.RELEASE {
            // count down sustain to 0 over release*Float(RtSwift.sampleRate) samples
            value -= sustain/(release*Float(RtSwift.sampleRate))
            if value <= 0 {
                value = 0
                state = State.OFF
            }
        }
        
        return value
    }
    
    func keyOn() {
        state = State.ATTACK
    }
    
    func keyOff() {
        state = State.RELEASE
    }
}

class Filter {
    // filter coefficients
    var b0: Float = 1, b1: Float = 0, b2: Float = 0
    var a0: Float = 1, a1: Float = 0, a2: Float = 0
    
    // filter state (previous inputs/outputs
    var x1: Float = 0, x2: Float = 0
    var y1: Float = 0, y2: Float = 0
    
    func tick(input: Float) -> Float {
        // calculate filter output
        let y0 = (b0*input + b1*x1 + b2*x2 - a1*y1 - a2*y2)/a0
        
        // delayed inputs/outputs
        x2 = x1
        x1 = input
        y2 = y1
        y1 = y0
        
        return y0
    }
    
    // set filter to work as resonant lowpass
    func lowPass(cutoff: Float, Q: Float) {
        // f0 = cutoff, Fs = sample rate
        let w0 = 2*Float(M_PI)*cutoff/Float(RtSwift.sampleRate)
        let alpha = sin(w0)/(2*Q)
        
        b0 =  (1 - cos(w0))/2
        b1 =   1 - cos(w0)
        b2 =  (1 - cos(w0))/2
        a0 =   1 + alpha
        a1 =  -2*cos(w0)
        a2 =   1 - alpha
    }
}

class SynthVoice {
    var osc1 = SinOsc()
    var mod1 = SinOsc()
    var filter = Filter()
    var lfo = SinOsc()
    
    
}

class ViewController: UIViewController {
    
    var masterGain = 0.5
    var voices = [SynthVoice]()
    
    var sampleNumber = 0
    // create our osc sin, square, saw
    var osc1 = SquareOsc()
    var mod1 = SinOsc()
    var osc2 = SquareOsc()
    var osc3 = SquareOsc()
    var trill = 0.0
    
    var filter = Filter()
    var lfo = SinOsc()
    
    var env1 = ADSR()
    var env2 = ADSR()
    var env3 = ADSR()
    
    var filterQ: Float = 2
    
    var fundamental: Float = 60
    var volume: Float = 0.5
    
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var fundLabel: UILabel!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        RtSwift.sampleRate = 48000
        // initialize filter as lowpass
        filter.lowPass(cutoff: 400, Q: 2)
        lfo.freq = 2
        RtSwift.start(process: { (left, right, numFrames) in
            // code goes here
            for i in 0..<numFrames {
                // fill each sample with silence
                
                // modulate frequency
                // let modValue = self.mod1.tick()
                // self.osc1.freq = 220+modValue*10000
                
                // modulate filter with lfo
                let lfoValue = self.lfo.tick()
                self.filter.lowPass(cutoff: 2000+lfoValue*800, Q: self.filterQ)
                
                // calculate synth value
                var samp: Float = 0
                //samp += self.filter.tick(input: self.osc1.tick()*self.env1.tick())
                samp += self.osc1.tick()*self.env1.tick()
                samp += self.osc2.tick()*self.env2.tick()
                samp += self.osc3.tick()*self.env3.tick()
                
                // apply gain and set to each channel
                left[i] = samp * Float(self.masterGain) * (lfoValue*1)
                right[i] = samp * Float(self.masterGain) * (lfoValue*1)
            }
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func button1On(_sender: UIButton){
        osc1.freq = fundamental*1
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button1Off(_sender: UIButton){
        env1.keyOff()
        
    }
    
    @IBAction func button2On(_sender: UIButton){
        osc2.freq = fundamental*2
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button2Off(_sender: UIButton){
        env2.keyOff()
        
    }
    
    @IBAction func button3On(_sender: UIButton){
        osc3.freq = fundamental*3
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button3Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button4On(_sender: UIButton){
        osc1.freq = fundamental*4
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button4Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button5On(_sender: UIButton){
        osc2.freq = fundamental*5
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button5Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button6On(_sender: UIButton){
        osc3.freq = fundamental*6
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button6Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button7On(_sender: UIButton){
        osc1.freq = fundamental*7
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button7Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button8On(_sender: UIButton){
        osc2.freq = fundamental*8
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button8Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button9On(_sender: UIButton){
        osc3.freq = fundamental*9
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button9Off(_sender: UIButton){
        env3.keyOff()
        
    }
    
    @IBAction func button10On(_sender: UIButton){
        osc1.freq = fundamental*10
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button10Off(_sender: UIButton){
        env1.keyOff()
        
    }
    
    @IBAction func button11On(_sender: UIButton){
        osc2.freq = fundamental*11
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button11Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button12On(_sender: UIButton){
        osc3.freq = fundamental*12
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button12Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button13On(_sender: UIButton){
        osc1.freq = fundamental*13
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button13Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button14On(_sender: UIButton){
        osc2.freq = fundamental*14
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button14Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button15On(_sender: UIButton){
        osc3.freq = fundamental*15
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button15Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button16On(_sender: UIButton){
        osc1.freq = fundamental*16
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button16Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button17On(_sender: UIButton){
        osc2.freq = fundamental*17
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button17Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button18On(_sender: UIButton){
        osc3.freq = fundamental*18
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button18Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button19On(_sender: UIButton){
        osc1.freq = fundamental*19
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button19Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button20On(_sender: UIButton){
        osc2.freq = fundamental*20
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button20Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button21On(_sender: UIButton){
        osc3.freq = fundamental*21
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button21Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button22On(_sender: UIButton){
        osc1.freq = fundamental*22
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button22Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button23On(_sender: UIButton){
        osc2.freq = fundamental*23
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button23Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button24On(_sender: UIButton){
        osc3.freq = fundamental*24
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button24Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button25On(_sender: UIButton){
        osc1.freq = fundamental*25
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button25Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button26On(_sender: UIButton){
        osc2.freq = fundamental*26
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button26Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button27On(_sender: UIButton){
        osc3.freq = fundamental*27
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button27Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button28On(_sender: UIButton){
        osc1.freq = fundamental*28
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button28Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button30On(_sender: UIButton){
        osc2.freq = fundamental*30
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button30Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button32On(_sender: UIButton){
        osc3.freq = fundamental*32
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button32Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button33On(_sender: UIButton){
        osc1.freq = fundamental*33
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button33Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button34On(_sender: UIButton){
        osc2.freq = fundamental*34
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button34Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button35On(_sender: UIButton){
        osc3.freq = fundamental*35
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button35Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button36On(_sender: UIButton){
        osc1.freq = fundamental*36
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button36Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button38On(_sender: UIButton){
        osc2.freq = fundamental*38
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button38Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button39On(_sender: UIButton){
        osc3.freq = fundamental*39
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button39Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button40On(_sender: UIButton){
        osc1.freq = fundamental*40
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button40Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button42On(_sender: UIButton){
        osc2.freq = fundamental*42
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button42Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button44On(_sender: UIButton){
        osc3.freq = fundamental*44
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button44Off(_sender: UIButton){
        
        env3.keyOff()
    }

    @IBAction func button45On(_sender: UIButton){
        osc1.freq = fundamental*45
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button45Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button46On(_sender: UIButton){
        osc2.freq = fundamental*46
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button46Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button48On(_sender: UIButton){
        osc3.freq = fundamental*48
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button48Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button49On(_sender: UIButton){
        osc1.freq = fundamental*49
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button49Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button50On(_sender: UIButton){
        osc2.freq = fundamental*50
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button50Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button51On(_sender: UIButton){
        osc3.freq = fundamental*51
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button51Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button52On(_sender: UIButton){
        osc1.freq = fundamental*52
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button52Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button55On(_sender: UIButton){
        osc2.freq = fundamental*55
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button55Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button56On(_sender: UIButton){
        osc3.freq = fundamental*56
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button56Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button57On(_sender: UIButton){
        osc1.freq = fundamental*57
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button57Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button60On(_sender: UIButton){
        osc2.freq = fundamental*60
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button60Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button63On(_sender: UIButton){
        osc3.freq = fundamental*63
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button63Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button65On(_sender: UIButton){
        osc1.freq = fundamental*65
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button65Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button66On(_sender: UIButton){
        osc2.freq = fundamental*66
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button66Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button68On(_sender: UIButton){
        osc3.freq = fundamental*68
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button68Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button69On(_sender: UIButton){
        osc1.freq = fundamental*69
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button69Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button70On(_sender: UIButton){
        osc2.freq = fundamental*70
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button70Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button75On(_sender: UIButton){
        osc3.freq = fundamental*75
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button75Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button76On(_sender: UIButton){
        osc1.freq = fundamental*76
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button76Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button77On(_sender: UIButton){
        osc2.freq = fundamental*77
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button77Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button78On(_sender: UIButton){
        osc3.freq = fundamental*78
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button78Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button80On(_sender: UIButton){
        osc1.freq = fundamental*80
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button80Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button84On(_sender: UIButton){
        osc2.freq = fundamental*84
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button84Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button85On(_sender: UIButton){
        osc3.freq = fundamental*85
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button85Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button88On(_sender: UIButton){
        osc1.freq = fundamental*88
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button88Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button91On(_sender: UIButton){
        osc2.freq = fundamental*91
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button91Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button92On(_sender: UIButton){
        osc3.freq = fundamental*92
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button92Off(_sender: UIButton){
        
        env3.keyOff()
    }
    @IBAction func button95On(_sender: UIButton){
        osc1.freq = fundamental*95
        env1.keyOn()
        lfo.freq = (osc1.freq/60)*0.5
        
    }
    @IBAction func button95Off(_sender: UIButton){
        
        env1.keyOff()
    }
    @IBAction func button98On(_sender: UIButton){
        osc2.freq = fundamental*98
        env2.keyOn()
        lfo.freq = (osc2.freq/60)*0.5
        
    }
    @IBAction func button98Off(_sender: UIButton){
        
        env2.keyOff()
    }
    @IBAction func button99On(_sender: UIButton){
        osc3.freq = fundamental*99
        env3.keyOn()
        lfo.freq = (osc3.freq/60)*0.5
        
    }
    @IBAction func button99Off(_sender: UIButton){
        
        env3.keyOff()
    }

    @IBAction func buttonDoubleOn(_sender: UIButton){
        fundamental *= 2
        fundLabel.text =  "\(fundamental)";
        
    }
    @IBAction func buttonTripleOn(_sender: UIButton){
       fundamental *= 3
        fundLabel.text =  "\(fundamental)";
        
    }
    @IBAction func buttonHalfOn(_sender: UIButton){
        fundamental *= 0.5
        fundLabel.text =  "\(fundamental)";
        
    }
    @IBAction func buttonThirdOn(_sender: UIButton){
        fundamental *= 0.33
        fundLabel.text =  "\(fundamental)";
        
    }



    
    @IBAction func volumeSlideChanged(_sender: UISlider){
        print(" Volume: \(_sender.value)")
        volumeLabel.text =  "\(_sender.value)";
        masterGain = Double(_sender.value);
    }
    @IBAction func FundSliderChanged(_sender: UISlider){
        print(" Fundamental: \(_sender.value)")
        fundLabel.text =  "\(_sender.value)";
        fundamental = _sender.value;
        //fundamental = fundamental * 1;
    }
}

