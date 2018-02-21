

/*
FFT Processing

The Fast Fourier Transform (FFT) is a central technnology in computer music, allowing an efficient transformation between the time domain (amplitude-time waveforms) and the frequency domain (spectrum, representing the phase and strength of component pure frequencies). Fourier re-synthesis back into the time domain is accomplished by an IFFT (Inverse FFT) or additive synthesis UGens, which enable a variety of useful spectral processing techniques.


Read the summary of FFT principles  in the tutorial
"6.2 Spectral Processing & the FFT.html".

 ...then see helpfile:  [FFT Overview], in UGens>FFT

PV (Phase Vocoder) UGens are used to operate directly on the FFT spectral data:

input -> FFT -> PV_UGen1 ... PV_UGenN... -> IFFT -> output
*/
(
s.options.memSize =  8192*2;   // increase server memory for FFT proc
s = Server.local.waitForBoot({
	s.scope(2);
});
)
( //	do nothing transformation
{ var in, chain;
	in = WhiteNoise.ar(0.8);
	chain = FFT(LocalBuf(1024,1), in);  // allocate a Buffer as part of this Synth for computing an FFT of the time domain signal--  its size is the size of the FFT. The hop size is half the window by default.  The FFT UGen takes a time domain signal and returns one in the frequency domain.  It does not appear to run at a conventional rate (no .ar or .kr); in actual fact, FFT and PV_UGens are at control rate, but only calculate when there is data to act on

	[in,IFFT.ar(chain)]   // IFFT converts the frequency domain data to the time domain; IFFT is an audio rate UGen, and defaults to that rate if 'ar' is omitted -- the output of the input on the right is in stereo with the IFFT output on the left for comparison
}.play(s);
)

// spectral gates
(
 // pass only bins above an amplitude threshold
Ndef(\magAbove, { arg freq=80, threshold=15, amp=0.5;
	var in, chain;
	in = WhiteNoise.ar(amp);
//	in = Pulse.ar(freq,0.1,amp);
	chain = FFT(LocalBuf(2048,1), in);
	chain = PV_MagAbove(chain, threshold);
	IFFT(chain).dup;
});
Spec.add(\threshold,[0,100,\lin,0,15])
)
Ndef(\magAbove).gui

(
 // pass only bins below an amplitude threshold
Ndef(\magBelow, { arg freq=80, threshold=15, amp=0.5;
	var in, chain;
	in = WhiteNoise.ar(amp);
	// in = Pulse.ar(freq,0.1,amp);
	chain = FFT(LocalBuf(2048,1), in);
	chain = PV_MagBelow(chain, threshold);
	IFFT(chain).dup;
});
)
Ndef(\magBelow).gui

 ( // PV_LocalMaxPasses only bins whose magnitude is above a threshold and above their nearest neighbors.
Ndef(\localMax, { arg threshold=50, amp=0.1;
    var in, chain;
    in = Mix.arFill(3, { LFSaw.ar(exprand(100, 500), 0, amp); });
    chain = FFT(LocalBuf(2048), in);
    chain = PV_LocalMax(chain, threshold);
    IFFT(chain).dup;
})
)
Ndef(\localMax).gui;

// spectral filtering

( // with spectral processing, you can have a "brickwall filter", exactly passing only amplitudes below or above a particular frequency bin
// 0->1 = hi bins pass; -1 -> 0 lo bins pass
Ndef(\brickWall, { arg freq=200, wipe=0.1, amp=0.1;
	var in, chain;
	in = WhiteNoise.ar(amp);
//	in = Pulse.ar(freq,0.1,0.5);
	chain = FFT(LocalBuf(2048,1), in);
	// wipe = 0, allpass; wipe > 0 = hi pass; wipe < 0≥ = lo pass
	chain = PV_BrickWall(chain, wipe);
	IFFT(chain).dup;
});
Spec.add(\wipe,[-1,1,\lin,0,0]);
)
Ndef(\brickWall).gui

(	// brickWall filters an FM voice
Ndef(\oscBrickWall, { arg cfreq=800, mfreq=100, lfofreq=1,wipe=0;
	var in, chain;
	in = SinOsc.ar(
		SinOsc.kr(
			// mod oscillator is itself modulated by LFO
			SinOsc.kr(lfofreq,0,6,6.2).squared,
			0, mfreq,	// modulation range
			cfreq)		// center freq
	);
	chain = FFT(LocalBuf(2048,1), in);
	// pass freq above threshold
	chain = PV_BrickWall(chain, wipe);
	IFFT(chain).dup;
});
Spec.add(\wipe,[-1,1,\lin,0,0]);
Spec.add(\cfreq,[20,20000,\exp,0,440]);
Spec.add(\mfreq,[0.1,2000,\exp,0,4]);
Spec.add(\lfofreq,[0.1,40,\exp,0,0.5]);
)
Ndef(\oscBrickWall).gui

( // chooses bins to suppress at random -- wipe 0->1 controls how many are chosen, from none to all, at each trigger
Ndef(\PVrandComb, { arg trgfreq=2, plsfreq=100,width=0.1, wipe=0, nseAmp=0.1, plsAmp=0.1;
	var in, chain;
	in = Mix([WhiteNoise.ar(nseAmp),Pulse.ar(plsfreq,width,plsAmp)]);
	chain = FFT(LocalBuf(2048,1), in);
//	PV_RandComb args =  buffer, wipe, trig;
	chain = PV_RandComb(chain, wipe, Impulse.kr(trgfreq));
	IFFT(chain).dup;
});
Spec.add(\tfreq,[0.1,20,\exp,0,1]);
Spec.add(\wipe,[0,1,\lin,0,0]);
Spec.add(\nseAmp,[0,1,\amp,0,0.1]);
Spec.add(\plsAmp,[0,1,\amp,0,0.1]);
)
Ndef(\PVrandComb).gui;

( // suppress 'numTeeth' blocks of bins, blocksize= width
Ndef(\PVrectComb, { arg numTeeth=8, plsfreq=100,phsRate=0.2, width=0.5,
	nseAmp=0.1, plsAmp=0.1;
	var in, chain;
	in = Mix([WhiteNoise.ar(nseAmp),Pulse.ar(plsfreq,width,plsAmp)]);
	chain = FFT(LocalBuf(2048,1), in);
// PV_RectComb args = buffer, numTeeth, phase, width
 	chain = PV_RectComb(chain, numTeeth,
		LFTri.kr(phsRate,0,0.4,0.5),width);
	IFFT(chain).dup;
});
Spec.add(\numTeeth,[0,1024,\lin,1,64]);
Spec.add(\phsRate,[0.01,20,\exp,0,0.1]);
)
Ndef(\PVrectComb).gui

// PV_ConformalMap  Makes a transformation of the complex plane so the output is full of phase vocoder artifacts but may be musically fun.
// PV_ConformalMap.new(buffer, areal: 0, aimag: 0)
(
Ndef(\conformer, { arg areal=1, aimag=0.15, delay=0.1, decay=2, amp=0.3;
    var in, chain, sound;
    in = Mix.ar(LFSaw.ar(SinOsc.kr(Array.rand(3,0.1,0.5),0,10,[1,1.1,1.5,1.78,2.45,6.7]*220),0,0.3));
    chain = FFT(LocalBuf(2048), in);
    chain = PV_ConformalMap(chain, areal, aimag);
    sound = IFFT(chain);
	CombN.ar(sound, 0.5, delay, decay, amp, sound).dup;
});
Spec.add(\areal,[0.01,20,\exp,0,1]);
Spec.add(\imag,[0.01,10.0, 'exponential',0,0.5]);
Spec.add(\delay,[0.01,10.0, 'exponential',0,0.1]);
Spec.add(\decay,[0.01,10.0, 'exponential',0,2]);
)
Ndef(\conformer).gui

// spectral modulation

(	// PV_MagMul -- multiply magnitudes of two signals,keep phases of first
Ndef(\magMul,{ arg freq1=440, freq2=220, amp=0.5;
	 var inA, chainA, inB, chainB, chain;
	inA = LPF.ar(WhiteNoise.ar(0.2),freq1);
    inB = LFSaw.ar(freq2, 0, 0.2);
    chainA = FFT(LocalBuf(2048), inA);
    chainB = FFT(LocalBuf(2048), inB);
    chain = PV_MagMul(chainA, chainB);
	(amp * IFFT(chain)).dup
});
Spec.add(\freq1,[20,20000,\exp,0,0.1]);
Spec.add(\freq2,[20,20000,\exp,0,0.1]);
)
Ndef(\magMul).gui

// spectral magnitude distortion
(
Ndef(\magClip,{ arg freq=220, threshold=10, amp=0.5;
	var in;
	in = SoundIn.ar(0,amp);
//	in = SinOsc.ar(freq,0,amp);
	IFFT(PV_MagClip(
		FFT(LocalBuf(2048,1), in),
		threshold )).dup
})
)
Ndef(\magClip).gui

// spectral bin processing

// PV_MagFreeze freezes spectrum, when 'freeze' arg goes above 0
(
//trig with Pulse wave or MouseY
Ndef(\magFreeze, { arg spd=4,width=0.1,amp=0.1,bufnum=0;
    var in, chain;
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), loop: 1);
    chain = FFT(LocalBuf(2048), in);
	chain = PV_MagFreeze(chain, Pulse.kr(spd,width).poll );
 //   chain = PV_MagFreeze(chain, MouseY.kr > 0.5 );
	   (amp * IFFT(chain)).dup;
})
)
Ndef(\magFreeze).gui

( // freeze magnitudes when freeze > 0
Ndef(\PVmagFreeze, { arg freeze=0, freq=400, nspeed=4.6;
	var in, chain;
	in = SinOsc.ar(LFNoise1.kr(nspeed,freq/1.6,freq));
	chain = FFT(LocalBuf(2048,1), in);
	// moves in and out of freeze
	chain = PV_MagFreeze(chain, freeze );
	IFFT(chain).dup;
});
Spec.add(\nspeed,[0.1,40,\exp,0,2]);
Spec.add(\freeze,[0,1,\lin,1,0]);
)
Ndef(\PVmagFreeze).gui

( //	bin smearing: averages n adjacent bins for each side of bin. cpu-expensive for large values of n.

Ndef(\PVmagSmear, { arg freq=100, nbins=0, sinAmp=0.5, plsAmp=0,audioInAmp=0;
	var in, chain;
	in = Mix([SinOsc.ar(freq,0,sinAmp),
		Pulse.ar(freq,0.01,plsAmp),
		SoundIn.ar(0,audioInAmp)]);
	chain = FFT(LocalBuf(2048,1), in);
// PV_MagSmear(in, n)
	chain = PV_MagSmear(chain, nbins);
	IFFT(chain);
});
Spec.add(\nbins,[1,128,\lin,1,2]);
)
Ndef(\PVmagSmear).gui;


(//PV_BinScramble -- randomizes the order of bins with each trigger
Ndef(\binScramble, { arg  freq=220, wipe=0.1, trigSpd=4,sinAmp=0.5, plsAmp=0,audioInAmp=0;
   var in, chain;
	in = Mix([SinOsc.ar(freq,0,sinAmp),
		Pulse.ar(freq,0.01,plsAmp),
		SoundIn.ar(0,audioInAmp)]);
    chain = FFT(LocalBuf(2048), in);
	chain = PV_BinScramble(chain, wipe, 0.1,Pulse.kr(trigSpd) );
    IFFT(chain).dup;
});
Spec.add(\trigSpd,[0.1,40,\exp,0,4])
)
Ndef(\binScramble).gui


//	PV_Diffuser .. adds random values to phases. trig selects new random values.
//	PV_Diffuser(in, trig)
(
Ndef(\pvDiffuser,{ arg freq,trigSpd;
	IFFT(
		PV_Diffuser(
			FFT(LocalBuf(2048,1),
				Pulse.ar(freq,0.01)),
			SinOsc.kr(trigSpd)[
		);
	).dup;
});
Spec.add(\trigSpd,[0.1,40,\exp,0,4]);
Spec.add(\wipe,[0,1,\lin,0,0.5]);
)
Ndef(\pvDiffuser).gui

/* 	BinShifting
PV_BinShift args: buffer, stretch = 1.0, shift;
newbin = (shift + oldbin), and stretch original magnitudes proportionally across bins
*/
(
Ndef(\binShift, { arg freq=100, stretch=1, shift=0.0,
	sinAmp=0.5, plsAmp=0,audioInAmp=0;
	var in, chain;
	in = Mix([SinOsc.ar(freq,0,sinAmp),
		Pulse.ar(freq,0.01,plsAmp),
		SoundIn.ar(0,audioInAmp)]);
	chain = FFT(LocalBuf(2048,1), in);
	chain = PV_BinShift(chain, stretch, shift);
	IFFT(chain).dup;
});
Spec.add(\stretch,[0,12,\lin,0,1]);
Spec.add(\shift,[0,256,\lin,1,1]);
)
Ndef(\binShift).gui

/*
(
b = Buffer.alloc(s,2048,1);
c = Buffer.alloc(s,2048,1);
)*/

//	file processing/morphing -- first put your own correct sample filepath as an argument to the class 'Sample' in each example

(
~samps = [
	Buffer.read(s,"/Sounds/disco/bustaloop"),
	Buffer.read(s,"/Sounds/manystreams/bali_insects"),
	Buffer.read(s,"/Sounds/bells/belltree1")
];
)

//// binShift a sample
(
Spec.add(\bufnum,[~samps.first.bufnum,~samps.last.bufnum,\lin,1,~samps.first.bufnum]);
Spec.add(\stretch,[0.1,10,\linear,0.05]);
Spec.add(\shift,[0,64,\linear,1]);
Spec.add(\rate,[0.01,2]);
Spec.add(\dir,[-1,1,\linear,1,1]);
Spec.add(\startPos,[0,1,\linear,0,0]);
Spec.add(\endPos,[0,1,\linear,0,1]);

Ndef(\sampBinShift, { arg bufnum=~samps[0],stretch=1, shift=0.0, rate=1,startPos=0,endPos=1,dir=1,amp=0.5;
	var in, chain, dur;
	var thisDur = ((endPos-startPos).abs*BufDur.kr(bufnum));
	dur = ((endPos-startPos).abs*thisDur);
	in = PlayBuf.ar(1,bufnum,
		BufRateScale.kr(bufnum)*rate*dir,
		Impulse.kr((1/dur).min(100)),
		startPos*BufFrames.kr(bufnum),
		endPos*BufFrames.kr(bufnum),1);
	chain = FFT(LocalBuf(2048,1), in);
	chain = PV_BinShift(chain, stretch, shift);
	(amp * IFFT(chain)).dup
});
)
Ndef(\sampBinShift).gui

/*	PV_BinWipe .. spectral crossfade between two sounds
(PV_BinWipe(inA, inB, wipe)
as wipe goes from 0 to 1, begin copying in high bins from inB.
as wipe goes from 0 to -1, begin copying in low bins from inB.
*/
(
Ndef(\sampBinWipe, { arg sample1=~samps[0],sample2=~samps[1],wipe = 0.0, rate=1, startPos=0,endPos=1,dir=1, amp=0.5;
	var in1, in2, chain, chain1, chain2, trig;
	var dur1 = ((endPos-startPos).abs*BufDur.kr(sample1));
	var dur2 = ((endPos-startPos).abs*BufDur.kr(sample2));
	in1 = PlayBuf.ar(1,sample1,
		BufRateScale.kr(sample1)*rate*dir,
			Impulse.kr((1/dur1).min(100)),
		startPos*BufFrames.kr(sample1),
			endPos*BufFrames.kr(sample1),1);
	chain1 = FFT(LocalBuf(2048,1), in1);
	in2 = PlayBuf.ar(1,sample2,
		BufRateScale.kr(sample2)*rate*dir,
			Impulse.kr((1/dur1).min(100)),
			startPos*BufFrames.kr(sample2),
			endPos*BufFrames.kr(sample2),1);
	chain2 = FFT(LocalBuf(2048,1), in2);
	chain = PV_BinWipe(chain1, chain2, wipe);
	(amp * IFFT(chain)).dup;
});
Spec.add(\sample1,[~samps.first.bufnum,~samps.last.bufnum,\lin,1,~samps.first.bufnum]);
Spec.add(\sample2,[~samps.first.bufnum,~samps.last.bufnum,\lin,1,~samps.first.bufnum]);
Spec.add(\wipe,[-1,1]);
Spec.add(\rate,[0.125,8,\exp]);
Spec.add(\dir,[-1,1,\linear,1]);
)
Ndef(\sampBinWipe).gui

(	// PV_Max .. pass bins with the max magnitude of A and B -- timbral mutation!
Ndef(\pvMax, { arg sample1=~samps[0],sample2=~samps[1], rate=1,
	startPos=0,endPos=1,dir=1, amp=0.5, amp1=0.5, amp2=0.5;
	var in1, in2, chain, chain1, chain2, trig;
	var dur1 = ((endPos-startPos).abs*BufDur.kr(sample1));
	var dur2 = ((endPos-startPos).abs*BufDur.kr(sample2));
	in1 = PlayBuf.ar(1,sample1,
		BufRateScale.kr(sample1)*rate*dir,
			Impulse.kr((1/dur1).min(100)),
		startPos*BufFrames.kr(sample1),
			endPos*BufFrames.kr(sample1),1);
	chain1 = FFT(LocalBuf(2048,1), in1*amp1);
	in2 = PlayBuf.ar(1,sample2,
		BufRateScale.kr(sample2)*rate*dir,
			Impulse.kr((1/dur1).min(100)),
			startPos*BufFrames.kr(sample2),
			endPos*BufFrames.kr(sample2),1);
	chain2 = FFT(LocalBuf(2048,1), in2*amp2);
	chain = PV_Max(chain1, chain2);
	(amp * IFFT(chain)).dup;
})
)
Ndef(\pvMax).gui

(	// PV_Min .. pass bins with the min magnitude of A and B.
Ndef(\pvMin, { arg sample1=~samps[0],sample2=~samps[1], rate=1,
	startPos=0,endPos=1,dir=1, amp=0.5, amp1=0.5, amp2=0.5;
	var in1, in2, chain, chain1, chain2, trig;
	var dur1 = ((endPos-startPos).abs*BufDur.kr(sample1));
	var dur2 = ((endPos-startPos).abs*BufDur.kr(sample2));
	in1 = PlayBuf.ar(1,sample1,
		BufRateScale.kr(sample1)*rate*dir,
			Impulse.kr((1/dur1).min(100)),
		startPos*BufFrames.kr(sample1),
			endPos*BufFrames.kr(sample1),1);
	chain1 = FFT(LocalBuf(2048,1), in1*amp1);
	in2 = PlayBuf.ar(1,sample2,
		BufRateScale.kr(sample2)*rate*dir,
			Impulse.kr((1/dur1).min(100)),
			startPos*BufFrames.kr(sample2),
			endPos*BufFrames.kr(sample2),1);
	chain2 = FFT(LocalBuf(2048,1), in2*amp2);
	chain = PV_Min(chain1, chain2);
	(amp * IFFT(chain)).dup;
});
)
Ndef(\pvMin).gui
)

// you can also operate directly on spectral data using other UGens using the method 'pvcollect' (a method of PV_ChainUGen, the base class for UGens that alter FFT chains)
//  The function argument processes each bin of an FFT chain separately: func(mag, phase, index)

(
Ndef(\sampMangler,{
    var in, numFrames=2048, chain, v=0.12;
    in = PlayBuf.ar(1, 0, loop: 1);
    chain = FFT(LocalBuf(numFrames), in);
    chain = chain.pvcollect(numFrames, {|mag, phase,index|
//////// Try uncommenting each of these lines in turn and re-running the synth:
        //mag;
        //[mag, phase];
        //[mag, phase] / 3;
		// [mag, phase].sqrt;
		//[mag, 3.14.rand];
        //[mag, LFNoise0.kr.range(0, 3.14)];
        //[mag * Dseq([1, 0, 0, 1, 1, 0, 1, 0].stutter(8), inf)]; // Can even use Demand ugens! One val demanded each frame
        //[mag.sqrt, 3.14.rand];
		//if(index % 8 == 0, mag, 0); // Comb filter
        //if(LFNoise0.kr(10) > 0.5, mag, 0);
        //mag + DelayN.kr(mag, 1, v); // Spectral delay
        if((index-LFPar.kr(0.1).range(2, 1024/20)).abs < 10, mag, 0); // Swept bandpass
    }, frombin: 0, tobin: 250, zeroothers: 0);
	IFFT(chain).dup
});
)
Ndef(\sampMangler).play


//FFT is also used as a first stage in various machine listening UGens:

[Onsets]  // onset detectors
[PV_HainsworthFoote]
[PV_JensenAndersen]

/*There are also many FFT based UGens that can be downloaded and installed in your Extensions folder to be explored.  You can download the latest build for MacOS here:  https://github.com/cbmuse/SC3-plugins

For Windows, the build is downloadable from:
https://supercollider.github.io/download

// We'll go over the installation process in a future class!

/*
Some third party sources:

Non-realtime analysis using LORIS, SPEAR and ATS
Josh Parmenter's JoshUGens library (a 'quark' extension) has many additional PV_UGens
*/

