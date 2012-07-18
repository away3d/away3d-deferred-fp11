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

	import flash.display3D.Context3DCompareMode;

	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;

	import flash.display3D.Program3D;
	import flash.display3D.textures.TextureBase;

	use namespace arcane;

	public class RenderDebugDepth extends QuadRenderBase
	{
		private var _data : Vector.<Number>;

		public function RenderDebugDepth(stage3DProxy : Stage3DProxy)
		{
			super(stage3DProxy);
			_data = new <Number>[ 1, 1/255, 0, 1 ];
		}

		public function execute(source : RenderTexture, target : TextureBase) : void
		{
			_stage3DProxy.setTextureAt(0, source.getTextureForStage3D(_stage3DProxy));
			_stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 1);
			render(target);
			_stage3DProxy.setTextureAt(0, null);
		}

		private function initProgram(stage3DProxy : Stage3DProxy) : void
		{
			_program = stage3DProxy._context3D.createProgram();
			_program.upload( 	new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getVertexCode()),
								new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getFragmentCode()));
		}

		override protected function getFragmentCode() : String
		{
			return 	"tex ft0, v0, fs0 <2d,nearest,clamp>\n" +
					"mul ft5.xy, ft0.zw, fc0.xy\n" +
					"add ft6.z, ft5.x, ft5.y\n" +
					"mov ft6.w, fc0.w\n" +
					"mov oc, ft6.zzzw";
		}


	}
}
