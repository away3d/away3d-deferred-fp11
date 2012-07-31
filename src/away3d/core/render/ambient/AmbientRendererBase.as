package away3d.core.render.ambient
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.events.Stage3DEvent;
	import away3d.textures.RenderTexture;

	import com.adobe.utils.AGALMiniAssembler;

	import flash.display3D.Context3D;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;

	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.events.EventDispatcher;

	use namespace arcane;

	public class AmbientRendererBase extends EventDispatcher
	{
		// need to tell
		arcane static const BLUR_CHANGED : String = "blurChanged";

		protected var _program : Program3D;
		protected var _stage3DProxy : Stage3DProxy;
		protected var _rttManager : RTTBufferManager;
		protected var _context : Context3D;
		private var _fragmentData : Vector.<Number>;
		private var _blur : Number = 4;

		public function AmbientRendererBase()
		{
			_fragmentData = new <Number>[	// depth decoding, 0, camera far
											1, 1/255, 0, 1,
											// ambient colour, normal decoding
											0, 0, 0, .5];
		}

		public function get blur() : Number
		{
			return _blur;
		}

		public function set blur(value : Number) : void
		{
			if (value < 0) value = 0;
			if (_blur == value) return;
			_blur = value;

			dispatchEvent(new Event(BLUR_CHANGED));
		}

		public function get stage3DProxy() : Stage3DProxy
		{
			return _stage3DProxy;
		}

		public function set stage3DProxy(value : Stage3DProxy) : void
		{
			if (!value) return;

			_stage3DProxy = value;
			if (_stage3DProxy._context3D)
				_context = _stage3DProxy.context3D;
			else
				_stage3DProxy.addEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContext3DCreated);

			_rttManager = RTTBufferManager.getInstance(value);
		}

		private function onContext3DCreated(event : Stage3DEvent) : void
		{
			_stage3DProxy.removeEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContext3DCreated);
			_context = _stage3DProxy.context3D;
		}

		arcane function render(normalDepthBuffer : RenderTexture, frustumCorners : Vector.<Number>, camera : Camera3D, ambientR : Number, ambientG : Number, ambientB : Number) : void
		{
			var vertexBuffer : VertexBuffer3D = _rttManager.renderToTextureVertexBuffer;

			_fragmentData[3] = camera.lens.far;
			_fragmentData[4] = ambientR;
			_fragmentData[5] = ambientG;
			_fragmentData[6] = ambientB;

			if (!_program) initProgram();

			_stage3DProxy.setSimpleVertexBuffer(0, vertexBuffer, Context3DVertexBufferFormat.FLOAT_2, 0);
			_stage3DProxy.setSimpleVertexBuffer(1, vertexBuffer, Context3DVertexBufferFormat.FLOAT_2, 2);
			_stage3DProxy.setSimpleVertexBuffer(2, vertexBuffer, Context3DVertexBufferFormat.FLOAT_1, 4);

			_stage3DProxy.setTextureAt(0, normalDepthBuffer.getTextureForStage3D(_stage3DProxy));

			_context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, frustumCorners, 4);
			_context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _fragmentData, 2);

			_stage3DProxy.setProgram(_program);

			_context.setDepthTest(false, Context3DCompareMode.ALWAYS);

			_context.drawTriangles(_rttManager.indexBuffer, 0, 2);

			_stage3DProxy.setSimpleVertexBuffer(0, null, null);
			_stage3DProxy.setSimpleVertexBuffer(1, null, null);
			_stage3DProxy.setSimpleVertexBuffer(2, null, null);
			_stage3DProxy.setTextureAt(0, null);
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
					"mov v0, va1\n" +
					// get frustum corners (will end up being view vector that can scale with
					"mov vt0, vc[va2.x]\n" +
					// need frustum vector with z == 1, so we can scale correctly
					"div vt0.xyz, vt0.xyz, vt0.z\n" +
					"mov v1, vt0\n";
		}

		/**
		 * If you call super(), it will already provide the code containing the eye space position in ft0, normal in ft1, original normalized depth in ft2.z!
		 * Otherwise, you can strip the code from below
		 *
		 * OUTPUT.W MUST BE 0! (is specular)
		 */
		protected function getFragmentCode() : String
		{
			var code : String = "tex ft2, v0, fs0 <2d,nearest,clamp>\n" +

								"dp3 ft2.z, ft2.zww, fc0.xyz\n" +
								"mul ft6.z, ft2.z, fc0.w\n" +
								"mul ft0.xyz, ft6.z, v1.xyz\n" +
								"mov ft0.w, v1.w\n" +

					// calc normal
								"sub ft1.xy, ft2.xy, fc1.ww\n" +
								"add ft1.xy, ft1.xy, ft1.xy\n" +
								"mul ft1.z, ft1.x, ft1.x\n" +
								"mul ft1.w, ft1.y, ft1.y\n" +
								"add ft1.z, ft1.z, ft1.w\n" +
								"sub ft1.z, fc0.x, ft1.z\n" + // z² = 1-(x*x+y*y)
								"sqt ft1.z, ft1.z\n" +
								"neg ft1.z, ft1.z\n";
			return code;
		}

		public function dispose() : void
		{
			_program.dispose();
			_stage3DProxy.removeEventListener(Stage3DEvent.CONTEXT3D_CREATED, onContext3DCreated);
			_stage3DProxy = null;
		}
	}
}
