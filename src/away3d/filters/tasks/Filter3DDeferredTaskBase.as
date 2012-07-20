package away3d.filters.tasks
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.core.render.DeferredRenderer;

	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.textures.Texture;

	use namespace arcane

	public class Filter3DDeferredTaskBase extends Filter3DTaskBase
	{
		protected var _renderer : DeferredRenderer;
		protected var _needsNormals : Boolean;
		protected var _needsPosition : Boolean;
		protected var _needsDepth : Boolean;
		protected var _data : Vector.<Number>;
		protected var _sourceSampleMode : String = "nearest";
		protected var _sampleSource : Boolean = true;

		public function Filter3DDeferredTaskBase(renderer : DeferredRenderer)
		{
			_renderer = renderer;
			_data = new <Number>[1, 1 / 255, .5, 1, 0, 0, 0, 0];
		}

		override public function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, depthTexture : Texture) : void
		{
			if (_needsDepth || _needsNormals || _needsPosition) {
				if (_needsPosition) {
					_data[4] = camera.lens.far;
					stage3DProxy.setSimpleVertexBuffer(2, RTTBufferManager.getInstance(stage3DProxy).renderToTextureVertexBuffer, Context3DVertexBufferFormat.FLOAT_1, 4);	// indices for frustum corners
					stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, _renderer.frustumCorners, 4);
				}
				stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 2);
				stage3DProxy.setTextureAt(1, _renderer.getNormalDepthBuffer().getTextureForStage3D(stage3DProxy));
			}
		}

		override public function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			if (_needsDepth || _needsNormals || _needsPosition) {
				if (_needsPosition)
					stage3DProxy.setSimpleVertexBuffer(2, null, null);

				stage3DProxy.setTextureAt(1, null);
			}
		}

		override protected function getVertexCode() : String
		{
			var code : String = super.getVertexCode();

			if (_needsPosition) {
				code += "mov vt0, vc[va2.x]\n" +
					// need frustum vector with z == 1, so we can scale correctly
						"div vt0.xyz, vt0.xyz, vt0.z\n" +
						"mov v1, vt0\n";
			}

			return code;
		}

		/**
		 * Things ye must know:
		 * v0 contains UV coords for current pixel
		 * v1 contains view direction
		 * fs0 and fs1 are reserved
		 * ft0, ft1 and ft2 are reserved
		 * ft0.xyz contains the normal, ft0.w contains the depth
		 * ft1 contains the view position
		 * output needs to write to and read from ft2 as source and target data
		 * fc0 and fc1 are reserved
		 */
		override protected function getFragmentCode() : String
		{
			var code : String = "";

			if (_sampleSource) code += "tex ft2, v0, fs0 <2d, "+_sourceSampleMode+", clamp>\n";

			if (_needsDepth || _needsNormals || _needsPosition) {
				code += "tex ft5, v0, fs1 <2d, nearest, clamp>\n";

				if (_needsDepth || _needsPosition) {
					code += getDecodeDepthCode();
					if (_needsPosition) code += getViewPosCode();
				}

				if (_needsNormals) code += getDecodeNormals();
			}

			return code;
		}

		private function getDecodeNormals() : String
		{
			// remap to [-1, 1]
			return 	"sub ft0.xy, ft5.xy, fc0.zz\n" +
					"add ft0.xy, ft0.xy, ft4.xy\n" +

				// z² = 1-(x*x+y*y)
					"mul ft0.z, ft0.x, ft0.x\n" +
					"mul ft3.w, ft2.y, ft2.y\n" +
					"add ft0.z, ft0.z, ft3.w\n" +
					"sub ft0.z, fc0.w, ft0.z\n" +

				// z = sqrt(z²)
					"sqt ft0.z, ft0.z\n" +
					"neg ft0.z, ft0.z\n";
		}

		private function getDecodeDepthCode() : String
		{
			return 	"mul ft4.xy, ft5.zw, fc0.xy\n" +
					"add ft0.w, ft4.x, ft4.y\n";
		}

		private function getViewPosCode() : String
		{
			return 	"mul ft1.w, ft0.w, fc1.x\n" +
					"mul ft1.xyz, ft1.w, v1.xyz\n" +
					"mov ft1.w, v1.w\n";
		}
	}
}
