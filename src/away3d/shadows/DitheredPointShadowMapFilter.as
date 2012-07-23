package away3d.shadows
{
	import away3d.arcane;
	import away3d.core.data.DitherTextureModel;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.PointLight;
	import away3d.textures.Texture2DBase;

	use namespace arcane;

	public class DitheredPointShadowMapFilter extends PointShadowMapFilterBase
	{
		private var _numSamples : uint;
		private var _grainTexture : Texture2DBase;
		private var _animateGrain : Boolean = false;
		private var _radius : Number;

		public function DitheredPointShadowMapFilter(numSamples : uint = 5, radius : Number = .5)
		{
			_numSamples = numSamples;
			_radius = radius*.05;

			super(2);

			depthOffset = .005;

			_data[5] = 1/numSamples;
			_grainTexture = DitherTextureModel.getInstance().getTexture();
		}

		public function get animateGrain() : Boolean
		{
			return _animateGrain;
		}

		public function set animateGrain(value : Boolean) : void
		{
			_animateGrain = value;
		}

		public function get radius() : Number
		{
			return _radius;
		}

		public function set radius(value : Number) : void
		{
			_radius = value;
		}

		override arcane function getSampleCode() : String
		{
			var decodeReg : String = getConstantRegister(0);
			var dataReg : String = getConstantRegister(1);
			var code : String;

			// randomize dither
			code = 	"add ft0.w, ft0.w, " + dataReg + ".x\n" +    // offset by epsilon
					"mul ft6.xy, v0.xy, " + dataReg + ".w\n";

			for (var i : uint = 0; i < _numSamples; ++i) {
				code += "tex ft3, ft6, fs4 <2d, nearest, wrap>\n" +
						"mul ft3.xyz, ft3.xyz, fc3.xx\n" +
						"add ft3.xyz, ft3.xyz, ft3.xyz\n" +
						"mul ft3.xyz, ft3.xyz, " + dataReg + ".z\n" +
						"add ft3.xyz, ft3.xyz, ft0.xyz\n" +
//						"nrm ft3.xyz, ft3.xyz\n" +
						"tex ft1, ft3, fs3 <cube, nearest, clamp>\n" +
						"dp4 ft1.z, ft1, " + decodeReg  + "\n";
				if (i == 0) {
					code += "slt ft2.w, ft0.w, ft1.z\n";
				}
				else {
					code += "slt ft2.z, ft0.w, ft1.z\n" +
							"add ft2.w, ft2.w, ft2.z\n";
				}

				code += "add ft6.xy, ft6.xy, ft6.xy\n"
			}

			code += "mul ft0.w, ft2.w, " + dataReg + ".y\n";

			return 	code;
		}

		arcane override function activate(stage3DProxy : Stage3DProxy, light : PointLight) : void
		{
			_data[6] = _radius/light.shadowMapper.depthMapSize;
			_data[7] = _animateGrain? 200 + 100*Math.random() : 200;
			stage3DProxy.setTextureAt(4, _grainTexture.getTextureForStage3D(stage3DProxy));
			super.activate(stage3DProxy, light);
		}

		arcane override function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			stage3DProxy.setTextureAt(4, null);
		}

		arcane override function dispose() : void
		{
			// be sure disposing twice doesn't mess with things
			if (_grainTexture) {
				DitherTextureModel.getInstance().freeTexture();
				_grainTexture = null;
			}
		}
	}
}
