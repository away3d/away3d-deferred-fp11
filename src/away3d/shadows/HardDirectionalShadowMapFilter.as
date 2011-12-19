package away3d.shadows
{
	import away3d.arcane;

	use namespace arcane;

	public class HardDirectionalShadowMapFilter extends DirectionalShadowMapFilterBase
	{
		public function HardDirectionalShadowMapFilter()
		{
			super(2);
		}

		override arcane function getSampleCode(numCascades : uint) : String
		{
			var decodeReg : String = getConstantRegister(numCascades, 0);
			var dataReg : String = getConstantRegister(numCascades, 1);

			return 	"tex ft1, ft0, fs3 <2d, nearest, clamp>\n" +
					"dp4 ft1.z, ft1, " + decodeReg  + "\n" +
					"add ft0.w, ft0.z, " + dataReg + ".x\n" +    // offset by epsilon
					"slt ft0.w, ft0.w, ft1.z\n";   // 0 if in shadow
		}
	}
}
