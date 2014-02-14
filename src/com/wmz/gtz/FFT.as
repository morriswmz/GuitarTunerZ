package com.wmz.gtz 
{
	/**
	 * ...
	 * @author morriswmz
	 */
	public final class FFT 
	{
		private var windowCoeffs:Vector.<Number>;
		private var _length:int;
		
		public function FFT(length:int, windowType:String) 
		{
			if (!((length != 0) && (length & (length - 1)) == 0)) {
				throw new Error('Vector length must be a power of 2.');
			}
			_length = length;
			windowCoeffs = WindowFunc.generate(windowType, _length, false);
		}
		
		// result vector has 2N numbers : [re im]
		public function computeReal(p_re:Vector.<Number>):Vector.<Number> {
			if (p_re.length != _length) {
				throw new Error('Vector length mismatch.');
			}
			var tmpr:Vector.<Number> = new Vector.<Number>(_length);
			var tmpi:Vector.<Number> = new Vector.<Number>(_length);
			for (var i:int = 0; i < _length; i++) {
				tmpr[i] = p_re[i] * windowCoeffs[i];
				tmpi[i] = 0.0;
			}
			compute(tmpr, tmpi, true, true);
			return tmpr.concat(tmpi);
		}
		
		
		
		private function bitReverse(p_seq:Vector.<Number>):void {
			var n:int = p_seq.length;
			var n2:int = n >> 1;
			var ret:Vector.<Number> = p_seq;
			var k:int; // current index inside current group
			var l:int; // current group size, 2^E
			var i:int; // current sequence index
			var r:int; // offset, 2^(log2N - E - 1)
			var j:Vector.<int> = new Vector.<int>(n >> 1); // swap index table
			var tmp:Number;
			// init
			j[0] = 0; j[1] = n2;
			tmp = ret[1];
			ret[1] = ret[n2];
			ret[n2] = tmp;
			for (i = 2, l = 2, r = n2 >> 1; r > 0; l <<= 1, r >>= 1) {
				for (k = 0; k < l; k++, i++) {
					j[i] = j[k] + r;
					if (i < j[i]) {
						tmp = ret[i];
						ret[i] = ret[j[i]];
						ret[j[i]] = tmp;
					}
				}
			}
		}
		
		// inplace fft
		private function compute(p_re:Vector.<Number>, p_im:Vector.<Number>, forward:Boolean = true, real:Boolean = true):void {
			var i:int;
			var n:int = _length;
			var inv_n:Number;
			// init result vector
			var resr:Vector.<Number> = p_re;
			var resi:Vector.<Number> = p_im;
			bitReverse(resr);
			// no need to reverse 0 sequence
			if (!real) bitReverse(resi);
			
			// fft
			var nWings:int = 1;
			var istep:int;
			var pos:int;
			var posStep:int = n >> 1;
			var wr:Number, wi:Number;
			var wpr:Number, wpi:Number;
			var theta:Number;
			var m:int, k:int, l:int;
			var pi:Number = forward ? -Math.PI:Math.PI;
			var tmpi:Number, tmpr:Number;
			
			while (n > nWings) {
				istep = nWings + nWings;
				theta = pi / nWings;
				wpi = Math.sin(theta);
				wpr = Math.sin(theta / 2.0);
				wpr = 1.0 - 2.0 * wpr * wpr;
				wi = 0;
				wr = 1.0;
				for (m = 1; m <= nWings; m++) {
					for (k = m - 1; k < n; k += istep) {
						l = k + nWings;
						tmpr = wr * resr[l] - wi * resi[l];
						tmpi = wr * resi[l] + wi * resr[l];
						resr[l] = resr[k] - tmpr;
						resi[l] = resi[k] - tmpi;
						resr[k] = resr[k] + tmpr;
						resi[k] = resi[k] + tmpi;
					}
					tmpr = wr;
					wr = wr * wpr - wi * wpi;
					wi = wr * wpi + wi * wpr;
				}
				posStep >>= 1;
				nWings = istep;
			}
			// scaling
			if (!forward) {
				inv_n = 1.0 / n;
				for (m = 0; m < n;m++) {
					resr[m] *= inv_n;
					resi[m] *= inv_n;
				}
			}
			
		}
		
		
		
	}

}