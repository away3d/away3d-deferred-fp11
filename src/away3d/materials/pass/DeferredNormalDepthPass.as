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
	import flash.geom.Vector3D;

	use namespace arcane;

	public class DeferredNormalDepthPass extends MaterialPassBase
	{
		private var _normalMap : Texture2DBase;

		private var _data : Vector.<Number>;
		private var _viewMatrix : Matrix3D = new Matrix3D();
		private var _alphaThreshold : Number = 0;
		private var _alphaMask : Texture2DBase;

		public function DeferredNormalDepthPass()
		{
			super();
			_numUsedVertexConstants = 5;
			// depth encode value 1 & 2, normal encode value, alpha threshold
			_data = new <Number>[ 1, 255, .5, 0, 1/255, 0, 0, 1 ];
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
			_data[5] = _alphaThreshold;
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

		arcane override function invalidateShaderProgram() : void
		{
			super.invalidateShaderProgram();

			if (_normalMap) {
				_numUsedTextures = _alphaThreshold > 0? 2 : 1;
				_numUsedStreams = 4;
				_numUsedVertexConstants = 9;
			}
			else {
				_numUsedTextures = _alphaThreshold > 0? 1 : 0;
				_numUsedStreams = _alphaThreshold > 0? 3 : 2;
				_numUsedVertexConstants = 5;
			}
		}

		arcane override function getVertexCode() : String
		{
			if (_normalMap)
				return getNormalMapVertexCode();
			else
				return getNormalVertexCode();
		}

		arcane override function getFragmentCode() : String
		{
			if (_normalMap)
				return getNormalMapFragmentCode();
			else
				return getNormalFragmentCode();
		}

		private function getNormalVertexCode() : String
		{
            var code : String = animation.getAGALVertexCode(this, ["va0", "va1"], ["vt0", "vt1"]);

			code += "m33 v0.xyz, vt1, vc9\n" +
                    "mov v0.w, va1.w	\n" +
                    // send view coord for linear depth
                    "m44 v1, vt0, vc5	\n";
            // project
            code += "m44 vt2, vt0, vc0		\n" +
                    "mul op, vt2, vc4\n";

            if (_alphaThreshold > 0) {
				code += "mov v2, va3\n";
			}

			return code;
		}

		private function getNormalFragmentCode() : String
		{
			var wrap : String = _repeat ? "wrap" : "clamp";
			var filter : String;

			if (_smooth) filter = _mipmap ? "linear,miplinear" : "linear";
			else filter = _mipmap ? "nearest,mipnearest" : "nearest";

			var code : String =
					"nrm ft0.xyz, v0.xyz\n" +
					// encode normal
					"mul ft1.xy, ft0.xy, fc0.zz\n" +
					"add ft1.xy, ft1.xy, fc0.zz\n" +

					// encode depth
					"mul ft0.z, v1.z, fc0.w\n" +
					"mul ft0.xy, ft0.z, fc0.xy\n" +
					"frc ft1.z, ft0.x\n" +
					"frc ft1.w, ft0.y\n" +
					"mul ft2.z, ft1.w, fc1.x\n" +
					"sub ft1.z, ft1.z, ft2.z\n";

			if (_alphaThreshold > 0) {
				code +=	"tex ft3, v2, fs1 <2d,"+filter+","+wrap+">\n" +
						"sub ft3.w, ft3.w, fc1.y\n" +
						"kil ft3.w\n";
			}

			code += "mov oc, ft1";

			return code;
		}

		private function getNormalMapVertexCode() : String
		{
            var code : String = animation.getAGALVertexCode(this, ["va0", "va1", "va2"], ["vt0", "vt1", "vt2"]);

			// view-space position
			code +=	"m44 v4, vt0, vc5	\n" +
				// view space normal
					"m33 vt3.xyz, vt1, vc9\n" +
					"nrm vt3.xyz, vt3.xyz\n" +
				// view space tangent
					"m33 vt4.xyz, vt2, vc9\n" +
					"nrm vt4.xyz, vt4.xyz\n" +
				// calculate view space bitangent
					"mul vt5.xyz, vt3.yzx, vt4.zxy	\n" +	// cross product (crs is broken?)
					"mul vt6.xyz, vt3.zxy, vt4.yzx	\n" +
					"sub vt6.xyz, vt5.xyz, vt6.xyz	\n" +

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

			if (_smooth) filter = _mipmap ? "linear,miplinear" : "linear";
			else filter = _mipmap ? "nearest,mipnearest" : "nearest";

					// store TBN matrix
			var code : String = "nrm ft0.xyz, v1.xyz	\n" +
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
								"mul ft0.z, v4.z, fc0.w\n" +
								"mul ft0.xy, ft0.z, fc0.xy\n" +
								"frc ft3.z, ft0.x\n" +
								"frc ft3.w, ft0.y\n" +
								"mul ft2.z, ft3.w, fc1.x\n" +
								"sub ft3.z, ft3.z, ft2.z\n";

			if (_alphaThreshold > 0) {
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

			_data[3] = 1/camera.lens.far;
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 2);

			if (_normalMap) {
				stage3DProxy.setTextureAt(0, _normalMap.getTextureForStage3D(stage3DProxy));
			}

			if (_alphaThreshold > 0) {
				stage3DProxy.setTextureAt(1, _alphaMask.getTextureForStage3D(stage3DProxy));
			}
		}


		arcane override function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			super.deactivate(stage3DProxy);
			if (_alphaThreshold > 0)
				stage3DProxy.setTextureAt(1, null);
		}

		arcane override function render(renderable : IRenderable, stage3DProxy : Stage3DProxy, camera : Camera3D, lightPicker : LightPickerBase) : void
		{
			stage3DProxy.setSimpleVertexBuffer(1, renderable.getVertexNormalBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_3);

			_viewMatrix.copyFrom(renderable.sceneTransform);
			_viewMatrix.append(camera.inverseSceneTransform);
			stage3DProxy._context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 5, _viewMatrix, true);

			_viewMatrix.invert();
			stage3DProxy._context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 9, _viewMatrix);


			if (_normalMap) {
				stage3DProxy.setSimpleVertexBuffer(2, renderable.getVertexTangentBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_3);
			}

			if (_normalMap || _alphaThreshold > 0) {
				stage3DProxy.setSimpleVertexBuffer(3, renderable.getUVBuffer(stage3DProxy), Context3DVertexBufferFormat.FLOAT_2);
			}

			super.render(renderable, stage3DProxy, camera, lightPicker);
		}
	}
}
