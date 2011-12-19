package away3d.core.render.light
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.core.data.RenderValueRanges;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.LightBase;
	import away3d.lights.PointLight;
	import away3d.primitives.Sphere;
	import away3d.shadows.HardPointShadowMapFilter;
	import away3d.shadows.PointShadowMapFilterBase;

	import com.adobe.utils.AGALMiniAssembler;

	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DClearMask;
	import flash.display3D.Context3DCompareMode;

	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DStencilAction;
	import flash.display3D.Context3DTriangleFace;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.TextureBase;
	import flash.display3D.textures.TextureBase;
	import flash.geom.Vector3D;

	use namespace arcane;

	public class PointLightRenderer implements ILightRenderer
	{
		private var _stencilProgram : Program3D;
		private var _copyProgram : Program3D;
		private var _lightingProgram : Program3D;
		private var _lightingProgramShadows : Program3D;
		private var _lightData : Vector.<Number>;
		private var _stencilData : Vector.<Number>;

		private var _normalDepthBuffer : TextureBase;
		private var _specularBuffer : TextureBase;
		private var _rttManager : RTTBufferManager;

		private static var _sphereGeometry : SubGeometry;
		private var _stencilFragmentColor : Vector.<Number>;

		private var _shadowMapFilter : PointShadowMapFilterBase;

		public function PointLightRenderer()
		{
			_shadowMapFilter = new HardPointShadowMapFilter();
			_lightData = new <Number> [  // diffuse
				1, 1, 1, 1,
				// dir + const
				0, 0, 0, .5,
				// depth + specular decoding
				1, 1/255, RenderValueRanges.MAX_SPECULAR, RenderValueRanges.MAX_GLOSS,
				// radius, falloff factor, camera far, depth normalisation value
				0, 0, 0 , 0
			];
			_stencilFragmentColor = new <Number>[0, 0, 0, 0];

			_stencilData = new Vector.<Number>(8, true);
			_stencilData[6] = 1;
			_stencilData[7] = 1;

			if (!_sphereGeometry) {
				var sphere : Sphere = new Sphere(null, 1);
				_sphereGeometry = sphere.geometry.subGeometries[0];
				sphere.dispose();
			}
		}

		public function get shadowMapFilter() : PointShadowMapFilterBase
		{
			return _shadowMapFilter;
		}

		public function set shadowMapFilter(value : PointShadowMapFilterBase) : void
		{
			_shadowMapFilter = value;
			invalidateLightProgram();
		}

		private function invalidateLightProgram() : void
		{
			if (_lightingProgram) {
				_lightingProgram.dispose();
				_lightingProgram = null;
			}
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

		private function initStencilProgram(stage3DProxy : Stage3DProxy) : void
		{
			_stencilProgram = stage3DProxy._context3D.createProgram();
			_stencilProgram.upload(	new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getStencilVertexCode()),
									new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getStencilFragmentCode()));

		}

		private function initCopyProgram(stage3DProxy : Stage3DProxy) : void
		{
			_copyProgram = stage3DProxy._context3D.createProgram();
			_copyProgram.upload( 	new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getCopyVertexCode()),
									new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getCopyFragmentCode()));
		}

		private function initLightingProgram(stage3DProxy : Stage3DProxy) : void
		{
			_lightingProgram = stage3DProxy._context3D.createProgram();
			_lightingProgram.upload(new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getLightVertexCode()),
									new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getLightFragmentCode(false)));
		}

		private function initLightingProgramShadows(stage3DProxy : Stage3DProxy) : void
		{
			_lightingProgramShadows = stage3DProxy._context3D.createProgram();
			_lightingProgramShadows.upload(	new AGALMiniAssembler().assemble(Context3DProgramType.VERTEX, getLightVertexCode()),
											new AGALMiniAssembler().assemble(Context3DProgramType.FRAGMENT, getLightFragmentCode(true)));

		}

		private function getCopyVertexCode() : String
		{
			return 	"mov v0, va1\n" +
					"mov op, va0\n";
		}

		private function getCopyFragmentCode() : String
		{
			return 	"tex ft0, v0, fs0 <2d,nearest,clamp>\n" +
					"mov oc, ft0";
		}

		protected function getStencilVertexCode() : String
		{
					// scale by radius
			return	"mov vt0.w, va0.w\n" +
					"mul vt0.xyz, va0.xyz, vc8.w\n" +
					// add position
					"add vt0.xyz, vt0.xyz, vc8.xyz\n" +
					// project
					"m44 vt0, vt0, vc4\n" +
					"mul op, vt0, vc9\n";
		}

		protected function getStencilFragmentCode() : String
		{
			// just output something, stencil action is the only important thing
			return "mov oc, fc0";
		}

		protected function getLightVertexCode() : String
		{
			return	"mov op, va0\n" +
					"mov v0, va1\n" +
					"mov vt0, vc[va2.x]\n" +
					// need frustum vector with z == 1, so we can scale correctly
					"div vt0.xyz, vt0.xyz, vt0.z\n" +
					"mov v1, vt0\n";
		}

		protected function getLightFragmentCode(shadows : Boolean) : String
		{
			var code : String;
			code =  "tex ft1, v0, fs0 <2d,nearest,clamp>\n" +
				// decode depth
					"mul ft5.xy, ft1.zw, fc2.xy\n" +
//					"mul ft5.y, ft1.w, fc2.y\n" +
					"add ft6.z, ft5.x, ft5.y\n" +
					"mul ft6.z, ft6.z, fc3.z\n" +
				// view position in FT6
					"mul ft6.xyz, ft6.z, v1.xyz\n" +
					"mov ft6.w, v1.w\n" +

				// light vector in FT0
					"sub ft0.xyz, fc1.xyz, ft6.xyz\n" +

				// strength in ft0.w, SQUARED LENGTH OF LIGHT VECTOR in FT3.w!!! (needed for shadows)
					// w = d - radius
					"dp3 ft3.w, ft0.xyz, ft0.xyz\n" +
					"sqt ft0.w, ft3.w\n" +
					"sub ft0.w, ft0.w, fc3.x\n" +
					// w = (d - radius)/(max-min)
					"mul ft0.w, ft0.w, fc3.y\n" +
					"sat ft0.w, ft0.w\n" +
					// 1-w
					"sub ft0.w, fc2.x, ft0.w\n" +

					"nrm ft0.xyz, ft0.xyz\n" +

				// diffuse:
					"sub ft2.xy, ft1.xy, fc1.ww\n" +
					"add ft2.xy, ft2.xy, ft2.xy\n" +
					"mul ft2.z, ft2.x, ft2.x\n" +
					"mul ft2.w, ft2.y, ft2.y\n" +
					"add ft2.z, ft2.z, ft2.w\n" +
					"sub ft2.z, fc0.w, ft2.z\n" + // z² = 1-(x*x+y*y)
					"sqt ft2.z, ft2.z\n" +
					"neg ft2.z, ft2.z\n" +
					"dp3 ft3.x, ft2.xyz, ft0.xyz\n" +
					"sat ft3.x, ft3.x\n" +
					"mul ft7, ft3.x, fc0\n" +

				// specular

				// view vector:
					"nrm ft4.xyz, v1.xyz\n" +
					"mov ft4.w, v1.w\n" +
					"neg ft4.xyz, ft4.xyz\n" +
				// half vector
					"add ft4.xyz, ft0.xyz, ft4.xyz\n" +
					"nrm ft4.xyz, ft4.xyz\n" +
					"dp3 ft4.w, ft2.xyz, ft4.xyz\n" +
					"sat ft4.w, ft4.w\n" +

				// only support monochrome specularity
					"tex ft5, v0, fs1 <2d,nearest,clamp>\n" +
					"mul ft5.x, ft5.x, fc2.z\n" +
					"mul ft5.y, ft5.y, fc2.w\n" +
					"pow ft5.y, ft4.w, ft5.y\n" +
					"mul ft7.w, ft5.x, ft5.y\n";

			if (shadows) {
				code += "mul ft7, ft7, ft0.w\n" +
						getShadowMapCode() +
						"mul oc, ft7, ft0.w\n";
			}
			else {
				code += "mul oc, ft7, ft0.w\n";
			}


//			"mov oc, fc0\n";

			return code;
		}

		private function getShadowMapCode() : String
		{
			_shadowMapFilter.constantRegisterOffset = 10;

			return	"neg ft0.xyz, ft0.xyz\n" +
					"m33 ft0.xyz, ft0.xyz, fc6\n" +
					"nrm ft0.xyz, ft0.xyz\n" +
					"mul ft0.w, ft3.w, fc3.w\n" +

					_shadowMapFilter.getSampleCode();
		}

		public function render(light : LightBase, camera : Camera3D, stage3DProxy : Stage3DProxy, frustumCorners : Vector.<Number>, sourceBuffer : TextureBase = null) : void
		{
			var pointLight : PointLight = PointLight(light);
			var context : Context3D = stage3DProxy._context3D;
			context.setDepthTest(false, Context3DCompareMode.ALWAYS);

			_rttManager = RTTBufferManager.getInstance(stage3DProxy);

			if (light.castsShadows) {
				renderCopy(sourceBuffer, stage3DProxy);

				context.setStencilReferenceValue(0xff);
				context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);
			}
			renderStencil(stage3DProxy, camera, pointLight);
			renderLight(stage3DProxy, camera, pointLight, frustumCorners);

			if (light.castsShadows)
				context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);

			context.clear(0, 0, 0, 1, 1, 0, Context3DClearMask.STENCIL);

			stage3DProxy.setSimpleVertexBuffer(0, null, null);
			context.setStencilActions();
		}

		private function renderCopy(source : TextureBase, stage3DProxy : Stage3DProxy) : void
		{
			var context : Context3D = stage3DProxy._context3D;
			var toTextureBuffer : VertexBuffer3D;

			if (!_copyProgram) initCopyProgram(stage3DProxy);

			toTextureBuffer = _rttManager.renderToTextureVertexBuffer;
			context.setVertexBufferAt(0, toTextureBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			context.setVertexBufferAt(1, toTextureBuffer, 2, Context3DVertexBufferFormat.FLOAT_2);

			stage3DProxy.setProgram(_copyProgram);
			stage3DProxy.setTextureAt(0, source);
			context.drawTriangles(_rttManager.indexBuffer, 0, 2);
			stage3DProxy.setTextureAt(0, null);

			context.setVertexBufferAt(1, null);
		}

		private function renderStencil(stage3DProxy : Stage3DProxy, camera : Camera3D, light : PointLight) : void
		{
			var context : Context3D = stage3DProxy._context3D;
			var pos : Vector3D = light.scenePosition;

			if (!_stencilProgram) initStencilProgram(stage3DProxy);

			_stencilData[0] = pos.x;
			_stencilData[1] = pos.y;
			_stencilData[2] = pos.z;
			_stencilData[3] = light.fallOff;
			_stencilData[4] = _rttManager.textureRatioX;
			_stencilData[5] = _rttManager.textureRatioY;

			stage3DProxy.scissorRect = _rttManager.renderToTextureRect;
			context.setCulling(Context3DTriangleFace.FRONT);
			context.setVertexBufferAt(0, _sphereGeometry.getVertexBuffer(stage3DProxy), 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 4, camera.viewProjection, true);
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 8, _stencilData, 2);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _stencilFragmentColor, 1);

			// don't have depth data, so can't do proper depth-based stencil, only 2d area-of-effect :(
			// so *always* write fragment to stencil buffer
			context.setStencilActions(Context3DTriangleFace.FRONT_AND_BACK, Context3DCompareMode.ALWAYS, Context3DStencilAction.SET, Context3DStencilAction.SET, Context3DStencilAction.SET);
			stage3DProxy.setProgram(_stencilProgram);
			context.drawTriangles(_sphereGeometry.getIndexBuffer(stage3DProxy), 0, _sphereGeometry.numTriangles);
			stage3DProxy.scissorRect = null;
			context.setCulling(Context3DTriangleFace.BACK);
		}

		private function renderLight(stage3DProxy : Stage3DProxy, camera : Camera3D, light : PointLight, frustumCorners : Vector.<Number>) : void
		{
			var pos : Vector3D = camera.inverseSceneTransform.transformVector(light.scenePosition);
			var context : Context3D = stage3DProxy._context3D;
			var toTextureBuffer : VertexBuffer3D;

			toTextureBuffer = _rttManager.renderToTextureVertexBuffer;

			stage3DProxy.setTextureAt(0, _normalDepthBuffer);
			stage3DProxy.setTextureAt(1, _specularBuffer);

			context.setVertexBufferAt(0, toTextureBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			context.setVertexBufferAt(1, toTextureBuffer, 2, Context3DVertexBufferFormat.FLOAT_2);
			context.setVertexBufferAt(2, toTextureBuffer, 4, Context3DVertexBufferFormat.FLOAT_1);	// indices for frustum corners

			context.setStencilActions(Context3DTriangleFace.FRONT_AND_BACK, Context3DCompareMode.EQUAL);

			// todo: there's only monochrome specular light, but we can approximate the total specular colour to use from lights
			_lightData[0] = light._diffuseR;
			_lightData[1] = light._diffuseG;
			_lightData[2] = light._diffuseB;
			_lightData[3] = light.specular;
			_lightData[4] = pos.x;
			_lightData[5] = pos.y;
			_lightData[6] = pos.z;
			_lightData[12] = light._radius;
			_lightData[13] = light._fallOffFactor;
			_lightData[14] = camera.lens.far;

			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, frustumCorners, 4);

			if (light.castsShadows) {
				var f : Number = light._fallOff;
				_lightData[15] = 1/(2*f*f); // distance values were divided by 2*f*f for depth encoding, so do the same to test distance
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _lightData, 4);
				// used to transform light vector to world vector, for sampling world-space cube map
				context.setProgramConstantsFromMatrix(Context3DProgramType.FRAGMENT, 6, camera.sceneTransform, true);
				if (!_lightingProgramShadows) initLightingProgramShadows(stage3DProxy);
				stage3DProxy.setProgram(_lightingProgramShadows);
				stage3DProxy.setTextureAt(3, light.shadowMapper.depthMap.getTextureForStage3D(stage3DProxy));
				_shadowMapFilter.activate(stage3DProxy, light);
			}
			else {
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _lightData, 4);
				if (!_lightingProgram) initLightingProgram(stage3DProxy);
				stage3DProxy.setProgram(_lightingProgram);
			}

			context.drawTriangles(_rttManager.indexBuffer, 0, 2);

			stage3DProxy.setSimpleVertexBuffer(1, null, null);
			stage3DProxy.setSimpleVertexBuffer(2, null, null);
			stage3DProxy.setTextureAt(0, null);
			stage3DProxy.setTextureAt(1, null);
			if (light.castsShadows) {
				stage3DProxy.setTextureAt(3, null);
				_shadowMapFilter.deactivate(stage3DProxy);
			}
		}

		public function dispose() : void
		{
			for (var i : int = 0; i < 4; ++i) {
				if (_lightingProgram) _lightingProgram.dispose();
				if (_stencilProgram) _stencilProgram.dispose();
				if (_lightingProgramShadows) _lightingProgramShadows.dispose();
			}
			_lightingProgram = null;
			_stencilProgram = null;
			_lightingProgramShadows = null;
		}
	}
}
