package away3d.core.render.quad
{
	import away3d.arcane;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;
	import away3d.events.Stage3DEvent;

	import com.adobe.utils.AGALMiniAssembler;

	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;

	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.TextureBase;

	use namespace arcane;

	public class QuadRenderBase
	{
		protected var _program : Program3D;
		protected var _stage3DProxy : Stage3DProxy;
		protected var _rttManager : RTTBufferManager;
		protected var _context : Context3D;
		protected var _sourceBlendFactor : String = Context3DBlendFactor.ONE;
		protected var _destBlendFactor : String = Context3DBlendFactor.ZERO;
		private var _clearOnRender : Boolean;

		public function QuadRenderBase(stage3DProxy : Stage3DProxy, clearOnRender : Boolean = true)
		{
			_clearOnRender = clearOnRender;
			_stage3DProxy = stage3DProxy;
			if (_stage3DProxy._context3D)
				_context = _stage3DProxy._context3D;
			else
				_stage3DProxy.addEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContext3DCreated);
			_rttManager = RTTBufferManager.getInstance(stage3DProxy);
		}

		private function onContext3DCreated(event : Stage3DEvent) : void
		{
			_stage3DProxy.removeEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContext3DCreated);
			_context = _stage3DProxy.context3D;
		}

		protected function render(target : TextureBase) : void
		{
			var vertexBuffer : VertexBuffer3D = target? _rttManager.renderToTextureVertexBuffer : _rttManager.renderToScreenVertexBuffer;

			if (!_program) initProgram();

			_stage3DProxy.setRenderTarget(target);

			if (_clearOnRender) _context.clear(.5, .5, .5, 0);

			_stage3DProxy.setSimpleVertexBuffer(0, vertexBuffer, Context3DVertexBufferFormat.FLOAT_2, 0);
			_stage3DProxy.setSimpleVertexBuffer(1, vertexBuffer, Context3DVertexBufferFormat.FLOAT_2, 2);

			_stage3DProxy.setProgram(_program);

			_context.setBlendFactors(_sourceBlendFactor, _destBlendFactor);
			_context.setDepthTest(false, Context3DCompareMode.ALWAYS);

			_context.drawTriangles(_rttManager.indexBuffer, 0, 2);

			_stage3DProxy.setSimpleVertexBuffer(0, null, null);
			_stage3DProxy.setSimpleVertexBuffer(1, null, null);
		}

		private function initProgram() : void
		{
			_program = _context.createProgram();
			_program.upload( 	new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getVertexCode()),
								new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getFragmentCode()));
		}

		protected function getVertexCode() : String
		{
			return	"mov op, va0\n" +
					"mov v0, va1\n";
		}

		protected function getFragmentCode() : String
		{
			throw new AbstractMethodError();
		}

		public function dispose() : void
		{
			if (_program) _program.dispose();
			_stage3DProxy.removeEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContext3DCreated);
			_stage3DProxy = null;
		}

		protected function invalidateShader() : void
		{
			if (_program) {
				_program.dispose();
				_program = null;
			}
		}
	}
}
