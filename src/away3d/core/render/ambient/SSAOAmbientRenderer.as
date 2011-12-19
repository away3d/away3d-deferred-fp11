package away3d.core.render.ambient
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.data.DitherTextureModel;
	import away3d.textures.RenderTexture;
	import away3d.textures.Texture2DBase;

	import flash.display3D.Context3D;

	import flash.display3D.Context3DProgramType;

	use namespace arcane;

	public class SSAOAmbientRenderer extends AmbientRendererBase
	{
		private var _kernel : Vector.<Number>;
		private var _grainTexture : Texture2DBase;
		private var _data : Vector.<Number>;
		private var _attenuate : Boolean = false;

		public function SSAOAmbientRenderer()
		{
			super();
			initDistrKernel();
			_grainTexture = DitherTextureModel.getInstance().getTexture(4);
			// grain multiplier X, grain multiplier Y , uv conversion, 0
			_data = new <Number>[200, 0, .5, 0,
								// uv conversion scale, ssao offset
								0, 0, 0, .5,
								// sample radius, depth offset, average samples
								25, 0.00015, 1/8, 0
								];
		}

		public function get sampleRadius() : Number
		{
			return _data[8];
		}

		public function set sampleRadius(value : Number) : void
		{
			_data[8] = value;
		}

		public function get attenuate() : Boolean
		{
			return _attenuate;
		}

		public function set attenuate(value : Boolean) : void
		{
			if (value == _attenuate) return;
			_attenuate = value;
			invalidateShader();
		}

		private function invalidateShader() : void
		{
			if (_program) {
				_program.dispose();
				_program = null;
			}
		}

		private function initDistrKernel() : void
		{
			_kernel = new <Number>[
				0.355512,  -0.709318,  -0.102371, 0.0,
				0.534186,  0.71511,  -0.115167, 0.0,
				-0.87866,  0.157139,  -0.115167, 0.0,
				0.140679,  -0.475516,  -0.0639818, 0.0,
				-0.207641,  0.414286,  0.187755, 0.0,
				-0.277332,  -0.371262,  0.187755, 0.0,
				0.63864,  -0.114214,  0.262857, 0.0,
				-0.184051,  0.622119,  0.262857, 0.0
			];
		}

		override protected function getFragmentCode() : String
		{
			var code : String = super.getFragmentCode();
			var obscRegs : Array = [ "ft7.x", "ft7.y", "ft7.z", "ft7.w" ];
			var sampleRayReg : String;

			code += //"sub ft2.z, ft2.z, fc8.y\n"+
					"mul ft3, v0, fc6.xyww\n" +
					"tex ft3, ft3, fs1 <2d, nearest, wrap>\n" +
					"sub ft3.xyz, ft3.xyz, fc1.www\n" +
					"nrm ft3.xyz, ft3.xyz\n" +
					// random plane normal in ft3

					// need this later
					"mov ft4.w, fc0.x\n";

			var k : uint;
			var tgt : String;
			for (var i : uint = 0; i < 2; ++i) {
				for (var j : uint = 0; j < 4; ++j) {
					sampleRayReg = "fc"+((k++)+9);
					tgt = obscRegs[j];

					// I - 2*dot(I, N)*N
					code += "dp3 ft4.x, " + sampleRayReg + ", ft3.xyz\n" +
							"add ft4.x, ft4.x, ft4.x\n" +
							"mul ft4.xyz, ft3.xyz, ft4.x\n" +
							"sub ft4.xyz, " + sampleRayReg + ".xyz, ft4.xyz\n";

					// check orientation versus normal, and flip if necessary
					code += "dp3 ft5.x, ft4.xyz, ft1.xyz\n" +
							"slt ft5.x, ft5.x, fc6.w\n" +	// if < 0, add normal
							"mul ft5.xyz, ft5.x, ft1.xyz\n" +
							"add ft4.xyz, ft4.xyz, ft5.xyz\n";
							"mov ft4.xyz, ft5.xxx\n";

					// set to sample radius and add to view pos
					code += "mul ft4.xyz, ft4.xyz, fc8.x\n" +
							"add ft4.xyz, ft4.xyz, ft0.xyz\n";

					// project and convert to uv coords
					code += "m44 ft4, ft4, fc2\n" +
							"div ft4, ft4, ft4.w\n" +
							"mul ft4.xy, ft4.xy, fc7.xy\n" +
							"add ft4.xy, ft4.xy, fc6.zz\n";


					// sample and decode depth (just need normalized depth)
					code +=	"tex ft4, ft4, fs0 <2d,nearest,clamp>\n" +
							"dp3 "+tgt+", ft4.zww, fc0.xyz\n";
				}


				// we can calculate stuff for 4 elements at once == less instructions

				// depth difference
				code += "sub ft4, ft2.zzzz, ft7\n";

				// close enough?
				code += "div ft5, ft4, ft2.zzzz\n" +
						"sat ft5, ft5\n";

				// conditional, if scene depth > sample depth
				code += "slt ft4, ft4, fc6.wwww\n";

				// add to occlusion
				code += "sub ft7, fc7.wwww, ft4\n" +
						"mul ft7, ft7, ft5\n";

				if (i == 0)
					code += "add ft6, ft4, ft7\n";
				else {
					code += "add ft4, ft4, ft7\n" +
							"add ft6, ft6, ft4\n";
				}
			}

			code += "dp4 ft6.x, ft6, fc8.zzzz\n";	// add all together whilst multiplying average

			if (_attenuate) {
				code +=	"mul ft7.x, ft6.x, ft6.x\n" +
						"add ft6.x, ft6.x, ft7.x\n";
			}
			code += "sat ft6.x, ft6.x\n" +
					"mul ft4.xyz, fc1.xyz, ft6.xxx\n" +
					// must output 0 for w!
					"mov ft4.w, fc6.w\n" +
					"mov oc, ft4\n";

			return code;
		}

		arcane override function render(normalDepthBuffer : RenderTexture, frustumCorners : Vector.<Number>, camera : Camera3D, ambientR : Number, ambientG : Number, ambientB : Number) : void
		{
			var context : Context3D = _stage3DProxy._context3D;
			context.setProgramConstantsFromMatrix(Context3DProgramType.FRAGMENT, 2, camera.lens.matrix, true);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 6, _data, 3);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 9, _kernel, 8);
			_stage3DProxy.setTextureAt(1, _grainTexture.getTextureForStage3D(_stage3DProxy));

			_data[0] = _rttManager.textureWidth/4;
			_data[1] = _rttManager.textureHeight/4;
			_data[4] = _rttManager.textureRatioX*.5;
			_data[5] = -_rttManager.textureRatioY*.5;

			super.render(normalDepthBuffer, frustumCorners, camera, ambientR, ambientG, ambientB);
			_stage3DProxy.setTextureAt(1, null);
		}

		override public function dispose() : void
		{
			super.dispose();
			DitherTextureModel.getInstance().freeTexture(4);
		}
	}
}
