package away3d.materials.pass
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.base.IRenderable;
	import away3d.core.data.RenderValueRanges;
	import away3d.core.managers.Stage3DProxy;
	import away3d.materials.lightpickers.LightPickerBase;
	import away3d.materials.passes.MaterialPassBase;
	import away3d.textures.Texture2DBase;

	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;

	use namespace arcane;

	// to do: add fresnel power + reflection strength property?
	public class DeferredSpecularPass extends MaterialPassBase
	{
		private var _data : Vector.<Number>;
		private var _specularStrength : Number = 1.0;
		private var _specularColor : uint = 0xffffff;
		private var _gloss : Number = 50.0;
		private var _specularMap : Texture2DBase;
		private var _alphaThreshold : Number = 0;
		private var _alphaMask : Texture2DBase;
		private var _specularMapIndex : uint;

		public function DeferredSpecularPass()
		{
			_data = new <Number>[1.0/RenderValueRanges.MAX_SPECULAR, 5.0/RenderValueRanges.MAX_GLOSS, 0, 0];
			_animatableAttributes = ["va0"];
			_animationTargetRegisters = ["vt0"];
		}

		/**
		 * The minimum alpha value for which pixels should be drawn. This is used for transparency that is either
		 * invisible or entirely opaque, often used with textures for foliage, etc.
		 * Recommended values are 0 to disable alpha, or 0.5 to create smooth edges. Default value is 0 (disabled).
		 */
		public function get alphaThreshold() : Number
		{
			return _alphaThreshold;
		}

		public function set alphaThreshold(value : Number) : void
		{
			if (value < 0) value = 0;
			else if (value > 1) value = 1;
			if (value == _alphaThreshold) return;

			if (value == 0 || _alphaThreshold == 0)
				invalidateShaderProgram();

			_alphaThreshold = value;
			_data[3] = _alphaThreshold;
		}

		public function get alphaMask() : Texture2DBase
		{
			return _alphaMask;
		}

		public function set alphaMask(value : Texture2DBase) : void
		{
			_alphaMask = value;
		}

		public function get specularMap() : Texture2DBase
		{
			return _specularMap;
		}

		public function set specularMap(value : Texture2DBase) : void
		{
			if (Boolean(_specularMap) != Boolean(value)) invalidateShaderProgram();
			_specularMap = value;
		}

		public function get gloss() : Number
		{
			return _gloss;
		}

		public function set gloss(value : Number) : void
		{
			_gloss = value;
			_data[1] = _gloss/RenderValueRanges.MAX_GLOSS;
		}

		public function get strength() : Number
		{
			return _specularStrength;
		}

		public function set strength(value : Number) : void
		{
			_specularStrength = value;
			_data[0] = value/RenderValueRanges.MAX_SPECULAR
		}

		public function get specularColor() : uint
		{
			return _specularColor;
		}

		public function set specularColor(value : uint) : void
		{
			_specularColor = value;
		}

		arcane override function getVertexCode(animatorCode : String) : String
		{
			var code : String = animatorCode;

			_numUsedStreams = 1;
			// project
			code += "m44 vt1, vt0, vc0		\n" +
					"mul op, vt1, vc4\n";

			if (_specularMap || _alphaThreshold > 0) {
				_numUsedStreams = 2;
				code += "mov v0, va1";
			}

			return code;
		}

		arcane override function getFragmentCode() : String
		{
			var wrap : String = _repeat ? "wrap" : "clamp";
			var filter : String;
			var code : String = "";

			_numUsedTextures = 0;

			if (_smooth) filter = _mipmap ? "linear,miplinear" : "linear";
			else filter = _mipmap ? "nearest,mipnearest" : "nearest";

			if (_alphaThreshold > 0) {
				_numUsedTextures = 1;
				code += "tex ft0, v0, fs0 <2d,"+filter+","+wrap+">\n" +
						"sub ft0.w, ft0.w, fc0.w\n" +
						"kil ft0.w\n";
			}

			if (_specularMap) {
				_specularMapIndex = _numUsedTextures++;
				var reg : String = "fs"+_specularMapIndex;
				code +=	"tex ft0, v0, "+reg+" <2d,"+filter+","+wrap+">\n" +
						"mul oc, ft0, fc0\n";

			}
			else {
				code += "mov oc, fc0";
			}
			return code;
		}

		arcane override function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, textureRatioX : Number, textureRatioY : Number) : void
		{
			super.activate(stage3DProxy, camera, textureRatioX, textureRatioY);
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data,  1);
			if (_specularMap) stage3DProxy.setTextureAt(_specularMapIndex, _specularMap.getTextureForStage3D(stage3DProxy));
			if (_alphaThreshold > 0) stage3DProxy.setTextureAt(0, _alphaMask.getTextureForStage3D(stage3DProxy));
		}

		arcane override function render(renderable : IRenderable, stage3DProxy : Stage3DProxy, camera : Camera3D, lightPicker : LightPickerBase) : void
		{
			if (_specularMap || _alphaThreshold > 0)
				stage3DProxy.setSimpleVertexBuffer(1, renderable.getUVBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_2);

			super.render(renderable, stage3DProxy, camera, lightPicker);
		}
	}
}
