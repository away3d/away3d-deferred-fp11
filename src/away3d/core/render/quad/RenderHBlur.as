/**
 *
 */
package away3d.core.render.quad
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.textures.RenderTexture;

	import flash.display3D.Context3DProgramType;

	import flash.display3D.textures.TextureBase;

	use namespace arcane;

	public class RenderHBlur extends QuadRenderBase
	{
		private var _amount : Number = 4;
		private var _data : Vector.<Number>;

		// it's usually cheaper to just take uneven numbers for amount
		public function RenderHBlur(stage3DProxy : Stage3DProxy)
		{
			super(stage3DProxy);
			_data = new Vector.<Number>(4, true);
		}

		public function get amount() : Number
		{
			return _amount;
		}

		public function set amount(value : Number) : void
		{
			if (_amount == value) return;
			_amount = value;
			invalidateShader();
		}

		public function execute(source : RenderTexture, target : TextureBase) : void
		{
			_stage3DProxy.setTextureAt(0, source.getTextureForStage3D(_stage3DProxy));

			// amount in texture space
			_data[0] = ((_amount-1)*.5)/_rttManager.textureWidth;
			// step size
			_data[1] = 1/_rttManager.textureWidth;
			// average
			_data[2] = 1/_amount;

			_stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 1);

			render(target);

			_stage3DProxy.setTextureAt(0, null);
		}

		override protected function getFragmentCode() : String
		{
			var code : String;

			code = 	"mov ft0, v0\n" +
					"sub ft0.x, ft0.x, fc0.x\n";

			for (var i : int = 0; i < _amount; ++i) {
				if (i == 0) {
					code += "tex ft1, ft0, fs0 <2d,nearest,wrap>\n";
				}
				else {
					code += "tex ft2, ft0, fs0 <2d,nearest,wrap>\n" +
							"add ft1, ft1, ft2\n";
				}

				if (i < _amount - 1) {
					code += "add ft0.x, ft0.x, fc0.y\n";
				}
			}

			code += "mul oc, ft1, fc0.z\n";

			return code;
		}
	}
}
