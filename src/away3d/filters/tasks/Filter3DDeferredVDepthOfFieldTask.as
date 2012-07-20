package away3d.filters.tasks
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.core.render.DeferredRenderer;
	import away3d.filters.tasks.*;

	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.textures.Texture;

	use namespace arcane;

	public class Filter3DDeferredVDepthOfFieldTask extends Filter3DDeferredTaskBase
	{
		private static var MAX_AUTO_SAMPLES : int = 10;
		private var _maxBlur : uint;
		private var _customData : Vector.<Number>;
		private var _focusDistance : Number;
		private var _range : Number = 1000;
		private var _stepSize : int;
		private var _realStepSize : Number;

		/**
		 * Creates a new Filter3DHDepthOfFFieldTask
		 * @param amount The maximum amount of blur to apply in pixels at the most out-of-focus areas
		 * @param stepSize The distance between samples. Set to -1 to autodetect with acceptable quality.
		 */
		public function Filter3DDeferredVDepthOfFieldTask(renderer : DeferredRenderer, maxBlur : uint, stepSize : int = -1)
		{
			super(renderer);
			_sampleSource = false;
			_needsDepth = true;
			_maxBlur = maxBlur;
			_customData = Vector.<Number>([0, 0, 0, 0, 0, 0, 0, 0]);
			this.stepSize = stepSize;
		}

		public function get stepSize() : int
		{
			return _stepSize;
		}

		public function set stepSize(value : int) : void
		{
			if (value == _stepSize) return;
			_stepSize = value;
			calculateStepSize();
			invalidateProgram3D();
			updateBlurData();
		}

		public function get range() : Number
		{
			return _range;
		}

		public function set range(value : Number) : void
		{
			_range = value;
		}


		public function get focusDistance() : Number
		{
			return _focusDistance;
		}

		public function set focusDistance(value : Number) : void
		{
			_focusDistance = value;
		}

		public function get maxBlur() : uint
		{
			return _maxBlur;
		}

		public function set maxBlur(value : uint) : void
		{
			if (_maxBlur == value) return;
			_maxBlur = value;

			invalidateProgram3D();
			updateBlurData();
			calculateStepSize();
		}

		override protected function getFragmentCode() : String
		{
			var code : String = super.getFragmentCode();
			var numSamples : uint = 1;

			code += "sub ft3.z, ft0.w, fc3.x			\n" + // d = d - f
					"abs ft3.z, ft3.z\n" +
					"mul ft3.z, ft3.z, fc3.y			\n" +
					"sat ft3.z, ft3.z\n" +
					"mul ft6.xy, ft3.z, fc2.xy			\n" +

					"mov ft4, v0\n" +
					"sub ft4.y, ft4.y, ft6.x\n";

			code += "tex ft2, ft4, fs0 <2d,linear,clamp>\n";

			// todo: we could use target depth to evaluate the amount it should be blended in
			for (var y : Number = 0; y <= _maxBlur; y += _realStepSize) {
				code += "add ft4.y, ft4.y, ft6.y	\n" +
						"tex ft5, ft4, fs0 <2d,linear,clamp>\n" +
						"add ft2, ft2, ft5 \n";
				++numSamples;
			}

			code += "mul oc, ft2, fc2.z";

			_customData[2] = 1 / numSamples;

			return code;
		}

		override public function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, depthTexture : Texture) : void
		{
			super.activate(stage3DProxy, camera, depthTexture);

			var near : Number = camera.lens.near;
			var far : Number = camera.lens.far;
			var scale : Number = far - near;

			_customData[4] = _focusDistance / scale;
			_customData[5] = far / _range;

			stage3DProxy.setTextureAt(1, _renderer.getNormalDepthBuffer().getTextureForStage3D(stage3DProxy));
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, _customData, 2);
		}

		override public function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			super.deactivate(stage3DProxy);
			stage3DProxy.setTextureAt(1, null);
		}

		override protected function updateTextures(stage : Stage3DProxy) : void
		{
			super.updateTextures(stage);

			updateBlurData();
		}

		private function updateBlurData() : void
		{
			// todo: replace with view width once texture rendering is scissored?
			var invH : Number = 1 / _textureHeight;

			_customData[0] = _maxBlur * .5 * invH;
			_customData[1] = _realStepSize * invH;
		}

		private function calculateStepSize() : void
		{
			_realStepSize = _stepSize > 0? 				_stepSize :
							_maxBlur > MAX_AUTO_SAMPLES? _maxBlur/MAX_AUTO_SAMPLES :
							1;
		}
	}
}
