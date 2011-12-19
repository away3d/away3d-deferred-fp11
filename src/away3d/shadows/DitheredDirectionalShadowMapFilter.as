package away3d.shadows
{
	import away3d.arcane;
	import away3d.core.data.DitherTextureModel;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.DirectionalLight;
	import away3d.textures.Texture2DBase;

	use namespace arcane;

	public class DitheredDirectionalShadowMapFilter extends DirectionalShadowMapFilterBase
	{
		private var _numSamples : uint;
		private var _grainTexture : Texture2DBase;
		private var _animateGrain : Boolean = false;

		public function DitheredDirectionalShadowMapFilter(numSamples : uint = 5, radius : Number = 1)
		{
			_numSamples = numSamples;

			super(2, true);

			_data[5] = 1/numSamples;
			_data[6] = radius;

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
			return _data[6];
		}

		public function set radius(value : Number) : void
		{
			_data[6] = value;
		}

		// todo: consider using screen-space coordinates for the dither sample coords, so the grain can stay constant
		override arcane function getSampleCode(numCascades : uint) : String
		{
			var decodeReg : String = getConstantRegister(numCascades, 0);
			var dataReg : String = getConstantRegister(numCascades, 1);
			var scaleReg : String = getConstantRegister(numCascades, 2);
			var code : String;

			code = 	"add ft0.w, ft0.z, " + dataReg + ".x\n" +
					"mul ft6.xy, v0.xy, " + dataReg + ".w\n"; // scale uv coord for some random grain lookup

			for (var i : uint = 0; i < _numSamples; ++i) {
				code += "tex ft3, ft6, fs4 <2d, nearest, wrap>\n" +
						"mul ft3.xy, ft3.xy, fc3.xx\n" +
						"add ft3.xy, ft3.xy, ft3.xy\n" +
						"mul ft3.xy, ft3.xy, " + dataReg + ".z\n" +
						"mul ft3.xy, ft3.xy, ft5.xy\n" +
						"add ft3.xy, ft3.xy, ft0.xy\n" +
						"tex ft1, ft3.xy, fs3 <2d, nearest, clamp>\n" +
						"dp4 ft1.z, ft1, " + decodeReg  + "\n";
				if (i == 0) {
					code += "slt ft2.w, ft0.w, ft1.z\n";   // 0 if in shadow
				}
				else {
					code += "slt ft2.z, ft0.w, ft1.z\n" +
							"add ft2.w, ft2.w, ft2.z\n";
				}
				code += "add ft6.xy, ft6.xy, ft6.xy\n"
			}

			code += "mul ft0.w, ft2.w, " + dataReg + ".y\n";

			return code;
		}

		arcane override function activate(stage3DProxy : Stage3DProxy, light : DirectionalLight, numCascades : uint) : void
		{
			_data[7] = _animateGrain? 200 + 200*Math.random() : 200;
			// just some random large number to scale uv for random grain coord
			stage3DProxy.setTextureAt(4, _grainTexture.getTextureForStage3D(stage3DProxy));
			super.activate(stage3DProxy, light, numCascades);
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
