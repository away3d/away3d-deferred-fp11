package away3d.core.render.quad
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;
	import away3d.lights.DirectionalLight;
	import away3d.textures.RenderTexture;

	import com.adobe.utils.AGALMiniAssembler;

	import flash.display3D.Context3DProgramType;

	import flash.display3D.Program3D;
	import flash.display3D.textures.TextureBase;

	use namespace arcane;

	public class RenderDebugNormals extends QuadRenderBase
	{
		private var _data : Vector.<Number>;

		public function RenderDebugNormals(stage3DProxy : Stage3DProxy)
		{
			super(stage3DProxy);
			_data = new <Number>[ .5, 0, 0, 1 ];
		}

		public function execute(source : RenderTexture, target : TextureBase) : void
		{
			_stage3DProxy.setTextureAt(0, source.getTextureForStage3D(_stage3DProxy));

			_context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 1);

			render(target);
			_stage3DProxy.setTextureAt(0, null);
			_stage3DProxy.setTextureAt(0, null);
		}

		override protected function getFragmentCode() : String
		{
			return 	"tex ft0, v0, fs0 <2d,nearest,clamp>\n" +

					"sub ft2.xy, ft0.xy, fc0.xx\n" +
					"add ft2.xy, ft2.xy, ft2.xy\n" +
					"mul ft2.z, ft2.x, ft2.x\n" +
					"mul ft2.w, ft2.y, ft2.y\n" +
					"add ft2.z, ft2.z, ft2.w\n" +
					"sub ft2.z, fc0.w, ft2.z\n" +
					"mul ft2.xyz, ft2.xyz, fc0.x\n" +
					"add ft2.xyz, ft2.xyz, fc0.x\n" +
					"mov ft2.w, fc0.w\n" +
					"mov oc, ft2"; // z² = 1-(x*x+y*y)
		}
	}
}
