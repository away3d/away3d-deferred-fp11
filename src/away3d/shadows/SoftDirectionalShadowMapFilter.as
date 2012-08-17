package away3d.shadows
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.DirectionalLight;

	use namespace arcane;

	public class SoftDirectionalShadowMapFilter extends DirectionalShadowMapFilterBase
	{
		private var _numSamples : uint;
		private var _radius : Number;

		public function SoftDirectionalShadowMapFilter(numSamples : uint = 5, radius : Number = 1)
		{
			super(2, true);
			if (numSamples < 1) numSamples = 1;
			else if (numSamples > 9) numSamples = 9;
			_numSamples = numSamples;
			_data[5] = 1/numSamples;
			_radius = radius;
		}

		public function get radius() : Number
		{
			return _radius;
		}

		public function set radius(value : Number) : void
		{
			_radius = value;
		}

		override arcane function getSampleCode(numCascades : uint) : String
		{
			var decodeReg : String = getConstantRegister(numCascades, 0);
			var dataReg : String = getConstantRegister(numCascades, 1);
			var code : String =
					"tex ft1, ft0, fs3 <2d, nearest, clamp>\n" +
					"dp4 ft1.z, ft1, " + decodeReg  + "\n" +
					"add ft0.w, ft0.z, " + dataReg + ".x\n" +    // offset by epsilon
					"slt ft6.w, ft0.w, ft1.z\n";

			if (_numSamples > 1)
				code += "mul ft2.xy, " + dataReg + ".zw, ft5.xy\n" + 	// scale for quadrant

						"add ft1.xy, ft0.xy, ft2.yy\n" +	// (-1, -1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 5)
				code += "add ft1.xy, ft1.xy, ft2.yy\n" +	// (-2, -2)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 2)
				code += "add ft1.xy, ft0.xy, ft2.xy\n" +	// (1, -1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 6)
				code += "add ft1.xy, ft1.xy, ft2.xy\n" +	// (1, -1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 3)
				code += "add ft1.xy, ft0.xy, ft2.yx\n" +	// (-1, 1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 7)
				code += "add ft1.xy, ft1.xy, ft2.yx\n" +	// (-1, 1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 4)
				code += "add ft1.xy, ft0.xy, ft2.xx\n" +	// (1, 1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			if (_numSamples > 8)
				code += "add ft1.xy, ft1.xy, ft2.xx\n" +	// (1, 1)
						"tex ft5, ft1, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft5.z, ft5, " + decodeReg  + "\n" +
						"slt ft3.w, ft0.w, ft5.z\n" +
						"add ft6.w, ft6.w, ft3.w\n";

			code += "mul ft0.w, ft6.w, " + dataReg + ".y\n";   // 0 if in shadow

			return code;
		}


		override arcane function activate(stage3DProxy : Stage3DProxy, light : DirectionalLight, numCascades : uint) : void
		{
			_data[6] = _radius;
			_data[7] = -_radius;
			super.activate(stage3DProxy, light, numCascades);
		}
	}
}
