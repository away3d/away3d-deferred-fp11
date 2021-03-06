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
	import flash.geom.Matrix3D;

	use namespace arcane;

	public class DeferredNormalDepthPass extends MaterialPassBase
	{
		private var _normalMap : Texture2DBase;

		private var _fragmentData : Vector.<Number>;
		private var _vertexData : Vector.<Number>;
		private var _viewMatrix : Matrix3D = new Matrix3D();
		private var _alphaThreshold : Number = 0;
		private var _alphaMask : Texture2DBase;
		private var _uvIndex : int;
		private var _alphaMaskIndex : int;

		public function DeferredNormalDepthPass()
		{
			super();
			_numUsedVertexConstants = 14;
			// depth encode value 1 & 2, normal encode value, alpha threshold
			_fragmentData = new <Number>[ 1, 255, .5, 0, 1/255, 0, 0, 1 ];
			_vertexData = new <Number>[ 1, 1, 0, 1 ];
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
			_fragmentData[5] = _alphaThreshold;
		}

		public function get alphaMask() : Texture2DBase
		{
			return _alphaMask;
		}

		public function set alphaMask(value : Texture2DBase) : void
		{
			_alphaMask = value;
		}

		public function get normalMap() : Texture2DBase
		{
			return _normalMap;
		}

		public function set normalMap(value : Texture2DBase) : void
		{
			var change : Boolean = Boolean(_normalMap) != Boolean(value);

			_normalMap = value;

			if (change) invalidateShaderProgram();
		}

		arcane override function invalidateShaderProgram(updateMaterial : Boolean = true) : void
		{
			super.invalidateShaderProgram(updateMaterial);

			if (_normalMap) {
				_numUsedVertexConstants = 9;
				_animatableAttributes = ["va0", "va1", "va2" ];
				_animationTargetRegisters = ["vt0", "vt1", "vt2" ];
			}
			else {
				_numUsedVertexConstants = 5;
				_animatableAttributes = ["va0", "va1"];
				_animationTargetRegisters = ["vt0", "vt1"];
			}
		}

		arcane override function getVertexCode(animatorCode : String) : String
		{
			if (_normalMap)
				return getNormalMapVertexCode(animatorCode);
			else
				return getNormalVertexCode(animatorCode);
		}

		arcane override function getFragmentCode() : String
		{
			if (_normalMap)
				return getNormalMapFragmentCode();
			else
				return getNormalFragmentCode();
		}

		private function getNormalVertexCode(animatorCode : String) : String
		{
			var code : String = animatorCode;

			_numUsedStreams = 2;	// positions + normals

			code += "m33 v0.xyz, vt1, vc9\n" +
					"mov v0.w, va1.w	\n" +
				// send view coord for linear depth
					"m44 vt1, vt0, vc5	\n" +
					"mul v1, vt1.zzzz, vc13.xyww\n";
			// project
			code += "m44 vt2, vt0, vc0		\n" +
					"mul op, vt2, vc4\n";

			if (_alphaThreshold > 0) {
				_numUsedStreams = 3;	// uvs
				_uvIndex = 2;
				code += "mov v2, va2\n";
			}

			return code;
		}

		private function getNormalFragmentCode() : String
		{
			var wrap : String = _repeat ? "wrap" : "clamp";
			var filter : String;

			_numUsedTextures = 0;

			if (_smooth) filter = _mipmap ? "linear,miplinear" : "linear";
			else filter = _mipmap ? "nearest,mipnearest" : "nearest";

			var code : String =
				// encode depth
							"frc ft1.z, v1.x\n" +
							"frc ft1.w, v1.y\n" +
							"mul ft2.z, ft1.w, fc1.x\n" +
							"sub ft1.z, ft1.z, ft2.z\n" +

							"nrm ft0.xyz, v0.xyz\n" +
						// encode normal
							"mul ft1.xy, ft0.xy, fc0.zz\n" +
							"add ft1.xy, ft1.xy, fc0.zz\n";



			if (_alphaThreshold > 0) {
				_numUsedTextures = 1;
				_alphaMaskIndex = 0;
				code +=	"tex ft3, v2, fs0 <2d,"+filter+","+wrap+">\n" +
						"sub ft3.w, ft3.w, fc1.y\n" +
						"kil ft3.w\n";
			}

			code += "mov oc, ft1";

			return code;
		}

		private function getNormalMapVertexCode(animatorCode : String) : String
		{
			var code : String = animatorCode;

			_numUsedStreams = 4;
			_uvIndex = 3;

			// view-space position
			code +=	"m44 vt5, vt0, vc5	\n" +
					"mul v4, vt5.zzzz, vc13.xyww	\n" +
				// view space normal
					"m33 vt3.xyz, vt1, vc9\n" +
					"nrm vt3.xyz, vt3.xyz\n" +
				// view space tangent
					"m33 vt4.xyz, vt2, vc9\n" +
					"nrm vt4.xyz, vt4.xyz\n" +
				// calculate view space bitangent
					"crs vt6.xyz, vt3.xyz, vt4.xyz  \n" +

					"mov v1.x, vt4.x	\n" +
					"mov v1.y, vt6.x	\n" +
					"mov v1.z, vt3.x	\n" +
					"mov v1.w, va1.w	\n" +

					"mov v2.x, vt4.y	\n" +
					"mov v2.y, vt6.y	\n" +
					"mov v2.z, vt3.y	\n" +
					"mov v2.w, va1.w	\n" +

					"mov v0.x, vt4.z	\n" +
					"mov v0.y, vt6.z	\n" +
					"mov v0.z, vt3.z	\n" +
					"mov v0.w, va1.w	\n" +

					"mov v3, va3		\n";

			// project
			code += "m44 vt3, vt0, vc0		\n" +
					"mul op, vt3, vc4\n";

			return code;
		}

		private function getNormalMapFragmentCode() : String
		{
			var wrap : String = _repeat ? "wrap" : "clamp";
			var filter : String;

			_numUsedTextures = 1;

			if (_smooth) filter = _mipmap ? "linear,miplinear" : "linear";
			else filter = _mipmap ? "nearest,mipnearest" : "nearest";

			// store TBN matrix
			var code : String =
					"nrm ft0.xyz, v1.xyz	\n" +
					"mov ft0.w, v1.w	\n" +
					"nrm ft1.xyz, v2.xyz	\n" +
					"nrm ft2.xyz, v0.xyz	\n" +

					"tex ft3, v3, fs0 <2d,"+filter+","+wrap+">\n" +

					"sub ft3.xyz, ft3.xyz, fc0.zzz	\n" +
					"nrm ft3.xyz, ft3.xyz		\n" +
					"m33 ft3.xyz, ft3.xyz, ft0	\n" +

				// encode normal
					"mul ft3.xy, ft3.xy, fc0.zz\n" +
					"add ft3.xy, ft3.xy, fc0.zz\n" +

				// encode depth
					"frc ft3.z, v4.x\n" +
					"frc ft3.w, v4.y\n" +
					"mul ft2.z, ft3.w, fc1.x\n" +
					"sub ft3.z, ft3.z, ft2.z\n";

			if (_alphaThreshold > 0) {
				_alphaMaskIndex = 1;
				_numUsedTextures = 2;
				code +=	"tex ft1, v3, fs1 <2d,"+filter+","+wrap+">\n" +
						"sub ft1.w, ft1.w, fc1.y\n" +
						"kil ft1.w\n";
			}

			code += "mov oc, ft3";

			return code;
		}

		arcane override function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, textureRatioX : Number, textureRatioY : Number) : void
		{
			super.activate(stage3DProxy, camera, textureRatioX, textureRatioY);

			_vertexData[0] = 1/camera.lens.far;
			_vertexData[1] = 255/camera.lens.far;
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _fragmentData, 2);
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 13, _vertexData, 1);

			if (_normalMap)
				stage3DProxy.setTextureAt(0, _normalMap.getTextureForStage3D(stage3DProxy));

			if (_alphaThreshold > 0)
				stage3DProxy.setTextureAt(_alphaMaskIndex, _alphaMask.getTextureForStage3D(stage3DProxy));
		}

		arcane override function render(renderable : IRenderable, stage3DProxy : Stage3DProxy, camera : Camera3D, lightPicker : LightPickerBase) : void
		{
			stage3DProxy.setSimpleVertexBuffer(1, renderable.getVertexNormalBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_3);

			_viewMatrix.copyFrom(renderable.sceneTransform);
			_viewMatrix.append(camera.inverseSceneTransform);
			stage3DProxy._context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 5, _viewMatrix, true);

			_viewMatrix.invert();
			stage3DProxy._context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 9, _viewMatrix);


			if (_normalMap)
				stage3DProxy.setSimpleVertexBuffer(2, renderable.getVertexTangentBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_3);

			if (_normalMap || _alphaThreshold > 0)
				stage3DProxy.setSimpleVertexBuffer(_uvIndex, renderable.getUVBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_2);

			super.render(renderable, stage3DProxy, camera, lightPicker);
		}
	}
}
