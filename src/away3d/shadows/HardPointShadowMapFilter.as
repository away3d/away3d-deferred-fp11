package away3d.shadows
{
	import away3d.arcane;

	use namespace arcane;

	public class HardPointShadowMapFilter extends PointShadowMapFilterBase
	{
		public function HardPointShadowMapFilter()
		{
			super(2);
		}

		override arcane function getSampleCode() : String
		{
			var decodeReg : String = getConstantRegister(0);
			var dataReg : String = getConstantRegister(1);

			return 	"tex ft1, ft0, fs3 <cube, nearest, clamp>\n" +
					"dp4 ft1.z, ft1, " + decodeReg  + "\n" +
					"add ft0.w, ft0.w, " + dataReg + ".x\n" +    // offset by epsilon
					"slt ft0.w, ft0.w, ft1.z\n";   // 0 if in shadow
		}
	}
}
