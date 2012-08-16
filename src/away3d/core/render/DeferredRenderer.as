package away3d.core.render
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.base.IRenderable;
	import away3d.core.data.RenderableListItem;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.core.render.ambient.AmbientRendererBase;
	import away3d.core.render.light.DirectionalLightRenderer;
	import away3d.core.render.light.ILightRenderer;
	import away3d.core.render.light.PointLightRenderer;
	import away3d.core.render.quad.RenderCompositeSpecular;
	import away3d.core.render.quad.RenderCopy;
	import away3d.core.render.quad.RenderDebugDepth;
	import away3d.core.render.quad.RenderDebugNormals;
	import away3d.core.render.quad.RenderCompositeDiffuse;
	import away3d.core.render.quad.RenderHBlur;
	import away3d.core.render.quad.RenderVBlur;
	import away3d.core.traverse.DeferredEntityCollector;
	import away3d.core.traverse.EntityCollector;
	import away3d.debug.DeferredDebugMode;
	import away3d.lights.LightBase;
	import away3d.lights.shadowmaps.ShadowMapperBase;
	import away3d.materials.MaterialBase;
	import away3d.shadows.DirectionalShadowMapFilterBase;
	import away3d.shadows.PointShadowMapFilterBase;
	import away3d.textures.RenderCubeTexture;
	import away3d.textures.RenderTexture;
	import away3d.textures.TextureProxyBase;

	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.textures.TextureBase;
	import flash.events.Event;

	use namespace arcane;

	// TODO: encode "baked" property within albedo, which will indicate in how far lighting needs to be dynamic for that fragment (render skybox with baked)
	// TODO: toggle way for specular to be turned on or off
	// when adding reflections, use specular map to control reflection strength + only perform specular pass when specular or reflections are enabled
	// of course, lighting shaders need to be compiled conditionally
	public class DeferredRenderer extends RendererBase
	{
		private var _activeMaterial : MaterialBase;
		private var _gBuffer : Vector.<RenderTexture>;
		private var _lightAccumulationBuffer1 : RenderTexture;
		private var _lightAccumulationBuffer2 : RenderTexture;
		private var _gBufferInvalid : Boolean = true;
		private var _directionalLightRenderer : DirectionalLightRenderer;
		private var _pointLightRenderer : PointLightRenderer;
		private var _frustumCorners : Vector.<Number>;

		// debug shaders:
		private var _renderCompositeDiffuse : RenderCompositeDiffuse;
		private var _renderCompositeSpecular : RenderCompositeSpecular;
		private var _debugNormalsRender : RenderDebugNormals;
		private var _debugDepthRender : RenderDebugDepth;
		private var _copyRender : RenderCopy;

		private var _rttBufferManager : RTTBufferManager;

		private var _debugMode : String = "none";
		private var _distanceRenderer : DepthRenderer;
		// todo: should be able to use 2 cascades in one by using 16 bit depth, reducing max resolution to 2048x1024 and passes by 2
		private var _depthRenderer : DepthRenderer;
		private var _planarDepthMap : RenderTexture;
		private var _cubeDepthMap : RenderCubeTexture;
		private var _planarDepthMapSize : Number = 2048;
		private var _cubeDepthMapSize : Number = 256;

		private var _ambientRenderer : AmbientRendererBase;
		private var _hBlur : RenderHBlur;
		private var _vBlur : RenderVBlur;

		public function DeferredRenderer()
		{
			super(true);
			_directionalLightRenderer = new DirectionalLightRenderer();
			_pointLightRenderer = new PointLightRenderer();
			_backgroundAlpha = 0;
			_frustumCorners = new Vector.<Number>(16, true);
			_depthRenderer = new DepthRenderer();
			_distanceRenderer = new DepthRenderer(false, true);
		}

		override public function set antiAlias(antiAlias : uint) : void
		{
			super.antiAlias = antiAlias;
		}

		public function get ambientRenderer() : AmbientRendererBase
		{
			return _ambientRenderer;
		}

		public function set ambientRenderer(value : AmbientRendererBase) : void
		{
			if (_ambientRenderer) {
				_ambientRenderer.removeEventListener(AmbientRendererBase.BLUR_CHANGED, onAmbientBlurChanged);
				_ambientRenderer.dispose();
			}
			_ambientRenderer = value;
			if (value) {
				_ambientRenderer.addEventListener(AmbientRendererBase.BLUR_CHANGED, onAmbientBlurChanged);
				_ambientRenderer.stage3DProxy = _stage3DProxy;
			}

			setupAmbientBlur();
		}

		private function setupAmbientBlur() : void
		{
			if (!_stage3DProxy) return;

			if (_ambientRenderer && _ambientRenderer.blur > 0) {
				_hBlur ||= new RenderHBlur(_stage3DProxy);
				_vBlur ||= new RenderVBlur(_stage3DProxy);
				_hBlur.amount = _ambientRenderer.blur;
				_vBlur.amount = _ambientRenderer.blur;
			}
			else if (_hBlur) {
				_hBlur.dispose();
				_hBlur = null;
				_vBlur.dispose();
				_vBlur = null;
			}
		}

		private function onAmbientBlurChanged(event : Event) : void
		{
			setupAmbientBlur();
		}

		override arcane function createEntityCollector() : EntityCollector
		{
			return new DeferredEntityCollector();
		}

		public function get planarDepthMapSize() : Number
		{
			return _planarDepthMapSize;
		}

		public function set planarDepthMapSize(value : Number) : void
		{
			_planarDepthMapSize = value;
			if (_planarDepthMap) _planarDepthMap.width = _planarDepthMap.height = value;
		}

		public function get cubeDepthMapSize() : Number
		{
			return _cubeDepthMapSize;
		}

		public function set cubeDepthMapSize(value : Number) : void
		{
			_cubeDepthMapSize = value;
			if (_cubeDepthMap) _cubeDepthMap.size = value;
		}

		public function get debugMode() : String
		{
			return _debugMode;
		}

		public function set debugMode(value : String) : void
		{
			_debugMode = value;
		}

		arcane override function set stage3DProxy(value : Stage3DProxy) : void
		{
			super.stage3DProxy = value;
			_renderCompositeDiffuse = new RenderCompositeDiffuse(value);
			_renderCompositeSpecular = new RenderCompositeSpecular(value);
			_debugNormalsRender = new RenderDebugNormals(value);
			_debugDepthRender = new RenderDebugDepth(value);
			_copyRender = new RenderCopy(value);
			if (_ambientRenderer) _ambientRenderer.stage3DProxy = _stage3DProxy;

			_rttBufferManager = RTTBufferManager.getInstance(value);
			_rttBufferManager.addEventListener(Event.RESIZE, onRTTResize);
			_distanceRenderer.stage3DProxy = _depthRenderer.stage3DProxy = value;

			setupAmbientBlur();
		}

		private function onRTTResize(event : Event) : void
		{
			_gBufferInvalid = true;
		}

		public function get directionalShadowMapFilter() : DirectionalShadowMapFilterBase
		{
			return _directionalLightRenderer.shadowMapFilter;
		}

		public function set directionalShadowMapFilter(value : DirectionalShadowMapFilterBase) : void
		{
			_directionalLightRenderer.shadowMapFilter = value;
		}

		public function get pointShadowMapFilter() : PointShadowMapFilterBase
		{
			return _pointLightRenderer.shadowMapFilter;
		}

		public function set pointShadowMapFilter(value : PointShadowMapFilterBase) : void
		{
			_pointLightRenderer.shadowMapFilter = value;
		}

		override protected function executeRenderToTexturePass(entityCollector : EntityCollector) : void
		{
			updateFrustumCorners(entityCollector.camera);

			if (_gBufferInvalid) updateRenderTargets();

			if (_debugMode != DeferredDebugMode.ALBEDO) {
				renderGBuffer(entityCollector.opaqueRenderableHead, entityCollector);

				if (_debugMode != DeferredDebugMode.NONE && _debugMode != DeferredDebugMode.LIGHT_ACCUMULATION && _debugMode != DeferredDebugMode.AMBIENT_OCCLUSION)
					return;

				_stage3DProxy.scissorRect = null;
				renderLights(DeferredEntityCollector(entityCollector));
			}
		}

		arcane function getNormalDepthBuffer() : RenderTexture
		{
			return _gBuffer[0];
		}

		arcane function getSpecularBuffer() : RenderTexture
		{
			return _gBuffer[1];
		}

		/**
		 * Draw a list of renderables.
		 * @param renderables The renderables to draw.
		 * @param entityCollector The EntityCollector containing all potentially visible information.
		 */
		private function renderGBuffer(item : RenderableListItem, entityCollector : EntityCollector) : void
		{
			// normal+Depth, specular
			var numPasses : uint = 2;
			var camera : Camera3D = entityCollector.camera;
			var item2 : RenderableListItem;

			_context.setDepthTest(true, Context3DCompareMode.LESS);
			_context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);

			for (var i : uint = 0; i < numPasses; ++i) {
				_stage3DProxy.setRenderTarget(_gBuffer[i].getTextureForStage3D(stage3DProxy), true);
				_context.clear(1, 1, 1 ,1);
				_stage3DProxy.scissorRect = _rttBufferManager.renderToTextureRect;

				item2 = item;

				while (item2) {
					_activeMaterial = item2.renderable.material;

					if (_activeMaterial._classification != "deferred") {
						// skip current material if not deferred
						do {
							item2 = item2.next;
						} while (item2 && item2.renderable.material == _activeMaterial);
						continue;
					}

					_activeMaterial.updateMaterial(_context);
					_activeMaterial.activatePass(i, _stage3DProxy, camera, _textureRatioX, _textureRatioY);

					do {
						_activeMaterial.renderPass(i, item2.renderable, _stage3DProxy, entityCollector);
						item2 = item2.next;
					} while (item2 && item2.renderable.material == _activeMaterial);

					_activeMaterial.deactivatePass(i, _stage3DProxy);
				}
			}

			// last specular pass may have been using this
			_stage3DProxy.setTextureAt(0, null);
			_stage3DProxy.setTextureAt(1, null);
			_stage3DProxy.setSimpleVertexBuffer(1, null, null);
		}

		private function renderLights(entityCollector : DeferredEntityCollector) : void
		{
			_stage3DProxy.setRenderTarget(_lightAccumulationBuffer2.getTextureForStage3D(stage3DProxy));

			renderAmbient(entityCollector);

			if (_debugMode == DeferredDebugMode.AMBIENT_OCCLUSION)
				return;

			drawLightBatch(entityCollector.directionalLights, _directionalLightRenderer, entityCollector);
			drawLightBatch(entityCollector.pointLights, _pointLightRenderer, entityCollector);

			if (entityCollector.directionalCasterLights.length > 0) {
				_planarDepthMap ||= new RenderTexture(_planarDepthMapSize, _planarDepthMapSize);
				drawLightBatch(entityCollector.directionalCasterLights, _directionalLightRenderer, entityCollector, _planarDepthMap, _depthRenderer);
			}

			if (entityCollector.pointCasterLights.length > 0) {
				_cubeDepthMap ||= new RenderCubeTexture(_cubeDepthMapSize);
				drawLightBatch(entityCollector.pointCasterLights, _pointLightRenderer, entityCollector, _cubeDepthMap, _distanceRenderer);
			}
		}

		private function renderAmbient(entityCollector : DeferredEntityCollector) : void
		{
			var allLights : Vector.<LightBase> = entityCollector.lights;
			var ambientR : Number = 0, ambientG : Number = 0, ambientB : Number = 0;
			var len : uint = allLights.length;
			var light : LightBase;

			if (_debugMode == DeferredDebugMode.AMBIENT_OCCLUSION) {
				ambientR = 1;
				ambientG = 1;
				ambientB = 1;
			}
			else {
				for (var i : uint = 0; i < len; ++i) {
					light = allLights[i];
					ambientR += light._ambientR;
					ambientG += light._ambientG;
					ambientB += light._ambientB;
				}
			}

			if (_ambientRenderer) {
				_context.clear(.5, .5, .5, 0);
				_ambientRenderer.render(_gBuffer[0], _frustumCorners, entityCollector.camera, ambientR, ambientG, ambientB);
				if (_hBlur) {
					_hBlur.execute(_lightAccumulationBuffer2, _lightAccumulationBuffer1.getTextureForStage3D(_stage3DProxy));
					_vBlur.execute(_lightAccumulationBuffer1, _lightAccumulationBuffer2.getTextureForStage3D(_stage3DProxy));
				}
			}
			else {
				_context.clear(ambientR, ambientG, ambientB, 0);
			}
		}

		private function drawLightBatch(lights : *, renderer : ILightRenderer, entityCollector : DeferredEntityCollector, depthMap : TextureProxyBase = null, depthRenderer : DepthRenderer = null) : void
		{
			var len : uint = lights.length, i : uint;
			var light : LightBase;
			var shadowMapper : ShadowMapperBase;
			var camera : Camera3D = entityCollector.camera;
			var lightAccumBuffer1 : TextureBase = _lightAccumulationBuffer1.getTextureForStage3D(_stage3DProxy);
			var lightAccumBuffer2 : TextureBase = _lightAccumulationBuffer2.getTextureForStage3D(_stage3DProxy);
			var origAccumBuffer : TextureBase = lightAccumBuffer1;
			var temp : TextureBase;

			if (depthMap){
				_context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);

				for (i = 0; i < len; ++i) {
					// the following code alternates between two buffers because we need to call context.clear()
					// since rendering the depth map requires a new setRenderTarget call
					light = LightBase(lights[i]);

					shadowMapper = light.shadowMapper;
					shadowMapper.setDepthMap(depthMap);
					shadowMapper.renderDepthMap(_stage3DProxy, entityCollector, depthRenderer);

					_stage3DProxy.setRenderTarget(lightAccumBuffer1, false);
					_context.clear(0, 0, 0, 0);

					renderer.render(light, camera, _stage3DProxy, _frustumCorners, lightAccumBuffer2);

					temp = lightAccumBuffer2;
					lightAccumBuffer2 = lightAccumBuffer1;
					lightAccumBuffer1 = temp;
				}

				if (lightAccumBuffer2 == origAccumBuffer) {
					// swap active
					var tempRT : RenderTexture = _lightAccumulationBuffer1;
					_lightAccumulationBuffer1 = _lightAccumulationBuffer2;
					_lightAccumulationBuffer2 = tempRT;
				}
			}
			else {
				_context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);
				for (i = 0; i < len; ++i)
					renderer.render(LightBase(lights[i]), camera, _stage3DProxy, _frustumCorners);
			}
		}

		private function updateFrustumCorners(camera : Camera3D) : void
		{
			var frustumCorners : Vector.<Number> = camera.lens.frustumCorners;
			var j : uint, k : uint;

			while (j < 12) {
				_frustumCorners[k++] = frustumCorners[j++];
				_frustumCorners[k++] = frustumCorners[j++];
				_frustumCorners[k++] = frustumCorners[j++];
				_frustumCorners[k++] = 1.0;
			}
		}

		arcane function get frustumCorners() : Vector.<Number>
		{
			return _frustumCorners;
		}

		override protected function draw(entityCollector : EntityCollector, target : TextureBase) : void
		{
			switch (_debugMode) {
				case DeferredDebugMode.NORMALS:
					_debugNormalsRender.execute(_gBuffer[0], target);
					break;
				case DeferredDebugMode.DEPTH:
					_debugDepthRender.execute(_gBuffer[0], target);
					break;
				case DeferredDebugMode.LIGHT_ACCUMULATION:
				case DeferredDebugMode.AMBIENT_OCCLUSION:
					_copyRender.execute(_lightAccumulationBuffer2, target);
					break;
				case DeferredDebugMode.NORMALS_DEPTH:
					_copyRender.execute(_gBuffer[0], target);
					break;
				// todo: add specular and gloss separately, allow to pass single channel
				case DeferredDebugMode.SPECULAR:
					_copyRender.execute(_gBuffer[1], target);
					break;
				default:
					renderComposite(entityCollector, target);
			}
		}

		private function renderComposite(entityCollector : EntityCollector, target : TextureBase) : void
		{
			if (target)
				_stage3DProxy.scissorRect = _rttBufferManager.renderToTextureRect;
			else {
				_stage3DProxy.scissorRect = null;
				_textureRatioX = 1;
				_textureRatioY = 1;
			}

			_context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			_context.setStencilActions("front", "always", "set");

			// draw skybox as forward rendered
			_context.setStencilReferenceValue(0x00);

			if (entityCollector.skyBox) drawSkyBox(entityCollector);
			drawOpaques(entityCollector);

			if (_debugMode == DeferredDebugMode.ALBEDO) return;

			// apply light only for forward (stencil 0xff)
			_context.setStencilReferenceValue(0xff);
			_context.setStencilActions("front", "equal");
			_renderCompositeDiffuse.execute(_lightAccumulationBuffer2, target);
			_renderCompositeSpecular.execute(_lightAccumulationBuffer2, target);

			_context.setStencilActions();

			drawForwardBlended(entityCollector);
			_context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);

			_stage3DProxy.scissorRect = null;
		}

		// draw forward rendered elements opaque with stencil value 0x00
		// draw deferred elements with stencil value 0xff
		// later on, we'll run the light composition only if stencil == 0xff
		private function drawOpaques(entityCollector : EntityCollector) : void
		{
			var numPasses : uint;
			var j : uint;
			var camera : Camera3D = entityCollector.camera;
			var item2 : RenderableListItem;
			var item : RenderableListItem = entityCollector.opaqueRenderableHead;

			_context.setDepthTest(true, Context3DCompareMode.LESS);

			while (item) {
				_activeMaterial = item.renderable.material;

				if (_activeMaterial._classification == "deferred") {
					_context.setStencilReferenceValue(0xff);
					_activeMaterial.activatePass(2, stage3DProxy, camera, _textureRatioX, _textureRatioY);
					item2 = item;
					do {
						_activeMaterial.renderPass(2, item2.renderable, stage3DProxy, entityCollector);
						item2 = item2.next;
					} while (item2 && item2.renderable.material == _activeMaterial);
					_activeMaterial.deactivatePass(2, stage3DProxy);
				}
				else {
					_context.setStencilReferenceValue(0x00);
					_activeMaterial.updateMaterial(_context);

					numPasses = _activeMaterial.numPasses;
					j = 0;

					do {
						item2 = item;

						_activeMaterial.activatePass(j, _stage3DProxy, camera, _textureRatioX, _textureRatioY);
						do {
							_activeMaterial.renderPass(j, item2.renderable, _stage3DProxy, entityCollector);
							item2 = item2.next;
						} while (item2 && item2.renderable.material == _activeMaterial);
						_activeMaterial.deactivatePass(j, _stage3DProxy);

					} while (++j < numPasses);
				}

				item = item2;
			}
		}

		private function drawForwardBlended(entityCollector : EntityCollector) : void
		{
			var numPasses : uint;
			var j : uint;
			var camera : Camera3D = entityCollector.camera;
			var item2 : RenderableListItem;
			var item : RenderableListItem = entityCollector.blendedRenderableHead;

			_context.setDepthTest(false, Context3DCompareMode.LESS);

			while (item) {
				_activeMaterial = item.renderable.material;
				_activeMaterial.updateMaterial(_context);

				numPasses = _activeMaterial.numPasses;
				j = 0;

				do {
					item2 = item;

					// todo: if deferred is set here, pass composite buffer for refraction?

					_activeMaterial.activatePass(j, _stage3DProxy, camera, _textureRatioX, _textureRatioY);
					do {
						_activeMaterial.renderPass(j, item2.renderable, _stage3DProxy, entityCollector);
						item2 = item2.next;
					} while (item2 && item2.renderable.material == _activeMaterial);
					_activeMaterial.deactivatePass(j, _stage3DProxy);

				} while (++j < numPasses);

				item = item2;
			}
		}

		/**
		 * Draw the skybox if present.
		 * @param entityCollector The EntityCollector containing all potentially visible information.
		 */
		private function drawSkyBox(entityCollector : EntityCollector) : void
		{
			var skyBox : IRenderable = entityCollector.skyBox;
			var material : MaterialBase = skyBox.material;
			var camera : Camera3D = entityCollector.camera;

			material.activatePass(0, _stage3DProxy, camera, _textureRatioX, _textureRatioY);
			material.renderPass(0, skyBox, _stage3DProxy, entityCollector);
			material.deactivatePass(0, _stage3DProxy);
		}

		private function updateRenderTargets() : void
		{
			var i : uint;
			var textureWidth : int = _rttBufferManager.textureWidth;
			var textureHeight : int = _rttBufferManager.textureHeight;

			if (!_gBuffer) {
				_lightAccumulationBuffer1 = new RenderTexture(textureWidth, textureHeight);
				_lightAccumulationBuffer2 = new RenderTexture(textureWidth, textureHeight);
				_gBuffer = new Vector.<RenderTexture>(2, true);
				for (i = 0; i < 2; ++i)
					_gBuffer[i] = new RenderTexture(textureWidth, textureHeight);
			}
			else {
				_lightAccumulationBuffer1.width = textureWidth;
				_lightAccumulationBuffer1.height = textureHeight;
				_lightAccumulationBuffer2.width = textureWidth;
				_lightAccumulationBuffer2.height = textureHeight;
				for (i = 0; i < 2; ++i) {
					_gBuffer[i].width = textureWidth;
					_gBuffer[i].height = textureHeight;
				}
			}

			_gBufferInvalid = false;

			// set sources for lighting
			var normalDepthBuffer : TextureBase = _gBuffer[0].getTextureForStage3D(stage3DProxy);
			var specularBuffer : TextureBase = _gBuffer[1].getTextureForStage3D(stage3DProxy);

			_directionalLightRenderer.normalDepthBuffer = normalDepthBuffer;
			_directionalLightRenderer.specularBuffer = specularBuffer;
			_pointLightRenderer.normalDepthBuffer = normalDepthBuffer;
			_pointLightRenderer.specularBuffer = specularBuffer;
		}

		arcane override function dispose() : void
		{
			_directionalLightRenderer.dispose();
			_rttBufferManager.removeEventListener(Event.RESIZE, onRTTResize);

			for (var i : int = 0; i < 2; ++i) {
				_gBuffer[i].dispose();
			}

			_lightAccumulationBuffer1.dispose();
			_lightAccumulationBuffer2.dispose();
			_depthRenderer.dispose();
			_distanceRenderer.dispose();
			_pointLightRenderer.dispose();
			_directionalLightRenderer.dispose();
			if (_planarDepthMap) _planarDepthMap.dispose();
			if (_cubeDepthMap) _cubeDepthMap.dispose();
			if (_renderCompositeDiffuse) _renderCompositeDiffuse.dispose();
			if (_renderCompositeSpecular) _renderCompositeSpecular.dispose();
			if (_debugDepthRender) _debugDepthRender.dispose();
			if (_debugNormalsRender) _debugNormalsRender.dispose();
			if (_copyRender) _copyRender.dispose();
			if (_ambientRenderer) {
				_ambientRenderer.dispose();
				_ambientRenderer.removeEventListener(AmbientRendererBase.BLUR_CHANGED, onAmbientBlurChanged);
			}
			if (_hBlur) _hBlur.dispose();
			if (_vBlur) _vBlur.dispose();

			_gBuffer = null;
			_depthRenderer = null;
			_distanceRenderer = null;
			_lightAccumulationBuffer1 = null;
			_lightAccumulationBuffer2 = null;
			_pointLightRenderer = null;
			_directionalLightRenderer = null;
			_planarDepthMap = null;
			_cubeDepthMap = null;
			_renderCompositeDiffuse = null;
			_renderCompositeSpecular = null;
			_debugDepthRender = null;
			_debugNormalsRender = null;
			_copyRender = null;
			_ambientRenderer = null;
			_hBlur = null;
			_vBlur = null;

			super.dispose();
		}
	}
}