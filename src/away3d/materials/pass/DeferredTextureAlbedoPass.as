package away3d.materials.pass
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.base.IRenderable;
	import away3d.core.managers.Stage3DProxy;
	import away3d.materials.lightpickers.LightPickerBase;
	import away3d.materials.passes.MaterialPassBase;
	import away3d.textures.Texture2DBase;

	import flash.display3D.Context3DProgramType;

	import flash.display3D.Context3DVertexBufferFormat;

	use namespace arcane;

	public class DeferredTextureAlbedoPass extends MaterialPassBase
	{
		private var _texture : Texture2DBase;
		private var _alphaThreshold : Number = 0;
		private var _data : Vector.<Number>;

		public function DeferredTextureAlbedoPass()
		{
			super();
			_numUsedStreams = 2;	// vertex and uv
			_numUsedTextures = 1;
			_data = new <Number>[0, 0, 0, 0];
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
			_data[0] = _alphaThreshold;
		}

		public function get texture() : Texture2DBase
		{
			return _texture;
		}

		public function set texture(value : Texture2DBase) : void
		{
			_texture = value;
		}

		arcane override function getVertexCode(animatorCode : String) : String
		{
			var code : String = animatorCode;
			// project
			code += "m44 vt1, vt0, vc0\n" +
					"mul op, vt1, vc4\n";
			// only need to copy uv coords
			code += "mov v0, va1\n";
			return code;
		}

		arcane override function getFragmentCode() : String
		{
			var wrap : String = _repeat ? "wrap" : "clamp";
			var filter : String;

			if (_smooth) filter = _mipmap ? "linear,miplinear" : "linear";
			else filter = _mipmap ? "nearest,mipnearest" : "nearest";

			if (_alphaThreshold > 0) {
				return	"tex ft0, v0, fs0 <2d,"+filter+","+wrap+">\n" +
						"sub ft1.w, ft0.w, fc0.x\n" +
						"kil ft1.w\n" +
						"div oc, ft0, ft0.w\n";
			}
			else {
				return "tex oc, v0, fs0 <2d,"+filter+","+wrap+">\n";
			}
		}

		arcane override function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, textureRatioX : Number, textureRatioY : Number) : void
		{
			super.activate(stage3DProxy, camera, textureRatioX, textureRatioY);
			stage3DProxy.setTextureAt(0, _texture.getTextureForStage3D(stage3DProxy));

			if (_alphaThreshold > 0)
				stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 1);
		}

		arcane override function render(renderable : IRenderable, stage3DProxy : Stage3DProxy, camera : Camera3D, lightPicker : LightPickerBase) : void
		{
			stage3DProxy.setSimpleVertexBuffer(1, renderable.getUVBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_2);
			super.render(renderable, stage3DProxy, camera, lightPicker);
		}
	}
}
