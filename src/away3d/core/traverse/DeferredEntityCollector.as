package away3d.core.traverse
{
	import away3d.arcane;
	import away3d.core.base.IRenderable;
	import away3d.core.data.RenderableListItem;
	import away3d.lights.DirectionalLight;
	import away3d.lights.PointLight;
	import away3d.materials.MaterialBase;

	use namespace arcane;

	public class DeferredEntityCollector extends EntityCollector
	{
		private var _directionalCasterLights : Vector.<DirectionalLight>;
		private var _pointCasterLights : Vector.<PointLight>;
		private var _deferredRenderables : Vector.<IRenderable>;

		private var _numDirCasters : uint;
		private var _numPointCasters : uint;

		private var _numDeferred : uint;

		public function DeferredEntityCollector()
		{
			super();
			_directionalCasterLights = new Vector.<DirectionalLight>();
			_pointCasterLights = new Vector.<PointLight>();
			_deferredRenderables = new Vector.<IRenderable>();
		}

		public function get directionalCasterLights() : Vector.<DirectionalLight>
		{
			return _directionalCasterLights;
		}

		public function get pointCasterLights() : Vector.<PointLight>
		{
			return _pointCasterLights;
		}

		override public function applyPointLight(light : PointLight) : void
		{
			if (light.castsShadows) {
				_pointCasterLights[_numPointCasters++] = light;
				_lights[_numLights++] = light;
			}
			else super.applyPointLight(light);
		}

		override public function applyDirectionalLight(light : DirectionalLight) : void
		{
			if (light.castsShadows) {
				_directionalCasterLights[_numDirCasters++] = light;
				_lights[_numLights++] = light;
			}
			else super.applyDirectionalLight(light);
		}


		override public function clear() : void
		{
			super.clear();
			if (_numPointCasters > 0) _pointCasterLights.length = _numPointCasters = 0;
			if (_numDirCasters > 0) _directionalCasterLights.length = _numDirCasters = 0;
			if (_numDeferred > 0) _deferredRenderables.length = _numDeferred = 0;
		}
	}
}
