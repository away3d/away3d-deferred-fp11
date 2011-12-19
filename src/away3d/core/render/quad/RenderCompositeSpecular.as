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

	public class RenderCompositeSpecular extends QuadRenderBase
	{
		public function RenderCompositeSpecular(stage3DProxy : Stage3DProxy)
		{
			super(stage3DProxy, false);
			_sourceBlendFactor = Context3DBlendFactor.ONE;
			_destBlendFactor = Context3DBlendFactor.ONE;
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

				// use a normalized version of the light colour as the specular colour. It's not correct vis a vis rendering equation, but should look natural.
					"nrm ft0.xyz, ft0.xyz\n" +
					"mul ft0.xyz, ft0.xyz, ft0.w\n" +

					"mov oc, ft0";
		}
	}
}
