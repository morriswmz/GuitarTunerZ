package com.wmz.gtz 
{
	/**
	 * 	Biquad low pass filter
	 * @author morriswmz
	 */
	public final class LPF 
	{
		private var b0:Number;
		private var b1:Number;
		private var b2:Number;
		private var a0:Number;
		private var a1:Number;
		private var a2:Number;
		private var w1:Number;
		private var w2:Number;
		private var x_1:Number;
		private var x_2:Number;
		private var y_0:Number;
		private var y_1:Number;
		private var y_2:Number;
		
		private var buffer:Vector.<Number>;
		
		private static const M_LN2:Number = 0.69314718055994530942;
		
		public function LPF(fc:Number, fs:Number) 
		{
			var omega:Number = 2 * Math.PI * fc / fs;
			var sn:Number = Math.sin(omega);
			var cs:Number = Math.cos(omega);
			var alpha:Number = 2 * sn / 0.707; // Q = 0.707
			b0 = (1.0 - cs) / 2.0;
			b1 = 1.0 - cs;
			b2 = (1.0 - cs) / 2.0;
			a0 = 1.0 + alpha;
			a1 = -2.0 * cs;
			a2 = 1.0 - alpha;
			b0 /= a0;
			b1 /= a0;
			b2 /= a0;
			w1 = - a1 / a0;
			w2 = - a2 / a0;
			x_1 = 0.0;
			x_2 = 0.0;
			y_0 = 0.0;
			y_1 = 0.0;
			y_2 = 0.0;
			buffer = new Vector.<Number>();
		}
		
		public function apply(vec:Vector.<Number>):void {
			var n:int = vec.length;
			var i:int;
			buffer[0] = w1 * y_1 + w1 * y_2 + b0 * vec[0] + b1 * x_1 +b2 * x_2;
			buffer[1] = w1 * buffer[0] + w1 * y_1 + b0 * vec[1] + b1 * vec[0] +b2 * x_1;
			for (i = 2; i < n; i++) {
				buffer[i] = w1 * buffer[i - 1] + w2 * buffer[i - 2] + b0 * vec[i] + b1 * vec[i - 1] + b2 * vec[i - 2];
			}
			x_1 = vec[n - 1];
			x_2 = vec[n - 2];
			y_1 = buffer[i - 1];
			y_2 = buffer[i - 2];
			for (i = 0; i < n; i++) {
				vec[i] = buffer[i];
			}
		}
		
	}

}