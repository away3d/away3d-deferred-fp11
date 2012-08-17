package away3d.core.render.light
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.data.RenderValueRanges;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.DirectionalLight;
	import away3d.lights.LightBase;
	import away3d.lights.shadowmaps.CascadeShadowMapper;
	import away3d.shadows.HardDirectionalShadowMapFilter;
	import away3d.shadows.DirectionalShadowMapFilterBase;

	import com.adobe.utils.AGALMiniAssembler;

	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;

	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.TextureBase;
	import flash.display3D.textures.TextureBase;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;

	use namespace arcane;

	public class DirectionalLightRenderer implements ILightRenderer
	{
		private var _programs : Vector.<Program3D>;
		private var _data : Vector.<Number>;
		private var _matrix : Matrix3D = new Matrix3D();
		private var _shadowMapFilter : DirectionalShadowMapFilterBase;

		private var _normalDepthBuffer : TextureBase;
		private var _specularBuffer : TextureBase;
		private var _rttManager : RTTBufferManager;

		public function DirectionalLightRenderer()
		{
			_data = new <Number> [  // diffuse
				1, 1, 1, 1,
				// dir + const
				0, 0, 0, .5,
				// depth + specular decoding
				1, 1/255, RenderValueRanges.MAX_SPECULAR, RenderValueRanges.MAX_GLOSS,
				// texture normalization, far plane
				.5, -.5, 0.0, 0.0,
				// 3 possible values bounds in post-projective space, far plane - near plane
				0.04, .96, -.96, -0.04,
				// 4*2 projection scales
				0, 0, 0, 0, 0, 0, 0, 0
			];
			_programs = new Vector.<Program3D>(5, true);
			_shadowMapFilter = new HardDirectionalShadowMapFilter();
		}

		arcane function get normalDepthBuffer() : TextureBase
		{
			return _normalDepthBuffer;
		}

		arcane function set normalDepthBuffer(value : TextureBase) : void
		{
			_normalDepthBuffer = value;
		}

		arcane function get specularBuffer() : TextureBase
		{
			return _specularBuffer;
		}

		arcane function set specularBuffer(value : TextureBase) : void
		{
			_specularBuffer = value;
		}

		public function get shadowMapFilter() : DirectionalShadowMapFilterBase
		{
			return _shadowMapFilter;
		}

		public function set shadowMapFilter(value : DirectionalShadowMapFilterBase) : void
		{
			_shadowMapFilter = value;
			invalidatePrograms();
		}

		private function invalidatePrograms() : void
		{
			for (var i : uint = 0; i < _programs.length; ++i) {
				if (_programs[i]) {
					_programs[i].dispose();
					_programs[i] = null;
				}
			}
		}

		private function initProgram(numCascades : uint, stage3DProxy : Stage3DProxy) : void
		{
			_programs[numCascades] = stage3DProxy._context3D.createProgram();
			_programs[numCascades].upload(new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getVertexCode()),
					new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getFragmentCode(numCascades)));
		}

		protected function getVertexCode() : String
		{
			return	"mov op, va0\n" +
					"mov v0, va1\n" +
					"mov vt0, vc[va2.x]\n" +
				// need frustum vector with z == 1, so we can scale correctly
					"div vt0.xyz, vt0.xyz, vt0.z\n" +
					"mov v1, vt0\n";
		}

		protected function getFragmentCode(numCascades : uint) : String
		{
			var code : String;
			code = "tex ft1, v0, fs0 <2d,nearest,clamp>\n" +

				// diffuse:
				// normals:
					"sub ft2.xy, ft1.xy, fc1.ww\n" +
					"add ft2.xy, ft2.xy, ft2.xy\n" +
					"mov ft2.z, fc4.w\n" +
					"dp3 ft2.z, ft2.xyz, ft2.xyz\n" +	// z² = 1-(x*x+y*y)
					"sub ft2.z, fc0.w, ft2.z\n" +
					"sqt ft2.z, ft2.z\n" +
					"neg ft2.z, ft2.z\n" +

				// diffuse
					"dp3 ft3.x, ft2.xyz, fc1.xyz\n" +
					"sat ft3.x, ft3.x\n" +
					"mul ft7, ft3.x, fc0\n" +	// multiply with color

				// specular

				// decode depth
					"mul ft5.xy, ft1.zw, fc2.xy\n" +
					"add ft6.z, ft5.x, ft5.y\n" +
					"mul ft6.z, ft6.z, fc3.z\n" +
				// view position in FT6
					"mul ft6.xyz, ft6.z, v1.xyz\n" +
					"mov ft6.w, v1.w\n" +

				// view vector:
					"nrm ft4.xyz, v1.xyz\n" +
					"mov ft4.w, v1.w\n" +
				// half vector
					"sub ft4.xyz, fc1.xyz, ft4.xyz\n" +
					"nrm ft4.xyz, ft4.xyz\n" +
					"dp3 ft4.w, ft2.xyz, ft4.xyz\n" +
					"sat ft4.w, ft4.w\n" +

				// only support monochrome specularity (color of total light will be applied later)
					"tex ft5, v0, fs1 <2d,nearest,clamp>\n" +
					"mul ft5.x, ft5.x, fc2.z\n" +
					"mul ft5.y, ft5.y, fc2.w\n" +
					"pow ft5.y, ft4.w, ft5.y\n" +
					"mul ft7.w, ft5.x, ft5.y\n";

			if (numCascades > 0) {
				code += generateShadowMapCode(numCascades);
				code += "mul ft7, ft7, ft0.w\n";
				code += "tex ft1, v0, fs2 <2d,nearest,clamp>\n" +
						"add oc, ft1, ft7\n";
			}
			else code += "mov oc, ft7\n";




			return code;
		}

		private function generateShadowMapCode(numCascades : uint) : String
		{
			var projIndex : int = 7;
			var projMatrix : String;
			var code : String = "";
			var boundsReg : String = "fc4";
			var toTexReg : String = "fc3";
			var minBounds : Vector.<String> = new <String>[	boundsReg + ".x", boundsReg + ".z", boundsReg + ".z", boundsReg + ".z", boundsReg + ".x", boundsReg + ".x", boundsReg + ".z", boundsReg + ".x" ];
			var maxBounds : Vector.<String> = new <String>[	boundsReg + ".y", boundsReg + ".w", boundsReg + ".w", boundsReg + ".w", boundsReg + ".y", boundsReg + ".y", boundsReg + ".w", boundsReg + ".y" ];
			var boundIndex : int = (4-numCascades)*2;
			var scaleRegisters : Array = [ 	"fc5.xy", "fc5.zw",
											"fc6.xy", "fc6.zw"
										];


			for (var i : int = 0; i < numCascades; ++i) {
				projMatrix = "fc" + projIndex;

				// don't bother checking if lowest quality is in, if a better one will be found it will be nullified anyway
				if (i == 0) {
					// calculate projection coord for partition
					code += "m44 ft0, ft6, " + projMatrix + "\n";

					if (_shadowMapFilter.needsProjectionScale)
						code += "mov ft5.xy, " + scaleRegisters[i] + "\n";
				}
				else {
					code += "m44 ft1, ft6, " + projMatrix + "\n";

					// todo: should be able to do this hugely in parallel by calculating slts and sges in a loop
					// and storing results in xyzw resp. for each cascade
					// if storing min test results in ft3, max test results in ft4
					// should be able to multiply results together
					// can also somewhat parallize per two
					// so support either 1, 2 or 4 cascades


					// calculate if in texturemap (result == 0 or 1, only 1 for a single partition)
					code += "sge ft4.z, ft1.x, " + minBounds[boundIndex] + "\n" + // z = x > minX, w = y > minY
							"sge ft4.w, ft1.y, " + minBounds[boundIndex+1] + "\n" + // z = x > minX, w = y > minY
							"sge ft4.x, " + maxBounds[boundIndex] + ", ft1.x \n" + // z = x < maxX, w = y < maxY
							"sge ft4.y, " + maxBounds[boundIndex+1] + ", ft1.y\n" + // z = x < maxX, w = y < maxY

						// parall. per 2?
							"mul ft4.xz, ft4.xz, ft4.yw\n" +

						// parall. per 4
							"mul ft4.z, ft4.z, ft4.x\n";	// 1 if all are in bounds, so in this quad

					// since we're going from low to high quality, if 1, we must multiply previous total with 0 so we're only using the current higher quality result
					// if 0, we keep the total (= multiply with 1)
					// that is: multiply with 1-b
					code += "sub ft4.w, fc2.x, ft4.z\n" +
							"mul ft0, ft0, ft4.w\n";

					if (_shadowMapFilter.needsProjectionScale)
						code += "mul ft5.xy, ft5.xy, ft4.w\n";

					// multiply projection with boolean (so do not use if outside texture projection)
					code += "mul ft1, ft1, ft4.z\n" +
							"add ft0, ft0, ft1\n";

					if (_shadowMapFilter.needsProjectionScale) {
						code += "mul ft5.zw, " + scaleRegisters[i] + ", ft4.z\n" +
								"add ft5.xy, ft5.xy, ft5.zw\n";
					}
				}

				projIndex += 4;
				boundIndex += 2;
			}

			code += "mul ft0.xy, ft0.xy, " + toTexReg + ".xy\n" +
					"add ft0.xy, ft0.xy, " + toTexReg + ".xx\n";

			_shadowMapFilter.setConstantRegisterOffset(numCascades, projIndex);
			code += _shadowMapFilter.getSampleCode(numCascades);

			return code;
		}

		private function activate(stage3DProxy : Stage3DProxy) : void
		{
			var context : Context3D = stage3DProxy._context3D;
			var toTextureBuffer : VertexBuffer3D;

			_rttManager = RTTBufferManager.getInstance(stage3DProxy);
			toTextureBuffer = _rttManager.renderToTextureVertexBuffer;

			stage3DProxy.setTextureAt(0, _normalDepthBuffer);
			stage3DProxy.setTextureAt(1, _specularBuffer);

			stage3DProxy.setSimpleVertexBuffer(0, toTextureBuffer, Context3DVertexBufferFormat.FLOAT_2, 0);
			stage3DProxy.setSimpleVertexBuffer(1, toTextureBuffer, Context3DVertexBufferFormat.FLOAT_2, 2);
			stage3DProxy.setSimpleVertexBuffer(2, toTextureBuffer, Context3DVertexBufferFormat.FLOAT_1, 4);	// indices for frustum corners

			context.setDepthTest(false, Context3DCompareMode.ALWAYS);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);
		}

		public function render(light : LightBase, camera : Camera3D, stage3DProxy : Stage3DProxy, frustumCorners : Vector.<Number>, sourceBuffer : TextureBase = null) : void
		{
			var dirLight : DirectionalLight = DirectionalLight(light);
			var dir : Vector3D = camera.inverseSceneTransform.deltaTransformVector(dirLight.sceneDirection);
			var shadowMapper : CascadeShadowMapper = light.castsShadows ? CascadeShadowMapper(light.shadowMapper) : null;
			var dx : Number = dir.x;
			var dy : Number = dir.y;
			var dz : Number = dir.z;
			var len : Number = -1 / Math.sqrt(dx * dx + dy * dy + dz * dz);
			var numCascades : uint = shadowMapper? shadowMapper.numCascades : 0;
			var context : Context3D = stage3DProxy.context3D;
			var i : uint, j : uint, k : uint;

			activate(stage3DProxy);

			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, frustumCorners, 4);

			if (shadowMapper) {
				var cameraScene : Matrix3D = camera.sceneTransform;

				stage3DProxy.setTextureAt(2, sourceBuffer);
				stage3DProxy.setTextureAt(3, shadowMapper.depthMap.getTextureForStage3D(stage3DProxy));
				_shadowMapFilter.activate(stage3DProxy, dirLight, numCascades);

				// low res first
				k = numCascades;
				j = 7;
				var l : uint = 20;
				for (i = 0; i < numCascades; ++i) {
					_matrix.copyFrom(cameraScene);
					_matrix.append(shadowMapper.getDepthProjections(--k));
					context.setProgramConstantsFromMatrix(Context3DProgramType.FRAGMENT, j, _matrix, true);
					if (_shadowMapFilter.needsProjectionScale) {
						_data[l++] = shadowMapper._projectionXScales[k];
						_data[l++] = shadowMapper._projectionYScales[k];
					}
					j += 4;

				}
			}

			// todo: there's only monochrome specular light, but we can approximate the total specular colour to use from lights
			_data[0] = light._diffuseR;
			_data[1] = light._diffuseG;
			_data[2] = light._diffuseB;
			_data[3] = light.specular;
			_data[4] = dir.x * len;
			_data[5] = dir.y * len;
			_data[6] = dir.z * len;
			_data[14] = camera.lens.far;

			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 7);

			if (!_programs[numCascades]) initProgram(numCascades, stage3DProxy);

			stage3DProxy.setProgram(_programs[numCascades]);
			context.drawTriangles(_rttManager.indexBuffer, 0, 2);

			deactivate(stage3DProxy);
		}

		private function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			stage3DProxy.setSimpleVertexBuffer(0, null, null);
			stage3DProxy.setSimpleVertexBuffer(1, null, null);
			stage3DProxy.setSimpleVertexBuffer(2, null, null);
			stage3DProxy.setTextureAt(0, null);
			stage3DProxy.setTextureAt(1, null);
			stage3DProxy.setTextureAt(2, null);
			stage3DProxy.setTextureAt(3, null);
			_shadowMapFilter.deactivate(stage3DProxy);
		}

		public function dispose() : void
		{
			for (var i : int = 0; i < 4; ++i) {
				if (_programs[i])
					_programs[i].dispose();
			}
			_programs = null;
			_shadowMapFilter.dispose();
		}
	}
}
