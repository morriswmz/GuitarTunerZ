package 
{
	import adobe.utils.CustomActions;
	import com.wmz.gtz.FFT;
	import com.wmz.gtz.LPF;
	import com.wmz.gtz.WindowFunc;
	import flash.display.Bitmap;
	import flash.display.CapsStyle;
	import flash.display.Shader;
	import flash.display.Shape;
	import flash.display.SpreadMethod;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.SampleDataEvent;
	import flash.filters.GlowFilter;
	import flash.media.Microphone;
	import flash.text.AntiAliasType;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;

	/**
	 * ...
	 * @author morriswmz
	 */
	[Frame(factoryClass="Preloader")]
	public class Main extends Sprite 
	{
		// assets
		[Embed(source = "tuner_bg.png")]
		private var tunerBgAsset:Class;
		
		[Embed(source = "tuner_light.png")]
		private var tunerLightAsset:Class;
		
		[Embed(source="QuartzMS.TTF", fontName="QuartzMS", mimeType="application/x-font-truetype", embedAsCFF="false")]
		private var quartzMSFont:Class;
		
		// sound data
		private var microphone:Microphone;
		private var sampleBuffer:Vector.<Number>;
		private var fftBuffer:Vector.<Number>;
		private var waveformBuffer:Vector.<Number>;
		private const WAVEFORM_LENGTH:int = 170;
		private var samplingRate:Number;
		private var isActive:Boolean;
		
		private const FFTSIZE:int = 8192;
		private const SLICESIZE:int = 1024;
		private var fft:FFT;
		private var aalpf:LPF;
		private var spectrum:Vector.<Number>;
		private var currentPitch:Number;
		
		private var silentCounter:Number = 0;
		
		private var _sp3:Vector.<Number>
		
		private var guitarPitches:Array = [
			82.41,	// E2
			110.0,	// A2
			146.83,	// D3
			196.0,	// G3
			246.94,	// B3
			329.63	// E4
		];
		private var guitarPitchNames:Array = [
			'E2', 'A2', 'D3', 'G3', 'B3', 'E4'
		];
		
		// ui
		private var tunerBg:Bitmap;
		private var tunerLight:Bitmap;
		private var waveform:Sprite;
		private var gaugeFrame:Sprite;
		private var gaugeTrack:Sprite;
		private var gaugeTargetX:Number
		private var leftArrow:Shape;
		private var rightArrow:Shape;
		private const GAUGE_WIDTH:Number = 341;
		private const GAUGE_HEIGHT:Number = 102;
		private const WAVEFORM_WIDTH:Number = 341;
		private const WAVEFORM_HEIGHT:Number = 48;
		
		private var freqText:TextField;
		private var pitchIndicatorText:TextField;
		private var pitchIndicatorArrow:Shape;
		private const INDICATOR_ARROW_SPAN:Number = 33.0;
		private var lohIndicatorText:TextField;
		private var lohIndicatorBlock:Shape;
		private var LOH_BLOCK_WIDTH:Number = 32.0;
		private var LOH_BLOCK_HEIGHT:Number = 15.0;
		
		private var inactiveText:TextField;
		private var flashingCounter:Number;
		
		private const RULER_SPAN:Number = 8;
		private const RULER_HEGHT:Number = 56;
		private const RULER_OFFSET:Number = 46;
		private const RULER_TXT_Y:Number = 2;
		private const RULER_MAX_F:Number = 440;
		private const RULER_MIN_F:Number = 20;
		
		
		private var glowFilter:GlowFilter = new GlowFilter(0xffffff, 0.6, 6, 6, 1);
		
		private var pauseSprite:Sprite;
		private var focusLost:Boolean;
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}

		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point
			// init ui
			var i:int;
			tunerBg = new tunerBgAsset();
			
			addChild(tunerBg);
			
			waveform = new Sprite();
			var waveformFrame:Shape = new Shape();
			waveformFrame.graphics.lineStyle(1, 0xffffff);
			waveformFrame.graphics.drawRect(0, 0, WAVEFORM_WIDTH, WAVEFORM_HEIGHT);
			waveformFrame.graphics.moveTo(0, WAVEFORM_HEIGHT / 2);
			waveformFrame.graphics.lineTo(WAVEFORM_WIDTH, WAVEFORM_HEIGHT / 2);
			waveformFrame.cacheAsBitmap = true;
			waveform.addChild(waveformFrame);
			waveform.x = 30;
			waveform.y = 169;
			waveform.filters = [glowFilter];
			addChild(waveform);
			
			freqText = new TextField();
			freqText.embedFonts = true;
			freqText.selectable = false;
			freqText.x = 31;
			freqText.y = 25;
			freqText.autoSize = TextFieldAutoSize.LEFT;
			freqText.text = "DETECTED FREQ: "
			freqText.setTextFormat(new TextFormat('QuartzMS', 14, 0xffffff));
			freqText.antiAliasType = AntiAliasType.ADVANCED;
			freqText.filters = [glowFilter];
			addChild(freqText);
			
			pitchIndicatorArrow = new Shape();
			pitchIndicatorArrow.graphics.lineStyle(1, 0xffffff);
			pitchIndicatorArrow.graphics.beginFill(0xffffff);
			pitchIndicatorArrow.graphics.moveTo(0, 0);
			pitchIndicatorArrow.graphics.lineTo(10, 0);
			pitchIndicatorArrow.graphics.lineTo(5, 7);
			pitchIndicatorArrow.graphics.lineTo(0, 0);
			pitchIndicatorArrow.graphics.endFill();
			pitchIndicatorArrow.x = 39;
			pitchIndicatorArrow.y = 230;
			pitchIndicatorArrow.filters = [glowFilter];
			addChild(pitchIndicatorArrow);
			pitchIndicatorText = new TextField();
			pitchIndicatorText.embedFonts = true;
			pitchIndicatorText.selectable = false;
			pitchIndicatorText.text = guitarPitchNames.join('     ');
			pitchIndicatorText.x = 35;
			pitchIndicatorText.y = 240;
			pitchIndicatorText.autoSize = TextFieldAutoSize.LEFT;
			pitchIndicatorText.setTextFormat(new TextFormat('QuartzMS', 13, 0xffffff));
			pitchIndicatorText.cacheAsBitmap = true;
			addChild(pitchIndicatorText);
			
			lohIndicatorBlock = new Shape();
			lohIndicatorBlock.graphics.beginFill(0xffffff, 0.26);
			lohIndicatorBlock.graphics.drawRoundRect(0, 0, LOH_BLOCK_WIDTH, LOH_BLOCK_HEIGHT, 3);
			lohIndicatorBlock.graphics.endFill();
			lohIndicatorBlock.x = 271;
			lohIndicatorBlock.y = 29;
			lohIndicatorBlock.filters = [glowFilter];
			addChild(lohIndicatorBlock);
			lohIndicatorText = new TextField();
			lohIndicatorText.embedFonts = true;
			lohIndicatorText.selectable = false;
			lohIndicatorText.text = 'low       ok       high';
			lohIndicatorText.x = 274;
			lohIndicatorText.y = 27;
			lohIndicatorText.antiAliasType = AntiAliasType.ADVANCED;
			lohIndicatorText.autoSize = TextFieldAutoSize.LEFT;
			lohIndicatorText.setTextFormat(new TextFormat('QuartzMS', 10, 0xffffff));
			lohIndicatorText.filters = [glowFilter];
			lohIndicatorText.cacheAsBitmap = true;
			addChild(lohIndicatorText);
			
			var gaugeMask:Shape = new Shape();
			gaugeMask.graphics.beginFill(0x000000);
			gaugeMask.graphics.drawRect(0, 0, GAUGE_WIDTH, GAUGE_HEIGHT);
			gaugeMask.graphics.endFill();
			gaugeMask.x = 30;
			gaugeMask.y = 50;
			gaugeTrack = createTrack();
			var trackContainer:Sprite = new Sprite();
			trackContainer.x = 30;
			trackContainer.y = 50;
			trackContainer.addChild(gaugeTrack);
			trackContainer.mask = gaugeMask;
			
			leftArrow = new Shape();
			leftArrow.graphics.beginFill(0xffffff);
			leftArrow.graphics.lineTo(-6, 4);
			leftArrow.graphics.lineTo(0, 8);
			leftArrow.graphics.lineTo(0, 0);
			leftArrow.graphics.endFill();
			leftArrow.x = 42;
			leftArrow.y = 55;
			leftArrow.filters = [glowFilter];
			leftArrow.cacheAsBitmap = true;
			leftArrow.visible = false;
			addChild(leftArrow);
			
			rightArrow = new Shape();
			rightArrow.graphics.beginFill(0xffffff);
			rightArrow.graphics.lineTo(6, 4);
			rightArrow.graphics.lineTo(0, 8);
			rightArrow.graphics.lineTo(0, 0);
			rightArrow.graphics.endFill();
			rightArrow.x = 360;
			rightArrow.y = 55;
			rightArrow.filters = [glowFilter];
			rightArrow.cacheAsBitmap = true;
			rightArrow.visible = false;
			addChild(rightArrow);
			
			addChild(trackContainer);
			gaugeFrame = new Sprite();
			gaugeFrame.x = 30;
			gaugeFrame.y = 50;
			gaugeFrame.graphics.lineStyle(1, 0xffffff);
			gaugeFrame.graphics.drawRect(0, 0, GAUGE_WIDTH, GAUGE_HEIGHT);
			gaugeFrame.graphics.lineStyle(RULER_SPAN, 0xffffff,0.2,false,'normal',CapsStyle.SQUARE);
			gaugeFrame.graphics.moveTo(GAUGE_WIDTH / 2, RULER_SPAN/2);
			gaugeFrame.graphics.lineTo(GAUGE_WIDTH / 2, GAUGE_HEIGHT-RULER_SPAN/2);
			gaugeFrame.filters = [glowFilter];
			gaugeFrame.cacheAsBitmap = true;
			addChild(gaugeFrame);
			
			inactiveText = new TextField();
			inactiveText.embedFonts = true;
			inactiveText.selectable = false;
			inactiveText.text = 'inactive';
			inactiveText.x = 32;
			inactiveText.y = 170;
			inactiveText.antiAliasType = AntiAliasType.ADVANCED;
			inactiveText.autoSize = TextFieldAutoSize.LEFT;
			inactiveText.setTextFormat(new TextFormat('QuartzMS', 8, 0xffffff));
			inactiveText.filters = [glowFilter];
			inactiveText.cacheAsBitmap = true;
			addChild(inactiveText);
			
			pauseSprite = new Sprite();
			pauseSprite.graphics.beginFill(0xffffff, 0.5);
			pauseSprite.graphics.drawRect(0, 0, 400, 300);
			pauseSprite.graphics.endFill();
			pauseSprite.graphics.beginFill(0x000000, 0.6);
			pauseSprite.graphics.moveTo(170, 110);
			pauseSprite.graphics.lineTo(250, 150);
			pauseSprite.graphics.lineTo(170, 190);
			pauseSprite.graphics.lineTo(170, 110);
			pauseSprite.graphics.endFill();
			pauseSprite.visible = false;
			addChild(pauseSprite);
			
			tunerLight = new tunerLightAsset();
			addChild(tunerLight);
			// setup microphone
			microphone = Microphone.getMicrophone();
			microphone.rate = 11;
			samplingRate = 11025;
			sampleBuffer = new Vector.<Number>();
			fftBuffer = new Vector.<Number>();
			waveformBuffer = new Vector.<Number>(WAVEFORM_LENGTH); // used for waveform display, not computation
			for (i = 0; i < WAVEFORM_LENGTH; i++) waveformBuffer[i] = 0.0;
			
			microphone.addEventListener(SampleDataEvent.SAMPLE_DATA, sampleDataHandler);
			
			fft = new FFT(FFTSIZE, WindowFunc.W_HANNING);
			aalpf = new LPF(1350, samplingRate);
			spectrum = new Vector.<Number>(FFTSIZE / 2);
			
			gaugeTargetX = 0;
			flashingCounter = 0;
			
			addEventListener(Event.ENTER_FRAME, enterFrameHandler);
			
			stage.addEventListener(Event.DEACTIVATE, deactivateHandler);
			stage.addEventListener(Event.ACTIVATE, activateHandler);
			stage.dispatchEvent(new Event(Event.DEACTIVATE));
	
			pauseSprite.addEventListener(MouseEvent.CLICK, function (e:Event):void {
				stage.dispatchEvent(new Event(Event.ACTIVATE));
			});
		}
		
		private function deactivateHandler(e:Event):void {
			focusLost = true;
			pauseSprite.visible = true;
			microphone.removeEventListener(SampleDataEvent.SAMPLE_DATA, sampleDataHandler);
		}
		
		private function activateHandler(e:Event):void {
			focusLost = false;
			pauseSprite.visible = false;
			microphone.addEventListener(SampleDataEvent.SAMPLE_DATA, sampleDataHandler);
		}
		
		private function createTrack():Sprite {
			var i:int, j:int;
			var track:Sprite = new Sprite();
			// generate ruler from 20Hz to 440Hz
			var ruler:Shape = new Shape();
			ruler.graphics.lineStyle(1, 0xffffff);
			for (i = 0; i < (RULER_MAX_F - RULER_MIN_F) + 1; i++) {
				ruler.graphics.moveTo(i * RULER_SPAN, RULER_HEGHT + RULER_OFFSET);
				if (i % 10 == 0) {
					ruler.graphics.lineTo(i * RULER_SPAN, RULER_OFFSET);
					rulerText = new TextField();
					rulerText.embedFonts = true;
					rulerText.selectable = false;
					rulerText.text = String(i + RULER_MIN_F);
					rulerText.width = 20;
					rulerText.x = i * RULER_SPAN - 10;
					rulerText.y = RULER_OFFSET - 14;
					rulerText.antiAliasType = AntiAliasType.ADVANCED;
					rulerText.setTextFormat(new TextFormat('QuartzMS', 8, 0xffffff, false, false, false, '', '', TextFormatAlign.CENTER));
					rulerText.filters = [glowFilter];
					track.addChild(rulerText);
				} else if (i % 5 == 0) {
					ruler.graphics.lineTo(i * RULER_SPAN, RULER_OFFSET + RULER_HEGHT * 0.3);
				} else {
					ruler.graphics.lineTo(i * RULER_SPAN, RULER_OFFSET + RULER_HEGHT * 0.7);
				}
			}
			ruler.filters = [glowFilter];
			track.addChild(ruler);
			// add text
			var totalLength:Number = i * RULER_SPAN;
			var tmp:Number;
			var rulerText:TextField;
			for (i = 0; i < guitarPitches.length; i++) {
				tmp = Math.round((guitarPitches[i] - RULER_MIN_F) / (RULER_MAX_F - RULER_MIN_F) * totalLength) - 1;
				ruler.graphics.moveTo(tmp, RULER_OFFSET - 19);
				ruler.graphics.beginFill(0xffffff);
				ruler.graphics.lineTo(tmp - 4, RULER_OFFSET - 25);
				ruler.graphics.lineTo(tmp + 4, RULER_OFFSET - 25);
				ruler.graphics.lineTo(tmp, RULER_OFFSET - 19);
				ruler.graphics.endFill();
				rulerText = new TextField();
				rulerText.embedFonts = true;
				rulerText.selectable = false;
				rulerText.text = guitarPitchNames[i];
				rulerText.x = tmp - 9;
				rulerText.y = RULER_TXT_Y;
				rulerText.antiAliasType = AntiAliasType.ADVANCED;
				rulerText.autoSize = TextFieldAutoSize.LEFT;
				rulerText.setTextFormat(new TextFormat('QuartzMS', 12, 0xffffff));
				rulerText.filters = [glowFilter];
				track.addChild(rulerText);
			}
			track.cacheAsBitmap = true;
			return track;
		}
		
		private function enterFrameHandler(e:Event):void {
			if (focusLost) return;
			silentCounter++;
			if (silentCounter > 30) {
				pitchIndicatorArrow.visible = false;
				lohIndicatorBlock.visible = false;
				flashingCounter++;
				if (flashingCounter > 7) {
					flashingCounter = 0;
					inactiveText.visible = !inactiveText.visible;
				}
				return;
			}
			var i:int, idx:int;
			var tmp:Number, cur:Number;
			var pitchValid:Boolean = (currentPitch > 20 && currentPitch < 440);
			// update waveform
			waveform.graphics.clear();
			waveform.graphics.lineStyle(1, 0xffffff);
			waveform.graphics.moveTo(2, WAVEFORM_HEIGHT/2);
			for (i = 0; i < waveformBuffer.length; i++) {
				tmp = Math.min(Math.abs(waveformBuffer[i] * 50), WAVEFORM_HEIGHT/2);
				waveform.graphics.moveTo(i * 2 + 2, WAVEFORM_HEIGHT / 2 - tmp);
				waveform.graphics.lineTo(i * 2 + 2, WAVEFORM_HEIGHT / 2 + tmp);
			}
			
			var pitchText:String = (currentPitch > 10 && currentPitch < 440) ? String(Math.round(currentPitch*10)/10) + 'HZ' : 'N/A';
			freqText.text = 'DETECTED FREQ: ' + pitchText;
			freqText.setTextFormat(new TextFormat('QuartzMS', 14, 0xffffff));
			inactiveText.visible = false;
			
			if (Math.abs(gaugeTargetX - gaugeTrack.x) < 0.5) { 
				gaugeTrack.x = gaugeTargetX;
			} else {
				gaugeTrack.x = gaugeTrack.x + 0.15 * (gaugeTargetX - gaugeTrack.x);
			}
			
			rightArrow.visible = (gaugeTargetX - gaugeTrack.x > GAUGE_WIDTH / 2);
			leftArrow.visible = (gaugeTargetX - gaugeTrack.x < -GAUGE_WIDTH / 2);
			
			// update pitch indicator
			if (pitchValid) {
				pitchIndicatorArrow.visible = true;
				lohIndicatorBlock.visible = true;
				// find matching pitch
				tmp = 10000;
				for (i = 0; i < guitarPitches.length; i++) {
					cur = Math.abs(guitarPitches[i] - currentPitch);
					if (cur < tmp) {
						tmp = cur;
						idx = i;
					}
				}
				// low ok high
				pitchIndicatorArrow.x = 40 + INDICATOR_ARROW_SPAN * idx;
				if (tmp < 1) {
					lohIndicatorBlock.x = 308;
				} else if (currentPitch > guitarPitches[idx]) {
					lohIndicatorBlock.x = 345;
				} else {
					lohIndicatorBlock.x = 271;
				}
				// gauge
				gaugeTargetX = GAUGE_WIDTH / 2 - (currentPitch - RULER_MIN_F) * RULER_SPAN;
			} else {
				pitchIndicatorArrow.visible = false;
				lohIndicatorBlock.visible = false;
			}
		}
		
		private function sampleDataHandler(e:SampleDataEvent):void {
			var i:int, j:int;
			var samplesToRead:int = e.data.bytesAvailable / 4;
			var fftResult:Vector.<Number>;
			var tmp:Vector.<Number>;
			var dc:Number;
			var curSample:Number;
			// downsampling to 11025/4 = 2756.25
			for (i = 0; i < samplesToRead; i++) {
				curSample = e.data.readFloat();
				sampleBuffer.push(curSample);
				if (i < WAVEFORM_LENGTH) waveformBuffer[i] = curSample;
			}
			while (sampleBuffer.length > SLICESIZE * 4) {
				tmp = sampleBuffer.slice(0, SLICESIZE * 4);
				aalpf.apply(tmp);
				for (i = 0; i < SLICESIZE * 4; i+=4) {
					fftBuffer.push(tmp[i]);
				}
				sampleBuffer = sampleBuffer.slice(SLICESIZE * 4);
			}
			if (fftBuffer.length > FFTSIZE) {
				tmp = fftBuffer.slice(0, FFTSIZE);
				// substract DC offset
				dc = 0;
				for (i = 0; i < FFTSIZE; i++) {
					dc += tmp[i];
				}
				dc /= FFTSIZE;
				for (i = 0; i < FFTSIZE; i++) {
					tmp[i] -= dc;
				}
				// fft
				fftResult = fft.computeReal(tmp);
				for (i = 0; i < FFTSIZE / 2; i++) {
					spectrum[i] = fftResult[i] * fftResult[i] + fftResult[i + FFTSIZE] * fftResult[i + FFTSIZE];
				}
				currentPitch = HPS(spectrum, FFTSIZE, samplingRate/4.0);
				fftBuffer = fftBuffer.slice(SLICESIZE);
			}
			silentCounter = 0;
		}
		
		// detect pitch using HPS
		// half-spectrum must be long enough to contain 3rd harmonic 
		public function HPS(halfSpectrum:Vector.<Number>, fftsize:int, fs:Number):Number {
			var n0:int = halfSpectrum.length;
			var n:int = Math.floor(halfSpectrum.length / 3.0);
			var sp1:Vector.<Number> = halfSpectrum.slice(0, n);
			var sp2:Vector.<Number> = new Vector.<Number>(n);
			var sp3:Vector.<Number> = new Vector.<Number>(n);
			var i:int, j:int;
			for (i = 1, j = 0; i < n0; i += 2, j++) {
				sp2[j] = (halfSpectrum[i] + halfSpectrum[i - 1]) * 0.5;
			}
			for (i = 2, j = 0; i < n0; i += 3, j++) {
				sp3[j] = (halfSpectrum[i] + halfSpectrum[i - 1] + halfSpectrum[i - 2]) * 0.3333333333333;
			}
			var max:Number = -1;
			var idx:int;
			for (i = 0; i < n; i++) {
				sp1[i] = sp1[i] * sp2[i] * sp3[i];
				if (sp1[i] > max) {
					max = sp1[i];
					idx = i;
				}
			}
			
			return idx * fs / fftsize;
			
		}

	}

}