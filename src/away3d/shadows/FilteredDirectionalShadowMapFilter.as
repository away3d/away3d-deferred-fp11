package away3d.shadows
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.DirectionalLight;

	use namespace arcane;

	public class FilteredDirectionalShadowMapFilter extends DirectionalShadowMapFilterBase
	{
		public function FilteredDirectionalShadowMapFilter()
		{
			super();
		}

		override arcane function getSampleCode(numCascades : uint) : String
		{
			var decodeReg : String = getConstantRegister(numCascades, 0);
			var dataReg : String = getConstantRegister(numCascades, 1);

			return 	"add ft0.w, ft0.z, " + dataReg + ".x\n" +    // offset by epsilon
					// get positional fraction
					"mul ft4.xy, ft0.xy, " + dataReg + ".z\n" +
					"frc ft4.x, ft4.x\n" +
					"frc ft4.y, ft4.y\n" +

					// top-left
					"tex ft1, ft0, fs3 <2d, nearest, clamp>\n" +
					"dp4 ft1.z, ft1, " + decodeReg  + "\n" +
					"slt ft1.z, ft0.w, ft1.z\n" +   // 0 if in shadow

					// top-right
					"add ft0.x, ft0.x, " + dataReg + ".y\n" +
					"tex ft2, ft0, fs3 <2d, nearest, clamp>\n" +
					"dp4 ft2.z, ft2, " + decodeReg  + "\n" +
					"slt ft2.z, ft0.w, ft2.z\n" +

					// bottom-right
					"add ft0.y, ft0.y, " + dataReg + ".y\n" +
					"tex ft3, ft0, fs3 <2d, nearest, clamp>\n" +
					"dp4 ft2.w, ft3, " + decodeReg  + "\n" +
					"slt ft2.w, ft0.w, ft2.w\n" +

					// bottom-left
					"sub ft0.x, ft0.x, " + dataReg + ".y\n" +
					"tex ft3, ft0, fs3 <2d, nearest, clamp>\n" +
					"dp4 ft1.w, ft3, " + decodeReg  + "\n" +
					"slt ft1.w, ft0.w, ft1.w\n" +

					// ft1.z = top left
					// ft2.z = top right
					// ft1.w = bottom left
					// ft2.w = bottom right

				// lerp on x
					// ft1.zw = ft1.zw + t*(ft2.zw - ft1.zw)
					"sub ft2, ft2, ft1\n" +
					"mul ft2, ft2, ft4.x\n" +
					"add ft1, ft1, ft2\n" +

					// lerp on y
//					ft1.z = ft1.z + t*(ft1.w - ft1.z)
					"sub ft1.w, ft1.w, ft1.z\n" +
					"mul ft1.w, ft1.w, ft4.y\n" +
					"add ft0.w, ft1.z, ft1.w\n";
		}

		override arcane function activate(stage3DProxy : Stage3DProxy, light : DirectionalLight, numCascades : uint) : void
		{
			var depthMapSize : int = light.shadowMapper.depthMapSize;
			_data[5] = 1/depthMapSize;
			_data[6] = depthMapSize;
			super.activate(stage3DProxy, light, numCascades);
		}
	}
}
