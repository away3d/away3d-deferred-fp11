package away3d.core.render.quad
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;
	import away3d.lights.DirectionalLight;
	import away3d.textures.RenderTexture;

	import com.adobe.utils.AGALMiniAssembler;

	import flash.display3D.Context3DBlendFactor;

	import flash.display3D.Context3DProgramType;

	import flash.display3D.Program3D;
	import flash.display3D.textures.TextureBase;

	use namespace arcane;

	public class RenderCompositeDiffuse extends QuadRenderBase
	{
		public function RenderCompositeDiffuse(stage3DProxy : Stage3DProxy)
		{
			super(stage3DProxy, false);
			_sourceBlendFactor = Context3DBlendFactor.ZERO;
			_destBlendFactor = Context3DBlendFactor.SOURCE_COLOR;
		}

		public function execute(lightBuffer : RenderTexture, target : TextureBase) : void
		{
			_stage3DProxy.setTextureAt(0, lightBuffer.getTextureForStage3D(_stage3DProxy));

			render(target);

			_stage3DProxy.setTextureAt(0, null);
		}

		override protected function getFragmentCode() : String
		{
			return 	"tex ft0, v0, fs0 <2d,nearest,clamp>\n" +
					"mov oc, ft0\n";
		}
	}
}
